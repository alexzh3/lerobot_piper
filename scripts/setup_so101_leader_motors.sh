#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SO101_PORT="${1:-${SO101_PORT:-/dev/serial/by-id/usb-1a86_USB_Single_Serial_5AA9017078-if00}}"

cd "$ROOT_DIR"

if [ ! -x "$ROOT_DIR/.venv/bin/lerobot-setup-motors" ]; then
  echo "LeRobot is not installed in .venv. Run ./scripts/setup_piper_arm.sh first." >&2
  exit 1
fi

echo "This configures SO101 leader Feetech motors only."
echo "Do not use this for the AgileX Piper follower."

"$ROOT_DIR/.venv/bin/lerobot-setup-motors" \
  --teleop.type=so101_leader \
  --teleop.port="$SO101_PORT"

