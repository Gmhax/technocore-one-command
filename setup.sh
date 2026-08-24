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

echo "[1/5] Python:"
python3 --version
echo

# Clone official starter
if [ -d "$INSTALL_DIR" ]; then
    echo "[2/5] Existing Technocore folder found."
    echo "      Keeping the existing installation."
else
    echo "[2/5] Downloading official Technocore DID starter..."
    git clone "$REPO_URL" "$INSTALL_DIR"
fi

cd "$INSTALL_DIR"

echo
echo "[3/5] Creating Python virtual environment..."

if [ ! -d ".venv" ]; then
    python3 -m venv .venv
fi

source .venv/bin/activate

echo
echo "[4/5] Installing dependencies..."
python -m pip install --upgrade pip
python -m pip install -r requirements.txt

echo
echo "[5/5] Checking Technocore identity..."

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
echo "Your public DID:"
python technocore_agent.py did
echo
echo "Technocore folder:"
pwd
echo
echo "IMPORTANT:"
echo "- Keep identity.pem private."
echo "- Never upload identity.pem to GitHub."
echo "- Never share your identity passphrase."
echo
echo "=========================================="
echo "  Publishing signed message to room: $LOBBY"
echo "=========================================="
echo

# Post the message and show the full response (includes Sequence)
python technocore_agent.py say "$LOBBY" "Hello from my Technocore DID."

echo
echo "=========================================="
echo "  Done! Check the Sequence number above."
echo "=========================================="
echo
