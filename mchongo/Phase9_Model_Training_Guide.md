# Phase 9: Custom ASL Model Training Guide

This document serves as a comprehensive step-by-step guide for creating your own custom Sign Language AI model (from dataset creation to deployment) and integrating it into the SignBridge app.

## 🧠 Step 1: Dataset Creation & Collection

To train an AI to recognize hand gestures, you need a dataset of images showing those gestures.

### Approach A: Using Pre-existing Datasets (Fastest)
You do not need to film yourself thousands of times if open-source datasets exist.
1. Go to **Kaggle.com** or **Roboflow.com** and search for "American Sign Language Dataset" or "ASL Alphabet Dataset".
2. Download a dataset that contains images sorted into folders by class (e.g., a folder named `hello` containing 500 images of the hello sign, a folder named `yes` with 500 images, etc.).

### Approach B: Creating Your Own Custom Dataset (Most Accurate)
If you are doing custom Swahili signs or specialized gestures:
1. **Record Video:** Film yourself performing a gesture (e.g., "Hello") for 30 seconds from different angles, lighting conditions, and distances.
2. **Extract Frames:** Use a script (or a tool like VLC/Roboflow) to extract 10 frames per second from the video.
3. **Background Diversity:** Ensure your hands are filmed against different backgrounds so the AI learns the hands, not the wall behind you.

---

## 🏷️ Step 2: Labeling and Preprocessing

If your dataset is just raw images, you need to format it so the AI understands it.

1. **Use Roboflow (Highly Recommended):** 
   - Create a free account at Roboflow.com.
   - Upload your raw images.
   - Use their bounding box tool to draw boxes around the hands, or just assign image-level labels (e.g., "This whole image is 'Hello'").
2. **Augmentation:** 
   - Inside Roboflow, apply augmentations (blurring, rotating, changing brightness). This artificially expands a 500-image dataset into a 1,500-image dataset, making your AI much smarter and more robust against bad phone cameras.
3. **Export:** Export the dataset in **TensorFlow / Keras** format.

---

## 🚀 Step 3: Training the Model (With or Without Deep AI Knowledge)

You need to train a Convolutional Neural Network (CNN) to classify the images.

### The "No-Code" Way (Easiest)
1. Go to **Google Teachable Machine** (teachablemachine.withgoogle.com).
2. Create an "Image Project".
3. Upload your folders of images (one folder for "Hello", one for "Yes", etc.).
4. Click **Train Model**.
5. Once trained, click **Export Model** -> select **TensorFlow Lite (TFLite)** -> **Floating Point**.
6. Download the generated `.tflite` file and the `labels.txt` file.

### The Python/Colab Way (Most Professional & Customizable)
1. Open **Google Colab** (a free Python notebook running on Google's cloud GPUs).
2. Write a Python script using `TensorFlow` and `Keras`.
3. Use **Transfer Learning**: Load a pre-trained model like `MobileNetV2` (which already knows how to see edges, shapes, and colors).
4. Remove the final layer of MobileNet and add a new layer matching your number of signs (e.g., 5).
5. Train the model on your dataset for 20-50 Epochs.
6. **Convert to TFLite:**
   ```python
   converter = tf.lite.TFLiteConverter.from_keras_model(model)
   tflite_model = converter.convert()
   with open('gesture_model.tflite', 'wb') as f:
       f.write(tflite_model)
   ```

---

## ⚙️ Step 4: Fine-Tuning & Evaluation

Before putting it in the app, test it.
- **Validation Accuracy:** If your Colab script says the model is 95% accurate on training data but 50% on validation data, it is **overfitting**. You need more diverse images (different lighting, different people).
- **Quantization:** If the `.tflite` file is 20MB, it might slow down the phone. Apply "Float16 Quantization" or "Int8 Quantization" during the Colab conversion step to shrink the model to ~3MB with almost no loss in accuracy.

---

## 📲 Step 5: Tying it into SignBridge

We have already built 100% of the architecture in SignBridge to support this. Because we used a decoupled architecture in `gesture_recognition_service.dart`, you do **not** need to touch any Dart code when your model is ready.

1. **The Model:** Take your downloaded `gesture_model.tflite` and overwrite the empty placeholder at:
   `sign_bridge/assets/models/gesture_model.tflite`

2. **The Labels:** Open `sign_bridge/assets/labels/gesture_labels.txt`. Delete the placeholder text and paste your exact classes in the exact order the model outputs them. (If using Teachable Machine, it gives you this text file).

3. **The GIFs:** Create or download GIF animations for your signs. If your label file has `hello` and `thank_you`, you must place:
   `sign_bridge/assets/gifs/hello.gif`
   `sign_bridge/assets/gifs/thank_you.gif`

### How the App Reacts Automatically:
When you open SignBridge:
- The app detects `gesture_model.tflite` is no longer empty.
- It spins up a background Isolate (CPU thread).
- It grabs 3 frames per second from the selfie camera.
- It converts them to `224x224` RGB Tensors.
- It passes them to your custom model.
- Your model spits out a probability (e.g., "99% Hello").
- The app immediately shows `hello.gif` to the deaf user, prints "hello" on the screen, speaks "hello" out loud for the hearing user, and syncs it over the internet to the person they are calling.

**That is the complete lifecycle of AI in SignBridge!**
