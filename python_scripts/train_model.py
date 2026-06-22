# train_model.py — trains a lightweight Keras MLP gesture classifier on landmarks CSV
# and exports the model directly to TensorFlow Lite (gesture_classifier.tflite).
#
# Requirements:
# - tensorflow
# - scikit-learn
# - pandas
# - numpy

import tensorflow as tf
from tensorflow.keras import layers, models
import numpy as np
import pandas as pd
from sklearn.model_selection import train_test_split
import os

CSV_PATH = "keypoint.csv"
TFLITE_OUTPUT = "gesture_classifier.tflite"

def main():
    if not os.path.exists(CSV_PATH):
        print(f"Error: Dataset {CSV_PATH} not found. Run record_landmarks.py first.")
        return

    # 1. Load dataset
    print(f"Loading dataset from {CSV_PATH}...")
    df = pd.read_csv(CSV_PATH, header=None)
    
    X = df.iloc[:, 1:].values.astype(np.float32)  # 42 coordinates (x, y for 21 points)
    y = df.iloc[:, 0].values.astype(np.int64)     # Class index

    num_classes = len(np.unique(y))
    print(f"Dataset loaded. Total samples: {X.shape[0]}, Input dimensions: {X.shape[1]}, Classes found: {num_classes}")

    # 2. Train/Validation Split (80% Train, 20% Val/Test)
    X_train, X_val, y_train, y_val = train_test_split(
        X, y, test_size=0.2, random_state=42, stratify=y
    )
    print(f"Split completed. Training set: {X_train.shape[0]} samples, Validation set: {X_val.shape[0]} samples.")

    # 3. Build Keras Model (MLP Architecture)
    model = models.Sequential([
        layers.Input(shape=(42,)),
        layers.Dense(64, activation='relu'),
        layers.Dropout(0.15),
        layers.Dense(32, activation='relu'),
        layers.Dropout(0.1),
        layers.Dense(num_classes, activation='softmax')
    ])

    print("\nModel Summary:")
    model.summary()

    # Compile Model
    model.compile(
        optimizer='adam',
        loss='sparse_categorical_crossentropy',
        metrics=['accuracy']
    )

    # 4. Train Model
    print("\nTraining MLP classifier...")
    history = model.fit(
        X_train, y_train,
        epochs=80,
        batch_size=16,
        validation_data=(X_val, y_val),
        verbose=1
    )

    # Evaluate validation loss and accuracy
    val_loss, val_acc = model.evaluate(X_val, y_val, verbose=0)
    print(f"\nFinal Validation Loss: {val_loss:.4f}")
    print(f"Final Validation Accuracy: {val_acc * 100:.2f}%")

    if val_acc < 0.95:
        print("Warning: Validation accuracy is below 95%. Consider collecting more samples.")
    else:
        print("Success: Target validation accuracy (>95%) achieved!")

    # 5. Convert to TFLite
    print("\nConverting model to TensorFlow Lite (.tflite)...")
    tflite_model = None
    try:
        print("Attempting conversion via model.export()...")
        export_dir = "gesture_model_saved"
        model.export(export_dir)
        converter = tf.lite.TFLiteConverter.from_saved_model(export_dir)
        converter.optimizations = [tf.lite.Optimize.DEFAULT]
        tflite_model = converter.convert()
        print("Conversion via model.export() succeeded.")
    except Exception as e:
        print(f"model.export() conversion failed or not supported: {e}")
        print("Falling back to tf.lite.TFLiteConverter.from_keras_model...")
        converter = tf.lite.TFLiteConverter.from_keras_model(model)
        converter.optimizations = [tf.lite.Optimize.DEFAULT]
        tflite_model = converter.convert()
        print("Conversion via from_keras_model succeeded.")
    
    # Save the model
    with open(TFLITE_OUTPUT, 'wb') as f:
        f.write(tflite_model)
        
    model_size_kb = os.path.getsize(TFLITE_OUTPUT) / 1024.0
    print(f"TFLite model successfully saved to: {TFLITE_OUTPUT}")
    print(f"Model size: {model_size_kb:.2f} KB (Target: <1024 KB)")

if __name__ == "__main__":
    main()
