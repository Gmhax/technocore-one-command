#!/usr/bin/env bash

set -e

REPO_URL="https://github.com/Gmhax/technocore-one-command.git"
INSTALL_DIR="technocore-did-starter"
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

    # --------------------------------------
    # Save configuration locally
    # --------------------------------------

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

if [ -z "$CONTRIBUTION_TYPE" ]; then
    echo "Error: Contribution type cannot be empty."
    exit 1
fi

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
echo "  Summary: $CONTRIBUTION_SUMMARY"
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

    echo "Checking existing Technocore mailboxes..."
    echo

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

    FOUND_MAILBOX=""

    if [ -n "$ROOM_NAMES" ]; then

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

                FOUND_MAILBOX="$CANDIDATE_ROOM"
                break
            fi

        done <<< "$ROOM_NAMES"

    fi

    if [ -n "$FOUND_MAILBOX" ]; then
        echo "$FOUND_MAILBOX"
        return 0
    fi

    return 1
}

# ==========================================
# STEP 7: MAILBOX
# ==========================================

echo "=========================================="
echo "  Agent Mailbox"
echo "=========================================="
echo

MAILBOX=""

# ------------------------------------------
# FIRST: Look for existing mailbox
# ------------------------------------------

EXISTING_MAILBOX=$(find_existing_mailbox || true)

if [ -n "$EXISTING_MAILBOX" ]; then

    MAILBOX="$EXISTING_MAILBOX"

    echo "Existing mailbox found:"
    echo "/r/$MAILBOX"
    echo
    echo "Reusing your existing mailbox."
    echo

else

    echo "No existing mailbox found."
    echo "Attempting to create a new mailbox..."
    echo

    # Generate a new mailbox name
    NEW_MAILBOX="mb-p-$(python3 -c 'import secrets; print(secrets.token_hex(12))')"

    MAILBOX_TEXT="mailbox-online-v1 agent:$AGENT_NAME did:$DID profile:/kv/did-$SHARD/$KEY"

    echo "Generated mailbox:"
    echo "/r/$NEW_MAILBOX"
    echo

    # --------------------------------------
    # Try creating new mailbox
    # --------------------------------------

    set +e

    NEW_MAILBOX_RESPONSE=$(python technocore_agent.py say \
        "$NEW_MAILBOX" \
        "$MAILBOX_TEXT" \
        2>&1)

    NEW_MAILBOX_STATUS=$?

    set -e

    if [ "$NEW_MAILBOX_STATUS" -eq 0 ]; then

        MAILBOX="$NEW_MAILBOX"

        echo "New mailbox created successfully."
        echo "$NEW_MAILBOX_RESPONSE"
        echo

    else

        echo "Initial mailbox request returned an error:"
        echo "$NEW_MAILBOX_RESPONSE"
        echo

        # ----------------------------------
        # IMPORTANT:
        # Check whether the mailbox actually
        # exists despite a timeout.
        # ----------------------------------

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

                echo "Mailbox creation succeeded despite the timeout."
                echo "Using:"
                echo "/r/$MAILBOX"
                echo

            fi
        fi

        # ----------------------------------
        # If still no mailbox:
        # search existing mailbox again.
        # ----------------------------------

        if [ -z "$MAILBOX" ]; then

            echo "Searching for an existing mailbox belonging to this DID..."
            echo

            EXISTING_MAILBOX=$(find_existing_mailbox || true)

            if [ -n "$EXISTING_MAILBOX" ]; then

                MAILBOX="$EXISTING_MAILBOX"

                echo "Existing mailbox found:"
                echo "/r/$MAILBOX"
                echo
                echo "Reusing existing mailbox."
                echo

            fi
        fi

        # ----------------------------------
        # If room cap reached and nothing found
        # ----------------------------------

        if [ -z "$MAILBOX" ]; then

            if printf '%s' "$NEW_MAILBOX_RESPONSE" | grep -qi \
                "room limit reached"; then

                echo "Technocore room limit has been reached."
                echo "No existing mailbox belonging to this DID was found."
                echo
                echo "Setup cannot continue until a mailbox is available."
                exit 1

            fi

            echo "Mailbox setup failed."
            echo
            echo "$NEW_MAILBOX_RESPONSE"
            echo
            exit 1

        fi
    fi
fi

# ==========================================
# STEP 8: EXISTING RECORD DETECTION
# ==========================================

echo "=========================================="
echo "  Checking Existing Technocore Records"
echo "=========================================="
echo

DID_PATH="$BASE_URL/kv/did-$SHARD/$KEY"
CONTRIB_PATH="$BASE_URL/kv/contrib/$FP"

# ------------------------------------------
# Check existing DID profile
# ------------------------------------------

echo "[1/4] Checking DID profile..."

EXISTING_PROFILE=$(curl -sS "$DID_PATH" 2>/dev/null || true)

if printf '%s' "$EXISTING_PROFILE" | grep -Fq "did:$DID" &&
   printf '%s' "$EXISTING_PROFILE" | grep -Fq "agent:$AGENT_NAME"; then

    HAS_PROFILE="yes"
    echo "      Existing matching DID profile found."

else

    HAS_PROFILE="no"
    echo "      No matching DID profile found."

fi

echo

# ------------------------------------------
# Check existing contribution
# ------------------------------------------

echo "[2/4] Checking contribution..."

EXISTING_CONTRIBUTION=$(curl -sS "$CONTRIB_PATH" 2>/dev/null || true)

if printf '%s' "$EXISTING_CONTRIBUTION" | grep -Fq "did:$DID" &&
   printf '%s' "$EXISTING_CONTRIBUTION" | grep -Fq "agent:$AGENT_NAME"; then

    if [ -n "$CONTRIBUTION_URL" ]; then

        if printf '%s' "$EXISTING_CONTRIBUTION" | grep -Fq "url:$CONTRIBUTION_URL"; then
            HAS_CONTRIBUTION="yes"
            echo "      Existing matching contribution found."
        else
            HAS_CONTRIBUTION="no"
            echo "      Contribution exists, but URL differs."
        fi

    else

        HAS_CONTRIBUTION="yes"
        echo "      Existing matching contribution found."

    fi

else

    HAS_CONTRIBUTION="no"
    echo "      No matching contribution found."

fi

echo

# ------------------------------------------
# Mailbox was already resolved above
# ------------------------------------------

echo "[3/4] Mailbox..."

if [ -n "$MAILBOX" ]; then
    echo "      Using existing/resolved mailbox: $MAILBOX"
else
    echo "      No mailbox available."
    exit 1
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

if [ "$HAS_PROFILE" = "yes" ]; then

    echo "Existing DID profile detected."
    echo "Reusing existing DID profile."
    echo
    echo "$EXISTING_PROFILE"

else

    PROFILE_VALUE="technocore-profile-v1 did:$DID agent:$AGENT_NAME mailbox:$MAILBOX contribution:/kv/contrib/$FP"

    if [ -n "$X_HANDLE" ]; then
        PROFILE_VALUE="$PROFILE_VALUE x:@$X_HANDLE"
    fi

    if [ -n "$CONTRIBUTION_URL" ]; then
        PROFILE_VALUE="$PROFILE_VALUE guide:$CONTRIBUTION_URL"
    fi

    PROFILE_ENCODED=$(urlencode "$PROFILE_VALUE")

    echo "No DID profile found."
    echo "Publishing new DID profile..."
    echo "Path: /kv/did-$SHARD/$KEY"
    echo

    curl -sS --fail-with-body \
        "$DID_PATH/set/$PROFILE_ENCODED"

    echo
    echo "DID profile created."
fi

echo

# ==========================================
# STEP 8B: CONTRIBUTION
# ==========================================

echo "=========================================="
echo "  Contribution"
echo "=========================================="
echo

if [ "$HAS_CONTRIBUTION" = "yes" ]; then

    echo "Existing contribution detected."
    echo "Reusing existing contribution."
    echo
    echo "$EXISTING_CONTRIBUTION"

else

    CONTRIBUTION_VALUE="technocore-contribution-v1 did:$DID agent:$AGENT_NAME type:$CONTRIBUTION_TYPE summary:$CONTRIBUTION_SUMMARY"

    if [ -n "$CONTRIBUTION_URL" ]; then
        CONTRIBUTION_VALUE="$CONTRIBUTION_VALUE url:$CONTRIBUTION_URL"
    fi

    if [ -n "$X_HANDLE" ]; then
        CONTRIBUTION_VALUE="$CONTRIBUTION_VALUE x:@$X_HANDLE"
    fi

    CONTRIBUTION_ENCODED=$(urlencode "$CONTRIBUTION_VALUE")

    echo "No contribution found."
    echo "Publishing new contribution..."
    echo "Path: /kv/contrib/$FP"
    echo

    curl -sS --fail-with-body \
        "$CONTRIB_PATH/set/$CONTRIBUTION_ENCODED"

    echo
    echo "Contribution created."
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

    LOBBY_TEXT="technocore-proof-v1 agent:$AGENT_NAME did:$DID mailbox:$MAILBOX contribution:/kv/contrib/$FP"

    if [ -n "$CONTRIBUTION_URL" ]; then
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
echo "  /kv/contrib/$FP"
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
