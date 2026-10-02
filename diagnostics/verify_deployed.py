"""Verify the model that actually ships, against the user's own hand.

train_help_v2.py showed the new `help` recordings add nothing: a fresh model on the
existing recipe already reads the user's fist as `help` at 99.7% on rows it never saw.
That is a claim about a *retrained* model though, and a retrain is not the artifact on
the phone. This loads the deployed asset itself and scores it, so the number describes
what will actually run.

The two held-out sets are the user's own hand, recorded separately and in no training
file at all:
    help_fist_new.csv      - 177 closed fists with the thumb wrapped
    yes_validation_new.csv - 177 thumbs-up, the critical control

`yes` is the control because it is the class that was being lost: a fist was answering
as `yes`, which is only possible if the two are close enough to trade. If the deployed
model holds `yes` at ~100% while also reading the fist as `help`, the two are separated
and the fix is real.

Both chiralities are scored. The recorder mirrors left hands and the app mirrors left
hands, but the webcam feed underneath is flipped and the phone's is not, so the two can
disagree about which hand is which. Mirror-augmented training is what makes that
disagreement harmless, and this is where that gets checked rather than assumed.
"""
import hashlib
import numpy as np
import pandas as pd
import tensorflow as tf

MODEL = r"C:\Users\FutureTech\sign_bridge\assets\models\gesture_model_dense.tflite"
BASE = r"C:\Users\FutureTech\sign_bridge\python_scripts\keypoint.csv"
HELP = r"C:\Users\FutureTech\sign_bridge\diagnostics\help_fist_new.csv"
YES = r"C:\Users\FutureTech\sign_bridge\diagnostics\yes_validation_new.csv"

NAMES = ["hello", "yes", "no", "help", "thank_you"]

with open(MODEL, 'rb') as f:
    raw = f.read()
print(f"deployed: {MODEL}")
print(f"  {len(raw)} bytes   md5 {hashlib.md5(raw).hexdigest()[:8]}\n")

it = tf.lite.Interpreter(model_content=raw)
it.allocate_tensors()
inp, out = it.get_input_details()[0], it.get_output_details()[0]
print(f"  input {inp['shape']}   output {out['shape']}\n")
assert list(inp['shape']) == [1, 42], "not the 42-feature 5-class model"
assert list(out['shape']) == [1, 5], "not the 5-class head"


def mirror(rows):
    m = rows.copy()
    m[:, 0::2] *= -1.0
    return m


def load(path):
    d = pd.read_csv(path, header=None)
    return d.iloc[:, 1:].values.astype(np.float32), d.iloc[:, 0].values.astype(np.int64)


def score(X):
    """Per-row argmax and confidence through the real interpreter."""
    preds, confs = [], []
    for r in X:
        it.set_tensor(inp['index'], r.reshape(1, 42).astype(np.float32))
        it.invoke()
        p = it.get_tensor(out['index'])[0]
        preds.append(int(p.argmax()))
        confs.append(float(p.max()))
    return np.array(preds), np.array(confs)


Xb, yb = load(BASE)
Xh, _ = load(HELP)
Xv, _ = load(YES)

rng = np.random.default_rng(0)
perm = rng.permutation(len(Xb))
# A slice of the training file, held back here purely as a regression check: a model that
# has forgotten the original five words would show up as a dip on this row.
holdout = Xb[perm[-300:]]
holdout_y = yb[perm[-300:]]

print("=" * 62)
for label, X, want in (
    ("keypoint.csv holdout   ", holdout, holdout_y),
    ("user's help (177 fists)", Xh, np.full(len(Xh), 3)),
    ("user's yes  (177 up)   ", Xv, np.full(len(Xv), 1)),
    ("help, mirrored hand    ", mirror(Xh), np.full(len(Xh), 3)),
    ("yes,  mirrored hand    ", mirror(Xv), np.full(len(Xv), 1)),
):
    pred, conf = score(X)
    ok = pred == want
    hit = conf[ok].mean() * 100 if ok.any() else 0.0
    print(f"{label}  {ok.mean()*100:6.2f}% correct   mean conf on correct {hit:5.1f}%")
    if not ok.all():
        bad = np.bincount(pred[~ok], minlength=5)
        tops = ", ".join(f"{NAMES[i]}x{bad[i]}" for i in np.argsort(bad)[::-1] if bad[i])
        print(f"{'':26}misread as: {tops}")

# The specific confusion that matters. `help` and `yes` are the pair that were trading;
# print the full matrix so a swap in either direction is visible rather than summarised.
print("\nhelp vs yes, held-out, both chiralities:")
ph, _ = score(Xh)
pv, _ = score(Xv)
phm, _ = score(mirror(Xh))
pvm, _ = score(mirror(Xv))
print(f"  fist  -> help {(ph == 3).mean()*100:6.2f}%   -> yes {(ph == 1).mean()*100:6.2f}%"
      f"   -> hello {(ph == 0).mean()*100:6.2f}%")
print(f"  up    -> yes  {(pv == 1).mean()*100:6.2f}%   -> help {(pv == 3).mean()*100:6.2f}%"
      f"   -> no {(pv == 2).mean()*100:6.2f}%")
print(f"  fist/mirrored -> help {(phm == 3).mean()*100:6.2f}%   -> yes {(phm == 1).mean()*100:6.2f}%")
print(f"  up/mirrored   -> yes  {(pvm == 1).mean()*100:6.2f}%   -> help {(pvm == 3).mean()*100:6.2f}%")
