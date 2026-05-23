#!/usr/bin/env python3
import argparse
import time

from piper_sdk import C_PiperInterface_V2


def main() -> None:
    parser = argparse.ArgumentParser(description="Read-only Piper SDK connectivity check.")
    parser.add_argument("--can-interface", default="can0", help="CAN interface to use, default: can0")
    args = parser.parse_args()

    piper = C_PiperInterface_V2(args.can_interface)
    piper.ConnectPort()
    time.sleep(0.2)

    print("Firmware:", piper.GetPiperFirmwareVersion())
    print("Arm status:", piper.GetArmStatus())


if __name__ == "__main__":
    main()

