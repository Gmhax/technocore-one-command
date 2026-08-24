#!/usr/bin/env bash

set -e

REPO_URL="https://github.com/zunmax/technocore-did-starter.git"
INSTALL_DIR="technocore-did-starter"
LOBBY="lobby"  

echo "=========================================="
echo "  Technocore DID One-Command Setup"
echo "=========================================="
echo

# Check Python
if ! command -v python3 >/dev/null 2>&1; then
    echo "Error: Python 3 is not installed."
    exit 1
fi

echo "[1/6] Python:"
python3 --version
echo

# Clone official starter
if [ -d "$INSTALL_DIR" ]; then
    echo "[2/6] Existing Technocore folder found."
    echo "      Keeping the existing installation."
else
    echo "[2/6] Downloading official Technocore DID starter..."
    git clone "$REPO_URL" "$INSTALL_DIR"
fi

cd "$INSTALL_DIR"

echo
echo "[3/6] Creating Python virtual environment..."

if [ ! -d ".venv" ]; then
    python3 -m venv .venv
fi

source .venv/bin/activate

echo
echo "[4/6] Installing dependencies..."
python -m pip install --upgrade pip
python -m pip install -r requirements.txt

echo
echo "[5/6] Checking Technocore identity..."

if [ -f "identity.pem" ]; then
    echo
    echo "Existing identity.pem found."
    echo "Your existing DID will be preserved."
else
    echo
    echo "No identity found."
    echo "Create your encrypted Technocore DID now."
    echo
    python technocore_agent.py init
fi

echo
echo "=========================================="
echo "  Setup complete!"
echo "=========================================="
echo

# Get DID
echo "Your public DID:"
DID=$(python technocore_agent.py did)
echo "$DID"
echo

echo "Technocore folder:"
pwd
echo

echo "IMPORTANT:"
echo "- Keep identity.pem private."
echo "- Never upload identity.pem to GitHub."
echo "- Never share your identity passphrase."
echo

# ========================
# STEP: Publish DID Note
# ========================
echo "=========================================="
echo "  Publishing DID Note to /kv/did/ ..."
echo "=========================================="
echo

FP=$(printf '%s' "$DID" | sha256sum | cut -c1-16)
echo "Fingerprint: $FP"
echo

echo "Publishing..."
curl -s "https://technocore.chat/kv/did/$FP/set/$DID"
echo
echo

echo "Verifying DID Note:"
curl -s "https://technocore.chat/kv/did/$FP"
echo
echo

# ========================
# STEP: Post signed message
# ========================
echo "=========================================="
echo "  Publishing signed message to room: $LOBBY"
echo "=========================================="
echo

python technocore_agent.py say "$LOBBY" "Hello from my Technocore DID."

echo
echo "=========================================="
echo "  ALL DONE!"
echo "=========================================="
echo
echo "DID:       $DID"
echo "Fingerprint: $FP"
echo "DID Note:  https://technocore.chat/kv/did/$FP"
echo
echo "Check the Sequence number in the JSON above."
echo
