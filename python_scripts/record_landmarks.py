# record_landmarks.py — custom keypoint dataset recorder using laptop webcam.
# Extracts 21 2D hand landmarks from MediaPipe and saves normalized keypoints to keypoint.csv.
# Features progress tracking towards 500 samples per class and automatic balancing caps.
#
# Keyboard Controls:
# - Press '0' to record 'hello' samples
# - Press '1' to record 'yes' samples
# - Press '2' to record 'no' samples
# - Press '3' to record 'help' samples
# - Press '4' to record 'thank_you' samples
# - Press 'q' to quit

import cv2
import mediapipe as mp
import csv
import numpy as np
import os

# Configuration
CSV_PATH = "keypoint.csv"
TARGET_SAMPLES = 500
CLASSES = ["hello", "yes", "no", "help", "thank_you"]

# Initialize MediaPipe Hands
mp_hands = mp.solutions.hands
hands = mp_hands.Hands(
    static_image_mode=False,
    max_num_hands=1,
    min_detection_confidence=0.7,
    min_tracking_confidence=0.5
)
mp_draw = mp.solutions.drawing_utils

# Normalized Coordinates Function (translation and scale invariance)
def normalize_landmarks(landmarks, is_left=False):
    # Convert landmarks to numpy array
    temp_landmarks = []
    for lm in landmarks:
        temp_landmarks.append([lm.x, lm.y])
    
    temp_landmarks = np.array(temp_landmarks)
    
    # 1. Translate relative to wrist (landmark 0)
    base_x, base_y = temp_landmarks[0]
    temp_landmarks = temp_landmarks - [base_x, base_y]
    
    # 2. Left-hand horizontal flip trick (mirror x to look like right hand)
    if is_left:
        temp_landmarks[:, 0] = temp_landmarks[:, 0] * -1.0
    
    # 3. Scale landmarks
    max_val = np.max(np.abs(temp_landmarks))
    if max_val != 0:
        temp_landmarks = temp_landmarks / max_val
        
    # 4. Flatten to 1D array of 42 parameters
    return temp_landmarks.flatten().tolist()

def draw_progress_bar(val, max_val, bar_length=15):
    percent = float(val) / max_val
    arrow = '#' * int(round(percent * bar_length) - 1) + '>'
    spaces = ' ' * (bar_length - len(arrow))
    return f"[{arrow[:bar_length]}{spaces[:bar_length]}]"

def main():
    cap = cv2.VideoCapture(0)
    if not cap.isOpened():
        print("Error: Could not open camera.")
        return

    # Counts for feedback
    counts = {i: 0 for i in range(len(CLASSES))}
    
    # Read existing CSV to load counters
    if os.path.exists(CSV_PATH):
        with open(CSV_PATH, 'r') as f:
            reader = csv.reader(f)
            for row in reader:
                if row:
                    cls_id = int(row[0])
                    if cls_id in counts:
                        counts[cls_id] += 1

    print("\n--- Keypoint Recording System Initialized ---")
    print(f"Target: {TARGET_SAMPLES} balanced samples per class.")
    print("Press 0-4 matching the classes below to record.")
    print("Press 'q' to exit.\n")

    while cap.isOpened():
        ret, frame = cap.read()
        if not ret:
            break
            
        frame = cv2.flip(frame, 1) # Flip horizontally for natural mirror feel
        h, w, c = frame.shape
        
        # Process frame with MediaPipe
        rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        results = hands.process(rgb)
        
        normalized_coords = None
        hand_type = "Unknown"
        
        if results.multi_hand_landmarks and results.multi_handedness:
            for hand_landmarks, handedness in zip(results.multi_hand_landmarks, results.multi_handedness):
                # Draw landmarks on screen
                mp_draw.draw_landmarks(frame, hand_landmarks, mp_hands.HAND_CONNECTIONS)
                
                # Detect handedness label
                hand_type = handedness.classification[0].label
                is_left = (hand_type == "Left")
                
                # Extract and normalize coordinates (mirroring Left hand to look like Right)
                normalized_coords = normalize_landmarks(hand_landmarks.landmark, is_left=is_left)
        
        # Check keyboard inputs
        key = cv2.waitKey(1) & 0xFF
        recording_active = False
        active_class_id = -1
        
        if key == ord('q'):
            break
        elif ord('0') <= key <= ord('4'):
            cls_id = key - ord('0')
            active_class_id = cls_id
            
            if counts[cls_id] >= TARGET_SAMPLES:
                print(f"Auto-Balanced Cap Reached: '{CLASSES[cls_id]}' already has {TARGET_SAMPLES} samples.")
            elif normalized_coords is not None:
                recording_active = True
                # Append to CSV
                with open(CSV_PATH, 'a', newline='') as f:
                    writer = csv.writer(f)
                    writer.writerow([cls_id] + normalized_coords)
                counts[cls_id] += 1
                print(f"Recorded '{CLASSES[cls_id]}' ({hand_type}) -> {counts[cls_id]}/{TARGET_SAMPLES}")
            else:
                print("Warning: No hand detected! Please align hand in frame.")

        # Overlay text display
        y_offset = 35
        for i, name in enumerate(CLASSES):
            is_active = (i == active_class_id)
            is_done = (counts[i] >= TARGET_SAMPLES)
            
            # Form progress string
            prog_bar = draw_progress_bar(counts[i], TARGET_SAMPLES)
            text = f"{i}: {name.upper():<10} {prog_bar} {counts[i]}/{TARGET_SAMPLES}"
            if is_done:
                text += " [BALANCED]"
                
            # Selection color highlights
            if is_done:
                color = (0, 200, 0) # Green for finished
            elif is_active and recording_active:
                color = (0, 0, 255) # Red for active recording
            elif is_active:
                color = (0, 255, 255) # Yellow for key press without hand
            else:
                color = (255, 255, 255) # White default
                
            cv2.putText(frame, text, (15, y_offset),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.5, color, 1, cv2.LINE_AA)
            y_offset += 25
            
        # Draw recording status banner
        if results.multi_hand_landmarks:
            status_text = f"HAND DETECTED ({hand_type})"
            status_color = (0, 255, 0)
        else:
            status_text = "NO HAND DETECTED"
            status_color = (0, 0, 255)
            
        cv2.putText(frame, f"STATUS: {status_text}", (15, y_offset + 10),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.55, status_color, 2, cv2.LINE_AA)
                    
        cv2.putText(frame, "Hold 0-4 to Record | 'q' to Quit", (15, h - 20),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 255, 255), 1, cv2.LINE_AA)
                    
        cv2.imshow("SignBridge Landmark Dataset Recorder", frame)

    cap.release()
    cv2.destroyAllWindows()
    print("\nRecording session terminated.")
    print("Final Counts:")
    for i, name in enumerate(CLASSES):
        print(f" - {name}: {counts[i]}/{TARGET_SAMPLES}")
    print(f"Dataset successfully compiled at: {os.path.abspath(CSV_PATH)}")

if __name__ == "__main__":
    main()
