#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SO101_PORT="${SO101_PORT:-/dev/serial/by-id/usb-1a86_USB_Single_Serial_5AA9017078-if00}"
SO101_ID="${SO101_ID:-so101_leader_piper}"
CAN_INTERFACE="${CAN_INTERFACE:-can0}"
CAN_BITRATE="${CAN_BITRATE:-1000000}"
PIPER_CAMERA="${PIPER_CAMERA:-/dev/video4}"
PIPER_CAMERA_WIDTH="${PIPER_CAMERA_WIDTH:-640}"
PIPER_CAMERA_HEIGHT="${PIPER_CAMERA_HEIGHT:-480}"
PIPER_CAMERA_FPS="${PIPER_CAMERA_FPS:-30}"
PIPER_CAMERA_FOURCC="${PIPER_CAMERA_FOURCC:-MJPG}"
DISPLAY_DATA="${DISPLAY_DATA:-false}"

cd "$ROOT_DIR"

if [ ! -x "$ROOT_DIR/.venv/bin/lerobot-teleoperate" ]; then
  echo "LeRobot is not installed in .venv. Run ./scripts/setup_piper_arm.sh first." >&2
  exit 1
fi

CAMERA_CONFIG=$(printf '{"wrist": {"type": "opencv", "index_or_path": "%s", "width": %s, "height": %s, "fps": %s, "fourcc": "%s"}}' \
  "$PIPER_CAMERA" \
  "$PIPER_CAMERA_WIDTH" \
  "$PIPER_CAMERA_HEIGHT" \
  "$PIPER_CAMERA_FPS" \
  "$PIPER_CAMERA_FOURCC")

"$ROOT_DIR/.venv/bin/lerobot-teleoperate" \
  --robot.type=piper \
  --robot.can_interface="$CAN_INTERFACE" \
  --robot.bitrate="$CAN_BITRATE" \
  --robot.include_gripper=true \
  --robot.use_degrees=false \
  --robot.cameras="$CAMERA_CONFIG" \
  --teleop.type=so101_leader \
  --teleop.port="$SO101_PORT" \
  --teleop.id="$SO101_ID" \
  --teleop.use_degrees=false \
  --display_data="$DISPLAY_DATA"
