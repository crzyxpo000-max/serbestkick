#!/usr/bin/env python3
"""Oyunun ses dosyalarını üretir (assets/audio/*.wav). Hazır kayıt kullanılmaz; hepsi sentezdir.

Kullanım: python3 tools/make_sounds.py
"""
import os
import wave

import numpy as np

RATE = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")
rng = np.random.default_rng(7)


def t(seconds):
    return np.arange(int(RATE * seconds)) / RATE


def lowpass(x, cutoff):
    alpha = 1.0 - np.exp(-2.0 * np.pi * cutoff / RATE)
    y = np.empty_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc += alpha * (v - acc)
        y[i] = acc
    return y


def highpass(x, cutoff):
    return x - lowpass(x, cutoff)


def bandpass(x, low, high):
    return highpass(lowpass(x, high), low)


def fade(x, attack=0.005, release=0.02):
    a = int(RATE * attack)
    r = int(RATE * release)
    y = x.copy()
    y[:a] *= np.linspace(0.0, 1.0, a)
    y[-r:] *= np.linspace(1.0, 0.0, r)
    return y


def save(name, x, peak=0.9):
    x = x / max(np.max(np.abs(x)), 1e-9) * peak
    data = (x * 32767).astype("<i2")
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(data.tobytes())


def noise(seconds):
    return rng.standard_normal(int(RATE * seconds))


def thump(seconds, f0, f1, decay, click=0.0):
    x = t(seconds)
    freq = f1 + (f0 - f1) * np.exp(-x * 30.0)
    body = np.sin(2 * np.pi * np.cumsum(freq) / RATE) * np.exp(-x * decay)
    if click > 0.0:
        body += click * lowpass(noise(seconds), 2500) * np.exp(-x * 90.0)
    return fade(body)


def crowd_bed(seconds):
    """Uğultu: bant geçiren gürültü + yavaş dalgalanma."""
    x = bandpass(noise(seconds), 180, 1400)
    swell = 0.75 + 0.25 * np.sin(2 * np.pi * t(seconds) * 0.31 + rng.uniform(0, 6.28))
    swell *= 0.85 + 0.15 * np.sin(2 * np.pi * t(seconds) * 0.83 + rng.uniform(0, 6.28))
    return x * swell


def main():
    os.makedirs(OUT, exist_ok=True)

    save("kick", thump(0.22, 190, 62, 26, click=0.9))
    save("bounce", thump(0.16, 130, 70, 34, click=0.25), peak=0.6)
    save("save", fade(lowpass(noise(0.14), 1800) * np.exp(-t(0.14) * 45.0)) + 0.5 * thump(0.14, 150, 90, 40), peak=0.75)

    # Direk: uyumsuz kısmi seslerden metalik çınlama.
    x = t(0.7)
    post = sum(a * np.sin(2 * np.pi * f * x) * np.exp(-x * d)
               for f, a, d in [(412, 1.0, 7), (967, 0.7, 9), (1543, 0.5, 11), (2371, 0.35, 14), (3180, 0.2, 18)])
    post += 0.6 * lowpass(noise(0.7), 3000) * np.exp(-x * 80.0)
    save("post", fade(post))

    # File: yumuşak hışırtı.
    x = t(0.45)
    save("net", fade(bandpass(noise(0.45), 900, 5000) * np.exp(-x * 9.0) * (1.0 - np.exp(-x * 60.0)), release=0.1), peak=0.7)

    # Hakem düdüğü: yakın iki ton + bilye titremesi.
    x = t(0.55)
    trill = 0.75 + 0.25 * np.sign(np.sin(2 * np.pi * 38 * x))
    whistle = (np.sin(2 * np.pi * 2780 * x) + 0.8 * np.sin(2 * np.pi * 2930 * x)) * trill
    whistle += 0.15 * highpass(noise(0.55), 3000)
    save("whistle", fade(whistle, attack=0.01, release=0.05), peak=0.6)

    # Tribün uğultusu: döngüye uygun (başı ve sonu çapraz geçişli).
    seconds, overlap = 6.0, 1.0
    bed = crowd_bed(seconds + overlap)
    n = int(RATE * overlap)
    ramp = np.linspace(0.0, 1.0, n)
    loop = bed[:int(RATE * seconds)].copy()
    loop[:n] = loop[:n] * ramp + bed[int(RATE * seconds):] * (1.0 - ramp)
    save("crowd", loop, peak=0.5)

    # Gol tezahüratı: yükselip yavaşça sönen kükreme.
    x = t(3.2)
    roar = bandpass(noise(3.2), 250, 2600) * (1.0 - np.exp(-x * 9.0)) * np.exp(-np.maximum(x - 1.2, 0.0) * 1.3)
    roar *= 0.8 + 0.2 * np.sin(2 * np.pi * x * 5.5)
    save("cheer", fade(roar, release=0.3))

    # Kaçan vuruş: alçalan "ooo".
    x = t(1.5)
    groan = lowpass(noise(1.5), 700) * (1.0 - np.exp(-x * 14.0)) * np.exp(-x * 2.6)
    save("groan", fade(groan, release=0.3), peak=0.6)

    # Kalp atışı: "lub-dub".
    beat = np.zeros(int(RATE * 0.5))
    first = thump(0.16, 75, 48, 28)
    second = thump(0.14, 95, 55, 34) * 0.75
    beat[:len(first)] += first
    start = int(RATE * 0.19)
    beat[start:start + len(second)] += second
    save("heartbeat", beat, peak=0.85)

    save("click", fade(np.sin(2 * np.pi * 880 * t(0.05)) * np.exp(-t(0.05) * 70.0)), peak=0.35)


if __name__ == "__main__":
    main()
