"""Diagnose the vector captured from the device.

The [DIAG] dump gave one real 42-vector from the phone. Decoding it as 21 (x,y) pairs:

    L0  wrist      (0.000, 0.000)      <- centred
    L1  thumb CMC  (0.152, 0.443)
    L3  thumb IP   (0.646, 1.000)      <- max|coord| == 1.0, so scaled
    L5  index MCP  (0.670, 0.471)
    L9  mid MCP    (0.659, 0.139)
    L13 ring MCP   (0.616,-0.163)
    L17 pinky MCP  (0.545,-0.456)

So centring and scaling are both applied correctly, and the wrist arrives at a sane
position (0.237, 0.538). Dart is doing its job. But look at the geometry: the four
knuckles are stacked along Y, and the fingers extend along +X. In keypoint.csv it is the
reverse -- fingers extend along -Y and the knuckles spread along X. Every x in the device
vector is positive, which never occurs in the training file.

That reads as a hand rotated ~90 degrees, which is an orientation bug in the native capture,
not a model or normalization bug. This checks that directly, and rules out the alternative
that the hand simply is not one of the five words.
"""
import numpy as np
import pandas as pd
import tensorflow as tf

MODEL = r"C:\Users\FutureTech\sign_bridge\assets\models\gesture_model_dense.tflite"
BASE = r"C:\Users\FutureTech\sign_bridge\python_scripts\keypoint.csv"
NAMES = ["hello", "yes", "no", "help", "thank_you"]

# Captured live from the Huawei via the temporary [DIAG] dump.
DEVICE = np.array([
    0.000, 0.000, 0.172, 0.473, 0.444, 0.896, 0.717, 1.000, 0.932, 0.886,
    0.706, 0.510, 0.879, 0.506, 0.656, 0.490, 0.429, 0.496, 0.692, 0.156,
    0.894, 0.147, 0.615, 0.180, 0.351, 0.233, 0.644, -0.160, 0.811, -0.187,
    0.530, -0.097, 0.292, -0.004, 0.562, -0.469, 0.718, -0.449, 0.541, -0.328,
    0.373, -0.219,
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


def rotate(v, deg):
    """Rotate the hand about the wrist, then re-scale, as the recorder would."""
    p = v.reshape(21, 2).copy()
    t = np.radians(deg)
    R = np.array([[np.cos(t), -np.sin(t)], [np.sin(t), np.cos(t)]])
    p = p @ R.T
    m = np.abs(p).max()
    return (p / m).reshape(42) if m else p.reshape(42)


d = pd.read_csv(BASE, header=None)
X = d.iloc[:, 1:].values.astype(np.float64)
y = d.iloc[:, 0].values.astype(np.int64)
centroids = {n: X[y == i].mean(0) for i, n in enumerate(NAMES)}

print("=== the device vector, as captured ===")
lab, conf = classify(DEVICE)
print(f"  model says: {NAMES[lab[0]]} at {conf[0]*100:.1f}%")
print(f"  x range: {DEVICE[0::2].min():+.3f} .. {DEVICE[0::2].max():+.3f}   "
      f"y range: {DEVICE[1::2].min():+.3f} .. {DEVICE[1::2].max():+.3f}")
print("  distance to each class centroid:")
rank = sorted(NAMES, key=lambda n: np.linalg.norm(DEVICE - centroids[n]))
for n in rank:
    print(f"     {n:<10} {np.linalg.norm(DEVICE - centroids[n]):.4f}")
print(f"  --> nearest class: {rank[0]}")

print("\n=== rotate the captured hand back, does it become signable? ===")
for deg in (0, 90, 180, 270, -90):
    r = rotate(DEVICE, deg)
    lab, conf = classify(r)
    print(f"  rotate {deg:+4d} deg -> {NAMES[lab[0]]:<9} {conf[0]*100:5.1f}%")

print("\n=== control: rotate the TRAINING data, does it collapse? ===")
# If rotating real training hands reproduces the device's constant answer, then a
# 90-degree capture rotation is confirmed as the cause and not merely correlated with it.
for deg in (0, 90, 180, 270):
    R = np.vstack([rotate(v, deg) for v in X])
    lab, conf = classify(R)
    dist = np.bincount(lab, minlength=5)
    top = int(dist.argmax())
    print(f"  rotate {deg:+4d} deg -> dominant {NAMES[top]:<9} {dist[top]/dist.sum()*100:5.1f}%  "
          f"conf {conf.mean()*100:5.1f}%  correct {(lab == y).mean()*100:5.1f}%")
