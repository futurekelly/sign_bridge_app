"""Is handedness essential, or can we pick chirality by confidence?

record_landmarks.py mirrors LEFT hands to right-hand shape, so the training set is
single-chirality. At inference we must mirror the same way -- but the Android
handedness convention differs from the recorder's (non-mirrored buffer vs cv2.flip),
so getting it wrong is a real possibility.

This measures the cost of getting it wrong. For real training rows and their mirrored
twins, it reports the predicted class and confidence. If mirrored (off-chirality)
inputs come back low-confidence, then "pick the chirality the model is most confident
about" is safe. If they come back confident, handedness must be transported instead.
"""
import numpy as np
import pandas as pd
import tensorflow as tf

REPO = r"C:\Users\FutureTech\sign_bridge"
CSV = REPO + r"\python_scripts\keypoint.csv"
MODEL = REPO + r"\assets\models\gesture_model_dense.tflite"
NAMES = ["hello", "yes", "no", "help", "thank_you"]

df = pd.read_csv(CSV, header=None)
X = df.iloc[:, 1:].values.astype(np.float32)
y = df.iloc[:, 0].values.astype(int)

it = tf.lite.Interpreter(model_path=MODEL)
it.allocate_tensors()
inp, out = it.get_input_details()[0], it.get_output_details()[0]


def run(rows):
    res = []
    for r in rows:
        it.set_tensor(inp['index'], r.reshape(1, 42))
        it.invoke()
        p = it.get_tensor(out['index'])[0]
        res.append((int(np.argmax(p)), float(np.max(p))))
    return res


def mirror_x(rows):
    m = rows.copy()
    m[:, 0::2] *= -1.0
    return m


print(f"{'class':12s} {'chirality':10s} {'n':>5s} {'acc':>7s} {'mean conf':>10s} {'conf of wrong preds':>20s}")
print("-" * 72)

for cls in sorted(set(y)):
    rows = X[y == cls]
    for label, data in (("canonical", rows), ("MIRRORED", mirror_x(rows))):
        preds = run(data)
        idx = np.array([p[0] for p in preds])
        conf = np.array([p[1] for p in preds])
        acc = (idx == cls).mean()
        wrong = conf[idx != cls]
        wrong_s = f"{wrong.mean():.3f} (max {wrong.max():.3f}) n={len(wrong)}" if len(wrong) else "-- none --"
        print(f"{NAMES[cls]:12s} {label:10s} {len(rows):5d} {acc*100:6.1f}% {conf.mean():10.3f} {wrong_s:>20s}")
    print()
