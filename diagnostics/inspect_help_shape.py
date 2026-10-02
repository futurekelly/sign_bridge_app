"""What hand shape was actually recorded for each class?

The retrained model separates all five classes perfectly on held-out data, so the failure
of `help` on device is a mismatch between what was RECORDED and what the user now signs.
Reconstruct the mean hand skeleton per class to see what each recording actually contains.

Coordinates are the recorder's normalized output: wrist-centred, mirrored to right-handed,
scaled so max|coord| == 1. Distances are therefore in units of "the most extreme landmark".
"""
import numpy as np
import pandas as pd

CSV = r"C:\Users\FutureTech\sign_bridge\python_scripts\keypoint.csv"
NAMES = ["hello", "yes", "no", "help", "thank_you"]
FINGERS = ["thumb", "index", "middle", "ring", "pinky"]
TIPS = [4, 8, 12, 16, 20]
MCPS = [2, 6, 10, 14, 18]
PIPS = [3, 7, 11, 15, 19]

df = pd.read_csv(CSV, header=None)
X = df.iloc[:, 1:].values.astype(np.float64)
y = df.iloc[:, 0].values.astype(np.int64)

print("Fingertip distance from wrist, in units where the most extreme landmark = 1.0")
print("A curled finger keeps its tip close to the wrist; an extended one pushes it far.\n")
hdr = "".join(f"{f:>10s}" for f in FINGERS)
print(f"{'class':>10s} {hdr}   {'curl_ratio'}")
print("-" * 68)
for cls in range(5):
    rows = X[y == cls].reshape(-1, 21, 2)
    mean = rows.mean(0)
    wrist = mean[0]

    tip_d = [np.linalg.norm(mean[t] - wrist) for t in TIPS]
    mcp_d = [np.linalg.norm(mean[m] - wrist) for m in MCPS]
    # >1 means the tip is pushed beyond the knuckle -> that finger is extended
    ratio = [t / m if m else 0 for t, m in zip(tip_d, mcp_d)]

    tips = "".join(f"{d:>10.3f}" for d in tip_d)
    ratios = " ".join(f"{r:.2f}" for r in ratio)
    print(f"{NAMES[cls]:>10s} {tips}   {ratios}")
    print(f"{'':>10s} extended: {[f for f, r in zip(FINGERS, ratio) if r > 1.05]}")
print()

# How tightly was each class recorded? Tight clusters generalise badly.
print("Within-class spread (mean per-feature std) -- small means one narrow pose only:")
for cls in range(5):
    print(f"  {NAMES[cls]:>10s}  std={X[y==cls].std(0).mean():.4f}")

print("\nDistance between the mean `yes` and mean `help` skeletons:")
a, b = X[y == 1].mean(0), X[y == 3].mean(0)
print(f"  {np.linalg.norm(a - b):.3f}  (compare to the ~0.05 within-class std above)")

print("\nLandmarks that differ most between `yes` and `help` (top 8 of 21):")
pts_a, pts_b = a.reshape(21, 2), b.reshape(21, 2)
d = np.linalg.norm(pts_a - pts_b, axis=1)
for i in np.argsort(d)[::-1][:8]:
    print(f"  landmark {i:2d}  yes=({pts_a[i][0]:+.3f},{pts_a[i][1]:+.3f})"
          f"  help=({pts_b[i][0]:+.3f},{pts_b[i][1]:+.3f})  diff={d[i]:.3f}")
