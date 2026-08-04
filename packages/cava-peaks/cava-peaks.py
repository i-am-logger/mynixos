#!/usr/bin/env python3
"""
cava-peaks — cava with peak-hold caps.

cava has no peak-hold feature (no peak/hold/cap key exists in its config), so this
drives cava in `raw` output mode, where it emits bar heights as numbers instead of
drawing anything, and does the rendering here. That lets the cap decay on its own
timeline, independent of how fast the bar underneath falls.

Design note: cava is spawned ONCE at a fixed source resolution and the renderer
downsamples to whatever the terminal currently is. Resizing therefore only
recomputes a mapping -- cava is never restarted and the two can never desync.

Response and falloff follow Audacious's analyzer, as used by Linamp
(src/view-player/spectrumwidget.cpp): a fixed 40 dB window,
  x = clamp(40 + 20*log10(n), 0, 40)
with bars falling at VIS_FALLOFF=4 and peaks at VIS_PEAK_FALLOFF=1 units per
frame of a 0-40 scale, holding VIS_DELAY=1 and VIS_PEAK_DELAY=16 frames
respectively, on a 33ms (~30fps) timer.

Default look: an LED-ladder of shade blocks in Winamp's 16 colour bands.

Usage:  cava-peaks                     # the default described above
        cava-peaks --style blocks      # solid bars instead of a ladder
        cava-peaks --retro             # chunky blocks, 4 hard colour zones
        cava-peaks --segment-char thick --segment-gap 1
        cava-peaks --viscolor FILE     # real colours from a skin's viscolor.txt
        cava-peaks --no-caps           # plain bars, for comparison
Keys:   q, Esc or Ctrl-C to quit.
"""

import argparse
import math
import os
import re
import select
import shutil
import signal
import subprocess
import sys
import tempfile
import termios
import time
import tty

BLOCKS = " ▁▂▃▄▅▆▇█"  # 0/8 .. 8/8
CAP_CHAR = "━"

# Segment glyphs, thinnest to densest. The thin rules leave vertical space inside
# their cell, so a ladder of them looks airy even with no blank rows between;
# the half and full blocks fill the cell and read as a solid stack.
SEGMENT_CHARS = {
    "line": "━",      # thin rule, most space around it
    "double": "═",
    "dash": "▬",      # U+25AC: East Asian Ambiguous width, may render wide
    "half": "▄",      # lower 1/2 block -- 50% fill, visibly striped
    "thick": "▆",     # lower 3/4 -- near-solid with a thin dark separator
    "solid": "▇",     # lower 7/8 -- densest that still shows a seam
    "block": "█",     # full cell, no seam at all (same as --style blocks)
    "shade": "▓",     # full cell, textured rather than flat
}
ASCII_MAX = 1000
SOURCE_BARS = 512  # cava's own internal ceiling; we downsample from this

# Winamp colours live in a skin's viscolor.txt: 24 rows, row 0 background,
# row 1 dots, rows 2-17 the analyzer (row 2 = TOP of the bar), rows 18-22 the
# oscilloscope, row 23 the analyzer peak dots. Sixteen analyzer colours for a
# 16px-tall analyzer, i.e. one colour per pixel row -- which is why the classic
# look is banded rather than smoothly blended. BANDS reproduces that.
#
# Values below are the genuine ones, taken from the base-2.91 skin's VISCOLOR.TXT
# (Winamp's own default skin), reversed here to bottom-up ordering. A copy of the
# source file is at ~/.config/cava/viscolor-base-2.91.txt. It runs dark green at
# the bottom through amber to red at the top -- there is no blue in it.
BANDS = 16
WINAMP = [
    (24, 132, 8), (41, 148, 0), (49, 156, 8), (57, 181, 16),
    (50, 190, 16), (41, 206, 16), (148, 222, 33), (189, 222, 41),
    (214, 181, 33), (222, 165, 24), (198, 123, 8), (214, 115, 0),
    (214, 102, 0), (214, 90, 0), (206, 41, 16), (239, 49, 16),
]
OCEAN = [
    (0x2E, 0x9E, 0xF4), (0x22, 0xB3, 0xC8), (0x1C, 0xC7, 0xA0),
    (0x63, 0xD1, 0x3C), (0xD9, 0xC6, 0x2B), (0xF4, 0x5D, 0x5D),
]
PALETTES = {"winamp": WINAMP, "ocean": OCEAN}
CAP_RGB = (150, 150, 150)  # viscolor row 23, "analyzer peak dots" -- grey, not white

# Flat (non-gradient) colours for retro mode. The greens/ambers are the classic
# monochrome phosphor tints; "winamp" borrows the pure green from the middle of
# the base-2.91 analyzer ramp so it sits alongside the gradient palette.
FLAT_COLORS = {
    "green": (51, 255, 51),      # P1 phosphor
    "amber": (255, 176, 0),      # P3 phosphor
    "white": (222, 222, 222),
    "winamp": (41, 206, 16),
    "red": (239, 49, 16),
    "cyan": (0, 224, 224),
}


def load_viscolor(path):
    """Parse a real Winamp viscolor.txt -> (analyzer stops bottom->top, cap rgb).

    Format is 24 rows of 'r,g,b // comment'. Rows 2-17 are the analyzer, listed
    top-down, so they are reversed here. Row 23 is the analyzer peak-dot colour;
    rows 18-22 are the oscilloscope and are ignored."""
    rows = []
    with open(path, "r") as fh:
        for line in fh:
            line = line.split("//")[0].split("#")[0].split(";")[0].strip()
            if not line:
                continue
            parts = [p.strip() for p in line.split(",")]
            if len(parts) >= 3:
                try:
                    rows.append(tuple(int(p) for p in parts[:3]))
                except ValueError:
                    pass
    if len(rows) < 18:
        raise SystemExit("cava-peaks: %s has %d colour rows, expected at least 18"
                         % (path, len(rows)))
    stops = list(reversed(rows[2:18]))          # top-down -> bottom-up
    cap = rows[23] if len(rows) > 23 else CAP_RGB
    return stops, cap

def _spawn_cava(cfg):
    """Spawn cava in raw mode, capturing stderr.

    cava's stderr used to go to DEVNULL, which made every backend failure look
    identical to silence: flat bars, no message. Real cases this hides are a
    missing macOS "System Audio Recording Only" grant (coreaudio tap), and a
    loopback device that has dropped to a degraded sample rate, which makes
    cava reject higher_cutoff_freq and emit nothing at all.

    Returns (proc, stderr_path). Call _cava_died() to surface what it said.
    """
    fd, err_path = tempfile.mkstemp(prefix="cava-peaks-", suffix=".err")
    proc = subprocess.Popen(["cava", "-p", cfg],
                            stdout=subprocess.PIPE, stderr=fd)
    os.close(fd)
    return proc, err_path


def _silent_session(err_path):
    """Warn that no audio ever arrived, and relay anything cava complained about.

    Deferred to process exit so it is not swallowed by the alternate screen.
    """
    try:
        with open(err_path) as fh:
            msg = fh.read().strip()
    except OSError:
        msg = ""
    finally:
        try:
            os.unlink(err_path)
        except OSError:
            pass

    import atexit

    def _report():
        sys.stderr.write("cava-peaks: no audio was captured this session "
                         "(every bar was zero).\n")
        if msg:
            sys.stderr.write("cava said:\n")
            for line in msg.splitlines():
                sys.stderr.write("    %s\n" % line)
        else:
            sys.stderr.write(
                "    cava reported no error, so it is reading a source that is\n"
                "    silent. On macOS check the [input] section:\n"
                "      method = coreaudio / source = tap   needs the terminal\n"
                "        granted 'System Audio Recording Only' in System Settings\n"
                "      method = portaudio                  needs a loopback device\n"
                "        (e.g. Background Music) actually running\n")

    atexit.register(_report)


def _cava_died(proc, err_path, context=""):
    """Print whatever cava wrote to stderr, then exit non-zero."""
    try:
        with open(err_path) as fh:
            msg = fh.read().strip()
    except OSError:
        msg = ""
    finally:
        try:
            os.unlink(err_path)
        except OSError:
            pass
    sys.stderr.write("cava-peaks: cava produced no audio data%s\n"
                     % (" " + context if context else ""))
    if msg:
        sys.stderr.write("cava said:\n")
        for line in msg.splitlines():
            sys.stderr.write("    %s\n" % line)
    else:
        sys.stderr.write("    (cava exited without a message)\n")
    raise SystemExit(1)


DEFAULT_CONFIG = os.path.expanduser("~/.config/cava/config")
GAIN_FILE = os.path.expanduser("~/.config/cava/peaks-gain.txt")


def load_gain():
    """Calibrated dB offset from --calibrate, 0 if never run."""
    try:
        with open(GAIN_FILE) as fh:
            return float(fh.read().strip())
    except (OSError, ValueError):
        return 0.0


def save_gain(db):
    os.makedirs(os.path.dirname(GAIN_FILE), exist_ok=True)
    with open(GAIN_FILE, "w") as fh:
        fh.write("%.2f\n" % db)


def parse_flat_color(args):
    """--flat takes a preset name or a #RRGGBB / RRGGBB hex value."""
    v = args.flat
    if v in FLAT_COLORS:
        return FLAT_COLORS[v]
    h = v.lstrip("#")
    if len(h) == 6:
        try:
            return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))
        except ValueError:
            pass
    raise SystemExit("cava-peaks: --flat wants one of %s, or a hex colour like "
                     "'#33ff33' (got %r)" % (", ".join(sorted(FLAT_COLORS)), v))


def lerp_gradient(stops, t):
    if t <= 0:
        return stops[0]
    if t >= 1:
        return stops[-1]
    span = t * (len(stops) - 1)
    i = int(span)
    f = span - i
    c1, c2 = stops[i], stops[i + 1]
    return tuple(int(round(c1[k] + (c2[k] - c1[k]) * f)) for k in range(3))


def fg(rgb):
    return "\x1b[38;2;{};{};{}m".format(*rgb)


def read_input_section(path):
    """Copy the [input] block out of the user's cava config so raw mode listens to
    the same device without duplicating the source name here."""
    try:
        with open(path, "r") as fh:
            text = fh.read()
    except OSError:
        return "method = portaudio\n"
    m = re.search(r"^\[input\]\s*$(.*?)(?=^\[|\Z)", text, re.M | re.S)
    if not m:
        return "method = portaudio\n"
    lines = [s for s in (l.strip() for l in m.group(1).splitlines())
             if s and not s.startswith("#") and not s.startswith(";")]
    return "\n".join(lines) + "\n" if lines else "method = portaudio\n"


def write_raw_config(framerate, input_section, noise_reduction, autosens):
    fd, path = tempfile.mkstemp(prefix="cava-peaks-", suffix=".conf")
    with os.fdopen(fd, "w") as fh:
        fh.write(
            "[general]\nframerate = {fr}\nbars = {bars}\nautosens = {asens}\n"
            "\n[input]\n{inp}"
            "\n[output]\nmethod = raw\nraw_target = /dev/stdout\n"
            "data_format = ascii\nascii_max_range = {amax}\n"
            "channels = mono\nmono_option = average\n"
            "\n[smoothing]\nnoise_reduction = {nr}\n".format(nr=noise_reduction, asens=1 if autosens else 0,
                fr=framerate, bars=SOURCE_BARS, inp=input_section, amax=ASCII_MAX)
        )
    return path


class Renderer:
    def __init__(self, args, stops=None, cap=None):
        self.args = args
        self.stops = stops or PALETTES[args.palette]
        self.cap_rgb = cap or CAP_RGB
        self.flat_rgb = parse_flat_color(args) if getattr(args, "flat", None) else None
        self.seg_char = SEGMENT_CHARS.get(getattr(args, "segment_char", "line"),
                                          getattr(args, "segment_char", "line"))
        self.nsrc = 0
        self.nbars = 0
        self.peaks = []
        self.bars = []
        self.bar_holds = []
        self.vels = []
        self.holds = []
        self.fit()

    def fit(self):
        """Recompute display geometry. Safe to call at any time; peaks are carried
        across so caps do not jump when the window changes."""
        size = shutil.get_terminal_size(fallback=(80, 24))
        self.cols, self.rows = size.columns, size.lines
        self.height = max(1, self.rows - 1)
        slot = self.args.bar_width + self.args.spacing
        new_n = max(1, (self.cols + self.args.spacing) // slot)

        old_peaks, old_n = self.peaks, self.nbars
        if old_n and new_n != old_n:
            self.peaks = [old_peaks[min(old_n - 1, i * old_n // new_n)]
                          for i in range(new_n)]
        elif new_n != old_n:
            self.peaks = [0.0] * new_n
        self.vels = [0.0] * new_n
        self.holds = [0.0] * new_n
        self.bars = [0.0] * new_n
        self.bar_holds = [0.0] * new_n
        self.nbars = new_n
        if self.flat_rgb is not None:
            # Retro: one flat colour for the whole bar, no vertical ramp. Winamp's
            # vis right-click offered exactly this as an alternative to the
            # gradient, and monochrome CRT meters had no choice about it.
            self.row_colors = [fg(self.flat_rgb)] * self.height
        else:
            # Quantise into BANDS discrete steps rather than blending per row, so
            # the ramp stays banded like a 16px Winamp analyzer at any height.
            nb = self.resolve_bands()
            self.row_colors = []
            for r in range(self.height):
                t = (self.height - 1 - r) / max(1, self.height - 1)
                band = min(nb - 1, int(t * nb))
                self.row_colors.append(
                    fg(lerp_gradient(self.stops, band / (nb - 1))))
        self.edges = None  # rebuilt lazily once we know the source width

    def resolve_bands(self):
        """How many colour steps to spread up the bar.

        'auto' ties it to how many marks are actually drawn, so every drawn
        segment gets its own colour: for the segment ladder that is the count of
        LIT rows (height / (gap + 1)), for solid bars it is the row count. A tall
        window therefore gets a finer ramp and a short one a coarser one, instead
        of a fixed 16 that looks banded at 40 rows and blocky at 10.
        """
        b = self.args.bands
        if b != "auto":
            return max(2, int(b))
        if self.args.style == "segments":
            step = max(1, self.args.segment_gap + 1)
            return max(2, (self.height + step - 1) // step)
        return max(2, self.height)

    def build_edges(self, nsrc):
        """Map nsrc source bins onto nbars display bars. Handles both directions:
        many source bins per bar (downsample by max) and fewer (nearest neighbour)."""
        self.nsrc = nsrc
        n = self.nbars
        self.edges = []
        for i in range(n):
            lo = i * nsrc // n
            hi = max(lo + 1, (i + 1) * nsrc // n)
            self.edges.append((lo, min(hi, nsrc)))

    def resample(self, src):
        if self.edges is None or self.nsrc != len(src):
            self.build_edges(len(src))
        if self.args.response == "db":
            # Audacious's computeFreqBand accumulates the bins inside a band
            # rather than taking their max. Mean rather than raw sum because
            # cava has already normalised, so a sum would just pin at full.
            return [sum(src[lo:hi]) / (hi - lo) for lo, hi in self.edges]
        return [max(src[lo:hi]) for lo, hi in self.edges]

    def apply_response(self, vals):
        """Audacious's amplitude response:  x = clamp(40 + 20*log10(n), 0, 40)

        A fixed 40 dB window, which is what gives the classic analyzer its feel:
        quiet detail is lifted well off the floor and loud passages compress,
        instead of the bottom-heavy look of a linear magnitude scale.

        gain_db anchors the reference. Audacious meters against FFT magnitudes;
        cava's raw units differ, so --calibrate measures the offset once and
        stores it. With autosens off this reference is FIXED, so a quiet track
        genuinely reads quiet -- which is the whole point of a real meter.
        """
        if self.args.response != "db":
            return vals
        r = self.args.db_range
        out = []
        for v in vals:
            if v <= 1e-6:
                out.append(0.0)
            else:
                db = 20.0 * math.log10(v) + self.args.gain_db
                out.append(max(0.0, min(1.0, (r + db) / r)))
        return out

    def step_bars(self, vals, dt):
        """Bar falloff, the same shape as the peaks but four times quicker --
        Audacious uses VIS_FALLOFF=4 against VIS_PEAK_FALLOFF=1, both per frame
        on a 0-40 scale. That 4:1 ratio is what makes the caps read as separate."""
        a = self.args
        if a.bar_fall_rate <= 0:
            return vals
        for i, v in enumerate(vals):
            if v >= self.bars[i]:
                self.bars[i] = v
                self.bar_holds[i] = a.bar_hold
            elif self.bar_holds[i] > 0.0:
                self.bar_holds[i] -= dt
            else:
                self.bars[i] = max(0.0, self.bars[i] - a.bar_fall_rate * dt)
        return self.bars

    def step_peaks(self, vals, dt):
        """Cap motion. Two curves:

        linear (default) -- what Winamp-lineage code actually does. Audacious's
        analyzer, and Linamp's copy of it, hold the peak for VIS_PEAK_DELAY=16
        frames then subtract VIS_PEAK_FALLOFF=1 unit per frame from a 0-40 scale
        at a 33ms timer. That is a 0.53s hold followed by a CONSTANT 0.75
        full-scale/s descent -- no acceleration.

        accel -- a gravity model: the cap starts slow and speeds up. Not what
        Winamp does, but some people prefer the weightier feel.
        """
        a = self.args
        linear = a.fall == "linear"
        for i, v in enumerate(vals):
            if v >= self.peaks[i]:
                self.peaks[i] = v
                self.vels[i] = 0.0
                self.holds[i] = a.hold
            elif self.holds[i] > 0.0:
                self.holds[i] -= dt
            elif linear:
                self.peaks[i] = max(0.0, self.peaks[i] - a.fall_rate * dt)
            else:
                self.vels[i] += a.decay * dt
                self.peaks[i] = max(0.0, self.peaks[i] - self.vels[i] * dt)

    def frame(self, vals):
        H = self.height
        bw, sp = self.args.bar_width, self.args.spacing
        gap = " " * sp
        cap_col = fg(self.cap_rgb)
        if self.args.coarse:
            # Round to whole cells so bars step in full rows, like a meter with
            # discrete segments rather than smooth sub-cell interpolation.
            eighths = [int(round(v * H)) * 8 for v in vals]
        else:
            eighths = [int(v * H * 8) for v in vals]
        # Caps never vanish: a fully decayed peak rests on row 0 rather than being
        # dropped, so the bottom keeps a continuous cap line.
        cap_rows = None if self.args.no_caps else [
            max(0, min(H - 1, int(p * H))) for p in self.peaks
        ]

        # Segment style: the bar is a stack of discrete marks with gaps between
        # them, drawn with the same glyph as the cap -- a hi-fi LED ladder rather
        # than a solid column. Lit rows are spaced every (gap + 1) cells.
        segments = self.args.style == "segments"
        if segments:
            step = self.args.segment_gap + 1
            seg_tops = [int(round(v * H)) for v in vals]

        out = ["\x1b[H"]
        for r in range(H):
            from_bottom = H - 1 - r
            rc = self.row_colors[r]
            out.append(rc)
            cells = []
            for i in range(self.nbars):
                if cap_rows is not None and cap_rows[i] == from_bottom:
                    cells.append(cap_col + CAP_CHAR * bw + rc)
                    continue
                if segments:
                    lit = from_bottom < seg_tops[i] and from_bottom % step == 0
                    cells.append((self.seg_char if lit else " ") * bw)
                    continue
                full, rem = divmod(eighths[i], 8)
                if from_bottom < full:
                    ch = BLOCKS[8]
                elif from_bottom == full and rem:
                    ch = BLOCKS[rem]
                else:
                    ch = " "
                cells.append(ch * bw)
            out.append(gap.join(cells))
            out.append("\x1b[K")
            if r != H - 1:
                out.append("\r\n")
        out.append("\x1b[0m")
        return "".join(out)


def run_calibration(args, rend, cfg):
    """Measure the loudest band level over a window and derive the dB offset that
    puts it at full scale. Runs with the SAME cava settings as a normal session,
    so the number transfers directly."""
    print("Calibrating for %.0fs -- play typical material at your usual volume."
          % args.calibrate)
    proc, cava_err = _spawn_cava(cfg)
    peak = 0.0
    frames = 0
    # frames stays 0 if cava never started; reported via _cava_died below.
    deadline = time.monotonic() + args.calibrate
    try:
        for raw in proc.stdout:
            if time.monotonic() >= deadline:
                break
            parts = raw.decode("ascii", "ignore").strip().strip(";").split(";")
            if len(parts) < 2:
                continue
            try:
                src = [int(x) / ASCII_MAX for x in parts]
            except ValueError:
                continue
            frames += 1
            band_peak = max(rend.resample(src))
            if band_peak > peak:
                peak = band_peak
            if sys.stdout.isatty():   # \r only overwrites on a terminal
                left = deadline - time.monotonic()
                sys.stdout.write("\r  %4.1fs left   loudest band so far: %.4f "
                                 % (left, peak))
                sys.stdout.flush()
    finally:
        proc.terminate()
        try:
            proc.wait(timeout=2)
        except subprocess.TimeoutExpired:
            proc.kill()
        if os.path.exists(cfg):
            os.unlink(cfg)

    print()
    if frames < 10 or peak <= 1e-6:
        print("Not enough signal (%d frames, peak %.6f). Is audio playing into the"
              % (frames, peak))
        print("device in ~/.config/cava/config? Nothing was saved.")
        return
    gain = -20.0 * math.log10(peak)
    save_gain(gain)
    print("Loudest band: %.4f  ->  gain %+.2f dB   (saved to %s)"
          % (peak, gain, GAIN_FILE))
    print("That level now sits at full scale; %.0f dB below it reaches the floor."
          % args.db_range)


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--hold", type=float, default=0.53,
                   help="seconds a cap sits at a new max before falling "
                        "(default 0.53 = Audacious/Linamp's 16 frames at 30fps)")
    p.add_argument("--fall", choices=("linear", "accel"), default="linear",
                   help="cap fall curve; linear is what Winamp-lineage code does")
    p.add_argument("--fall-rate", type=float, default=0.75,
                   help="linear cap fall speed, full-scale/s "
                        "(default 0.75 = 1 unit of 40 per frame at 30fps)")
    p.add_argument("--decay", type=float, default=1.8,
                   help="cap fall acceleration for --fall accel, full-scale/s^2")
    p.add_argument("--response", choices=("db", "linear"), default="db",
                   help="amplitude curve; db = Audacious's 40 dB window (default)")
    p.add_argument("--db-range", type=float, default=40.0,
                   help="dB window for --response db (default 40, as Audacious)")
    p.add_argument("--bar-fall-rate", type=float, default=3.0,
                   help="bar fall speed, full-scale/s (default 3.0 = 4 units of "
                        "40 per frame at 30fps; 0 disables and lets cava smooth)")
    p.add_argument("--bar-hold", type=float, default=0.033,
                   help="seconds a bar holds before falling (default 0.033 = 1 frame)")
    p.add_argument("--gain-db", type=float, default=None,
                   help="dB offset anchoring the fixed reference "
                        "(default: value from --calibrate, else 0)")
    p.add_argument("--autosens", action="store_true",
                   help="let cava auto-normalise instead of using a fixed "
                        "reference; livelier, but a quiet track no longer reads quiet")
    p.add_argument("--calibrate", type=float, nargs="?", const=10.0, metavar="SECONDS",
                   help="play typical material at typical volume for N seconds "
                        "(default 10); measures and stores the gain, then exits")
    p.add_argument("--palette", choices=sorted(PALETTES), default="winamp",
                   help="built-in palette (default: the real base-2.91 analyzer colours)")
    p.add_argument("--flat", metavar="COLOR", nargs="?", const="green",
                   help="retro flat colouring instead of the vertical gradient: "
                        "a preset (%s) or a hex value like '#33ff33'"
                        % ", ".join(sorted(FLAT_COLORS)))
    p.add_argument("--bands", default=None, metavar="N|auto",
                   help="discrete colour steps up the bar. 'auto' (default) gives "
                        "one per drawn mark, so it scales with the window; %d "
                        "matches Winamp's 16px analyzer; low values give hard, "
                        "obviously-stepped zones." % BANDS)
    p.add_argument("--style", choices=("blocks", "segments"), default="segments",
                   help="bar rendering: an LED-ladder stack of marks (default), "
                        "or solid blocks")
    p.add_argument("--segment-gap", type=int, default=0, metavar="N",
                   help="blank rows between lit segments (default 0; raise for a "
                        "sparser ladder)")
    p.add_argument("--segment-char", default="shade", metavar="CHAR",
                   help="glyph for --style segments: %s, or any single character. "
                        "default 'shade'. 'line' is a thin rule with space "
                        "around it; 'half'/'thick'/'block' fill the cell"
                        % ", ".join(SEGMENT_CHARS))
    p.add_argument("--coarse", action="store_true",
                   help="full blocks only, no eighth-height sub-cell steps -- "
                        "the chunkier look of a low-resolution meter")
    p.add_argument("--retro", action="store_true",
                   help="chunky solid blocks in 4 hard colour zones: sets "
                        "--style blocks --bands 4 --coarse")
    p.add_argument("--viscolor", metavar="FILE",
                   help="load real colours from a Winamp viscolor.txt (overrides --palette)")
    p.add_argument("--bar-width", type=int, default=2)
    p.add_argument("--spacing", type=int, default=1)
    p.add_argument("--framerate", type=int, default=60)
    p.add_argument("--config", default=DEFAULT_CONFIG,
                   help="cava config to copy the [input] section from")
    p.add_argument("--no-caps", action="store_true")
    args = p.parse_args()
    # --retro only fills in values the user did NOT pass. --bands defaults to None
    # so an explicit --bands 16 stays distinguishable from the unset default.
    if args.retro:
        args.style = "blocks"
        args.coarse = True
        if args.bands is None:
            args.bands = 4
    if args.bands is None:
        args.bands = "auto"
    if args.bands != "auto":
        try:
            int(args.bands)
        except ValueError:
            raise SystemExit("cava-peaks: --bands wants a number or 'auto' (got %r)"
                             % args.bands)
    if args.gain_db is None:
        args.gain_db = load_gain()

    if shutil.which("cava") is None:
        sys.exit("cava-peaks: cava not found on PATH")

    stops = cap = None
    if args.viscolor:
        stops, cap = load_viscolor(args.viscolor)

    rend = Renderer(args, stops, cap)
    resized = {"flag": False}
    signal.signal(signal.SIGWINCH, lambda *_: resized.__setitem__("flag", True))

    cfg = write_raw_config(args.framerate, read_input_section(args.config),
                           0 if args.bar_fall_rate > 0 else 45, args.autosens)

    if args.calibrate:
        run_calibration(args, rend, cfg)
        return
    stdin_fd = sys.stdin.fileno() if sys.stdin.isatty() else None
    saved_tty = termios.tcgetattr(stdin_fd) if stdin_fd is not None else None

    proc = None
    try:
        if stdin_fd is not None:
            tty.setcbreak(stdin_fd)  # so a single keypress arrives unbuffered
        sys.stdout.write("\x1b[?1049h\x1b[?25l\x1b[2J")
        sys.stdout.flush()

        proc, cava_err = _spawn_cava(cfg)
        last = time.monotonic()
        got_frame = False
        saw_signal = False
        for raw in proc.stdout:
            got_frame = True
            if resized["flag"]:
                resized["flag"] = False
                rend.fit()
                sys.stdout.write("\x1b[2J")

            if stdin_fd is not None and select.select([stdin_fd], [], [], 0)[0]:
                key = os.read(stdin_fd, 8)
                if key[:1] in (b"q", b"Q", b"\x1b", b"\x03"):
                    break

            parts = raw.decode("ascii", "ignore").strip().strip(";").split(";")
            if len(parts) < 2:
                continue
            try:
                src = [int(x) / ASCII_MAX for x in parts]
            except ValueError:
                continue

            if not saw_signal and any(v > 0 for v in src):
                saw_signal = True

            vals = rend.apply_response(rend.resample(src))
            now = time.monotonic()
            dt = min(0.25, now - last)
            last = now
            # Audacious compares BOTH bars and peaks against the same raw value,
            # so peaks track the input, not the already-smoothed bar.
            rend.step_peaks(vals, dt)
            sys.stdout.write(rend.frame(rend.step_bars(vals, dt)))
            sys.stdout.flush()
        if not got_frame:
            _cava_died(proc, cava_err,
                       "(check the [input] method/source in your cava config)")
        if not saw_signal:
            # cava ran and streamed, but every bar was zero for the whole
            # session. Silence looks identical to a misconfigured input, and
            # cava reports the latter on stderr, so show it.
            _silent_session(cava_err)
    except KeyboardInterrupt:
        pass
    finally:
        if proc and proc.poll() is None:
            proc.terminate()
            try:
                proc.wait(timeout=2)
            except subprocess.TimeoutExpired:
                proc.kill()
        if saved_tty is not None:
            termios.tcsetattr(stdin_fd, termios.TCSADRAIN, saved_tty)
        if os.path.exists(cfg):
            os.unlink(cfg)
        sys.stdout.write("\x1b[?25h\x1b[?1049l")
        sys.stdout.flush()


if __name__ == "__main__":
    main()
