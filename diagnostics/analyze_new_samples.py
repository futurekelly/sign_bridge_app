"""Sanity-check the freshly recorded help/yes samples BEFORE anything is trained on them.

The user recorded 177 samples under each key. If the keys were mixed up, or the same
gesture was signed for both, we would train a model to confuse two classes -- exactly the
failure we are trying to fix. So verify the labels from geometry first.

Two independent checks:
  1. Shape check. For a thumbs-up the thumb is the farthest thing from the wrist, because
     the fingers are curled but the thumb sticks out. For a fist with the thumb wrapped,
     the thumb tucks in and some knuckle becomes the extreme point instead. So look at
     where the thumb tip ranks among the landmarks.
  2. Centroid check. Compare each new file against the five recorded class centroids.
     Both files should sit in DIFFERENT places; if they sit on top of each other, the same
     sign was recorded twice.
"""
import numpy as np
import pandas as pd

CSV = r"C:\Users\FutureTech\sign_bridge\python_scripts\keypoint.csv"
NAMES = ["hello", "yes", "no", "help", "thank_you"]
TIP = 4  # thumb tip landmark

df = pd.read_csv(CSV, header=None)
X = df.iloc[:, 1:].values.astype(float)
y = df.iloc[:, 0].values.astype(int)
centroids = {n: X[y == i].mean(0) for i, n in enumerate(NAMES)}


def describe(path, label):
    try:
        d = pd.read_csv(path, header=None)
    except Exception as e:
        print(f"{label}: could not read ({e})")
        return None
    if len(d) == 0:
        print(f"{label}: EMPTY")
        return None

    P = d.iloc[:, 1:].values.astype(float)
    labs = sorted(set(d.iloc[:, 0].values.astype(int)))
    m = P.mean(0)
    pts = m.reshape(21, 2)

    # Thumb tip distance from wrist vs every other landmark's distance.
    dist = np.linalg.norm(pts - pts[0], axis=1)
    rank = int(np.argsort(dist)[::-1].tolist().index(TIP)) + 1  # 1 = thumb is the extreme

    print(f"\n=== {label} ===  ({path.split(chr(92))[-1]})")
    print(f"  rows: {len(P)}   labels present: {labs}   unique poses: "
          f"{len(np.unique(np.round(P, 3), axis=0))}")
    print(f"  within-file spread (mean per-feature std): {P.std(0).mean():.4f}")
    print(f"  thumb tip distance from wrist: {dist[TIP]:.3f}   "
          f"rank among 21 landmarks: {rank} (1 = thumb is the farthest)")
    print(f"  farthest landmark: #{int(np.argmax(dist))} at {dist.max():.3f}")
    print("  distance to each recorded class centroid:")
    for n in NAMES:
        print(f"     {n:<10} {np.linalg.norm(m - centroids[n]):.4f}")
    best = min(NAMES, key=lambda n: np.linalg.norm(m - centroids[n]))
    print(f"  --> closest recorded class: {best}")
    return m


h = describe(r"C:\Users\FutureTech\sign_bridge\diagnostics\help_fist_new.csv", "help_fist_new")
s = describe(r"C:\Users\FutureTech\sign_bridge\diagnostics\yes_validation_new.csv", "yes_validation_new")

if h is not None and s is not None:
    gap = np.linalg.norm(h - s)
    ref = X[y == 1].std(0).mean()
    print(f"\n=== are the two files actually different signs? ===")
    print(f"  distance between their mean poses: {gap:.4f}")
    print(f"  (recorded `yes` within-class spread for scale: {ref:.4f})")
    print("  " + ("DISTINCT - they are different handshapes, labels look right"
                  if gap > 3 * ref else
                  "TOO CLOSE - the same gesture may have been recorded under both keys"))
