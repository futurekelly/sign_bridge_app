"""Decide between `help`-replaced and `help`-supplemented, then train the winner.

The recorded `help` class is a loose half-curled hand; the user signs a closed fist. So the
new samples must enter the training set somehow, and there are two defensible ways:

  A. REPLACE - drop the old 500 `help` rows, keep the new fists.
  B. SUPPLEMENT - keep both, so the class covers two handshapes.

B is riskier than it looks. The old `help` is a half-open hand, which sits near `hello`; a
class containing both a fist and a half-open hand is also bimodal, which is the classic way
a class starts absorbing frames from its neighbours. So this measures rather than assumes.

The decisive test is NOT held-out accuracy on keypoint.csv. Both candidates will score near
100% there, because that split is drawn from the same narrow recording session. The test
that matters is the user's own 177 `yes` samples: they were recorded with the user's real
hand and are in NO training set, so they measure whether `yes` survives. A candidate that
lifts `help` while denting `yes` is not an improvement -- that is the exact bug being fixed.

Writes a candidate .tflite only. Nothing is deployed here.
"""
import numpy as np
import pandas as pd
import tensorflow as tf

BASE_CSV = r"C:\Users\FutureTech\sign_bridge\python_scripts\keypoint.csv"
HELP_NEW = r"C:\Users\FutureTech\sign_bridge\diagnostics\help_fist_new.csv"
YES_NEW = r"C:\Users\FutureTech\sign_bridge\diagnostics\yes_validation_new.csv"
OUT = r"C:\Users\FutureTech\sign_bridge\diagnostics\gesture_model_help_v2.tflite"

NAMES = ["hello", "yes", "no", "help", "thank_you"]
HELP, YES = 3, 1
JITTER = 0.02
SEED = 42


def mirror(rows):
    m = rows.copy()
    m[:, 0::2] *= -1.0
    return m


def load(path):
    d = pd.read_csv(path, header=None)
    return d.iloc[:, 1:].values.astype(np.float32), d.iloc[:, 0].values.astype(np.int64)


Xb, yb = load(BASE_CSV)
Xh, yh = load(HELP_NEW)
Xv, yv = load(YES_NEW)

print(f"base keypoint.csv : {len(Xb)} rows, classes {sorted(set(yb.tolist()))}")
print(f"new help          : {len(Xh)} rows, classes {sorted(set(yh.tolist()))}")
print(f"new yes (held-out): {len(Xv)} rows, classes {sorted(set(yv.tolist()))}", flush=True)
assert set(yh.tolist()) == {HELP}, "help_fist_new.csv must contain only label 3"
assert set(yv.tolist()) == {YES}, "yes_validation_new.csv must contain only label 1"

rng = np.random.default_rng(SEED)

# Hold out part of the new help so "does help work" is not measured on its own training rows.
perm = rng.permutation(len(Xh))
cut = int(len(Xh) * 0.7)
h_tr, h_te = Xh[perm[:cut]], Xh[perm[cut:]]
print(f"new help split    : {len(h_tr)} train / {len(h_te)} held-out\n", flush=True)


def build(mode):
    """Assemble the training set for one candidate."""
    if mode == "baseline":
        return Xb, yb
    if mode == "replace":
        keep = yb != HELP
        return np.vstack([Xb[keep], h_tr]), np.concatenate([yb[keep], np.full(len(h_tr), HELP)])
    if mode == "supplement":
        return np.vstack([Xb, h_tr]), np.concatenate([yb, np.full(len(h_tr), HELP)])
    raise ValueError(mode)


def train(mode):
    X, y = build(mode)
    # Mirror augmentation: each row plus its x-mirrored twin. Split-before-augment is not
    # needed here because the held-out sets below are separate files, not a split of X.
    Xa = np.vstack([X, mirror(X)]) + rng.normal(0, JITTER, (2 * len(X), 42)).astype(np.float32)
    ya = np.concatenate([y, y])

    tf.random.set_seed(SEED)
    m = tf.keras.Sequential([
        tf.keras.layers.Input(shape=(42,)),
        tf.keras.layers.Dense(64, activation='relu'),
        tf.keras.layers.Dropout(0.15),
        tf.keras.layers.Dense(32, activation='relu'),
        tf.keras.layers.Dropout(0.1),
        tf.keras.layers.Dense(5, activation='softmax'),
    ])
    m.compile(optimizer='adam', loss='sparse_categorical_crossentropy', metrics=['accuracy'])
    m.fit(Xa, ya, epochs=80, batch_size=16, verbose=0)
    return m


def report(name, model):
    print(f"--- {name} ---", flush=True)
    for label, data, want in (
        ("new help (held-out)", h_te, NAMES[HELP]),
        ("user's yes samples", Xv, NAMES[YES]),
    ):
        p = model.predict(data, verbose=0)
        pred = p.argmax(1)
        acc = (pred == list(NAMES).index(want))
        print(f"  {label:<20} -> {want:<9} {acc.mean()*100:6.2f}%"
              f"   mean conf {p[acc].max(1).mean()*100 if acc.any() else 0:5.1f}%"
              f"   n={len(data)}", flush=True)
        wrong = np.bincount(pred[~acc], minlength=5)
        if wrong.sum():
            tops = ", ".join(f"{NAMES[i]}x{wrong[i]}" for i in np.argsort(wrong)[::-1]
                             if wrong[i])
            print(f"      misread as: {tops}", flush=True)
    print(flush=True)


models = {}
for mode in ("baseline", "replace", "supplement"):
    models[mode] = train(mode)
    report(mode, models[mode])

# Pick the candidate that maximises the WORST of the two things we care about: recognising
# the user's help, and not damaging the user's yes. A model that wins on one and loses the
# other is a regression dressed up as a fix.
def worst_case(m):
    ph = m.predict(h_te, verbose=0).argmax(1) == HELP
    pv = m.predict(Xv, verbose=0).argmax(1) == YES
    return min(ph.mean(), pv.mean())


scores = {k: worst_case(v) for k, v in models.items()}
print("worst-case score (help recall vs yes recall, whichever is lower):")
for k, v in sorted(scores.items(), key=lambda kv: -kv[1]):
    print(f"  {k:<11} {v*100:6.2f}%")

best = max(scores, key=scores.get)
print(f"\nselected: {best}\n", flush=True)

# Convert with a constant-folded graph: Keras 3 + TF 2.16 aborts on from_keras_model with
# "LLVM ERROR: Failed to infer result type(s)" -- a hard abort, not catchable, so we simply
# never call it.
model = models[best]
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


probe = Xv[:8]
rebuilt = np.vstack([serve(tf.constant(r.reshape(1, 42), tf.float32)).numpy() for r in probe])
drift = float(np.abs(rebuilt - model.predict(probe, verbose=0)).max())
print(f"rebuilt graph agrees with Keras model: max drift {drift:.2e}", flush=True)
assert drift < 1e-5, "constant-folded rebuild does not match the trained model"

conv = tf.lite.TFLiteConverter.from_concrete_functions([serve.get_concrete_function()], serve)
conv.optimizations = [tf.lite.Optimize.DEFAULT]
tfl = conv.convert()

with open(OUT, 'wb') as f:
    f.write(tfl)

# Verify through the artifact the phone will actually run, not the Keras model.
it = tf.lite.Interpreter(model_content=tfl)
it.allocate_tensors()
inp, out = it.get_input_details()[0], it.get_output_details()[0]
print(f"\ncandidate: {len(tfl)} bytes  in {inp['shape']}  out {out['shape']}", flush=True)

for label, data, want in (("help (held-out)", h_te, HELP),
                          ("user yes", Xv, YES),
                          ("help mirrored", mirror(h_te), HELP),
                          ("yes mirrored", mirror(Xv), YES)):
    preds = np.array([(it.set_tensor(inp['index'], r.reshape(1, 42).astype(np.float32)),
                       it.invoke(),
                       int(it.get_tensor(out['index'])[0].argmax()))[2] for r in data])
    print(f"  tflite {label:<15} -> {NAMES[want]:<9} {(preds == want).mean()*100:6.2f}%",
          flush=True)

print(f"\nwritten: {OUT}\nNOT deployed.", flush=True)
