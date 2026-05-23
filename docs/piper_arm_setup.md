# Piper Arm Setup

This document tracks the host setup for using an AgileX Piper arm as the follower robot in a LeRobot teleoperation stack.

## One-Step Setup

Run the setup script from the repository root:

```bash
chmod +x scripts/setup_piper_arm.sh
./scripts/setup_piper_arm.sh
```

The script installs system packages, creates a Python 3.12 uv environment, installs LeRobot from source with SO101/Feetech support, installs the Piper SDK, and installs the Piper LeRobot plugin.

It also brings up `can0` at 1 Mbps when the CAN adapter is present.

## System Dependencies

The script installs:

- `git`
- `build-essential`
- `cmake`
- `pkg-config`
- `python3-dev`
- `ffmpeg`
- `can-utils`
- `v4l-utils`

## Python Environment

Create the local virtual environment with:

```bash
uv python install 3.12
uv venv --python 3.12
```

Activate it with:

```bash
source .venv/bin/activate
```

This repository keeps `.venv/`, `.uv-cache/`, and `.uv-python/` local and ignored by git.

## Piper CAN Setup

AgileX Piper uses a CAN bitrate of 1000000. The setup script uses `can0` and 1 Mbps by default.

See CAN devices:

```bash
ip link | grep -E "can[0-9]" || true
```

Bring up `can0`:

```bash
sudo ip link set can0 down 2>/dev/null || true
sudo ip link set can0 type can bitrate 1000000
sudo ip link set can0 up
```

Confirm:

```bash
ip -details link show can0
```

To use a different CAN interface or bitrate with the setup script:

```bash
CAN_INTERFACE=can1 CAN_BITRATE=1000000 ./scripts/setup_piper_arm.sh
```

## Required Read-Only Piper SDK Test

Do not teleoperate until the read-only SDK test works.

Run:

```bash
source .venv/bin/activate
python scripts/check_piper_sdk.py --can-interface can0
```

Equivalent inline test:

```bash
python - <<'PY'
import time
from piper_sdk import C_PiperInterface_V2

p = C_PiperInterface_V2("can0")
p.ConnectPort()
time.sleep(0.2)

print("Firmware:", p.GetPiperFirmwareVersion())
print("Arm status:", p.GetArmStatus())
PY
```

Expected result: firmware is printed, arm status is readable, `Arm Status` is normal, and the error code is zero.

## Find and Calibrate SO101 Leader

List stable serial device names:

```bash
ls -l /dev/serial/by-id/ || true
```

On this machine, the SO101 USB serial adapter was visible as:

```text
/dev/serial/by-id/usb-1a86_USB_Single_Serial_5AA9017078-if00 -> ../../ttyACM0
```

Prefer the stable `/dev/serial/by-id/...` path over `/dev/ttyACM0`:

```bash
export SO101_PORT=/dev/serial/by-id/usb-1a86_USB_Single_Serial_5AA9017078-if00
```

Run LeRobot's port finder from an interactive terminal:

```bash
source .venv/bin/activate
lerobot-find-port
```

This command requires human input. Keep the SO101 MotorsBus USB cable connected when starting it. When prompted, unplug the SO101 MotorsBus USB cable, press Enter, wait for LeRobot to print the port, then reconnect the cable.

You can also use the wrapper script:

```bash
./scripts/find_so101_port.sh
```

Current observed result:

```text
The port of this MotorsBus is '/dev/ttyACM0'
```

If the SO101 leader motors were never configured, run leader motor setup once:

```bash
source .venv/bin/activate
lerobot-setup-motors \
  --teleop.type=so101_leader \
  --teleop.port="$SO101_PORT"
```

Or use the helper script:

```bash
./scripts/setup_so101_leader_motors.sh "$SO101_PORT"
```

Do not run SO101 follower setup on the PiPER. PiPER is controlled via CAN and `piper_sdk`, not Feetech motors.

Then calibrate the SO101 leader after identifying the port:

```bash
source .venv/bin/activate
lerobot-calibrate \
  --teleop.type=so101_leader \
  --teleop.port="$SO101_PORT" \
  --teleop.id=so101_leader_piper
```

Or use the helper script:

```bash
./scripts/calibrate_so101_leader.sh "$SO101_PORT"
```

If no stable `/dev/serial/by-id/...` path is available, use the direct port reported by `lerobot-find-port`.

## LeRobot From Source

Install LeRobot with SO101/Feetech support:

```bash
git clone https://github.com/huggingface/lerobot.git
cd lerobot
uv pip install -e ".[feetech,dataset,viz]"
```

The SO101 setup needs the Feetech SDK extra. The dataset extra is also installed because `lerobot-record --help` imports dataset dependencies. The viz extra is required when using `--display_data=true`.

Sanity checks:

```bash
lerobot-info
lerobot-find-port --help
lerobot-teleoperate --help
lerobot-record --help
```

In LeRobot 0.5.2, `lerobot-find-port --help` starts the interactive port finder rather than printing argparse help. Run it from an interactive terminal with the SO101 bus-servo adapter connected, then follow its unplug/replug prompt.

## Piper SDK and Plugin

Install the Piper SDK packages and community LeRobot plugin:

```bash
uv pip install python-can piper_sdk piper_control
git clone https://github.com/AgRoboticsResearch/lerobot_robot_piper.git
cd lerobot_robot_piper
uv pip install -e .
```

`piper_control` is optional, but installed by the setup script. It wraps `piper_sdk` with helper functions for CAN port activation and simpler basic I/O, which is useful when debugging raw SDK behavior.

If the plugin install tries to replace the source LeRobot install, reinstall without dependencies:

```bash
uv pip install -e . --no-deps
```

Test imports:

```bash
python - <<'PY'
import lerobot
import piper_sdk
import lerobot_robot_piper

print("lerobot:", getattr(lerobot, "__version__", "unknown"))
print("piper_sdk import OK")
print("lerobot_robot_piper import OK")
PY
```

## SO101 to Piper Teleoperation

First teleop smoke test, with cameras disabled:

```bash
lerobot-teleoperate \
  --robot.type=piper \
  --robot.can_interface=can0 \
  --robot.bitrate=1000000 \
  --robot.include_gripper=true \
  --robot.use_degrees=false \
  --robot.cameras='{}' \
  --teleop.type=so101_leader \
  --teleop.port="$SO101_PORT" \
  --teleop.id=so101_leader_piper \
  --teleop.use_degrees=false
```

Set `SO101_PORT` to the stable `/dev/serial/by-id/...` path when available.

Or use:

```bash
./scripts/teleop_piper_so101_no_cameras.sh
```

The Piper plugin defaults to a wrist camera at OpenCV index `4`. If `/dev/video4` is not present, teleop fails with `Failed to open OpenCVCamera(4)`. The no-camera smoke test disables cameras with `--robot.cameras='{}'`.

## Camera Discovery and Camera Teleop

Discover available OpenCV cameras:

```bash
source .venv/bin/activate
lerobot-find-cameras opencv
```

This writes captured test images under `outputs/captured_images/`. The `outputs/` directory is ignored by git and should not be committed.

Example result on this machine:

```text
Camera #0: /dev/video0, YUYV, 640x480, 30 fps
Camera #1: /dev/video2, GREY, 640x360, 30 fps
Camera #2: /dev/video4, YUYV, 640x480, 30 fps
```

The working wrist camera here was `/dev/video4`, but users must run discovery on their own machine and choose the correct device.

Camera-enabled teleop:

```bash
export PIPER_CAMERA=/dev/video4

lerobot-teleoperate \
  --robot.type=piper \
  --robot.can_interface=can0 \
  --robot.bitrate=1000000 \
  --robot.include_gripper=true \
  --robot.use_degrees=false \
  --robot.cameras="{\"wrist\": {\"type\": \"opencv\", \"index_or_path\": \"$PIPER_CAMERA\", \"width\": 640, \"height\": 480, \"fps\": 30, \"fourcc\": \"MJPG\"}}" \
  --teleop.type=so101_leader \
  --teleop.port="$SO101_PORT" \
  --teleop.id=so101_leader_piper \
  --teleop.use_degrees=false \
  --display_data=true
```

Or use:

```bash
PIPER_CAMERA=/dev/video0 DISPLAY_DATA=true ./scripts/teleop_piper_so101_with_camera.sh
```

`--display_data=true` requires `rerun-sdk`, installed through `lerobot[viz]`.

## Record a Tiny Smoke Dataset

LeRobot's real-robot tutorial frames the workflow as teleoperation, recording trajectories, then training a policy. Use the same teleoperator `id` for teleoperation, recording, and evaluation because LeRobot stores calibration files under that id.

Current calibration id:

```bash
export SO101_ID=so101_leader_piper
```

Create a dataset directory:

```bash
mkdir -p ~/robot_ws/datasets
```

Record a tiny smoke dataset:

```bash
lerobot-record \
  --robot.type=piper \
  --robot.can_interface=can0 \
  --robot.bitrate=1000000 \
  --robot.include_gripper=true \
  --robot.use_degrees=false \
  --robot.cameras='{"front": {"type": "opencv", "index_or_path": 0, "width": 640, "height": 480, "fps": 30, "fourcc": "MJPG"}}' \
  --teleop.type=so101_leader \
  --teleop.port="$SO101_PORT" \
  --teleop.id=so101_leader_piper \
  --teleop.use_degrees=false \
  --display_data=true \
  --dataset.repo_id=local/piper-so101-smoke \
  --dataset.root=~/robot_ws/datasets \
  --dataset.single_task="move the gripper between two safe poses" \
  --dataset.num_episodes=2 \
  --dataset.episode_time_s=10 \
  --dataset.reset_time_s=5 \
  --dataset.push_to_hub=False
```

Or use:

```bash
PIPER_CAMERA=/dev/video0 ./scripts/record_piper_so101_smoke.sh
```

Known issue: the end effector/gripper path is not working yet. Keep smoke recordings limited to safe arm motion until the gripper mapping/control is fixed.

## Notes

- `can-utils` is needed for CAN bus inspection and control workflows.
- `v4l-utils` is useful for enumerating and validating camera devices.
- `ffmpeg` is commonly needed by robot data collection and video tooling.
