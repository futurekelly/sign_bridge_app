"""Candidate fix for the left hand: retrain with mirror augmentation.

The deployed model was trained on single-chirality data (the recorder mirrored every left
hand to right-handed shape), so a left hand as seen by the phone falls outside the training
manifold -- and off-manifold input gets a *confident* wrong answer, which is why mirroring
at inference produced a constant `no@100%`.

Augmenting the training set with each row's x-mirrored twin makes the model chirality-
invariant by construction. That is safe here: none of these five signs is distinguished by
chirality alone (thumb-up vs thumb-down is a y-axis distinction, a fist is a fist, an open
palm and a peace sign are unchanged in meaning when mirrored).

Writes a CANDIDATE model only -- nothing deployed, nothing overwritten.
"""
import numpy as np
import pandas as pd
import tensorflow as tf
from sklearn.model_selection import train_test_split

CSV = r"C:\Users\FutureTech\sign_bridge\python_scripts\keypoint.csv"
OUT = r"C:\Users\FutureTech\sign_bridge\diagnostics\gesture_model_dense_augmented.tflite"
NAMES = ["hello", "yes", "no", "help", "thank_you"]

df = pd.read_csv(CSV, header=None)
X = df.iloc[:, 1:].values.astype(np.float32)
y = df.iloc[:, 0].values.astype(np.int64)


def mirror(rows):
    m = rows.copy()
    m[:, 0::2] *= -1.0
    return m


# Split BEFORE augmenting so a mirrored twin of a training row can never leak into test.
Xtr, Xte, ytr, yte = train_test_split(X, y, test_size=0.2, random_state=42, stratify=y)

rng = np.random.default_rng(42)
# Mirror augmentation + a little coordinate jitter, to widen the very narrow recorded
# clusters (within-class std is ~0.03-0.19) toward real-world hand variation.
JITTER = 0.02
Xtr_aug = np.vstack([Xtr, mirror(Xtr)])
ytr_aug = np.concatenate([ytr, ytr])
Xtr_aug = Xtr_aug + rng.normal(0, JITTER, Xtr_aug.shape).astype(np.float32)

tf.random.set_seed(42)
model = tf.keras.Sequential([
    tf.keras.layers.Input(shape=(42,)),
    tf.keras.layers.Dense(64, activation='relu'),
    tf.keras.layers.Dropout(0.15),
    tf.keras.layers.Dense(32, activation='relu'),
    tf.keras.layers.Dropout(0.1),
    tf.keras.layers.Dense(5, activation='softmax'),
])
model.compile(optimizer='adam', loss='sparse_categorical_crossentropy', metrics=['accuracy'])
model.fit(Xtr_aug, ytr_aug, epochs=80, batch_size=16, verbose=0)

print(f"trained on {len(Xtr_aug)} rows ({len(Xtr)} original + mirrored twins)\n", flush=True)

for label, data in (("normal", Xte), ("MIRRORED", mirror(Xte))):
    p = model.predict(data, verbose=0)
    pred = p.argmax(1)
    print(f"{label:9s} held-out accuracy: {(pred == yte).mean()*100:6.2f}%", flush=True)
    for i, n in enumerate(NAMES):
        sel = yte == i
        print(f"    {n:>10s}  recall {((pred[sel] == i).mean())*100:6.1f}%"
              f"   mean conf {p[sel].max(1).mean()*100:5.1f}%", flush=True)
    print(flush=True)

# Conversion is fragile under Keras 3. from_keras_model and from_saved_model both die the
# same way -- "ReadVariableOp ... missing attribute 'value'" -- because the MLIR converter
# cannot read Keras 3's variable representation. Note that failure is a hard process abort
# (LLVM ERROR), NOT a Python exception, so it cannot be caught and retried here: we must
# simply not call it. Instead remove variables from the graph entirely -- read the three
# dense layers' weights out as plain numpy and rebuild the forward pass with tf.constant.
# What reaches the converter is then a pure-constant graph.
# Rebuild from the trained weights. Dropout is identity at inference, so the only layers
# that matter are the three Dense ones.
dense = [l for l in model.layers if len(l.get_weights()) == 2]
assert len(dense) == 3, f"expected 3 weighted layers, found {len(dense)}"
(W1, b1), (W2, b2), (W3, b3) = (l.get_weights() for l in dense)
C = {n: tf.constant(v, dtype=tf.float32) for n, v in
     zip("W1 b1 W2 b2 W3 b3".split(), [W1, b1, W2, b2, W3, b3])}


@tf.function(input_signature=[tf.TensorSpec([1, 42], tf.float32)])
def serve(x):
    h = tf.nn.relu(tf.matmul(x, C['W1']) + C['b1'])
    h = tf.nn.relu(tf.matmul(h, C['W2']) + C['b2'])
    return tf.nn.softmax(tf.matmul(h, C['W3']) + C['b3'])


# Sanity-check the rebuild against the Keras model BEFORE converting -- a transcription
# slip here would silently ship a wrong model. serve() is fixed at batch 1, so compare
# row by row.
probe = Xte[:8]
rebuilt = np.vstack([serve(tf.constant(r.reshape(1, 42), tf.float32)).numpy() for r in probe])
drift = float(np.abs(rebuilt - model.predict(probe, verbose=0)).max())
print(f"rebuilt graph agrees with Keras model: max drift {drift:.2e}", flush=True)
assert drift < 1e-5, "constant-folded rebuild does not match the trained model"

conv = tf.lite.TFLiteConverter.from_concrete_functions([serve.get_concrete_function()], serve)
conv.optimizations = [tf.lite.Optimize.DEFAULT]
tfl = conv.convert()

with open(OUT, 'wb') as f:
    f.write(tfl)

# Verify the deployed artifact end-to-end, not just the Keras model: run the .tflite itself
# over the held-out set, in both chiralities. This is what the phone will actually execute.
it = tf.lite.Interpreter(model_content=tfl)
it.allocate_tensors()
inp, out = it.get_input_details()[0], it.get_output_details()[0]
print(f"\ncandidate: {len(tfl)} bytes  in {inp['shape']}  out {out['shape']}", flush=True)

for label, data in (("normal", Xte), ("MIRRORED", mirror(Xte))):
    preds = np.array([(it.set_tensor(inp['index'], row.reshape(1, 42).astype(np.float32)),
                       it.invoke(),
                       int(it.get_tensor(out['index'])[0].argmax()))[2] for row in data])
    print(f"  tflite {label:9s} accuracy: {(preds == yte).mean()*100:6.2f}%", flush=True)

print("NOT deployed. The deployed model is untouched.", flush=True)
