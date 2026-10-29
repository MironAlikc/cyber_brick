 #!/usr/bin/env python3
"""Генерирует 8-бит звуки и оригинальную музыкальную петлю для cyber_brick.
Запуск:  python3 tools/generate_audio.py
Результат: assets/audio/*.wav
"""
import math
import os
import random
import struct
import wave

RATE = 22050
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'assets', 'audio')
os.makedirs(OUT, exist_ok=True)
random.seed(7)


def midi(n):
    return 440.0 * 2 ** ((n - 69) / 12)


def square(phase, duty=0.5):
    return 1.0 if (phase % 1.0) < duty else -1.0


def triangle(phase):
    p = phase % 1.0
    return 4 * p - 1 if p < 0.5 else 3 - 4 * p


def tone(freq, dur, vol=0.5, duty=0.5, wave_fn='sq', decay=True, f_end=None):
    n = int(RATE * dur)
    out, phase = [], 0.0
    for i in range(n):
        t = i / max(n - 1, 1)
        f = freq if f_end is None else freq + (f_end - freq) * t
        phase += f / RATE
        s = square(phase, duty) if wave_fn == 'sq' else triangle(phase)
        env = (1 - t) ** 1.3 if decay else 1.0
        attack = min(1.0, i / 60)
        out.append(s * vol * env * attack)
    return out


def noise(dur, vol=0.3, decay_pow=3):
    n = int(RATE * dur)
    return [(random.random() * 2 - 1) * vol * (1 - i / n) ** decay_pow for i in range(n)]


def save(name, samples, peak=0.85):
    m = max((abs(s) for s in samples), default=1) or 1
    k = min(1.0, peak / m) if m > peak else 1.0
    with wave.open(os.path.join(OUT, name), 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b''.join(struct.pack('<h', int(max(-1, min(1, s * k)) * 32767)) for s in samples))
    print(name, len(samples) / RATE, 's')


def seq(notes, dur, vol=0.45, duty=0.5, gap=0.0):
    out = []
    for n in notes:
        out += tone(midi(n), dur, vol, duty)
        out += [0.0] * int(RATE * gap)
    return out


# ───────── эффекты ─────────
save('move.wav', tone(520, 0.035, 0.25, 0.5))
save('rotate.wav', tone(620, 0.03, 0.3, 0.25) + tone(820, 0.04, 0.3, 0.25))
save('lock.wav', tone(150, 0.07, 0.45, 0.5, f_end=90) + noise(0.04, 0.2))
save('drop.wav', tone(700, 0.11, 0.4, 0.5, f_end=120) + noise(0.07, 0.35))
save('hold.wav', tone(440, 0.05, 0.3, 0.25) + tone(330, 0.07, 0.3, 0.25))
save('click.wav', tone(900, 0.025, 0.25, 0.5))
save('line.wav', seq([72, 76, 79, 84], 0.07, 0.4, 0.25))
save('tetris.wav', seq([72, 76, 79, 84, 79, 84, 88, 91], 0.075, 0.4, 0.25))
save('claim.wav', seq([67, 72, 76, 79, 84], 0.09, 0.4, 0.25))
save('gameover.wav', seq([67, 64, 60, 55], 0.22, 0.4, 0.5, gap=0.02)
     + tone(midi(48), 0.5, 0.4, 0.5, f_end=midi(41)))

# ───────── музыка (оригинальная петля, 8 тактов, Am) ─────────
BPM = 140
STEP = 60 / BPM / 2            # восьмая
chords = [  # (аккорд для арпеджио, бас)
    ([69, 72, 76], 45), ([65, 69, 72], 41), ([67, 72, 76], 48), ([67, 71, 74], 43),
    ([69, 72, 76], 45), ([65, 69, 72], 41), ([67, 71, 74], 43), ([68, 71, 76], 40),
]
pat_a = [0, 1, 2, 1, 0, 1, 2, 1]
pat_b = [2, 1, 0, 1, 2, 1, 0, 2]
step_n = int(RATE * STEP)
total = step_n * 8 * len(chords)
mix = [0.0] * total


def add(buf, start, samples):
    for i, s in enumerate(samples):
        if start + i < len(buf):
            buf[start + i] += s


for bar, (ch, bass) in enumerate(chords):
    pat = pat_a if bar < 4 else pat_b
    for st in range(8):
        pos = (bar * 8 + st) * step_n
        add(mix, pos, tone(midi(ch[pat[st]]), STEP * 0.9, 0.20, 0.25))        # лид
        if st % 2 == 0:
            add(mix, pos, tone(midi(bass), STEP * 1.8, 0.32, wave_fn='tri'))  # бас
        if st % 2 == 1:
            add(mix, pos, noise(0.04, 0.10))                                  # хэт
save('music.wav', mix, peak=0.8)