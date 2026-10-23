"""Synthesise the bundled alert sounds as 16-bit mono WAV files.

Pure standard library so it runs anywhere. Output goes to both
assets/sounds/ (in-app preview via audioplayers) and
android/app/src/main/res/raw/ (notification channels).
"""
import math
import os
import struct
import wave

SR = 44100


def env(i, n, attack=0.006, decay=6.0):
    t = i / n
    a = min(1.0, (i / SR) / attack) if attack > 0 else 1.0
    return a * math.exp(-decay * t)


def bell(freq, dur, decay=5.5, harmonics=((1, 1.0), (2, 0.42), (3, 0.18))):
    n = int(SR * dur)
    out = []
    for i in range(n):
        e = env(i, n, 0.004, decay)
        s = 0.0
        for mult, amp in harmonics:
            s += amp * math.sin(2 * math.pi * freq * mult * (i / SR))
        out.append(s * e)
    return out


def beep(freq, dur, decay=9.0):
    n = int(SR * dur)
    return [math.sin(2 * math.pi * freq * (i / SR)) * env(i, n, 0.008, decay) for i in range(n)]


def silence(dur):
    return [0.0] * int(SR * dur)


def mix(parts, offsets):
    total = 0
    for p, off in zip(parts, offsets):
        total = max(total, int(SR * off) + len(p))
    buf = [0.0] * total
    for p, off in zip(parts, offsets):
        start = int(SR * off)
        for i, v in enumerate(p):
            buf[start + i] += v
    return buf


def sweep(f0, f1, dur, decay=3.0):
    n = int(SR * dur)
    out = []
    phase = 0.0
    for i in range(n):
        t = i / n
        f = f0 + (f1 - f0) * (t ** 0.7)
        phase += 2 * math.pi * f / SR
        out.append(math.sin(phase) * env(i, n, 0.01, decay))
    return out


def normalise(buf, peak=0.82):
    m = max((abs(v) for v in buf), default=1.0) or 1.0
    g = peak / m
    return [v * g for v in buf]


def fade(buf, ms=12):
    n = int(SR * ms / 1000)
    if len(buf) < 2 * n:
        return buf
    out = list(buf)
    for i in range(n):
        k = i / n
        out[i] *= k
        out[-1 - i] *= k
    return out


def write_wav(path, buf):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        frames = b''.join(
            struct.pack('<h', int(max(-1.0, min(1.0, v)) * 32767)) for v in buf
        )
        w.writeframes(frames)


def chime():
    return mix(
        [bell(1046.5, 1.1, 4.6), bell(1568.0, 0.95, 5.0), bell(2093.0, 0.7, 6.5)],
        [0.0, 0.14, 0.28],
    )


def pulse():
    b = beep(880, 0.1, 14)
    return mix([b, b, b], [0.0, 0.17, 0.34])


def radar():
    return mix([sweep(420, 1500, 0.5, 3.4), beep(1320, 0.16, 10)], [0.0, 0.42])


def marimba():
    return mix(
        [
            bell(523.25, 0.42, 9.5, ((1, 1.0), (3.9, 0.3), (9.2, 0.12))),
            bell(659.25, 0.42, 9.5, ((1, 1.0), (3.9, 0.3), (9.2, 0.12))),
            bell(783.99, 0.75, 7.0, ((1, 1.0), (3.9, 0.3), (9.2, 0.12))),
        ],
        [0.0, 0.13, 0.26],
    )


def siren():
    up = sweep(700, 980, 0.22, 1.2)
    down = sweep(980, 700, 0.22, 1.2)
    return mix([up, down, up, down], [0.0, 0.22, 0.44, 0.66])


SOUNDS = {
    'alert_chime': chime,
    'alert_pulse': pulse,
    'alert_radar': radar,
    'alert_marimba': marimba,
    'alert_siren': siren,
}

if __name__ == '__main__':
    root = os.path.dirname(os.path.abspath(__file__))
    project = os.path.abspath(os.path.join(root, '..'))
    targets = [
        os.path.join(project, 'assets', 'sounds'),
        os.path.join(project, 'android', 'app', 'src', 'main', 'res', 'raw'),
    ]
    for name, fn in SOUNDS.items():
        buf = fade(normalise(fn()))
        for t in targets:
            path = os.path.join(t, name + '.wav')
            write_wav(path, buf)
            print(f'{path}  {len(buf)/SR:.2f}s  {os.path.getsize(path)//1024}KB')
    print('done')
