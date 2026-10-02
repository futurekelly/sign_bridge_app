"""Can the training data even separate `help` from `yes`?

On device, signing `help` produced `yes` at 53-79% while every other word hit 99-100%.
The deployed model was trained on ALL of keypoint.csv, so evaluating it on that same CSV
measures memorisation, not separability.

So: retrain the identical architecture on an 80/20 stratified split and read the confusion
matrix. That shows which classes are genuinely confusable in the data itself -- i.e.
whether `help` is a model problem or a dataset problem.
"""
import numpy as np
import pandas as pd
import tensorflow as tf
from sklearn.model_selection import train_test_split

CSV = r"C:\Users\FutureTech\sign_bridge\python_scripts\keypoint.csv"
NAMES = ["hello", "yes", "no", "help", "thank_you"]

df = pd.read_csv(CSV, header=None)
X = df.iloc[:, 1:].values.astype(np.float32)
y = df.iloc[:, 0].values.astype(np.int64)

# ── How far apart are the class centres, relative to their own spread? ──
print("Centroid separability (distance between class means / mean within-class std)")
print("  < 1.0 means the classes overlap more than they differ\n")
for a in range(5):
    for b in range(a + 1, 5):
        A, B = X[y == a], X[y == b]
        centroid_gap = np.linalg.norm(A.mean(0) - B.mean(0))
        spread = (A.std(0).mean() + B.std(0).mean()) / 2
        ratio = centroid_gap / spread if spread else float('inf')
        flag = "  <-- OVERLAPPING" if ratio < 1.5 else ""
        print(f"  {NAMES[a]:>9s} vs {NAMES[b]:<9s}  gap={centroid_gap:6.3f}  "
              f"spread={spread:6.3f}  ratio={ratio:5.2f}{flag}")

# ── Identical architecture, held-out evaluation ──
Xtr, Xte, ytr, yte = train_test_split(X, y, test_size=0.2, random_state=42, stratify=y)
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
model.fit(Xtr, ytr, epochs=80, batch_size=16, verbose=0)

probs = model.predict(Xte, verbose=0)
pred = probs.argmax(1)

print(f"\nHeld-out accuracy: {(pred == yte).mean()*100:.2f}%  (n={len(yte)})\n")
print("Confusion matrix (rows = signed, cols = predicted):")
print("             " + "".join(f"{n:>11s}" for n in NAMES))
for i, n in enumerate(NAMES):
    row = "".join(f"{((pred[yte==i]==j).sum()):>11d}" for j in range(5))
    print(f"  {n:>10s} {row}")

print("\nPer-class recall:")
for i, n in enumerate(NAMES):
    tot = (yte == i).sum()
    corr = ((pred == i) & (yte == i)).sum()
    conf = probs[yte == i].max(1).mean()
    print(f"  {n:>10s}  recall {corr/tot*100:6.1f}%   mean conf when signed {conf*100:5.1f}%")
