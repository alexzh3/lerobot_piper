@/home/dfki.uni-bremen.de/azheng/.codex/RTK.md

# Project Context

This repository sets up teleoperation with:

- SO-101 leader arm
- AgileX Piper follower arm
- LeRobot installed from source
- Piper support through `lerobot_robot_piper`
- Python environment managed by `uv`

# Environment

Use the repo-local virtual environment:

```bash
uv python install 3.12
uv venv --python 3.12
source .venv/bin/activate
```

The current expected Python version is 3.12.

# Setup Script

The main setup entry point is:

```bash
./scripts/setup_piper_arm.sh
```

The script installs system dependencies, creates the uv virtual environment, clones LeRobot and the Piper plugin, installs them editable, and runs an import smoke test.

# Source Dependencies

These directories are generated workspace dependencies and are ignored by git:

- `lerobot/`
- `lerobot_robot_piper/`
- `.venv/`
- `.uv-cache/`
- `.uv-python/`

Do not vendor or manually copy code from those repositories into this setup repo unless explicitly requested.

# Verification

After setup, use:

```bash
source .venv/bin/activate
lerobot-info
lerobot-teleoperate --help
lerobot-record --help
```

`lerobot-find-port --help` currently starts LeRobot's interactive port finder instead of showing argparse help. Run it manually in an interactive terminal with the SO101 bus-servo adapter connected.

Finding the SO101 port requires human physical input. Agents should not pretend this can be completed unattended. Use:

```bash
./scripts/find_so101_port.sh
```

Tell the human operator:

- Keep the SO101 MotorsBus USB cable connected before starting.
- When prompted, unplug the SO101 MotorsBus USB cable.
- Press Enter.
- Wait for LeRobot to print the detected port.
- Reconnect the SO101 MotorsBus USB cable.

Prefer stable `/dev/serial/by-id/...` paths over direct `/dev/ttyACM*` paths. Current observed stable path on this machine:

```bash
export SO101_PORT=/dev/serial/by-id/usb-1a86_USB_Single_Serial_5AA9017078-if00
```

The symlink currently points to `/dev/ttyACM0`, but agents should document and use the stable path when possible.

If the SO101 leader motors were never configured, run leader motor setup once:

```bash
lerobot-setup-motors \
  --teleop.type=so101_leader \
  --teleop.port="$SO101_PORT"
```

Then calibrate the leader:

```bash
lerobot-calibrate \
  --teleop.type=so101_leader \
  --teleop.port="$SO101_PORT" \
  --teleop.id=so101_leader_piper
```

Do not run SO101 follower setup on the PiPER. PiPER is controlled via CAN and `piper_sdk`, not Feetech motors.

# Teleoperation Target

The intended pairing is:

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

Set `SO101_PORT` to the stable SO101 adapter path found under `/dev/serial/by-id/`.

Use `./scripts/teleop_piper_so101_no_cameras.sh` for the first smoke test. The Piper plugin defaults to OpenCV camera index `4`; if `/dev/video4` is absent, teleop fails during camera connect. Disable cameras with `--robot.cameras='{}'` until camera discovery is configured intentionally.
