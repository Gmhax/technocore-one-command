import express from "express";
import { createHash } from "node:crypto";

/**
 * Read-only proxy in front of technocore.chat.
 *
 * It exists for three reasons: a browser cannot read the upstream host
 * directly, upstream meters reads per IP so many open tabs have to share one
 * fetch, and everything it relays is anonymous input that must be bounded and
 * validated before it reaches the page.
 */
const TECHNOCORE_URL = "https://technocore.chat";
const TECHNOCORE_ROOMS = ["lobby", "technocore", "flop", "kibble", "validators", "gpu-miners"];
// Upstream caps a single read at 200 messages; ask for the maximum so the
// visualizer sees as many distinct agents per poll as the protocol allows.
const TECHNOCORE_MESSAGE_LIMIT = 200;
// Technocore caches /rooms for 3s and edges for 1s, and meters reads per key.
// Cache just under that so many browser tabs cost one upstream read.
const TECHNOCORE_ROOM_TTL_MS = 2500;
// The room index is a heavy upstream page (~26k rooms) and only feeds the room
// cards, which do not need per-poll freshness.
const TECHNOCORE_INDEX_TTL_MS = 10000;
const TECHNOCORE_CONFIG_TTL_MS = 60000;
const TECHNOCORE_TIMEOUT_MS = 9000;

type TechnocoreRoomSummary = {
  room: string;
  seq: number;
  bytes: string;
  idle: string;
  topic: string;
};

type TechnocoreMessage = {
  seq: number;
  ts: string;
  from: string;
  text: string;
  room?: string;
};

type TechnocoreRoomPayload = {
  room?: string;
  count?: number;
  first_seq?: number;
  last_seq?: number;
  messages?: TechnocoreMessage[];
};

type TechnocoreConfig = { version?: string; settings?: Record<string, unknown> };

/**
 * Bounded so a caller that varies `since` on every request cannot grow the
 * cache without limit. Entries are small, and only a handful of distinct keys
 * are ever useful at once.
 */
const TECHNOCORE_CACHE_MAX = 64;
const technocoreCache = new Map<string, { expires: number; inflight: Promise<unknown> }>();

/**
 * Share one upstream request between every caller that asks for the same key
 * inside the TTL. Failures are not cached, so an outage retries immediately.
 */
function cachedFetch<T>(key: string, ttlMs: number, load: () => Promise<T>): Promise<T> {
  const now = Date.now();
  const hit = technocoreCache.get(key);
  if (hit && hit.expires > now) {
    return hit.inflight as Promise<T>;
  }

  for (const [existing, entry] of technocoreCache) {
    if (entry.expires <= now) technocoreCache.delete(existing);
  }
  while (technocoreCache.size >= TECHNOCORE_CACHE_MAX) {
    // Map preserves insertion order, so the first key is the oldest.
    const oldest = technocoreCache.keys().next();
    if (oldest.done) break;
    technocoreCache.delete(oldest.value);
  }

  const entry: { expires: number; inflight: Promise<unknown> } = {
    expires: now + ttlMs,
    inflight: Promise.resolve()
  };
  entry.inflight = load().catch((error: unknown) => {
    // Only drop this entry — a slow rejection must not evict a fresher one
    // that replaced it in the meantime.
    if (technocoreCache.get(key) === entry) technocoreCache.delete(key);
    throw error;
  });
  technocoreCache.set(key, entry);
  return entry.inflight as Promise<T>;
}

export function createTechnocoreRouter(): express.Router {
  const router = express.Router();

  router.get("/technocore/agent", async (request, response, next) => {
    try {
      const requestedDid = String(request.query.did ?? "").trim();

      if (!/^did:key:z[1-9A-HJ-NP-Za-km-z]+$/.test(requestedDid)) {
        response.status(400).json({ ok: false, error: "Invalid did:key." });
        return;
      }

      const key = requestedDid.slice("did:key:".length);
      const bytes = base58btcDecode(key.slice(1));

      if (bytes.length < 3 || bytes[0] !== 0xed || bytes[1] !== 0x01) {
        response.status(400).json({
          ok: false,
          error: "Unsupported did:key fingerprint."
        });
        return;
      }

      const ed25519Fingerprint = Buffer.from(bytes.slice(2)).toString("hex");

      if (!/^[0-9a-f]{64}$/.test(ed25519Fingerprint)) {
        response.status(400).json({
          ok: false,
          error: "Invalid Ed25519 fingerprint."
        });
        return;
      }

      // Technocore's published DID profile path uses SHA-256(DID),
      // truncated to the first 16 hex characters, matching setup.sh.
      const fingerprint = createHash("sha256")
        .update(requestedDid, "utf8")
        .digest("hex")
        .slice(0, 16);

      const shard = fingerprint.slice(0, 2);
      const remainder = fingerprint.slice(2);
      const profilePath = `/kv/did-${shard}/${remainder}`;

      console.log("[DID DEBUG]", {
        did: requestedDid,
        ed25519Fingerprint,
        fingerprint,
        shard,
        remainder,
        profilePath
      });

      const profile = await fetchTechnocoreText(profilePath);

      response.json({
        ok: true,
        did: requestedDid,
        fingerprint,
        profilePath,
        profile: sanitiseForVisualizer(profile).slice(0, 4000)
      });
    } catch (error) {
      if (error instanceof Error && /HTTP 404/.test(error.message)) {
        response.status(404).json({
          ok: false,
          error: "DID profile not found."
        });
        return;
      }

      next(error);
    }
  });

  router.get("/technocore/live", async (request, response, next) => {
    try {
      const requested = normalizeTechnocoreRoom(String(request.query.room ?? ""));
      // Only the curated rooms are proxied, so this endpoint can never be used
      // to enumerate arbitrary upstream rooms through the local server.
      const selectedRoom = requested && TECHNOCORE_ROOMS.includes(requested) ? requested : "lobby";
      // Upstream's incremental parameter is `since`, not `after`; an unknown
      // parameter is silently ignored and would refetch the whole window.
      const since = Number.parseInt(String(request.query.since ?? ""), 10);
      const hasSince = Number.isSafeInteger(since) && since > 0;
      // `/rooms` already reports seq, size and idle time for every room, so the
      // room cards need no extra per-room reads: 2 upstream calls, not 8.
      const messagePath = `/r/${selectedRoom}?format=json&limit=${TECHNOCORE_MESSAGE_LIMIT}${hasSince ? `&since=${since}` : ""}`;
      const [configResult, roomsResult, payloadResult] = await Promise.allSettled([
        cachedFetch(`config`, TECHNOCORE_CONFIG_TTL_MS, () => fetchTechnocoreJson<TechnocoreConfig>("/config")),
        cachedFetch(`rooms`, TECHNOCORE_INDEX_TTL_MS, () => fetchTechnocoreText("/rooms")),
        cachedFetch(`msg:${messagePath}`, TECHNOCORE_ROOM_TTL_MS, () =>
          fetchTechnocoreJson<TechnocoreRoomPayload>(messagePath)
        )
      ]);

      const config = configResult.status === "fulfilled" ? configResult.value : {};
      const roomsText = roomsResult.status === "fulfilled" ? roomsResult.value : "";
      const payload = payloadResult.status === "fulfilled" ? payloadResult.value : undefined;

      const rooms = parseTechnocoreRooms(roomsText);
      // Everything below the proxy is anonymous, unauthenticated input, so each
      // field is bounded and coerced here rather than trusted downstream.
      const stampFloor = Date.now() - 24 * 3600_000;
      const stampCeiling = Date.now() + 60_000;
      const messages = (payload?.messages ?? []).map((message) => {
        const parsed = Date.parse(String(message.ts ?? ""));
        // A single out-of-range timestamp would otherwise anchor the client's
        // history axis and blank every real bucket around it.
        const ts =
          Number.isFinite(parsed) && parsed >= stampFloor && parsed <= stampCeiling
            ? new Date(parsed).toISOString()
            : new Date().toISOString();
        return {
          room: selectedRoom,
          seq: Number(message.seq) || 0,
          ts,
          from: sanitiseForVisualizer(String(message.from ?? "")).slice(0, 128),
          text: truncateForVisualizer(message.text)
        };
      });

      // Report upstream trouble instead of returning an empty room that the UI
      // would otherwise render as "a quiet room".
      const warnings: string[] = [];
      if (roomsResult.status === "rejected") warnings.push(`Room index unavailable: ${reasonText(roomsResult.reason)}`);
      if (configResult.status === "rejected") warnings.push(`Config unavailable: ${reasonText(configResult.reason)}`);

      response.json({
        ok: payloadResult.status === "fulfilled",
        error: payloadResult.status === "rejected" ? reasonText(payloadResult.reason) : null,
        warnings,
        source: TECHNOCORE_URL,
        fetchedAt: new Date().toISOString(),
        selectedRoom,
        messageLimit: TECHNOCORE_MESSAGE_LIMIT,
        // Room names and topics are strings their creators chose. Upstream
        // flags them as untrusted; the UI must render them as data only.
        topicsUntrusted: true,
        config: { version: config.version, settings: config.settings },
        room: {
          room: selectedRoom,
          count: payload?.count ?? messages.length,
          firstSeq: payload?.first_seq ?? 0,
          lastSeq: payload?.last_seq ?? 0,
          // Upstream convention: first_seq > since + 1 means the room moved
          // faster than one window, so this poll is a sample, not the full tape.
          skipped: hasSince && payload?.first_seq ? Math.max(0, payload.first_seq - since - 1) : 0
        },
        rooms,
        messages,
        trackedRooms: TECHNOCORE_ROOMS
      });
    } catch (error) {
      next(error);
    }
  });

  return router;
}

/**
 * Strips C0/C1 controls plus the bidi overrides and isolates. Without this a
 * poster can end a line with U+202E and make the rest of it render reversed,
 * so a tape entry reads as something other than what it says.
 */
function sanitiseForVisualizer(value: string): string {
  return String(value || "")
    .replace(/[\u0000-\u001F\u007F-\u009F\u200B-\u200F\u202A-\u202E\u2066-\u2069]/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

function truncateForVisualizer(value: string): string {
  const text = sanitiseForVisualizer(value);
  return text.length > 180 ? `${text.slice(0, 177)}...` : text;
}

async function fetchTechnocoreText(path: string): Promise<string> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), TECHNOCORE_TIMEOUT_MS);
  try {
    const response = await fetch(`${TECHNOCORE_URL}${path}`, {
      headers: { Accept: "text/plain, application/json" },
      signal: controller.signal
    });
    if (!response.ok) {
      throw new Error(`Technocore returned HTTP ${response.status}.`);
    }
    return await response.text();
  } finally {
    clearTimeout(timer);
  }
}

async function fetchTechnocoreJson<T>(path: string): Promise<T> {
  return JSON.parse(await fetchTechnocoreText(path)) as T;
}

function normalizeTechnocoreRoom(value: string): string | undefined {
  const room = value.trim().toLowerCase();
  return /^[a-z0-9][a-z0-9_-]{0,47}$/.test(room) ? room : undefined;
}

function base58btcDecode(value: string): Uint8Array {
  const alphabet = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz";
  let number = 0n;

  for (const character of value) {
    const digit = alphabet.indexOf(character);
    if (digit < 0) throw new Error("Invalid base58btc DID.");
    number = number * 58n + BigInt(digit);
  }

  const hex = number.toString(16);
  const padded = hex.length % 2 ? `0${hex}` : hex;
  const decoded = new Uint8Array(padded.length / 2);

  for (let i = 0; i < decoded.length; i += 1) {
    decoded[i] = Number.parseInt(
      padded.slice(i * 2, i * 2 + 2),
      16
    );
  }

  let leadingZeroes = 0;
  for (const character of value) {
    if (character !== "1") break;
    leadingZeroes += 1;
  }

  if (!leadingZeroes) return decoded;

  const result = new Uint8Array(leadingZeroes + decoded.length);
  result.set(decoded, leadingZeroes);
  return result;
}

function reasonText(reason: unknown): string {
  return reason instanceof Error ? reason.message : "Request failed.";
}

function parseTechnocoreRooms(text: string): TechnocoreRoomSummary[] {
  const rooms: TechnocoreRoomSummary[] = [];
  for (const line of text.split("\n")) {
    const match = line.match(/^\/r\/([a-z0-9][a-z0-9_-]{0,47})\s+seq\s+(\d+)\s+(\S+)\s+(.+? ago)(?:\s+·\s+(.*))?$/);
    if (!match) continue;
    const [, room = "", seq = "0", bytes = "", idle = "", topic = ""] = match;
    rooms.push({
      room,
      seq: Number(seq),
      bytes,
      idle,
      topic
    });
  }
  return rooms;
}
