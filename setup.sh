#!/usr/bin/env bash

set -e

REPO_URL="https://github.com/Gmhax/technocore-one-command.git"
INSTALL_DIR="technocore-did-starter"
LOBBY="lobby"
BASE_URL="https://technocore.chat"

echo "=========================================="
echo "  Technocore One-Command Agent Setup"
echo "  (Updated for Sharded DID)"
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
# STEP 2: Clone official Technocore starter
# ==========================================

if [ -d "$INSTALL_DIR" ]; then
    echo "[2/8] Existing Technocore folder found."
    echo "      Keeping the existing installation."
else
    echo "[2/8] Downloading official Technocore DID starter..."
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

read -r -p "Agent name: " AGENT_NAME

if [ -z "$AGENT_NAME" ]; then
    echo "Error: Agent name cannot be empty."
    exit 1
fi

read -r -p "X handle (optional, without @): " X_HANDLE

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

read -r -p "Contribution type: " CONTRIBUTION_TYPE

if [ -z "$CONTRIBUTION_TYPE" ]; then
    echo "Error: Contribution type cannot be empty."
    exit 1
fi

read -r -p "Contribution URL (optional): " CONTRIBUTION_URL

read -r -p "Contribution summary: " CONTRIBUTION_SUMMARY

if [ -z "$CONTRIBUTION_SUMMARY" ]; then
    echo "Error: Contribution summary cannot be empty."
    exit 1
fi

echo
echo "Agent:"
echo "  Name: $AGENT_NAME"
echo "  X:    ${X_HANDLE:-none}"
echo "  Type: $CONTRIBUTION_TYPE"
echo "  URL:  ${CONTRIBUTION_URL:-none}"
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
# STEP 7: Mailbox
# ==========================================

echo "=========================================="
echo "  Creating Agent Mailbox"
echo "=========================================="
echo

# Generate a NEW mailbox name first.
NEW_MAILBOX="mb-p-$(python3 -c 'import secrets; print(secrets.token_hex(12))')"

MAILBOX="$NEW_MAILBOX"

echo "Generated new mailbox:"
echo "/r/$NEW_MAILBOX"
echo

MAILBOX_TEXT="mailbox-online-v1 agent:$AGENT_NAME did:$DID profile:/kv/did-$SHARD/$KEY"

# ==========================================
# Try NEW mailbox first
# ==========================================

echo "Trying new mailbox..."
echo

set +e

NEW_MAILBOX_RESPONSE=$(python technocore_agent.py say "$NEW_MAILBOX" "$MAILBOX_TEXT" 2>&1)
NEW_MAILBOX_STATUS=$?

set -e

if [ "$NEW_MAILBOX_STATUS" -eq 0 ]; then

    echo "New mailbox created successfully."
    echo "$NEW_MAILBOX_RESPONSE"
    echo

else

    # Check specifically for the Technocore room-cap error.
    if printf '%s' "$NEW_MAILBOX_RESPONSE" | grep -qi "room limit reached"; then

        echo "New mailbox could not be created."
        echo "Technocore mailbox room cap has been reached."
        echo
        echo "Searching for YOUR previous mailbox..."
        echo

        # ==========================================
        # Find YOUR previous mailbox
        # ==========================================

        ROOMS_RESPONSE=$(curl -sS "$BASE_URL/rooms" || true)

        if [ -z "$ROOMS_RESPONSE" ]; then
            echo
            echo "ERROR: Could not retrieve existing Technocore rooms."
            echo
            echo "Please wait for Technocore to increase"
            echo "the mailbox room cap."
            exit 1
        fi

        # Extract existing mb-p-* room names from /rooms.
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

        FOUND_MAILBOX=""

        # ==========================================
        # Check each mailbox for OUR DID
        # ==========================================

        if [ -n "$ROOM_NAMES" ]; then

            while IFS= read -r CANDIDATE_ROOM; do

                [ -z "$CANDIDATE_ROOM" ] && continue

                ROOM_DATA=$(curl -sS "$BASE_URL/r/$CANDIDATE_ROOM" 2>/dev/null || true)

                if [ -z "$ROOM_DATA" ]; then
                    continue
                fi

                # We identify ownership by finding our DID together
                # with the mailbox-online proof in that room.
                if printf '%s' "$ROOM_DATA" | grep -Fq "$DID" &&
                   printf '%s' "$ROOM_DATA" | grep -Fq "mailbox-online-v1"; then

                    FOUND_MAILBOX="$CANDIDATE_ROOM"
                    break
                fi

            done <<< "$ROOM_NAMES"

        fi

        # ==========================================
        # Reuse previous mailbox if found
        # ==========================================

        if [ -n "$FOUND_MAILBOX" ]; then

            MAILBOX="$FOUND_MAILBOX"

            echo
            echo "=========================================="
            echo "  Existing Mailbox Found"
            echo "=========================================="
            echo
            echo "Your previous mailbox was found:"
            echo "/r/$MAILBOX"
            echo
            echo "Reusing your existing mailbox..."
            echo

            echo "Posting signed mailbox proof..."

            MAILBOX_RESPONSE=$(python technocore_agent.py say "$MAILBOX" "$MAILBOX_TEXT")

            echo "$MAILBOX_RESPONSE"
            echo

        else

            echo
            echo "=========================================="
            echo "  No Existing Mailbox Found"
            echo "=========================================="
            echo
            echo "No existing mailbox belonging to this DID was found."
            echo
            echo "Please wait for Technocore to increase"
            echo "the mailbox room cap."
            echo
            exit 1

        fi

    else

        # ==========================================
        # Some other mailbox error
        # ==========================================

        echo
        echo "Mailbox creation failed for another reason:"
        echo
        echo "$NEW_MAILBOX_RESPONSE"
        echo
        exit 1

    fi
fi

# ==========================================
# STEP 8A: Publish DID profile (SHARDED)
# ==========================================

echo "=========================================="
echo "  Publishing DID Profile (Sharded)"
echo "=========================================="
echo

PROFILE_VALUE="technocore-profile-v1 did:$DID agent:$AGENT_NAME mailbox:$MAILBOX contribution:/kv/contrib/$FP"

if [ -n "$X_HANDLE" ]; then
    PROFILE_VALUE="$PROFILE_VALUE x:@$X_HANDLE"
fi

if [ -n "$CONTRIBUTION_URL" ]; then
    PROFILE_VALUE="$PROFILE_VALUE guide:$CONTRIBUTION_URL"
fi

PROFILE_ENCODED=$(urlencode "$PROFILE_VALUE")

echo "Publishing profile note to sharded path..."
echo "Path: /kv/did-$SHARD/$KEY"

curl -sS --fail-with-body \
    "$BASE_URL/kv/did-$SHARD/$KEY/set/$PROFILE_ENCODED"

echo
echo

# ==========================================
# STEP 8B: Publish contribution record
# ==========================================

echo "=========================================="
echo "  Registering Contribution"
echo "=========================================="
echo

CONTRIBUTION_VALUE="technocore-contribution-v1 did:$DID agent:$AGENT_NAME type:$CONTRIBUTION_TYPE summary:$CONTRIBUTION_SUMMARY"

if [ -n "$CONTRIBUTION_URL" ]; then
    CONTRIBUTION_VALUE="$CONTRIBUTION_VALUE url:$CONTRIBUTION_URL"
fi

if [ -n "$X_HANDLE" ]; then
    CONTRIBUTION_VALUE="$CONTRIBUTION_VALUE x:@$X_HANDLE"
fi

CONTRIBUTION_ENCODED=$(urlencode "$CONTRIBUTION_VALUE")

echo "Publishing contribution record..."

curl -sS --fail-with-body \
    "$BASE_URL/kv/contrib/$FP/set/$CONTRIBUTION_ENCODED"

echo
echo

# ==========================================
# STEP 8C: Signed lobby proof
# ==========================================

echo "=========================================="
echo "  Publishing Lobby Proof"
echo "=========================================="
echo

LOBBY_TEXT="technocore-proof-v1 agent:$AGENT_NAME did:$DID mailbox:$MAILBOX contribution:/kv/contrib/$FP"

if [ -n "$CONTRIBUTION_URL" ]; then
    LOBBY_TEXT="$LOBBY_TEXT guide:$CONTRIBUTION_URL"
fi

if [ -n "$X_HANDLE" ]; then
    LOBBY_TEXT="$LOBBY_TEXT x:@$X_HANDLE"
fi

echo "Posting signed lobby proof..."

LOBBY_RESPONSE=$(python technocore_agent.py say "$LOBBY" "$LOBBY_TEXT")

echo "$LOBBY_RESPONSE"
echo

# ==========================================
# Verify DID profile
# ==========================================

echo "=========================================="
echo "  Verifying DID Profile"
echo "=========================================="
echo

curl -sS \
    "$BASE_URL/kv/did-$SHARD/$KEY"

echo
echo

# ==========================================
# Final output
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

echo "Sharded DID Profile:"
echo "  $BASE_URL/kv/did-$SHARD/$KEY"
echo

echo "Contribution:"
echo "  $BASE_URL/kv/contrib/$FP"
echo

echo "Mailbox:"
echo "  $BASE_URL/r/$MAILBOX"
echo

echo "Lobby:"
echo "  $BASE_URL/r/$LOBBY"
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
