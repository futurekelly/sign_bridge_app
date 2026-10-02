"""Is 1.18 actually far?

profile_shapes.py showed a held-out training row sits 0.0337 from the training set while the
phone's captures sit ~1.18 away, which looks damning -- but a held-out row is a near-duplicate
of its own session, so 0.0337 measures "same recording", not "same word". The honest baseline
is a recording of the same word made in a *different* session, and the user's own 177+177
files are exactly that: real hand, real labels, and the deployed model already scores them at
99.4% / 100%. Whatever distance those sit at from keypoint.csv is the normal spread.

So: baseline = user's own recordings -> keypoint.csv. Question = phone captures -> keypoint.csv.
If the phone is in the same ballpark, orientation is innocent and the fault is elsewhere; if it
is far outside, the capture really is delivering a different kind of object.
"""
import numpy as np
import pandas as pd
import tensorflow as tf

MODEL = r"C:\Users\FutureTech\sign_bridge\assets\models\gesture_model_dense.tflite"
BASE = r"C:\Users\FutureTech\sign_bridge\python_scripts\keypoint.csv"
HELP = r"C:\Users\FutureTech\sign_bridge\diagnostics\help_fist_new.csv"
YES = r"C:\Users\FutureTech\sign_bridge\diagnostics\yes_validation_new.csv"
NAMES = ["hello", "yes", "no", "help", "thank_you"]

with open(MODEL, 'rb') as f:
    raw = f.read()
it = tf.lite.Interpreter(model_content=raw)
it.allocate_tensors()
inp, out = it.get_input_details()[0], it.get_output_details()[0]

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


def load(path):
    df = pd.read_csv(path, header=None)
    return (df.iloc[:, 1:].values.astype(np.float64) if df.shape[1] == 43
            else df.values.astype(np.float64))


d = pd.read_csv(BASE, header=None)
X = d.iloc[:, 1:].values.astype(np.float64)
y = d.iloc[:, 0].values.astype(np.int64)

H = load(HELP)
Y = load(YES)

print("=" * 74)
print("FAIR BASELINE -- the user's own recordings vs the training file")
print("=" * 74)
print("(real hand, real labels, different session; the deployed model already reads these well)")
for name, V, truth in (("help_fist_new", H, 3), ("yes_validation_new", Y, 1)):
    dist = np.linalg.norm(V[:, None, :] - X[None, :, :], axis=2).min(1)
    labs, confs = classify(V)
    print(f"  {name:<20} NN dist {dist.mean():6.3f} (max {dist.max():5.3f})   "
          f"model says {NAMES[truth]} on {np.mean(labs == truth)*100:5.1f}% of rows")

print()
print("  ^ THIS is what 'same word, different session' looks like. Compare with:")

print()
print("=" * 74)
print("THE PHONE'S CAPTURES, same yardstick")
print("=" * 74)
print(f"{'correction':<24} {'NN dist':>9}  nearest training poses")
print("-" * 74)
TR = X
for deg in (0, 90, 180, 270):
    for mirror in (False, True):
        T = np.vstack([xform(v, deg, mirror) for v in DEVICE])
        dist = np.linalg.norm(T[:, None, :] - TR[None, :, :], axis=2)
        n = y[dist.argmin(1)]
        h = np.bincount(n, minlength=5)
        near = " ".join(f"{NAMES[i]}:{h[i]}" for i in range(5) if h[i])
        label = f"rot {deg:+4d}{'  +mirror' if mirror else ''}"
        print(f"{label:<24} {dist.min(1).mean():9.3f}  {near}")

print()
print("=" * 74)
print("WHOSE HAND IS IT?  phone captures vs the user's own two recordings")
print("=" * 74)
for name, V in (("help_fist_new", H), ("yes_validation_new", Y)):
    dist = np.linalg.norm(DEVICE[:, None, :] - V[None, :, :], axis=2).min(1)
    print(f"  {name:<20} NN dist {dist.mean():6.3f}")
print("  (compare against the same-word baseline above -- if the phone were merely rotated,")
print("   some rotation would bring this down to the baseline. It does not.)")
