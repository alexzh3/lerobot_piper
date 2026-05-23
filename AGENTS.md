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

# Cameras

Run camera discovery before camera-enabled teleop:

```bash
lerobot-find-cameras opencv
```

This writes captured images to `outputs/captured_images/`; keep `outputs/` ignored and do not commit captured images.

Observed cameras on this machine included `/dev/video0`, `/dev/video2`, and `/dev/video4`; `/dev/video4` worked for the wrist camera here. Users must run discovery on their own machine because camera indices can change.

Use camera-enabled teleop only after selecting the camera:

```bash
PIPER_CAMERA=/dev/video0 DISPLAY_DATA=true ./scripts/teleop_piper_so101_with_camera.sh
```

`--display_data=true` requires `rerun-sdk`; install LeRobot with `.[feetech,dataset,viz]` or run `uv pip install 'lerobot[viz]'` in the active environment.

# Recording

Use the same teleoperator id for teleoperation, recording, and evaluation because LeRobot stores calibration files by id. Current id:

```bash
export SO101_ID=so101_leader_piper
```

Tiny smoke dataset helper:

```bash
PIPER_CAMERA=/dev/video0 ./scripts/record_piper_so101_smoke.sh
```

The helper writes to `~/robot_ws/datasets` by default. Do not commit local datasets or captured camera outputs.

Known issue: the end effector/gripper path is not working yet. Avoid workflows that depend on reliable gripper control until that mapping/control path is fixed.

# CAN and Piper Status

Use the reusable status helper before teleop or gripper debugging:

```bash
./scripts/piper_can_status.sh
```

It brings up `can0` at 1 Mbps by default, prints SocketCAN details/statistics, then reads Piper firmware, arm status, gripper status, and SDK gripper range. It may require the human operator to enter a `sudo` password.

Override when needed:

```bash
CAN_INTERFACE=can1 CAN_BITRATE=1000000 ./scripts/piper_can_status.sh
```
