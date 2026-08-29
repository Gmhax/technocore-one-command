#!/usr/bin/env bash
set -u
INSTALL_DIR="/workspaces/technocore-one-command/technocore-did-starter"
KEY="$INSTALL_DIR/identity.pem"
AGENT_PY="$INSTALL_DIR/technocore_agent.py"
INTERVAL="${INTERVAL:-300}"
ROOMS=(lobby technocore flop kibble)
if [ -x "$INSTALL_DIR/.venv/bin/python" ]; then
  PYTHON="$INSTALL_DIR/.venv/bin/python"
else
  PYTHON="python3"
fi
PASS="${IDENTITY_PASS:-}"
if [ -z "$PASS" ]; then
  echo "Type passphrase ONCE (hidden):"
  read -r -s PASS
  echo
fi
[ -n "$PASS" ] || exit 1
post_room() {
  IDENTITY_PASS="$PASS" KEY_PATH="$KEY" AGENT_PY="$AGENT_PY" ROOM="$1" MSG="$2" \
  "$PYTHON" -c 'import getpass,os,sys,runpy; getpass.getpass=lambda prompt="": os.environ.get("IDENTITY_PASS",""); sys.argv=[os.environ["AGENT_PY"],"say",os.environ["ROOM"],os.environ["MSG"],"--key",os.environ["KEY_PATH"]]; runpy.run_path(os.environ["AGENT_PY"], run_name="__main__")'
}
echo "rooms: ${ROOMS[*]}"
while true; do
  TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  for ROOM in "${ROOMS[@]}"; do
    echo "[$TS] /$ROOM ..."
    post_room "$ROOM" "Hax heartbeat $TS" || echo "FAIL /$ROOM"
    sleep 8
  done
  sleep "$INTERVAL"
done
