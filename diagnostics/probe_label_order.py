"""Reverse-engineer the 5-class model's TRUE label order.

inference_manager.dart hardcodes:
    numClasses == 5 -> ['hello', 'help', 'no', 'thank_you', 'yes']   (assumed alphabetical)

If that guess is wrong, every prediction is mislabeled, which looks exactly like
"yes / thank_you / help stopped working".

Method: LandmarkProcessor.extractLandmarks() synthesises an exact 21-point hand for
each word. Reproduce those numbers here, wrist-centre them the way
processRawLandmarks() does, feed the real .tflite, and read the argmax.
The geometry is known, so the argmax reveals the training label order.

Also probes the x-mirrored variant, to size up the left/right-hand question.
"""
import os
import math
import numpy as np
import tensorflow as tf

REPO = r"C:\Users\FutureTech\sign_bridge"
MODEL = os.path.join(REPO, r"assets\models\gesture_model_dense.tflite")

# ── LandmarkProcessor constants (landmark_processor.dart:82-83) ──
WRIST_X, WRIST_Y = 0.50, 0.65
DEFAULT_ANGLES = [-0.55, -0.22, 0.04, 0.30, 0.56]
JOINT_LENGTHS = [0.08, 0.06, 0.05, 0.04]

# (thumb, index, middle, ring, pinky) extended flags + optional thumb angle override
SHAPES = {
    "hello":     ((1, 1, 1, 1, 1), None),
    "yes":       ((1, 0, 0, 0, 0), 0.05),          # thumb tip above wrist
    "no":        ((1, 0, 0, 0, 0), math.pi - 0.05),  # thumb tip below wrist
    "thank_you": ((0, 1, 1, 0, 0), None),          # peace sign
    "help":      ((0, 0, 0, 0, 0), None),          # fist
}


def synth(ext, thumb_angle):
    """Replicates landmark_processor.dart:86-100. Returns 21 (x, y) pairs."""
    pts = [(WRIST_X, WRIST_Y)]
    for f in range(5):
        f_angle = thumb_angle if (f == 0 and thumb_angle is not None) else DEFAULT_ANGLES[f]
        curl = 1.0 if ext[f] else 0.28
        px, py = WRIST_X, WRIST_Y
        for j in range(4):
            ln = JOINT_LENGTHS[j]
            px = min(1.0, max(0.0, px + ln * math.sin(f_angle) * curl))
            py = min(1.0, max(0.0, py - ln * math.cos(f_angle) * curl))
            pts.append((px, py))
    return pts


def wrist_center(pts):
    """Replicates inference_manager.dart:125-133 — subtract the hand's own wrist."""
    wx, wy = pts[0]
    return [c for (x, y) in pts for c in (x - wx, y - wy)]


def mirror(vec):
    """Negate x in place (wrist is at 0,0 after centring -> mirrors about the wrist)."""
    out = list(vec)
    for i in range(0, len(out), 2):
        out[i] = -out[i]
    return out


it = tf.lite.Interpreter(model_path=MODEL)
it.allocate_tensors()
inp = it.get_input_details()[0]
out = it.get_output_details()[0]
print(f"model: in={list(inp['shape'])}  out={list(out['shape'])}")
print("hardcoded mapping in inference_manager.dart:")
print("  idx ->", ['hello', 'help', 'no', 'thank_you', 'yes'])
print()

for name, (ext, ta) in SHAPES.items():
    raw = wrist_center(synth(ext, ta))
    for variant, vec in (("asis", raw), ("mirrored", mirror(raw))):
        x = np.array([vec], dtype=np.float32)
        it.set_tensor(inp['index'], x)
        it.invoke()
        p = it.get_tensor(out['index'])[0]
        order = np.argsort(p)[::-1]
        top = ", ".join(f"[{i}]={p[i]*100:5.1f}%" for i in order[:3])
        print(f"sign {name:10s} {variant:9s} -> argmax=[{order[0]}]  top3: {top}")
    print()
