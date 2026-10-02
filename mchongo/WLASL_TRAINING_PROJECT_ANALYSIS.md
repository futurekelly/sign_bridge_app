# SignBridge Training Project Analysis
## WLASL Master Training Pipeline Architecture

**Date:** 2026-07-25  
**Project Path:** C:\Users\FutureTech\Desktop\WLASL-master  
**Flutter App Path:** C:\Users\FutureTech\sign_bridge

---

## Executive Summary

The WLASL training pipeline is a **static pose detection system** that:
- ✅ Extracts 84 floating-point landmark coordinates from MediaPipe Hands (21 landmarks × 2 hands × 2 dimensions)
- ✅ Trains a 3-layer Dense Neural Network on single frames (no temporal context)
- ✅ Produces **83.47% test accuracy** on 47 gesture classes
- ⚠️ **Does NOT retain sequence memory** — treats every frame independently

---

## 1. Current Dataset Structure

### 1.1 Raw Videos
- **Location:** dataset/raw/ (by gesture name)
- **Format:** MP4 files, one per gesture class
- **Example:** dataset/raw/book/book.mp4

### 1.2 Processed Videos
- **Location:** dataset/processed/ (organized by gesture name)
- **Processing:** Videos are trimmed using frame_start/frame_end from filtered_wlasl.json
- **Resolution:** 640×480 @ original FPS
- **File:** One processed MP4 per gesture

### 1.3 Landmarks CSV
- **Location:** dataset/landmarks.csv
- **Structure:**
  `
  label,f0,f1,f2,...,f83
  book,0.0,0.0,0.0,...,0.0
  book,0.589,0.945,0.567,...,0.0
  `
- **Rows:** ~5,000+ individual frames (1 row per frame extracted from all videos)
- **Columns:**
  - label = gesture name (47 classes)
  - f0-f83 = 84 coordinates representing:
    - Hand 1: 21 landmarks × 2 coords (x,y) = 42 values
    - Hand 2: 21 landmarks × 2 coords (x,y) = 42 values
    - Padding: 0.0 for frames with < 2 hands detected

### 1.4 Data Generation Pipeline
1. **preprocess_video.py** → Extracts frames using frame_start/frame_end from JSON
2. **landmark_extractor.py** → MediaPipe Hands on each frame, saves CSV
3. **Data Format:**
   - One row = one video frame
   - No temporal grouping (each frame is independent)
   - Frames with all zeros are cleaned before training

---

## 2. Current Training Pipeline

### 2.1 Model Architecture
**File:** builder/train_model.py

Model = Sequential([
  Input(shape=(84,)),
  Dense(256, activation='relu'),
  Dropout(0.3),
  Dense(128, activation='relu'),
  Dropout(0.2),
  Dense(47, activation='softmax')
])

Optimizer: Adam
Loss: sparse_categorical_crossentropy
Epochs: 120 (with early stopping, patience=15)
Batch: 32

### 2.2 Data Split
Train:     64%
Validation: 16%
Test:      20%

### 2.3 Current Performance Metrics
`
Training Accuracy:   86.83%
Validation Accuracy: 74.33%  ← Overfitting observed
Test Accuracy:       83.47%
Precision (weighted): 85.56%
Recall (weighted):   83.47%
F1-score (weighted): 83.15%
`

### 2.4 Weak Performing Classes
- book (0.64) — Similar to reading/writing poses
- child (0.55) — Small hand in frame
- hospital (0.67) — Similar to medical signs
- woman (0.29) — Only 3 samples
- walk (0.33) — Only 4 samples in test set
- safe (0.50) — Only 3 samples
- friend (0.62) — Hand position ambiguity

---

## 3. TFLite Export & Mobile Deployment

### 3.1 Export Process
**File:** builder/export_tflite.py

- Keras Model: output/signbridge_model.keras (~500 KB)
- TFLite Model: output/signbridge_model.tflite (~120 KB, quantized)
- Labels: output/labels.txt (47 gesture names, alphabetical order)

### 3.2 Input/Output Specification
- **Input Shape:** [1, 84] (batch_size=1, 84 coordinates)
- **Output Shape:** [1, 47] (batch_size=1, 47 gesture logits)
- **Data Type:** Float32
- **Quantization:** INT8

---

## 4. Label Mapping (47 Classes)

**File:** output/labels.txt - Alphabetically sorted

baby, book, boy, bread, bus, car, child, come, computer, danger, doctor, drink, eat, father, fire, food, friend, girl, go, hello, help, home, hospital, man, medicine, money, mother, no, phone, please, police, run, safe, school, shop, sit, sleep, sorry, stand, stop, student, teacher, walk, water, woman, work, yes

---

## 5. Flutter Integration Status

### Current State:
✅ Model loaded: assets/models/gesture_model.tflite  
✅ Labels loaded: assets/labels/gesture_labels.txt  
✅ Interpreter shape verified: [1, 84] input, [1, 47] output  
✅ No-hand detection implemented  
✅ Clean label names without gesture. prefix  
✅ Emoji mapping for all 47 labels  

### Current Limitation:
⚠️ **Single-frame inference only** — No temporal context

---

## 6. High-ROI Improvements for Research Quality

### Phase 1: Wrist-Centering Normalization (Day 1)
**Goal:** Make model robust to hand position in frame

**Kotlin Implementation (HandLandmarkerHelper.kt):**
- After MediaPipe detection
- Center all 21 landmarks on wrist (landmark index 0)
- Subtract wristX from all x coordinates
- Subtract wristY from all y coordinates
- Expected Gain: +10% accuracy

### Phase 2: Temporal GRU Model (Day 2-3)
**Goal:** Add sequence memory (15 frames ≈ 1.5 seconds)

**Architecture:**
- Input: [15, 84] (15 frames × 84 coords)
- GRU(128) → Dense(47, softmax)
- Group landmarks into rolling windows
- Add ±1% random jitter for augmentation
- Expected Gain: +20% accuracy

### Phase 3: H.264 WebRTC Optimization (Day 4)
**Goal:** Force hardware H.264 decoding

**Benefit:** Stops lag after 30 seconds on Huawei device

### Phase 4: GIF Asset Integration (Day 5)
**Architecture:** Map int index to assets/gifs/name.gif paths

---

## 7. Dataset Expansion Strategy

### Current Problem:
- One recording per word = severe overfitting
- Model memorizes pixel coordinates, not sign shape

### Solution:
Record **30-50 samples per word** using 3 long videos per word:
- Video 1: Normal speed, center frame
- Video 2: Slow speed, left/right positions
- Video 3: Fast speed, upward/downward movements

**Expected Result:**
- Current: ~100-150 samples per word (low)
- Target: 1500-2000 samples (realistic)

---

## 8. Implementation Roadmap

| Day | Task | Effort | Impact |
|-----|------|--------|--------|
| 1 | Wrist normalization (Kotlin) | Low | High (+10%) |
| 2-3 | GRU temporal model (Python) | Medium | High (+20%) |
| 4 | H.264 WebRTC (Dart) | Low | High |
| 5 | GIF integration (Dart) | Low | Medium |
| 6 | Dataset collection (optional) | High | High (+15-20%) |
| 7 | Metrics & documentation | Low | High |

---

## 9. Key Files for Gemini

### Must Read:
1. builder/landmark_extractor.py — 84 float extraction
2. builder/train_model.py — Current Dense baseline
3. builder/export_tflite.py — TFLite export process
4. output/labels.txt — 47 gesture names in order

### To Modify:
1. builder/train_model.py → GRU architecture
2. HandLandmarkerHelper.kt → Wrist centering

---

## 10. Gemini Prompt

You are implementing temporal gesture recognition.

CURRENT STATE:
- Dataset: landmarks.csv with 5000+ frames
- Model: Dense(256) → Dense(128) → Dense(47)
- Input: [1, 84] (single frame)
- Accuracy: 83.47%

TARGET:
- Model: GRU-based temporal
- Input: [1, 15, 84] (15 frames)
- Expected accuracy: >88%

REQUIREMENTS:
1. Preserve existing dataset
2. Group frames into 15-frame rolling windows
3. Add ±1% random jitter (data augmentation)
4. Implement GRU optimized for TFLite
5. Export with quantization
6. Keep labels.txt unchanged

DELIVERABLE:
Modified builder/train_model_temporal.py

---

## 11. Critical Notes

1. Do NOT regenerate landmarks — existing CSV works
2. Do NOT change labels.txt order — alphabetical
3. Do NOT modify MediaPipe config — 21 landmarks, 2 hands
4. Do preserve label names exactly
5. Model file size target: < 200 KB

---

**Status:** Analysis Complete - Ready for Gemini Implementation

