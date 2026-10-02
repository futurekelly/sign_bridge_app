"""Determine the exact rotation that maps the phone's landmark frame onto the recorder's.

The [DIAG] capture settled the geometry question that had been guessed at for three rounds:

    geometry src=640x360 rotation=270 bitmap=480x270

MediaPipe is handed a **landscape 16:9** bitmap. Decoding the landmark vectors from the
same log, every capture has the knuckles (L5/L9/L13/L17) stacked along **y** with the
fingers running along **x**. In keypoint.csv it is the other way round: knuckles spread
along x, fingers run up -y. The hand therefore arrives rotated a quarter turn, and the
model -- which is verified good on correctly oriented input -- faithfully reads a sideways
hand as whatever word a sideways hand looks like.

Which quarter turn is not a matter of opinion, and neither is the mirror. This scores each
candidate transform by how close it lands to the *training distribution*, which is
model-independent, and then reports what the model says for each. The transform that makes
the phone's own captures look like keypoint.csv is the correction, by definition.
"""
import numpy as np
import pandas as pd
import tensorflow as tf

MODEL = r"C:\Users\FutureTech\sign_bridge\assets\models\gesture_model_dense.tflite"
BASE = r"C:\Users\FutureTech\sign_bridge\python_scripts\keypoint.csv"
NAMES = ["hello", "yes", "no", "help", "thank_you"]

# Real captures, copied verbatim from the [DIAG] dump on the Huawei (12:56:36 - 12:56:48).
# Hand0 unless marked. These are what the model actually received.
DEVICE = np.array([
    # yes/hand0/mirrored @12:56:36.772
    [-0.000, 0.000, -0.054, -0.339, -0.230, -0.568, -0.369, -0.687, -0.452, -0.816,
     -0.488, -0.383, -0.665, -0.561, -0.770, -0.688, -0.852, -0.792, -0.533, -0.168,
     -0.746, -0.291, -0.879, -0.391, -0.983, -0.479, -0.528, 0.061, -0.751, 0.047,
     -0.887, 0.004, -1.000, -0.038, -0.487, 0.286, -0.662, 0.393, -0.782, 0.446,
     -0.893, 0.479],
    # yes/hand0/mirrored @12:56:37.506
    [-0.000, 0.000, -0.018, -0.356, -0.134, -0.643, -0.224, -0.827, -0.267, -1.000,
     -0.426, -0.539, -0.582, -0.743, -0.678, -0.864, -0.757, -0.959, -0.487, -0.342,
     -0.676, -0.507, -0.787, -0.599, -0.869, -0.671, -0.500, -0.124, -0.700, -0.165,
     -0.817, -0.198, -0.916, -0.234, -0.472, 0.102, -0.617, 0.164, -0.705, 0.191,
     -0.786, 0.197],
    # yes/hand0/mirrored @12:56:38.331
    [-0.000, 0.000, -0.040, -0.404, -0.178, -0.676, -0.292, -0.807, -0.337, -0.915,
     -0.466, -0.555, -0.633, -0.750, -0.738, -0.869, -0.828, -0.966, -0.523, -0.343,
     -0.731, -0.516, -0.851, -0.626, -0.947, -0.724, -0.533, -0.125, -0.746, -0.186,
     -0.882, -0.256, -1.000, -0.317, -0.505, 0.118, -0.664, 0.170, -0.770, 0.199,
     -0.873, 0.212],
    # yes/hand0/mirrored @12:56:39.943
    [-0.000, 0.000, -0.011, -0.302, -0.108, -0.593, -0.183, -0.814, -0.204, -1.000,
     -0.317, -0.584, -0.430, -0.771, -0.500, -0.868, -0.568, -0.932, -0.366, -0.450,
     -0.498, -0.623, -0.581, -0.716, -0.651, -0.779, -0.388, -0.282, -0.537, -0.407,
     -0.636, -0.492, -0.720, -0.554, -0.390, -0.089, -0.528, -0.108, -0.622, -0.123,
     -0.711, -0.144],
    # yes/hand0/mirrored @12:56:44.159 (hand1 absent -- the two-hand contest is NOT the cause here)
    [-0.000, 0.000, -0.028, -0.363, -0.118, -0.631, -0.216, -0.830, -0.282, -1.000,
     -0.405, -0.480, -0.548, -0.624, -0.637, -0.712, -0.704, -0.784, -0.450, -0.274,
     -0.612, -0.388, -0.702, -0.463, -0.782, -0.527, -0.454, -0.057, -0.619, -0.093,
     -0.717, -0.134, -0.800, -0.172, -0.427, 0.175, -0.567, 0.214, -0.655, 0.224,
     -0.737, 0.213],
    # no/hand1/as-is @12:56:42.372 (the raw, UNMIRRORED hand -- all x positive)
    [0.000, 0.000, 0.104, 0.552, 0.256, 0.824, 0.388, 0.957, 0.503, 1.000,
     0.585, 0.476, 0.549, 0.901, 0.385, 0.832, 0.353, 0.655, 0.610, 0.360,
     0.556, 0.911, 0.354, 0.783, 0.324, 0.553, 0.622, 0.285, 0.559, 0.835,
     0.353, 0.687, 0.331, 0.459, 0.613, 0.215, 0.558, 0.705, 0.404, 0.600,
     0.384, 0.391],
    # no/hand0/mirrored @12:56:48.225
    [-0.000, 0.000, -0.295, 0.204, -0.514, 0.139, -0.628, -0.071, -0.629, -0.308,
     -0.737, 0.076, -0.742, -0.340, -0.618, -0.367, -0.522, -0.263, -0.721, -0.214,
     -0.670, -0.593, -0.550, -0.608, -0.461, -0.483, -0.634, -0.496, -0.581, -0.819,
     -0.462, -0.786, -0.400, -0.638, -0.515, -0.751, -0.467, -1.000, -0.352, -0.924,
     -0.287, -0.783],
    # yes/hand0/mirrored @12:56:46.577
    [-0.000, 0.000, -0.071, -0.411, -0.217, -0.707, -0.349, -0.847, -0.425, -1.000,
     -0.441, -0.541, -0.581, -0.684, -0.454, -0.606, -0.323, -0.503, -0.471, -0.336,
     -0.631, -0.501, -0.454, -0.431, -0.299, -0.340, -0.488, -0.107, -0.650, -0.269,
     -0.447, -0.226, -0.286, -0.153, -0.484, 0.155, -0.599, -0.010, -0.451, -0.022,
     -0.327, 0.021],
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
    """Rotate the hand in image space (x right, y down), then optionally mirror x.

    This is the transform a capture-pipeline correction would apply, expressed the same
    way the app expresses it: rotate about the wrist and renormalise, because the model
    only ever sees a wrist-centred, max-normalised vector.
    """
    p = v.reshape(21, 2).copy()
    if deg:
        t = np.radians(deg)
        p = p @ np.array([[np.cos(t), -np.sin(t)], [np.sin(t), np.cos(t)]]).T
    if mirror:
        p[:, 0] *= -1
    m = np.abs(p).max()
    return (p / m).reshape(42) if m else p.reshape(42)


d = pd.read_csv(BASE, header=None)
X = d.iloc[:, 1:].values.astype(np.float64)
y = d.iloc[:, 0].values.astype(np.int64)
rng = np.random.default_rng(0)
sub = X[rng.permutation(len(X))[:2500]]

print(f"{len(DEVICE)} real captures from the phone; training set {len(X)} rows\n")

print("=== orientation of the hand, training vs phone ===")
# L0 -> L9 is wrist to middle knuckle: the palm axis, the most stable orientation cue.
for name, V in (("keypoint.csv", X[rng.permutation(len(X))[:400]]),
                ("phone (as sent)", DEVICE)):
    p = V.reshape(-1, 21, 2)
    palm = p[:, 9] - p[:, 0]
    palm = palm / np.linalg.norm(palm, axis=1, keepdims=True)
    ang = np.degrees(np.arctan2(palm[:, 1].mean(), palm[:, 0].mean()))
    print(f"  {name:<18} mean palm axis points {ang:+7.1f} deg   "
          f"(0=right, +90=down, 180=left, -90=up)")

print("\n=== which correction lands the phone's captures on the training set? ===")
print("(distance to nearest training row; smaller = more like the data the model learned)\n")
print(f"{'transform':<28} {'NN dist':>8} {'mean conf':>10}  predictions")
print("-" * 78)
results = []
for deg in (0, 90, 180, 270):
    for mirror in (False, True):
        T = np.vstack([xform(v, deg, mirror) for v in DEVICE])
        dist = np.linalg.norm(T[:, None, :] - sub[None, :, :], axis=2).min(axis=1).mean()
        labs, confs = classify(T)
        hist = np.bincount(labs, minlength=5)
        desc = " ".join(f"{NAMES[i][:4]}:{hist[i]}" for i in range(5) if hist[i])
        label = f"rot {deg:+4d}{'  + mirror x' if mirror else ''}"
        print(f"{label:<28} {dist:8.4f} {confs.mean()*100:9.1f}%  {desc}")
        results.append((dist, deg, mirror, confs.mean()))

print()
best = min(results)
print(f"--> closest to the training distribution: rot {best[1]:+d} deg"
      f"{'  + mirror x' if best[2] else ''}   (NN dist {best[0]:.4f})")

base = [r for r in results if r[1] == 0 and not r[2]][0]
print(f"    as currently sent to the model:        rot   +0 deg"
      f"            (NN dist {base[0]:.4f})")
print(f"    the correction moves the input {base[0]/best[0]:.2f}x closer to training data")

print("\n=== same-correction check on the raw unmirrored hand (hand1/as-is) ===")
# If the fix is real it must also rescue the capture the app did NOT mirror.
T = xform(DEVICE[5], best[1], best[2])
labs, confs = classify(T)
print(f"  hand1/as-is  rot {best[1]:+d}{'  + mirror x' if best[2] else ''}"
      f"  -> {NAMES[labs[0]]} at {confs[0]*100:.1f}%")
