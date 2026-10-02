"""Does the dense model use any Select TF (Flex) op?

This decides whether `org.tensorflow:tensorflow-lite-select-tf-ops` can be dropped from
android/app/build.gradle.kts. That Gradle dependency ships libtensorflowlite_flex_jni.so,
which is 68,177,576 bytes uncompressed for arm64-v8a -- bigger than every other file in the
APK combined (libflutter 11MB, mediapipe 14MB, webrtc 12MB).

The GRU model it was added for is not in the build at all: InferenceManager.initialize()
defaults to _useTemporalModel = true and asks for
assets/models/gesture_model_gru.tflite, which does not exist (only
gesture_model_gru_experimental.tflite does), so the load always throws and always falls back
to the dense model. If the dense model contains no Flex op, the library is never exercised.

Flex ops are how TFLite runs ops outside the builtin set, which is what RNN/LSTM/GRU models
need. They show up in the op list prefixed "Flex". A dense classifier should contain none --
but "should" is not a measurement, so this checks.

Run:
  python_scripts\\venv\\Scripts\\python.exe diagnostics\\verify_no_flex_ops.py
"""
import glob
import os

import tensorflow as tf

ROOT = r"C:\Users\FutureTech\sign_bridge"
DEPLOYED = os.path.join(ROOT, "assets", "models", "gesture_model_dense.tflite")


def ops_of(path):
    with open(path, "rb") as f:
        it = tf.lite.Interpreter(model_content=f.read())
    it.allocate_tensors()
    return sorted({d["op_name"] for d in it._get_ops_details()})


print(f"TensorFlow {tf.__version__}\n")

targets = [DEPLOYED]
targets += sorted(glob.glob(os.path.join(ROOT, "assets", "models", "*.tflite")))

seen = set()
for path in targets:
    if path in seen or not os.path.exists(path):
        continue
    seen.add(path)

    rel = os.path.relpath(path, ROOT)
    size = os.path.getsize(path)
    try:
        ops = ops_of(path)
    except Exception as exc:  # unreadable / non-TFLite: report, don't crash the check
        print(f"{rel}  ({size:,} B)\n    could not load: {type(exc).__name__}: {exc}\n")
        continue

    flex = [o for o in ops if o.startswith("Flex")]
    tag = "  <-- DEPLOYED" if path == DEPLOYED else ""
    print(f"{rel}  ({size:,} B){tag}")
    print(f"    {len(ops)} distinct op(s): {', '.join(ops) if ops else '(none reported)'}")
    if flex:
        print(f"    FLEX OPS PRESENT: {flex}  -> this model NEEDS the flex library")
    else:
        print("    no Flex ops -> does NOT need the flex library")
    print()

print("READ THIS")
print("-" * 60)
dense_ops = ops_of(DEPLOYED)
dense_flex = [o for o in dense_ops if o.startswith("Flex")]
if dense_flex:
    print(f"  Dense model HAS flex ops {dense_flex}: DO NOT remove the dependency.")
else:
    print("  Dense model has no Flex ops, and it is the only model that ever loads.")
    print("  libtensorflowlite_flex_jni.so is therefore dead weight and the Gradle")
    print("  dependency can be removed -- verify on device afterwards that the five")
    print("  words still classify exactly as before.")
