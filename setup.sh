#!/usr/bin/env bash

set -e

REPO_URL="https://github.com/Gmhax/technocore-one-command.git"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="$ROOT_DIR/technocore-did-starter"
LOBBY="lobby"
BASE_URL="https://technocore.chat"

echo "=========================================="
echo "  Technocore One-Command Agent Setup"
echo "  (Updated for Sharded DID + Mailbox Reuse)"
echo "=========================================="
echo

# ==========================================
# STEP 1: Check requirements
# ==========================================

if ! command -v python3 >/dev/null 2>&1; then
    echo "Error: Python 3 is not installed."
    exit 1
fi

if ! command -v git >/dev/null 2>&1; then
    echo "Error: Git is not installed."
    exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
    echo "Error: curl is not installed."
    exit 1
fi

echo "[1/8] Environment"
python3 --version
git --version
echo

# ==========================================
# STEP 2: Clone own Technocore starter
# ==========================================

if [ -d "$INSTALL_DIR" ]; then
    echo "[2/8] Existing Technocore folder found."
    echo "      Keeping the existing installation."
else
    echo "[2/8] Downloading Technocore DID starter..."
    git clone "$REPO_URL" "$INSTALL_DIR"
fi

cd "$INSTALL_DIR"

echo

# ==========================================
# STEP 3: Create virtual environment
# ==========================================

echo "[3/8] Creating Python virtual environment..."

if [ ! -d ".venv" ]; then
    python3 -m venv .venv
fi

source .venv/bin/activate

echo

# ==========================================
# STEP 4: Install dependencies
# ==========================================

echo "[4/8] Installing dependencies..."

python -m pip install --upgrade pip
python -m pip install -r requirements.txt

echo

# ==========================================
# STEP 5: Agent information
# ==========================================

echo "=========================================="
echo "  Agent Information"
echo "=========================================="
echo

CONFIG_FILE=".agent-config"

# ------------------------------------------
# Load existing configuration if available
# ------------------------------------------

if [ -f "$CONFIG_FILE" ]; then

    echo "Existing agent configuration found."
    echo "Loading saved agent information..."
    echo

    # shellcheck disable=SC1090
    source "$CONFIG_FILE"

else

    echo "No existing agent configuration found."
    echo "Enter your agent information."
    echo

    read -r -p "Agent name: " AGENT_NAME

    if [ -z "$AGENT_NAME" ]; then
        echo "Error: Agent name cannot be empty."
        exit 1
    fi

    read -r -p "X handle (optional, without @): " X_HANDLE

    # Contribution is optional during initial setup.
    CONTRIBUTION_TYPE=""
    CONTRIBUTION_URL=""
    CONTRIBUTION_SUMMARY=""

    umask 077

    cat > "$CONFIG_FILE" <<EOF
AGENT_NAME=$(printf '%q' "$AGENT_NAME")
X_HANDLE=$(printf '%q' "$X_HANDLE")
CONTRIBUTION_TYPE=$(printf '%q' "$CONTRIBUTION_TYPE")
CONTRIBUTION_URL=$(printf '%q' "$CONTRIBUTION_URL")
CONTRIBUTION_SUMMARY=$(printf '%q' "$CONTRIBUTION_SUMMARY")
EOF

    echo
    echo "Agent configuration saved locally."

fi

# ------------------------------------------
# Validate loaded configuration
# ------------------------------------------

if [ -z "$AGENT_NAME" ]; then
    echo "Error: Agent name cannot be empty."
    exit 1
fi

echo
echo "Agent:"
echo "  Name: $AGENT_NAME"
echo "  X:    ${X_HANDLE:-none}"
echo

# ------------------------------------------
# NEW CONTRIBUTION PROMPT
# ------------------------------------------
# Existing contribution records are preserved.
# A new contribution is stored separately.
# ------------------------------------------

read -r -p "Do you have a NEW contribution/guide? [y/N]: " HAS_NEW_CONTRIBUTION

case "$HAS_NEW_CONTRIBUTION" in
    y|Y|yes|YES|Yes)

        echo
        echo "Contribution types:"
        echo "  tool"
        echo "  guide"
        echo "  video"
        echo "  article"
        echo "  agent"
        echo "  prompt"
        echo "  other"
        echo

        read -r -p "Contribution type: " NEW_CONTRIBUTION_TYPE

        if [ -z "$NEW_CONTRIBUTION_TYPE" ]; then
            echo "Error: Contribution type cannot be empty."
            exit 1
        fi

        read -r -p "Contribution URL (optional): " NEW_CONTRIBUTION_URL
        read -r -p "Contribution summary: " NEW_CONTRIBUTION_SUMMARY

        if [ -z "$NEW_CONTRIBUTION_SUMMARY" ]; then
            echo "Error: Contribution summary cannot be empty."
            exit 1
        fi

        CONTRIBUTION_TYPE="$NEW_CONTRIBUTION_TYPE"
        CONTRIBUTION_URL="$NEW_CONTRIBUTION_URL"
        CONTRIBUTION_SUMMARY="$NEW_CONTRIBUTION_SUMMARY"
        HAS_NEW_CONTRIBUTION="yes"

        ;;

    *)
        HAS_NEW_CONTRIBUTION="no"

        echo
        echo "No new contribution provided."
        echo "Existing contribution records will be preserved."
        echo

        ;;
esac

echo
echo "Contribution input:"
if [ "$HAS_NEW_CONTRIBUTION" = "yes" ]; then
    echo "  Type: $CONTRIBUTION_TYPE"
    echo "  URL:  ${CONTRIBUTION_URL:-none}"
    echo "  Summary: $CONTRIBUTION_SUMMARY"
else
    echo "  No new contribution."
fi
echo

# ==========================================
# STEP 6: Create or load DID
# ==========================================

echo "=========================================="
echo "  Identity"
echo "=========================================="
echo

if [ -f "identity.pem" ]; then
    echo "Existing identity.pem found."
    echo "Your existing DID will be preserved."
else
    echo "No identity found."
    echo "Create your encrypted Technocore DID now."
    echo

    python technocore_agent.py init
fi

echo

DID=$(python technocore_agent.py did)

echo "Public DID:"
echo "$DID"
echo

# ==========================================
# Fingerprint + Shard
# ==========================================

FP=$(printf '%s' "$DID" | sha256sum | cut -c1-16)
SHARD=${FP:0:2}
KEY=${FP:2}

echo "Fingerprint:"
echo "$FP"
echo "Sharded path: /kv/did-$SHARD/$KEY"
echo

# ==========================================
# URL encode helper
# ==========================================

urlencode() {
    python3 -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1], safe=""))' "$1"
}

# ==========================================
# FIND EXISTING MAILBOX
# ==========================================
find_existing_mailbox() {

    ROOMS_RESPONSE=$(curl -sS "$BASE_URL/rooms" 2>/dev/null || true)

    if [ -z "$ROOMS_RESPONSE" ]; then
        return 1
    fi

    ROOM_NAMES=$(printf '%s' "$ROOMS_RESPONSE" | python3 -c '
import sys
import json
import re

data = sys.stdin.read()
names = set()

def walk(obj):
    if isinstance(obj, dict):
        for k, v in obj.items():
            if k in ("room", "name", "id"):
                if isinstance(v, str) and re.fullmatch(r"mb-p-[a-f0-9]{24}", v):
                    names.add(v)
            walk(v)

    elif isinstance(obj, list):
        for item in obj:
            walk(item)

    elif isinstance(obj, str):
        for match in re.findall(r"mb-p-[a-f0-9]{24}", obj):
            names.add(match)

try:
    parsed = json.loads(data)
    walk(parsed)
except Exception:
    for match in re.findall(r"mb-p-[a-f0-9]{24}", data):
        names.add(match)

for name in sorted(names):
    print(name)
' 2>/dev/null || true)

    if [ -z "$ROOM_NAMES" ]; then
        return 1
    fi

    while IFS= read -r CANDIDATE_ROOM; do

        [ -z "$CANDIDATE_ROOM" ] && continue

        ROOM_DATA=$(curl -sS \
            "$BASE_URL/r/$CANDIDATE_ROOM" \
            2>/dev/null || true)

        if [ -z "$ROOM_DATA" ]; then
            continue
        fi

        if printf '%s' "$ROOM_DATA" | grep -Fq "$DID" &&
           printf '%s' "$ROOM_DATA" | grep -Fq "mailbox-online-v1"; then

            printf '%s\n' "$CANDIDATE_ROOM"
            return 0

        fi

    done <<< "$ROOM_NAMES"

    return 1
}

# ==========================================
# STEP 7: MAILBOX
# ==========================================

echo "=========================================="
echo "  Agent Mailbox"
echo "=========================================="
echo

MAILBOX_FILE=".mailbox"
MAILBOX=""

# ------------------------------------------
# FIRST: Reuse persisted mailbox
# ------------------------------------------

if [ -f "$MAILBOX_FILE" ]; then

    SAVED_MAILBOX=$(tr -d '[:space:]' < "$MAILBOX_FILE")

    if printf '%s' "$SAVED_MAILBOX" | grep -qE '^mb-p-[a-f0-9]{24}$'; then

        echo "Existing mailbox record found:"
        echo "/r/$SAVED_MAILBOX"
        echo "Verifying mailbox ownership..."
        echo

        SAVED_ROOM_DATA=$(curl -sS \
            "$BASE_URL/r/$SAVED_MAILBOX" \
            2>/dev/null || true)

        if printf '%s' "$SAVED_ROOM_DATA" | grep -Fq "$DID" &&
           printf '%s' "$SAVED_ROOM_DATA" | grep -Fq "mailbox-online-v1"; then

            MAILBOX="$SAVED_MAILBOX"

            echo "Existing mailbox verified."
            echo "Reusing existing mailbox:"
            echo "/r/$MAILBOX"
            echo

        else

            echo "Saved mailbox is not valid for this DID."
            echo "Searching for another existing mailbox..."
            echo

        fi

    else

        echo "Saved mailbox record is invalid."
        echo "Searching for another existing mailbox..."
        echo

    fi

fi

# ------------------------------------------
# SECOND: Discover existing mailbox
# ------------------------------------------

if [ -z "$MAILBOX" ]; then

    EXISTING_MAILBOX=$(find_existing_mailbox || true)

    if [ -n "$EXISTING_MAILBOX" ]; then

        MAILBOX="$EXISTING_MAILBOX"

        printf '%s\n' "$MAILBOX" > "$MAILBOX_FILE"
        chmod 600 "$MAILBOX_FILE"

        echo "Existing mailbox found:"
        echo "/r/$MAILBOX"
        echo "Saved mailbox for future runs."
        echo

    fi

fi

# ------------------------------------------
# THIRD: Create mailbox ONLY if none exists
# ------------------------------------------

if [ -z "$MAILBOX" ]; then

    echo "No existing mailbox found."
    echo "Attempting to create a new mailbox..."
    echo

    NEW_MAILBOX="mb-p-$(python3 -c 'import secrets; print(secrets.token_hex(12))')"

    MAILBOX_TEXT="mailbox-online-v1 agent:$AGENT_NAME did:$DID profile:/kv/did-$SHARD/$KEY"

    echo "Generated mailbox:"
    echo "/r/$NEW_MAILBOX"
    echo

    set +e

    NEW_MAILBOX_RESPONSE=$(python technocore_agent.py say \
        "$NEW_MAILBOX" \
        "$MAILBOX_TEXT" \
        2>&1)

    NEW_MAILBOX_STATUS=$?

    set -e

    if [ "$NEW_MAILBOX_STATUS" -eq 0 ]; then

        MAILBOX="$NEW_MAILBOX"

        printf '%s\n' "$MAILBOX" > "$MAILBOX_FILE"
        chmod 600 "$MAILBOX_FILE"

        echo "New mailbox created successfully."
        echo "$NEW_MAILBOX_RESPONSE"
        echo
        echo "Mailbox saved for future runs."

    else

        echo "Initial mailbox request returned an error:"
        echo "$NEW_MAILBOX_RESPONSE"
        echo

        if printf '%s' "$NEW_MAILBOX_RESPONSE" | grep -qiE \
            "timed out|timeout|outcome is unknown"; then

            echo "Checking whether the mailbox was created despite the timeout..."
            echo

            NEW_ROOM_DATA=$(curl -sS \
                "$BASE_URL/r/$NEW_MAILBOX" \
                2>/dev/null || true)

            if printf '%s' "$NEW_ROOM_DATA" | grep -Fq "$DID" &&
               printf '%s' "$NEW_ROOM_DATA" | grep -Fq "mailbox-online-v1"; then

                MAILBOX="$NEW_MAILBOX"

                printf '%s\n' "$MAILBOX" > "$MAILBOX_FILE"
                chmod 600 "$MAILBOX_FILE"

                echo "Mailbox creation succeeded despite the timeout."
                echo "Using:"
                echo "/r/$MAILBOX"
                echo

            fi

        fi

        if [ -z "$MAILBOX" ]; then

            echo "WARNING: Mailbox setup failed (timeout or empty room)."
            echo "Continuing without a verified mailbox room message."
            echo "Profile may still reference the old mailbox path."
            echo "Activity/ACTIVE status uses kibble/lobby posts, not mailbox."
            echo
            echo "$NEW_MAILBOX_RESPONSE"
            echo

            # Prefer saved/old mailbox name if present (do not invent another).
            if [ -f "$MAILBOX_FILE" ]; then
                SAVED_MAILBOX=$(tr -d '[:space:]' < "$MAILBOX_FILE")
                if printf '%s' "$SAVED_MAILBOX" | grep -qE '^mb-p-[a-f0-9]{24}$'; then
                    MAILBOX="$SAVED_MAILBOX"
                    echo "Reusing saved mailbox name for profile continuity:"
                    echo "  /r/$MAILBOX"
                    echo
                fi
            fi

        fi

    fi

fi

# STEP 8: EXISTING RECORD DETECTION
# ==========================================

echo "=========================================="
echo "  Checking Existing Technocore Records"
echo "=========================================="
echo

DID_PATH="$BASE_URL/kv/did-$SHARD/$KEY"

# ------------------------------------------
# Contribution paths
# ------------------------------------------
# The original contribution record is preserved.
# New contributions receive their own unique key.
# ------------------------------------------

LEGACY_CONTRIB_PATH="$BASE_URL/kv/contrib/$FP"
CONTRIB_PATH="$LEGACY_CONTRIB_PATH"

if [ "${HAS_NEW_CONTRIBUTION:-no}" = "yes" ]; then

    NEW_CONTRIB_SUFFIX=$(python3 -c 'import secrets; print(secrets.token_hex(6))')
    NEW_CONTRIB_KEY="${FP}-${NEW_CONTRIB_SUFFIX}"

    CONTRIB_PATH="$BASE_URL/kv/contrib/$NEW_CONTRIB_KEY"

    echo
    echo "New contribution record will use:"
    echo "  $CONTRIB_PATH"
    echo
    echo "Previous contribution will be preserved:"
    echo "  $LEGACY_CONTRIB_PATH"
    echo

fi

# ------------------------------------------
# Check existing DID profile
# ------------------------------------------

echo "[1/4] Checking DID profile..."

EXISTING_PROFILE=$(curl -sS "$DID_PATH" 2>/dev/null || true)

if printf '%s' "$EXISTING_PROFILE" | grep -Fq "did:$DID" &&
   printf '%s' "$EXISTING_PROFILE" | grep -Fq "agent:$AGENT_NAME" &&
   printf '%s' "$EXISTING_PROFILE" | grep -Fq "mailbox:$MAILBOX"; then

    HAS_PROFILE="yes"
    echo "      Existing matching DID profile found."

else

    HAS_PROFILE="no"

    if [ -n "$EXISTING_PROFILE" ]; then
        echo "      Existing DID profile found, but mailbox is stale."
        echo "      It will be updated with the current mailbox."
    else
        echo "      No matching DID profile found."
    fi

fi

echo

# ------------------------------------------
# Check existing contribution
# ------------------------------------------

echo "[2/4] Checking contribution..."

# Always inspect the legacy contribution record.
# A new contribution must never overwrite this record.

EXISTING_CONTRIBUTION=$(curl -sS "$LEGACY_CONTRIB_PATH" 2>/dev/null || true)

if printf '%s' "$EXISTING_CONTRIBUTION" | grep -Fq "did:$DID" &&
   printf '%s' "$EXISTING_CONTRIBUTION" | grep -Fq "agent:$AGENT_NAME"; then

    HAS_CONTRIBUTION="yes"

    echo "      Existing contribution found."
    echo "      Legacy contribution will be preserved."

else

    HAS_CONTRIBUTION="no"

    if [ -n "$EXISTING_CONTRIBUTION" ]; then
        echo "      Contribution record exists, but does not match this agent."
    else
        echo "      No existing contribution found."
    fi

fi

echo

# ------------------------------------------
# Mailbox was already resolved above
# ------------------------------------------

echo "[3/4] Mailbox..."

if [ -n "$MAILBOX" ]; then
    echo "      Using existing/resolved mailbox: $MAILBOX"
else
    echo "      WARNING: No verified mailbox room. Continuing setup."
    echo "      (ACTIVE status does not require mailbox write success.)"
fi

echo

# ------------------------------------------
# Check lobby for existing proof
# ------------------------------------------

echo "[4/4] Checking lobby proof..."

HAS_LOBBY_PROOF="no"
LOBBY_SINCE=""

while true; do

    if [ -n "$LOBBY_SINCE" ]; then
        LOBBY_CHECK=$(curl -sS \
            "$BASE_URL/r/$LOBBY?since=$LOBBY_SINCE" \
            2>/dev/null || true)
    else
        LOBBY_CHECK=$(curl -sS \
            "$BASE_URL/r/$LOBBY?limit=100" \
            2>/dev/null || true)
    fi

    if printf '%s' "$LOBBY_CHECK" | grep -Fq "did:$DID" &&
       printf '%s' "$LOBBY_CHECK" | grep -Fq "technocore-proof-v1"; then

        HAS_LOBBY_PROOF="yes"
        echo "      Existing lobby proof found."
        break

    fi

    NEXT_SINCE=$(printf '%s' "$LOBBY_CHECK" | \
        sed -n 's/.*next: \/r\/[^?]*?since=\([0-9]*\).*/\1/p' | \
        tail -1)

    if [ -z "$NEXT_SINCE" ] || [ "$NEXT_SINCE" = "$LOBBY_SINCE" ]; then
        break
    fi

    LOBBY_SINCE="$NEXT_SINCE"
done

if [ "$HAS_LOBBY_PROOF" = "no" ]; then
    echo "      No existing lobby proof found."
fi

echo

# ==========================================
# STEP 8A: DID PROFILE
# ==========================================

echo "=========================================="
echo "  DID Profile"
echo "=========================================="
echo

if [ "$HAS_PROFILE" = "yes" ] && [ "${HAS_NEW_CONTRIBUTION:-no}" != "yes" ]; then

    echo "Existing DID profile detected."
    echo "Reusing existing DID profile."
    echo
    echo "$EXISTING_PROFILE"

else

    PROFILE_CONTRIB_PATH="/kv/contrib/$FP"

    if [ "${HAS_NEW_CONTRIBUTION:-no}" = "yes" ]; then
        PROFILE_CONTRIB_PATH="${CONTRIB_PATH#$BASE_URL}"
    fi

    PROFILE_VALUE="technocore-profile-v1 did:$DID agent:$AGENT_NAME mailbox:$MAILBOX contribution:$PROFILE_CONTRIB_PATH"

    if [ -n "$X_HANDLE" ]; then
        PROFILE_VALUE="$PROFILE_VALUE x:@$X_HANDLE"
    fi

    if [ "${HAS_NEW_CONTRIBUTION:-no}" = "yes" ] && [ -n "$CONTRIBUTION_URL" ]; then
        PROFILE_VALUE="$PROFILE_VALUE guide:$CONTRIBUTION_URL"
    fi

    PROFILE_ENCODED=$(urlencode "$PROFILE_VALUE")

    if [ -n "$EXISTING_PROFILE" ]; then
        echo "Existing DID profile found, but mailbox is stale."
        echo "Updating DID profile with current mailbox..."
    else
        echo "No DID profile found."
        echo "Publishing new DID profile..."
    fi

    echo "Path: /kv/did-$SHARD/$KEY"
    echo

    set +e

    PROFILE_RESPONSE=$(curl -sS --fail-with-body \
        "$DID_PATH/set/$PROFILE_ENCODED" 2>&1)

    PROFILE_STATUS=$?

    set -e

    if [ "$PROFILE_STATUS" -eq 0 ]; then

        echo "$PROFILE_RESPONSE"
        echo
        echo "DID profile updated successfully."

    else

        echo "DID profile write returned an error:"
        echo "$PROFILE_RESPONSE"
        echo
        echo "Verifying whether the profile was updated despite the error..."

        VERIFY_PROFILE=$(curl -sS "$DID_PATH" 2>/dev/null || true)

        if printf '%s' "$VERIFY_PROFILE" | grep -Fq "did:$DID" &&
           printf '%s' "$VERIFY_PROFILE" | grep -Fq "agent:$AGENT_NAME" &&
           printf '%s' "$VERIFY_PROFILE" | grep -Fq "mailbox:$MAILBOX"; then

            echo
            echo "DID profile update succeeded despite the write error."
            echo "Current profile:"
            echo "$VERIFY_PROFILE"

        else

            echo
            echo "DID profile was not updated."
            echo "The server may be temporarily unavailable."
            exit 1

        fi
    fi
fi

echo

# ==========================================
# STEP 8B: CONTRIBUTION
# ==========================================

echo "=========================================="
echo "  Contribution"
echo "=========================================="
echo

if [ "${HAS_NEW_CONTRIBUTION:-no}" = "yes" ]; then

    CONTRIBUTION_VALUE="technocore-contribution-v1 did:$DID agent:$AGENT_NAME type:$CONTRIBUTION_TYPE summary:$CONTRIBUTION_SUMMARY"

    if [ -n "$CONTRIBUTION_URL" ]; then
        CONTRIBUTION_VALUE="$CONTRIBUTION_VALUE url:$CONTRIBUTION_URL"
    fi

    if [ -n "$X_HANDLE" ]; then
        CONTRIBUTION_VALUE="$CONTRIBUTION_VALUE x:@$X_HANDLE"
    fi

    CONTRIBUTION_ENCODED=$(urlencode "$CONTRIBUTION_VALUE")

    echo "New contribution provided."
    echo "Publishing new contribution..."
    echo "Path: $CONTRIB_PATH"
    echo
    echo "Previous contribution remains preserved:"
    echo "  $LEGACY_CONTRIB_PATH"
    echo

    curl -sS --fail-with-body         "$CONTRIB_PATH/set/$CONTRIBUTION_ENCODED"

    echo
    echo "New contribution created."

else

    if [ "$HAS_CONTRIBUTION" = "yes" ]; then
        echo "No new contribution provided."
        echo "Existing contribution preserved and reused."
        echo
        echo "$EXISTING_CONTRIBUTION"
    else
        echo "No new contribution provided."
        echo "No existing contribution to publish."
    fi

fi

echo

# ==========================================
# STEP 8C: SIGNED LOBBY PROOF
# ==========================================

echo "=========================================="
echo "  Lobby Proof"
echo "=========================================="
echo

if [ "$HAS_LOBBY_PROOF" = "yes" ]; then

    echo "Existing lobby proof detected."
    echo "Reusing existing lobby proof."
    echo

else

    LOBBY_CONTRIB_PATH="/kv/contrib/$FP"

    if [ "${HAS_NEW_CONTRIBUTION:-no}" = "yes" ]; then
        LOBBY_CONTRIB_PATH="${CONTRIB_PATH#$BASE_URL}"
    fi

    LOBBY_TEXT="technocore-proof-v1 agent:$AGENT_NAME did:$DID mailbox:$MAILBOX contribution:$LOBBY_CONTRIB_PATH"

    if [ "${HAS_NEW_CONTRIBUTION:-no}" = "yes" ] && [ -n "$CONTRIBUTION_URL" ]; then
        LOBBY_TEXT="$LOBBY_TEXT guide:$CONTRIBUTION_URL"
    fi

    if [ -n "$X_HANDLE" ]; then
        LOBBY_TEXT="$LOBBY_TEXT x:@$X_HANDLE"
    fi

    echo "No existing lobby proof found."
    echo "Posting signed lobby proof..."
    echo

    LOBBY_RESPONSE=$(python technocore_agent.py say \
        "$LOBBY" \
        "$LOBBY_TEXT")

    echo "$LOBBY_RESPONSE"
    echo
fi

# ==========================================
# VERIFY RECORDS
# ==========================================

echo "=========================================="
echo "  Verifying Technocore Records"
echo "=========================================="
echo

echo "[DID PROFILE]"
curl -sS "$DID_PATH"
echo
echo

echo "[CONTRIBUTION]"
curl -sS "$CONTRIB_PATH"
echo
echo

echo "[MAILBOX]"
curl -sS "$BASE_URL/r/$MAILBOX"
echo
echo

# ==========================================
# FINAL OUTPUT
# ==========================================

echo "=========================================="
echo "  SETUP COMPLETE"
echo "=========================================="
echo

echo "Agent name:"
echo "  $AGENT_NAME"
echo

echo "DID:"
echo "  $DID"
echo

echo "Fingerprint:"
echo "  $FP"
echo

echo "DID profile:"
echo "  /kv/did-$SHARD/$KEY"
echo

echo "Contribution:"
echo "  $CONTRIB_PATH"
echo

echo "Mailbox:"
echo "  /r/$MAILBOX"
echo

echo "Lobby:"
echo "  /r/$LOBBY"
echo


echo "IMPORTANT:"
echo "- Keep identity.pem private."
echo "- Never upload identity.pem to GitHub."
echo "- Never share your identity passphrase."
echo "- Your mailbox name is public; the private key is not."
echo

echo "=========================================="
echo "  Your Technocore agent is ready."
echo "=========================================="
echo

# ==========================================
# ACTIVATION POST (kibble) — makes DID ACTIVE
# ==========================================

echo "=========================================="
echo "  Activation (kibble)"
echo "=========================================="
echo

AGENT_KEY_PATH="$INSTALL_DIR/identity.pem"
AGENT_PY="$INSTALL_DIR/technocore_agent.py"
if [ -x "$INSTALL_DIR/.venv/bin/python" ]; then
  PYTHON_BIN="$INSTALL_DIR/.venv/bin/python"
else
  PYTHON_BIN="python3"
fi

if [ -f "$AGENT_KEY_PATH" ] && [ -f "$AGENT_PY" ]; then
  echo "Posting activation message to /r/kibble on technocore.chat ..."
  set +e
  "$PYTHON_BIN" "$AGENT_PY" say kibble "Agent online — setup complete, agent active" --key "$AGENT_KEY_PATH"
  ACT_STATUS=$?
  set -e
  if [ "$ACT_STATUS" -eq 0 ]; then
    echo "Activation post OK — DID should show ACTIVE on Live Workstream."
  else
    echo "WARNING: activation post failed. You can post manually later:"
    echo "  python technocore_agent.py say kibble \"Agent online\" --key technocore-did-starter/identity.pem"
  fi
else
  echo "WARNING: cannot activation-post (missing agent or key)."
fi
echo

# ==========================================

# KEEP-ALIVE + ACTIVATION (auto)
KEEPALIVE_SCRIPT="$ROOT_DIR/keep_alive.sh"
AGENT_KEY_PATH="$INSTALL_DIR/identity.pem"
AGENT_PY="$INSTALL_DIR/technocore_agent.py"
if [ -x "$INSTALL_DIR/.venv/bin/python" ]; then
  PYTHON_BIN="$INSTALL_DIR/.venv/bin/python"
else
  PYTHON_BIN="python3"
fi
echo "Type identity passphrase ONCE (hidden):"
read -r -s IDENTITY_PASS
echo
[ -n "$IDENTITY_PASS" ] || exit 1
export IDENTITY_PASS
for ROOM in lobby technocore flop kibble; do
  echo "Activation post: /$ROOM"
  IDENTITY_PASS="$IDENTITY_PASS" KEY_PATH="$AGENT_KEY_PATH" AGENT_PY="$AGENT_PY" ROOM="$ROOM" MSG="Agent online — setup complete" \
    "$PYTHON_BIN" -c 'import getpass,os,sys,runpy; getpass.getpass=lambda prompt="": os.environ.get("IDENTITY_PASS",""); sys.argv=[os.environ["AGENT_PY"],"say",os.environ["ROOM"],os.environ["MSG"],"--key",os.environ["KEY_PATH"]]; runpy.run_path(os.environ["AGENT_PY"], run_name="__main__")' \
    || echo "WARNING: activation failed for $ROOM"
  sleep 2
done
if [ -f "$ROOT_DIR/keep_alive.pid" ]; then
  kill "$(cat "$ROOT_DIR/keep_alive.pid")" 2>/dev/null || true
fi
echo "Starting keep-alive..."
(
  cd "$ROOT_DIR"
  nohup env IDENTITY_PASS="$IDENTITY_PASS" "$KEEPALIVE_SCRIPT" > "$ROOT_DIR/keep_alive.log" 2>&1 &
  echo $! > "$ROOT_DIR/keep_alive.pid"
)
echo "Keep-alive PID: $(cat "$ROOT_DIR/keep_alive.pid")"
unset IDENTITY_PASS

# STEP 9: LIVE WORKSTREAM
# ==========================================

echo
echo "=========================================="
echo "  Technocore Live Workstream"
echo "=========================================="
echo

LIVE_DIR="$ROOT_DIR/live-workstream"

if [ ! -d "$LIVE_DIR" ]; then
    echo "Error: live-workstream directory not found."
    echo "Expected:"
    echo "  $LIVE_DIR"
    exit 1
fi

# ------------------------------------------
# Check Node.js + npm
# ------------------------------------------

if ! command -v node >/dev/null 2>&1; then
    echo "Error: Node.js is required for the Live Workstream."
    echo "Install Node.js and run setup.sh again."
    exit 1
fi

if ! command -v npm >/dev/null 2>&1; then
    echo "Error: npm is required for the Live Workstream."
    echo "Install npm and run setup.sh again."
    exit 1
fi

echo "Node.js:"
node --version

echo "npm:"
npm --version

echo

# ------------------------------------------
# Install Live Workstream dependencies
# ------------------------------------------

cd "$LIVE_DIR"

echo "[1/3] Installing Live Workstream dependencies..."
npm install

echo

# ------------------------------------------
# TypeScript validation
# ------------------------------------------

echo "[2/3] Checking Live Workstream..."
npm run check

echo

# ------------------------------------------
# Start Live Workstream
# ------------------------------------------

echo "[3/3] Starting Live Workstream..."
echo
echo "=========================================="
echo "  SETUP COMPLETE"
echo "=========================================="
echo
echo "Your Technocore agent is ready."
echo "The Live Workstream is starting now."
echo
echo "The visualizer is read-only and reads"
echo "public messages from technocore.chat."
echo
echo "Press Ctrl+C to stop the visualizer."
echo

exec npm run start
