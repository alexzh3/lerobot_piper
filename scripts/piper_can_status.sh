#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CAN_INTERFACE="${CAN_INTERFACE:-can0}"
CAN_BITRATE="${CAN_BITRATE:-1000000}"

cd "$ROOT_DIR"

if [ ! -x "$ROOT_DIR/.venv/bin/python" ]; then
  echo "Python virtual environment not found. Run ./scripts/setup_piper_arm.sh first." >&2
  exit 1
fi

if ! command -v ip >/dev/null 2>&1; then
  echo "ip command not found. Install iproute2." >&2
  exit 1
fi

echo "== SocketCAN setup =="
if ! ip link show "$CAN_INTERFACE" >/dev/null 2>&1; then
  echo "CAN interface '$CAN_INTERFACE' was not found. Connect the CAN adapter and try again." >&2
  exit 1
fi

sudo ip link set "$CAN_INTERFACE" down 2>/dev/null || true
sudo ip link set "$CAN_INTERFACE" type can bitrate "$CAN_BITRATE"
sudo ip link set "$CAN_INTERFACE" up
ip -details -statistics link show "$CAN_INTERFACE"

echo
echo "== Piper SDK status =="
"$ROOT_DIR/.venv/bin/python" - "$CAN_INTERFACE" <<'PY'
import sys
import time
from piper_sdk import C_PiperInterface_V2

can_interface = sys.argv[1]

piper = C_PiperInterface_V2(can_interface)
piper.ConnectPort()
time.sleep(0.2)

print("Firmware:", piper.GetPiperFirmwareVersion())
print("Arm status:")
print(piper.GetArmStatus())
print("Gripper status:")
print(piper.GetArmGripperMsgs())

try:
    print("SDK gripper range:", piper.GetSDKGripperRangeParam())
except Exception as exc:
    print("SDK gripper range unavailable:", repr(exc))
PY

