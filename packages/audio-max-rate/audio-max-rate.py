#!/usr/bin/env python3
"""Set CoreAudio devices to their highest supported nominal sample rate.

macOS exposes no way to do this declaratively: there is no `defaults` key, no
nix-darwin option, and no packaged CLI (switchaudio-osx only changes which
device is *default*). Audio MIDI Setup does it through the CoreAudio API, so
that is what this drives -- via ctypes, so it needs nothing beyond stdlib
python3 and no compiler.

Note a device only holds a rate until something renegotiates it. A passthrough
device such as Background Music follows whatever the real output is doing, so
setting it directly is meaningless; those advertise a sentinel "any rate" range
and are skipped.

Usage:
    audio-max-rate                 # set every device to its max
    audio-max-rate --exclude Mic   # skip devices whose name contains "Mic"
    audio-max-rate --dry-run       # report only
"""
import argparse
import ctypes
import ctypes.util
import struct
import sys

_ca = ctypes.CDLL(ctypes.util.find_library("CoreAudio"))
_cf = ctypes.CDLL(ctypes.util.find_library("CoreFoundation"))
_cf.CFStringGetCStringPtr.restype = ctypes.c_char_p

# Anything above this is a sentinel meaning "I accept any rate" (virtual
# passthrough devices), not a real capability.
SANE_MAX_HZ = 768000

kAudioObjectSystemObject = 1
kCFStringEncodingUTF8 = 0x08000100


class _Addr(ctypes.Structure):
    _fields_ = [
        ("mSelector", ctypes.c_uint32),
        ("mScope", ctypes.c_uint32),
        ("mElement", ctypes.c_uint32),
    ]


def _fourcc(s):
    return struct.unpack(">I", s.encode())[0]


_GLOBAL = _fourcc("glob")
_DEVICES = _fourcc("dev#")
_NAME = _fourcc("lnam")
_RATES = _fourcc("nsr#")
_RATE = _fourcc("nsrt")


def _devices():
    addr = _Addr(_DEVICES, _GLOBAL, 0)
    size = ctypes.c_uint32()
    if _ca.AudioObjectGetPropertyDataSize(
        kAudioObjectSystemObject, ctypes.byref(addr), 0, None, ctypes.byref(size)
    ):
        return []
    buf = (ctypes.c_uint32 * (size.value // 4))()
    _ca.AudioObjectGetPropertyData(
        kAudioObjectSystemObject, ctypes.byref(addr), 0, None,
        ctypes.byref(size), buf,
    )
    return list(buf)


def _name(dev):
    addr = _Addr(_NAME, _GLOBAL, 0)
    size = ctypes.c_uint32()
    if _ca.AudioObjectGetPropertyDataSize(dev, ctypes.byref(addr), 0, None,
                                          ctypes.byref(size)):
        return None
    ref = ctypes.c_void_p()
    _ca.AudioObjectGetPropertyData(dev, ctypes.byref(addr), 0, None,
                                   ctypes.byref(size), ctypes.byref(ref))
    raw = _cf.CFStringGetCStringPtr(ref, kCFStringEncodingUTF8)
    return raw.decode() if raw else None


def _available(dev):
    """Supported rates. The property is an array of (min,max) ranges."""
    addr = _Addr(_RATES, _GLOBAL, 0)
    size = ctypes.c_uint32()
    if _ca.AudioObjectGetPropertyDataSize(dev, ctypes.byref(addr), 0, None,
                                          ctypes.byref(size)):
        return []
    count = size.value // 16  # two doubles per range
    buf = (ctypes.c_double * (count * 2))()
    _ca.AudioObjectGetPropertyData(dev, ctypes.byref(addr), 0, None,
                                   ctypes.byref(size), buf)
    return sorted({buf[i * 2 + 1] for i in range(count)})


def _rate(dev):
    addr = _Addr(_RATE, _GLOBAL, 0)
    size = ctypes.c_uint32(8)
    val = ctypes.c_double()
    if _ca.AudioObjectGetPropertyData(dev, ctypes.byref(addr), 0, None,
                                      ctypes.byref(size), ctypes.byref(val)):
        return None
    return val.value


def _set_rate(dev, hz):
    addr = _Addr(_RATE, _GLOBAL, 0)
    return _ca.AudioObjectSetPropertyData(
        dev, ctypes.byref(addr), 0, None, 8, ctypes.byref(ctypes.c_double(hz))
    )


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--exclude", action="append", default=[], metavar="SUBSTR",
                    help="skip devices whose name contains SUBSTR (repeatable)")
    ap.add_argument("--dry-run", action="store_true",
                    help="report what would change, change nothing")
    args = ap.parse_args()

    changed = failed = 0
    for dev in _devices():
        name = _name(dev)
        if not name:
            continue
        if any(x.lower() in name.lower() for x in args.exclude):
            print(f"  {name:30s} skipped (excluded)")
            continue

        rates = [r for r in _available(dev) if r <= SANE_MAX_HZ]
        if not rates:
            print(f"  {name:30s} skipped (accepts any rate; follows its output)")
            continue

        target = rates[-1]
        current = _rate(dev)
        if current is None:
            print(f"  {name:30s} skipped (no current rate)")
            continue
        if abs(current - target) < 1:
            print(f"  {name:30s} {int(current)} already max")
            continue

        if args.dry_run:
            print(f"  {name:30s} {int(current)} -> {int(target)} (dry run)")
            continue

        status = _set_rate(dev, target)
        if status == 0:
            print(f"  {name:30s} {int(current)} -> {int(target)}")
            changed += 1
        else:
            # Commonly because the device is in use by another process.
            print(f"  {name:30s} {int(current)} -> {int(target)} FAILED ({status})")
            failed += 1

    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
