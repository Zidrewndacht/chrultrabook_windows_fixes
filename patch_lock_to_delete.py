#!/usr/bin/env python3
"""
croskbsettings.bin Lock->Delete Patcher
For Coolstar croskeyboard4 driver on Chromebooks running Windows.

Patches the driver-level keyboard mapping binary to remap the Lock key
(K_LOCK, scan code 0x5D) to Delete (K_DELETE, 0x53).

Usage:
    python patch_lock_to_delete.py [input.bin] [output.bin]

    Defaults: croskbsettings.bin -> croskbsettings_patched.bin
"""

import sys
import struct
import os

K_LOCK = 0x5D
K_DELETE = 0x53
KEY_E0 = 0x02
# 'CrKB' as a little-endian uint32 is stored on disk as b'BKrC'
DISK_MAGIC = b'BKrC'

HEADER_SIZE = 17   # offsetof(RemapCfgs, cfg) from C source
ENTRY_SIZE = 73    # sizeof(RemapCfg) from C source

# Offsets within each 73-byte RemapCfg entry:
#   0-31  : 8 x RemapCfgKeyState enums (4 bytes each)
#  32-33  : originalKey.MakeCode  (USHORT)
#  34-35  : originalKey.Flags    (USHORT)
#  36     : remapVivaldiToFnKeys (BOOLEAN)
#  37-38  : remappedKey.MakeCode (USHORT)
#  39-40  : remappedKey.Flags    (USHORT)
#  41-72  : additionalKeys[0..7] (8 x 4 bytes: MakeCode + Flags)

def patch_file(input_path, output_path):
    with open(input_path, 'rb') as f:
        data = bytearray(f.read())

    if len(data) < HEADER_SIZE:
        raise ValueError(f"File too small ({len(data)} bytes) to be valid croskbsettings.bin")

    magic = bytes(data[0:4])
    if magic != DISK_MAGIC:
        raise ValueError(
            f"Invalid magic: {magic!r} (expected {DISK_MAGIC!r})\n"
            f"This script expects a little-endian binary from croskeyboard4."
        )

    remappings = struct.unpack_from('<I', data, 4)[0]
    expected_size = HEADER_SIZE + ENTRY_SIZE * remappings
    if len(data) != expected_size:
        raise ValueError(
            f"File size mismatch: {len(data)} bytes != expected {expected_size} "
            f"(header {HEADER_SIZE} + {remappings} entries × {ENTRY_SIZE})\n"
            f"The binary may be from a different driver version."
        )

    print(f"[*] Valid binary: {remappings} remapping entries, {len(data)} bytes")

    modified = 0
    for i in range(remappings):
        entry_off = HEADER_SIZE + i * ENTRY_SIZE
        orig_make = struct.unpack_from('<H', data, entry_off + 32)[0]

        if orig_make == K_LOCK:
            print(f"[+] Entry {i}: K_LOCK (0x{K_LOCK:02X}) at file offset 0x{entry_off + 32:X}")

            # Wipe Vivaldi->Fn fallback
            data[entry_off + 36] = 0

            # Set remappedKey to Delete with KEY_E0
            struct.pack_into('<H', data, entry_off + 37, K_DELETE)
            struct.pack_into('<H', data, entry_off + 39, KEY_E0)

            # Clear all 8 additionalKeys slots (removes Win+L, etc.)
            for j in range(8):
                add_off = entry_off + 41 + j * 4
                struct.pack_into('<HH', data, add_off, 0, 0)

            print(f"    -> Remapped to K_DELETE (0x{K_DELETE:02X}) + KEY_E0")
            modified += 1

    if modified == 0:
        print("[!] No K_LOCK entries found. File may already be patched.")
        return False

    with open(output_path, 'wb') as f:
        f.write(data)

    print(f"[+] Wrote patched binary: {output_path}")
    print(f"[+] Modified {modified} entr{'y' if modified == 1 else 'ies'}.")
    print(f"[+] Copy to C:\\Windows\\system32\\drivers\\croskbsettings.bin")
    print(f"[+] Then run 'croskbreload' from an elevated prompt, or reboot.")
    return True


if __name__ == "__main__":
    if len(sys.argv) >= 3:
        in_file = sys.argv[1]
        out_file = sys.argv[2]
    elif len(sys.argv) == 2:
        in_file = sys.argv[1]
        base, ext = os.path.splitext(in_file)
        out_file = f"{base}_patched{ext}"
    else:
        in_file = "croskbsettings.bin"
        out_file = "croskbsettings_patched.bin"

    if not os.path.exists(in_file):
        print(f"[!] Error: Input file not found: {in_file}")
        print(f"    Usage: python {os.path.basename(sys.argv[0])} [input.bin] [output.bin]")
        sys.exit(1)

    patch_file(in_file, out_file)
