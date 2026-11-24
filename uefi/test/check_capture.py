"""Verify the real GOP fixture's serial output and optionally save the frame."""
import os
from pathlib import Path
import selectors
import subprocess
import sys
import time

output, *command = sys.argv[1:]
header = b"NEBOOT-GOP/1 00a0 0064\r\n"
footer = b"NEBOOT-GOP/END\r\n"
row = b"ff0000" * 80 + b"00ff00" * 80 + b"\r\n"
expected = header + row * 100 + footer
serial = bytearray()
start = -1
with subprocess.Popen(command, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
                      stderr=subprocess.STDOUT) as qemu:
    try:
        with selectors.DefaultSelector() as selector:
            selector.register(qemu.stdout, selectors.EVENT_READ)
            deadline = time.monotonic() + 60
            while (remaining := deadline - time.monotonic()) > 0 and selector.select(remaining):
                chunk = os.read(qemu.stdout.fileno(), 65536)
                if not chunk:
                    break
                serial.extend(chunk)
                start = serial.find(header)
                if start != -1 and len(serial) >= start + len(expected):
                    frame = bytes(serial[start:start + len(expected)])
                    if frame != expected:
                        raise SystemExit("Firmware GOP frame differs from the expected red/green image")
                    if output:
                        Path(output).write_bytes(frame)
                    print(f"AArch64 EDK2 GOP capture: PASS ({len(frame)} serial bytes)")
                    break
                if len(serial) > 4 * 1024 * 1024:
                    break
            if start == -1 or len(serial) < start + len(expected):
                sys.stderr.buffer.write(serial[-8192:])
                raise SystemExit("Firmware exited or timed out before emitting a complete GOP frame")
    finally:
        if qemu.poll() is None:
            qemu.kill()
