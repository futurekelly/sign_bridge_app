"""Find which preprocessing/distortion produces a constant `no@100%` on the phone.

The device now answers `no` at 100.0% for every sign. That is a preprocessing signature,
not a model one: verify_deployed.py scored these exact weights at 99.4% / 100% on the
user's own hand when fed correctly normalized vectors. So the app must be handing the model
a vector outside the training distribution, and the job here is to identify which.

The strongest lead is the bitmap aspect ratio. HandLandmarkerHelper.kt sets
TARGET_WIDTH/HEIGHT = 320x240 (4:3), but WebRTC capture on these phones is 16:9, so the
I420->ARGB downscale squeezes x more than y and every hand arrives ~33% too tall. That is a
uniform distortion, which is precisely the shape of failure that collapses a Dense net onto
one class. An earlier session hit the same 4:3 mistake and it killed detection outright
(handsCount=0); this checks what it does now that detection still succeeds.

Method: keypoint.csv holds the *normalized* 42-vectors the model was trained on, so we can
place a recorded hand back into image space and re-run the app's normalization on it. The
control must reproduce keypoint.csv exactly; each distortion then shows what the model says.
"""
import hashlib
import numpy as np
import pandas as pd
import tensorflow as tf

MODEL = r"C:\Users\FutureTech\sign_bridge\assets\models\gesture_model_dense.tflite"
BASE = r"C:\Users\FutureTech\sign_bridge\python_scripts\keypoint.csv"
NAMES = ["hello", "yes", "no", "help", "thank_you"]

# Where a hand sits in a phone frame: wrist low-centre, hand spanning ~a third of the image.
WRIST = np.array([0.5, 0.75])
SPAN = 0.30

with open(MODEL, 'rb') as f:
    raw = f.read()
it = tf.lite.Interpreter(model_content=raw)
it.allocate_tensors()
inp, out = it.get_input_details()[0], it.get_output_details()[0]


def classify(V):
    labs, confs = [], []
    for r in V:
        it.set_tensor(inp['index'], r.reshape(1, 42).astype(np.float32))
        it.invoke()
        p = it.get_tensor(out['index'])[0]
        labs.append(int(p.argmax()))
        confs.append(float(p.max()))
    return np.array(labs), np.array(confs)


def summarize(name, V, truth=None):
    labs, confs = classify(V)
    dist = np.bincount(labs, minlength=5)
    top = int(dist.argmax())
    share = dist[top] / dist.sum() * 100
    acc = "" if truth is None else f"{np.mean(labs == truth)*100:5.1f}%"
    flag = ""
    if share > 90:
        flag = f"   <-- COLLAPSED to {NAMES[top]}"
    elif share > 55:
        flag = f"   <-- biased toward {NAMES[top]}"
    print(f"{name:<38} dominant {NAMES[top]:<9} {share:5.1f}%  "
          f"conf {confs.mean()*100:5.1f}%  correct {acc:>6}{flag}")


def app_normalize(pts):
    """The app's normalization: wrist-centre, then divide by max|coord| (InferenceManager)."""
    c = pts - pts[:, 0:1, :]
    m = np.abs(c).reshape(len(c), -1).max(1).reshape(-1, 1, 1)
    m[m == 0] = 1.0
    return (c / m).reshape(len(c), 42)


d = pd.read_csv(BASE, header=None)
X = d.iloc[:, 1:].values.astype(np.float64)
y = d.iloc[:, 0].values.astype(np.int64)
rng = np.random.default_rng(0)
idx = rng.permutation(len(X))[:600]

Xs, ys = X[idx], y[idx]
pts = Xs.reshape(-1, 21, 2) * SPAN + WRIST     # recorded hand placed back in image space

print(f"model md5 {hashlib.md5(raw).hexdigest()[:8]}   {len(raw)} bytes   600 rows\n")

# Control: the round trip must land back on keypoint.csv, else the simulation is wrong.
roundtrip = app_normalize(pts)
drift = float(np.abs(roundtrip - Xs).max())
print(f"round-trip check: app_normalize(image coords) vs keypoint.csv, max drift {drift:.2e}")
assert drift < 1e-9, "simulation does not reproduce the training contract"
print()

print("--- aspect-ratio distortion (what MediaPipe actually sees) ---")


def distort(pts, kx=1.0, ky=1.0):
    p = pts.copy()
    p[:, :, 0] *= kx
    p[:, :, 1] *= ky
    return p


summarize("CONTROL: correct aspect", app_normalize(pts), ys)
# A 16:9 capture (e.g. 640x360) squeezed into a 320x240 bitmap: x compressed 2x, y 1.5x,
# so relative to a correct image the hand is 4/3 too tall.
summarize("y stretched 4/3 (4:3 bitmap, 16:9 src)", app_normalize(distort(pts, ky=4 / 3)), ys)
summarize("y squashed 3/4 (16:9 bitmap, 4:3 src)", app_normalize(distort(pts, ky=3 / 4)), ys)
summarize("x stretched 4/3", app_normalize(distort(pts, kx=4 / 3)), ys)
summarize("x squashed 3/4", app_normalize(distort(pts, kx=3 / 4)), ys)

print("\n--- other preprocessing failures ---")
summarize("NO SCALE (wrist-centre only)", (pts - pts[:, 0:1, :]).reshape(len(pts), 42), ys)
summarize("NO CENTERING (raw absolute)", pts.reshape(len(pts), 42), ys)
summarize("x and y swapped", Xs.reshape(-1, 21, 2)[:, :, ::-1].reshape(-1, 42), ys)
summarize("x negated (mirror)", (Xs.reshape(-1, 21, 2) * [-1, 1]).reshape(-1, 42), ys)
summarize("y negated", (Xs.reshape(-1, 21, 2) * [1, -1]).reshape(-1, 42), ys)
summarize("all zeros", np.zeros((len(Xs), 42)))
