"""Profile what each of the five words actually looks like, then find which one the phone sent.

find_orientation_fix.py said "rot +0 is closest to training", which contradicts the hand
geometry -- and a nearest-neighbour distance with no control cannot settle it, because
"1.1462" means nothing until you know what a *correctly oriented* hand scores. This supplies
that control, then compares the phone's captures against a per-class shape profile rather
than a raw distance, so the answer is legible either way.

Shape cues used (all rotation-sensitive, all mirror-sensitive, all scale-invariant):
  palm axis    wrist -> middle knuckle. Which way the hand points.
  finger ext   fingertip distance / knuckle distance, per finger. 1.0 = fully curled.
  thumb ext    thumb-tip distance / thumb-knuckle distance. Separates `help` (wrapped) from `yes`.
"""
import glob
import os
import numpy as np
import pandas as pd
import tensorflow as tf

MODEL = r"C:\Users\FutureTech\sign_bridge\assets\models\gesture_model_dense.tflite"
BASE = r"C:\Users\FutureTech\sign_bridge\python_scripts\keypoint.csv"
NAMES = ["hello", "yes", "no", "help", "thank_you"]
DIAG = r"C:\Users\FutureTech\sign_bridge\diagnostics"

DEVICE = np.array([
    [-0.000, 0.000, -0.054, -0.339, -0.230, -0.568, -0.369, -0.687, -0.452, -0.816,
     -0.488, -0.383, -0.665, -0.561, -0.770, -0.688, -0.852, -0.792, -0.533, -0.168,
     -0.746, -0.291, -0.879, -0.391, -0.983, -0.479, -0.528, 0.061, -0.751, 0.047,
     -0.887, 0.004, -1.000, -0.038, -0.487, 0.286, -0.662, 0.393, -0.782, 0.446,
     -0.893, 0.479],
    [-0.000, 0.000, -0.018, -0.356, -0.134, -0.643, -0.224, -0.827, -0.267, -1.000,
     -0.426, -0.539, -0.582, -0.743, -0.678, -0.864, -0.757, -0.959, -0.487, -0.342,
     -0.676, -0.507, -0.787, -0.599, -0.869, -0.671, -0.500, -0.124, -0.700, -0.165,
     -0.817, -0.198, -0.916, -0.234, -0.472, 0.102, -0.617, 0.164, -0.705, 0.191,
     -0.786, 0.197],
    [-0.000, 0.000, -0.011, -0.302, -0.108, -0.593, -0.183, -0.814, -0.204, -1.000,
     -0.317, -0.584, -0.430, -0.771, -0.500, -0.868, -0.568, -0.932, -0.366, -0.450,
     -0.498, -0.623, -0.581, -0.716, -0.651, -0.779, -0.388, -0.282, -0.537, -0.407,
     -0.636, -0.492, -0.720, -0.554, -0.390, -0.089, -0.528, -0.108, -0.622, -0.123,
     -0.711, -0.144],
    [-0.000, 0.000, -0.028, -0.363, -0.118, -0.631, -0.216, -0.830, -0.282, -1.000,
     -0.405, -0.480, -0.548, -0.624, -0.637, -0.712, -0.704, -0.784, -0.450, -0.274,
     -0.612, -0.388, -0.702, -0.463, -0.782, -0.527, -0.454, -0.057, -0.619, -0.093,
     -0.717, -0.134, -0.800, -0.172, -0.427, 0.175, -0.567, 0.214, -0.655, 0.224,
     -0.737, 0.213],
    [-0.000, 0.000, -0.295, 0.204, -0.514, 0.139, -0.628, -0.071, -0.629, -0.308,
     -0.737, 0.076, -0.742, -0.340, -0.618, -0.367, -0.522, -0.263, -0.721, -0.214,
     -0.670, -0.593, -0.550, -0.608, -0.461, -0.483, -0.634, -0.496, -0.581, -0.819,
     -0.462, -0.786, -0.400, -0.638, -0.515, -0.751, -0.467, -1.000, -0.352, -0.924,
     -0.287, -0.783],
], dtype=np.float64)

with open(MODEL, 'rb') as f:
    raw = f.read()
it = tf.lite.Interpreter(model_content=raw)
it.allocate_tensors()
inp, out = it.get_input_details()[0], it.get_output_details()[0]


def classify(V):
    labs, confs = [], []
    for r in np.atleast_2d(V):
        it.set_tensor(inp['index'], r.reshape(1, 42).astype(np.float32))
        it.invoke()
        p = it.get_tensor(out['index'])[0]
        labs.append(int(p.argmax()))
        confs.append(float(p.max()))
    return np.array(labs), np.array(confs)


def xform(v, deg, mirror):
    p = v.reshape(21, 2).copy()
    if deg:
        t = np.radians(deg)
        p = p @ np.array([[np.cos(t), -np.sin(t)], [np.sin(t), np.cos(t)]]).T
    if mirror:
        p[:, 0] *= -1
    m = np.abs(p).max()
    return (p / m).reshape(42) if m else p.reshape(42)


def profile(V):
    """Rotation-free + mirror-free shape description, averaged over rows."""
    P = np.atleast_2d(V).reshape(-1, 21, 2)
    palm = P[:, 9] - P[:, 0]
    ang = np.degrees(np.arctan2(palm[:, 1].mean(), palm[:, 0].mean()))
    n = np.linalg.norm(P, axis=2)
    n[n == 0] = 1e-9
    fingers = [n[:, 8] / n[:, 5], n[:, 12] / n[:, 9], n[:, 16] / n[:, 13], n[:, 20] / n[:, 17]]
    thumb = n[:, 4] / n[:, 2]
    return ang, np.array([f.mean() for f in fingers]), thumb.mean()


def load(path):
    df = pd.read_csv(path, header=None)
    if df.shape[1] == 43:
        return df.iloc[:, 1:].values.astype(np.float64), df.iloc[:, 0].values.astype(np.int64)
    return df.values.astype(np.float64), None


d = pd.read_csv(BASE, header=None)
X = d.iloc[:, 1:].values.astype(np.float64)
y = d.iloc[:, 0].values.astype(np.int64)
rng = np.random.default_rng(0)

print("=" * 78)
print("A. SHAPE PROFILE PER WORD  (what each sign looks like, from keypoint.csv)")
print("=" * 78)
print(f"{'word':<11} {'palm axis':>10} {'index':>7} {'middle':>7} {'ring':>7} {'pinky':>7} {'thumb':>7}")
print("-" * 78)
for i, name in enumerate(NAMES):
    ang, f, t = profile(X[y == i])
    print(f"{name:<11} {ang:>9.1f}d {f[0]:>7.2f} {f[1]:>7.2f} {f[2]:>7.2f} {f[3]:>7.2f} {t:>7.2f}")
print("  finger cols: 1.0 = fingertip at the knuckle (curled), >1.4 = extended")

print()
for path in sorted(glob.glob(os.path.join(DIAG, "*_new.csv"))):
    V, lab = load(path)
    ang, f, t = profile(V)
    print(f"  user's own {os.path.basename(path):<26} palm {ang:>8.1f}d  "
          f"fingers [{' '.join(f'{v:.2f}' for v in f)}]  thumb {t:.2f}")

print()
print("=" * 78)
print("B. WHAT THE PHONE SENT  (as delivered to the model, then under correction)")
print("=" * 78)
print(f"{'capture':<10} {'palm axis':>10} {'index':>7} {'middle':>7} {'ring':>7} {'pinky':>7} {'thumb':>7}")
print("-" * 78)
for i in range(len(DEVICE)):
    ang, f, t = profile(DEVICE[i])
    print(f"  #{i:<7} {ang:>9.1f}d {f[0]:>7.2f} {f[1]:>7.2f} {f[2]:>7.2f} {f[3]:>7.2f} {t:>7.2f}")

print()
print("=" * 78)
print("C. CONTROL -- how close is a row the model has NEVER seen to the training set?")
print("=" * 78)
te = rng.permutation(len(X))[:300]
tr_idx = np.setdiff1d(np.arange(len(X)), te)[:6000]
TR = X[tr_idx]
labs, confs = classify(X[te])
print(f"  held-out training rows:  NN dist {np.linalg.norm(X[te][:, None, :] - TR[None], axis=2).min(1).mean():.4f}"
      f"   model accuracy {np.mean(labs == y[te]) * 100:.1f}%   conf {confs.mean() * 100:.1f}%")
print("  ^ this is what 'correctly oriented input' scores. Anything much above it is out of distribution.")

print()
print("=" * 78)
print("D. THE PHONE'S CAPTURES UNDER EACH CORRECTION")
print("=" * 78)
print(f"{'correction':<24} {'NN dist':>8} {'nn said':>16} {'model said':>16}")
print("-" * 78)
nn = np.linalg.norm(DEVICE[:, None, :] - TR[None], axis=2).argmin(1)
for deg in (0, 90, 180, 270):
    for mirror in (False, True):
        T = np.vstack([xform(v, deg, mirror) for v in DEVICE])
        dist = np.linalg.norm(T[:, None, :] - TR[None], axis=2)
        nnc = y[tr_idx[dist.argmin(1)]]
        labs, confs = classify(T)
        h_nn = np.bincount(nnc, minlength=5)
        h_md = np.bincount(labs, minlength=5)
        top_nn = NAMES[int(h_nn.argmax())] + f" x{h_nn.max()}"
        top_md = NAMES[int(h_md.argmax())] + f" x{h_md.max()}"
        label = f"rot {deg:+4d}{'  +mirror' if mirror else ''}"
        print(f"{label:<24} {dist.min(1).mean():8.4f} {top_nn:>16} {top_md:>16}")
print()
print("Read column 3 and 4 together: the true correction is the one where the model's answer")
print("agrees with what the nearest *training poses* actually are.")
