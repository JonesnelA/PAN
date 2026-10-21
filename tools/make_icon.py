"""Generate the 1024x1024 app icon for PAN.

纯数学绘制：同一套金属/滚花/黄铜比例与 App 内的 DialCanvas 保持一致。
用法：  python tools/make_icon.py
"""

import numpy as np
from PIL import Image

S = 2048                      # 2x 超采样
C = S / 2 - 0.5
OUT = "PAN/Assets.xcassets/AppIcon.appiconset/icon-1024.png"

y, x = np.mgrid[0:S, 0:S].astype(np.float32)
dx = (x - C) / (S / 2)
dy = (y - C) / (S / 2)
rho = np.sqrt(dx * dx + dy * dy)
theta = np.arctan2(dy, dx)

img = np.zeros((S, S, 3), np.float32)


def _col(v):
    """标量原样返回，数组补一个通道维，避免 (S,S) 与 (S,S,1) 广播成 (S,S,S)"""
    a = np.asarray(v, dtype=np.float32)
    if a.ndim == 0:
        return float(a)
    return a[..., None]


def put(mask, r, g, b, alpha=1.0):
    """按 alpha 把颜色混合到 mask 区域内"""
    m = (mask.astype(np.float32) * alpha)[..., None]
    img[..., 0:1] = img[..., 0:1] * (1 - m) + _col(r) * m
    img[..., 1:2] = img[..., 1:2] * (1 - m) + _col(g) * m
    img[..., 2:3] = img[..., 2:3] * (1 - m) + _col(b) * m


def smoothstep(a, b, v):
    t = np.clip((v - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


# ---------- 背景 ----------
img[..., 0] = 0.016
img[..., 1] = 0.017
img[..., 2] = 0.020

gx = dx + 0.42
gy = dy + 0.52
glow = 0.055 * np.exp(-((gx * gx + gy * gy) / 0.62))
img[..., 0] += glow * 0.9
img[..., 1] += glow
img[..., 2] += glow * 1.05

# ---------- 外圈金属斜面 ----------
band = (rho >= 0.792) & (rho < 0.968)
if band.any():
    t = 0.50 + 0.30 * np.cos(3 * theta + 0.70) + 0.14 * np.cos(7 * theta - 0.40)
    t = np.clip(t, 0, 1)
    metal = 0.13 + 0.70 * t

    # 72 道滚花沟槽
    k = (theta + np.pi) / (2 * np.pi) * 72.0
    f = k - np.floor(k)
    d = np.minimum(f, 1 - f)
    groove = 1 - 0.55 * np.exp(-((d / 0.075) ** 2))

    light = 0.62 + 0.38 * (0.5 + 0.5 * np.cos(theta + 2.36 + np.pi))

    v = metal * groove * light
    put(band, v * 0.99, v, v * 1.03, 1.0)

# 外沿暗边 + 高光
put((rho >= 0.968) & (rho < 0.992), 0.045, 0.046, 0.05, 1.0)
put((rho >= 0.992) & (rho < 1.0), 0.10, 0.10, 0.11, 1.0)

# ---------- 盘面 ----------
face = rho < 0.792
fx = dx + 0.20
fy = dy + 0.26
face_v = 0.052 + 0.145 * np.exp(-((fx * fx + fy * fy) / 0.30))
face_v *= 1 - 0.55 * smoothstep(0.52, 0.792, rho)
put(face, face_v * 0.98, face_v, face_v * 1.04, 1.0)

# ---------- 刻度：60 格，每 5 格一条长线 ----------
k2 = (theta + np.pi) / (2 * np.pi) * 60.0
f2 = k2 - np.floor(k2)
d2 = np.minimum(f2, 1 - f2)
major = (np.floor(k2 + 0.5).astype(np.int64) % 5) == 0

minor_band = (rho >= 0.700) & (rho < 0.752) & (d2 < 0.085) & (~major)
major_band = (rho >= 0.668) & (rho < 0.752) & (d2 < 0.085) & major

put(minor_band, 1.0, 1.0, 1.0, 0.30)
put(major_band, 1.0, 1.0, 1.0, 0.72)

# ---------- 黄铜内环 ----------
put((rho >= 0.762) & (rho < 0.770), 0.79, 0.64, 0.16, 0.55)

# ---------- 中心轴 ----------
hub = rho < 0.176
if hub.any():
    ht = 0.48 + 0.32 * np.cos(3 * theta + 1.2) + 0.16 * np.cos(5 * theta)
    ht = np.clip(ht, 0, 1)
    hv = 0.14 + 0.62 * ht
    put(hub, hv * 0.99, hv, hv * 1.02, 1.0)

inner = rho < 0.140
put(inner, 0.055, 0.057, 0.062, 1.0)

# 一字螺丝槽
slot = (np.abs(dy) < 0.014) & (np.abs(dx) < 0.098) & (rho < 0.150)
put(slot, 0.02, 0.02, 0.025, 0.85)
slot_hi = (np.abs(dy + 0.016) < 0.006) & (np.abs(dx) < 0.095) & (rho < 0.150)
put(slot_hi, 1.0, 1.0, 1.0, 0.10)

# ---------- 12 点方向的黄铜指针 ----------
dd = np.sqrt((dx) ** 2 + (dy + 0.685) ** 2)
put(dd < 0.014, 0.85, 0.70, 0.22, 0.95)

# ---------- 输出 ----------
img = np.clip(img, 0, 1)
out = Image.fromarray((img * 255).astype(np.uint8), "RGB")
out = out.resize((1024, 1024), Image.LANCZOS)
out.save(OUT)
print("saved", OUT, out.size)
