"""Is the deployed model actually chirality-invariant, and how rotation-sensitive is it?

Both questions decide whether the fix in HandLandmarkerHelper.kt is safe and sufficient.

Chirality: the note in memory says mirror augmentation made the model chirality-invariant,
which is why the app is allowed to get handedness wrong. If that is true, it does not matter
whether MediaPipe reports the corrected hand as Left or Right after the frame is turned
upright -- both branches land on the same answer. If it is false, the mirror branch is
load-bearing and the fix's outcome depends on which way MediaPipe calls it.

Rotation: the fix assumes the model is genuinely orientation-sensitive, i.e. that a hand
turned a quarter turn is read as a different word rather than still recognised. If the model
were rotation-invariant there would be nothing to fix.

Both are measured through the deployed .tflite itself, on labelled data, so neither is a
matter of inference.
"""
import numpy as np
import pandas as pd
import tensorflow as tf

MODEL = r"C:\Users\FutureTech\sign_bridge\assets\models\gesture_model_dense.tflite"
BASE = r"C:\Users\FutureTech\sign_bridge\python_scripts\keypoint.csv"
NAMES = ["hello", "yes", "no", "help", "thank_you"]

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


def xform(V, deg, mirror):
    P = V.reshape(-1, 21, 2).copy()
    if deg:
        t = np.radians(deg)
        P = P @ np.array([[np.cos(t), -np.sin(t)], [np.sin(t), np.cos(t)]]).T
    if mirror:
        P[:, :, 0] *= -1
    m = np.abs(P).reshape(len(P), -1).max(1).reshape(-1, 1, 1)
    m[m == 0] = 1.0
    return (P / m).reshape(len(P), 42)


d = pd.read_csv(BASE, header=None)
X = d.iloc[:, 1:].values.astype(np.float64)
y = d.iloc[:, 0].values.astype(np.int64)
rng = np.random.default_rng(0)
idx = rng.permutation(len(X))[:1500]
Xs, ys = X[idx], y[idx]

print(f"deployed model: {len(raw)} bytes, {len(ys)} labelled rows\n")
print(f"{'transform applied to real training hands':<34} {'accuracy':>9}  {'conf':>6}")
print("-" * 56)
for deg in (0, 90, 180, 270):
    for mirror in (False, True):
        T = xform(Xs, deg, mirror)
        labs, confs = classify(T)
        note = ""
        if deg == 0 and not mirror:
            note = "  <- the orientation the app must deliver"
        if deg == 0 and mirror:
            note = "  <- is mirror augmentation real?"
        label = f"rot {deg:+4d}{'  + mirror x' if mirror else ''}"
        print(f"{label:<34} {np.mean(labs == ys)*100:8.1f}% {confs.mean()*100:5.1f}%{note}")

print()
print("READ THIS:")
for deg in (0, 90, 180, 270):
    T = xform(Xs, deg, False)
    labs, _ = classify(T)
    print(f"  rot {deg:>3} deg: {np.mean(labs == ys)*100:5.1f}% correct "
          f"({'orientation matters' if np.mean(labs == ys) < 0.6 else 'still recognised'})")
