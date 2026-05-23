# LeRobot Piper Teleoperation

Repository setup for teleoperating an AgileX Piper follower arm with an SO-101 leader arm using LeRobot.

## Current Scope

- SO-101 as the leader arm.
- AgileX Piper as the follower arm.
- Local Python 3.12 environment managed by `uv`.
- LeRobot installed from source with SO101/Feetech support.
- AgileX Piper SDK and community Piper LeRobot plugin.
- Host setup script for the full Piper arm software environment.

## One-Step Setup

From the repository root:

```bash
chmod +x scripts/setup_piper_arm.sh
./scripts/setup_piper_arm.sh
source .venv/bin/activate
```

The script installs system packages, creates `.venv`, clones LeRobot and the Piper plugin, installs the editable Python packages, and runs an import smoke test.

It also brings up `can0` at 1 Mbps when the CAN adapter is present. To override the interface:

```bash
CAN_INTERFACE=can1 CAN_BITRATE=1000000 ./scripts/setup_piper_arm.sh
```

## Create the Python Environment

From the repository root:

```bash
uv python install 3.12
uv venv --python 3.12
source .venv/bin/activate
python --version
```

The current local environment was created with Python 3.12.13.

## Install LeRobot From Source

Install LeRobot with SO101/Feetech support:

```bash
git clone https://github.com/huggingface/lerobot.git
cd lerobot
uv pip install -e ".[feetech,dataset]"
```

The SO101 setup needs the Feetech SDK extra via `.[feetech]`. The dataset extra is included so `lerobot-record` works.

Sanity checks:

```bash
lerobot-info
lerobot-find-port --help
lerobot-teleoperate --help
lerobot-record --help
```

Note: in the installed LeRobot 0.5.2, `lerobot-find-port --help` starts the interactive port finder. Run it from an interactive terminal and follow the unplug/replug prompt to identify the SO101 bus-servo adapter port.

## Install Piper SDK and Plugin

```bash
uv pip install python-can piper_sdk
git clone https://github.com/AgRoboticsResearch/lerobot_robot_piper.git
cd lerobot_robot_piper
uv pip install -e .
```

If the plugin install tries to replace the source LeRobot install:

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

## SO101 Leader to Piper Follower

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

The Piper plugin defaults to a wrist camera at OpenCV index `4`. If `/dev/video4` is not present, teleop fails with `Failed to open OpenCVCamera(4)`. The smoke-test command disables cameras with `--robot.cameras='{}'`.

## Piper CAN

Check CAN devices:

```bash
ip link | grep -E "can[0-9]" || true
```

Bring up `can0`:

```bash
sudo ip link set can0 down 2>/dev/null || true
sudo ip link set can0 type can bitrate 1000000
sudo ip link set can0 up
ip -details link show can0
```

## Required Piper SDK Check

Do not teleoperate until this read-only SDK check works:

```bash
source .venv/bin/activate
python scripts/check_piper_sdk.py --can-interface can0
```

Equivalent inline check:

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

This machine reported firmware `S-V1.8-7`, normal arm status, and error code `0`.

## SO101 Leader Port and Calibration

List stable serial device names:

```bash
ls -l /dev/serial/by-id/ || true
```

Prefer the stable `/dev/serial/by-id/...` path over `/dev/ttyACM0`, because the `ttyACM*` name can change across reconnects.

This machine currently shows the SO101 adapter at this stable path, which points to `/dev/ttyACM0`:

```text
/dev/serial/by-id/usb-1a86_USB_Single_Serial_5AA9017078-if00 -> ../../ttyACM0
```

Set:

```bash
export SO101_PORT=/dev/serial/by-id/usb-1a86_USB_Single_Serial_5AA9017078-if00
```

Find the port interactively:

```bash
source .venv/bin/activate
lerobot-find-port
```

This command needs human input. Keep the SO101 MotorsBus USB cable connected when starting it. When LeRobot prints `Remove the USB cable from your MotorsBus and press Enter when done.`, unplug the SO101 MotorsBus USB cable, press Enter, wait for LeRobot to print the port, then reconnect the cable.

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

Or use:

```bash
./scripts/setup_so101_leader_motors.sh "$SO101_PORT"
```

Do not run SO101 follower setup on the PiPER. PiPER is controlled via CAN and `piper_sdk`, not Feetech motors.

Then calibrate the SO101 leader:

```bash
source .venv/bin/activate
lerobot-calibrate \
  --teleop.type=so101_leader \
  --teleop.port="$SO101_PORT" \
  --teleop.id=so101_leader_piper
```

Or use:

```bash
./scripts/calibrate_so101_leader.sh "$SO101_PORT"
```

See [docs/piper_arm_setup.md](docs/piper_arm_setup.md) for more setup notes.

## Agent Notes

Repo-specific instructions for future coding agents are in [AGENTS.md](AGENTS.md).

## Planned Setup Areas

- SO-101 leader arm configuration.
- AgileX Piper follower arm configuration.
- CAN bus setup and validation.
- Teleoperation launch scripts.
