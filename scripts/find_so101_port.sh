#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$ROOT_DIR"

if [ ! -x "$ROOT_DIR/.venv/bin/lerobot-find-port" ]; then
  echo "LeRobot is not installed in .venv. Run ./scripts/setup_piper_arm.sh first." >&2
  exit 1
fi

echo "Stable serial devices:"
ls -l /dev/serial/by-id/ || true
echo
echo "This command requires human input:"
echo "1. Keep the SO101 MotorsBus USB cable connected now."
echo "2. When prompted, unplug the SO101 MotorsBus USB cable."
echo "3. Press Enter."
echo "4. Reconnect the SO101 MotorsBus USB cable after the port is printed."
echo

"$ROOT_DIR/.venv/bin/lerobot-find-port"

