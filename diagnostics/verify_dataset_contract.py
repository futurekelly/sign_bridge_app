"""Verify the 5-class model's label order AND its normalization contract against
the real training set (python_scripts/keypoint.csv), which record_landmarks.py wrote.

record_landmarks.py:CLASSES = ["hello","yes","no","help","thank_you"], and cls_id is
the key pressed minus ord('0'). So if that file is what trained the model, the CSV's
class column must reproduce those five gesture geometries:

    hello     = 5 fingers extended
    yes       = thumb only, tip UP
    no        = thumb only, tip DOWN
    help      = fist (0 extended)
    thank_you = index + middle only (peace)

Also checks the scale contract: normalize_landmarks divides by max|value|, so every
training row should have max|coord| == 1.0 exactly.
"""
import numpy as np
import pandas as pd

CSV = r"C:\Users\FutureTech\sign_bridge\python_scripts\keypoint.csv"
NAMES = ["hello", "yes", "no", "help", "thank_you"]
TIPS = [4, 8, 12, 16, 20]
PIPS = [2, 6, 10, 14, 18]

df = pd.read_csv(CSV, header=None)
X = df.iloc[:, 1:].values.astype(np.float64)
y = df.iloc[:, 0].values.astype(int)
print(f"rows={len(df)}  features={X.shape[1]}  classes={sorted(set(y))}")
print()

# ── scale contract ──
mx = np.abs(X).max(axis=1)
print(f"max|coord| per training row: min={mx.min():.4f} max={mx.max():.4f} mean={mx.mean():.4f}")
print("  -> matches 'divide by max|value|' contract?" , bool(np.allclose(mx, 1.0, atol=1e-3)))
print()

for cls in sorted(set(y)):
    rows = X[y == cls]
    pts = rows.reshape(len(rows), 21, 2)
    mean = pts.mean(axis=0)
    wrist = mean[0]

    def d(i):
        return np.linalg.norm(mean[i] - wrist)

    ext = [d(t) > d(p) * 1.05 for t, p in zip(TIPS, PIPS)]
    n_ext = sum(ext)
    thumb = mean[4]

    # which fingers, by name
    names = ["thumb", "index", "middle", "ring", "pinky"]
    on = [n for n, e in zip(names, ext) if e]

    # thumb direction relative to wrist. In image coords y grows downward.
    thumb_dir = "UP" if thumb[1] < wrist[1] else "DOWN"

    print(f"class {cls} ({NAMES[cls]:10s}) n={len(rows):4d}")
    print(f"   extended ({n_ext}): {on if on else 'none (fist)'}")
    print(f"   thumb tip y - wrist y = {thumb[1]-wrist[1]:+.4f}  -> thumb {thumb_dir}")
    print()
