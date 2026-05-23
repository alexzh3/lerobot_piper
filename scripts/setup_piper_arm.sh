#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PYTHON_VERSION="3.12"
CAN_INTERFACE="${CAN_INTERFACE:-can0}"
CAN_BITRATE="${CAN_BITRATE:-1000000}"
LEROBOT_REPO="https://github.com/huggingface/lerobot.git"
PIPER_PLUGIN_REPO="https://github.com/AgRoboticsResearch/lerobot_robot_piper.git"

cd "$ROOT_DIR"

if ! command -v sudo >/dev/null 2>&1; then
  echo "sudo is required to install system packages." >&2
  exit 1
fi

if ! command -v uv >/dev/null 2>&1; then
  echo "uv is required. Install uv before running this script." >&2
  exit 1
fi

setup_can() {
  if ! ip link show "$CAN_INTERFACE" >/dev/null 2>&1; then
    echo "CAN interface '$CAN_INTERFACE' was not found. Connect the CAN adapter and rerun CAN setup." >&2
    return 0
  fi

  sudo ip link set "$CAN_INTERFACE" down 2>/dev/null || true
  sudo ip link set "$CAN_INTERFACE" type can bitrate "$CAN_BITRATE"
  sudo ip link set "$CAN_INTERFACE" up
  ip -details link show "$CAN_INTERFACE"
}

sudo apt update
sudo apt install -y git build-essential cmake pkg-config python3-dev \
  ffmpeg can-utils v4l-utils

setup_can

export UV_PYTHON_INSTALL_DIR="${UV_PYTHON_INSTALL_DIR:-$ROOT_DIR/.uv-python}"
UV_CACHE_ARGS=(--cache-dir "$ROOT_DIR/.uv-cache")

uv python install "$PYTHON_VERSION" "${UV_CACHE_ARGS[@]}"
uv venv --python "$PYTHON_VERSION"

if [ ! -d lerobot/.git ]; then
  git clone "$LEROBOT_REPO" lerobot
else
  git -C lerobot pull --ff-only
fi

uv pip install --python "$ROOT_DIR/.venv/bin/python" -e "$ROOT_DIR/lerobot[feetech,dataset,viz]" "${UV_CACHE_ARGS[@]}"
uv pip install --python "$ROOT_DIR/.venv/bin/python" python-can piper_sdk piper_control "${UV_CACHE_ARGS[@]}"

if [ ! -d lerobot_robot_piper/.git ]; then
  git clone "$PIPER_PLUGIN_REPO" lerobot_robot_piper
else
  git -C lerobot_robot_piper pull --ff-only
fi

uv pip install --python "$ROOT_DIR/.venv/bin/python" -e "$ROOT_DIR/lerobot_robot_piper" "${UV_CACHE_ARGS[@]}"

"$ROOT_DIR/.venv/bin/python" - <<'PY'
import lerobot
import piper_sdk
import lerobot_robot_piper

print("lerobot:", getattr(lerobot, "__version__", "unknown"))
print("piper_sdk import OK")
print("lerobot_robot_piper import OK")
PY

echo "Piper arm LeRobot environment installed."
echo "Activate it with: source .venv/bin/activate"
echo "Before teleop, run: python scripts/check_piper_sdk.py --can-interface $CAN_INTERFACE"
