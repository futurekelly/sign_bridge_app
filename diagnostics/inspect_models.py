"""Identify every .tflite in the repo: input/output shapes + class count.

Answers one question: what does lib/services/ai/inference_manager.dart actually
load, and does it agree with assets/labels/gesture_labels.txt (47 labels)?
"""
import os
import tensorflow as tf

REPO = r"C:\Users\FutureTech\sign_bridge"
MODELS = [
    r"assets\models\gesture_model_dense.tflite",           # what the app loads
    r"assets\models\gesture_model.tflite",
    r"assets\models\gesture_model_dense.tflite.bak",
    r"assets\models\gesture_model_dense_experimental.tflite",
    r"assets\models\gesture_model_gru_experimental.tflite",
    r"assets\models\archive\gesture_model_old.tflite",
]

for rel in MODELS:
    p = os.path.join(REPO, rel)
    name = rel.replace("assets\\models\\", "")
    if not os.path.exists(p):
        print(f"{name:45s} MISSING")
        continue
    size = os.path.getsize(p)
    try:
        it = tf.lite.Interpreter(model_path=p)
        it.allocate_tensors()
        i = it.get_input_details()[0]
        o = it.get_output_details()[0]
        print(f"{name:45s} {size:>8} B  in={list(i['shape'])} {i['dtype'].__name__:8s}"
              f" out={list(o['shape'])} {o['dtype'].__name__}")
    except Exception as e:
        print(f"{name:45s} {size:>8} B  ERROR {type(e).__name__}: {str(e)[:90]}")

labels = os.path.join(REPO, r"assets\labels\gesture_labels.txt")
with open(labels) as f:
    words = [w.strip() for w in f if w.strip()]
print(f"\nassets/labels/gesture_labels.txt -> {len(words)} labels")
print("first 10:", words[:10])
