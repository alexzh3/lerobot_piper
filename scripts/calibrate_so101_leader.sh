#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SO101_PORT="${1:-${SO101_PORT:-/dev/serial/by-id/usb-1a86_USB_Single_Serial_5AA9017078-if00}}"
SO101_ID="${SO101_ID:-so101_leader_piper}"

cd "$ROOT_DIR"

if [ ! -x "$ROOT_DIR/.venv/bin/lerobot-calibrate" ]; then
  echo "LeRobot is not installed in .venv. Run ./scripts/setup_piper_arm.sh first." >&2
  exit 1
fi

"$ROOT_DIR/.venv/bin/lerobot-calibrate" \
  --teleop.type=so101_leader \
  --teleop.port="$SO101_PORT" \
  --teleop.id="$SO101_ID"
