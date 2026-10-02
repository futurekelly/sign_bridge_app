# record_help_auto.py — record `help` samples with NO keyboard input at all.
#
# Three earlier attempts to record `help` produced zero samples. The first lost every
# SPACE press (OpenCV's Windows highgui backend swallows the spacebar); the terminal-driven
# version then wasn't the one being run. Rather than debug an input path a fourth time,
# this script has no input path: no keypresses, no window focus, nothing to get wrong.
#
# It counts down, records for DURATION seconds, and exits on its own. You just hold your
# help sign and keep moving it. Every accepted sample is appended to the CSV the moment it
# is captured, so even Ctrl+C keeps whatever was collected.
#
# Usage:
#   python record_help_auto.py            # 90 second session
#   python record_help_auto.py 150        # 150 second session
#
# While recording, KEEP MOVING: rotate the wrist, tilt the hand, change distance from the
# camera. A sample is only accepted once the pose has changed enough from the previous one
# (see MIN_CHANGE), so a frozen hand records one sample and then nothing. That is
# deliberate -- the old `help` data was a single frozen pose, which is exactly why it
# failed to recognise the same sign made differently.
#
# normalize_landmarks() is copied VERBATIM from python_scripts/record_landmarks.py. Do not
# "tidy" it: wrist-centre, mirror-left, scale-by-max are the contract the model was trained
# under, and any drift here silently produces data the app cannot match.

import csv
import os
import sys
import time

import cv2
import mediapipe as mp
import numpy as np

OUT_DIR = os.path.dirname(os.path.abspath(__file__))
HELP_CSV = os.path.join(OUT_DIR, "help_fist_new.csv")

DURATION = int(sys.argv[1]) if len(sys.argv) > 1 else 90  # seconds
COUNTDOWN = 5
MIN_CHANGE = 0.012      # mean abs per-coordinate change required between accepted samples
MIN_INTERVAL = 0.15     # never accept samples faster than this (seconds)
HELP_LABEL = 3

mp_hands = mp.solutions.hands
hands = mp_hands.Hands(
    static_image_mode=False,
    max_num_hands=1,
    min_detection_confidence=0.7,
    min_tracking_confidence=0.5,
)
mp_draw = mp.solutions.drawing_utils


def normalize_landmarks(landmarks, is_left=False):
    """Copied verbatim from record_landmarks.py — see header note."""
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


def open_camera():
    """Try camera 0, then 1 — some laptops expose an IR/virtual camera first."""
    for index in (0, 1):
        cap = cv2.VideoCapture(index)
        if cap.isOpened():
            ok, probe = cap.read()
            if ok:
                print(f"camera {index} opened, frame {probe.shape[1]}x{probe.shape[0]}")
                return cap
            cap.release()
        print(f"camera {index} unavailable")
    return None


def main():
    print("=== SignBridge: automatic 'help' recorder ===")
    print(f"python {sys.version.split()[0]}   cv2 {cv2.__version__}   mediapipe {mp.__version__}")
    print(f"will append to: {HELP_CSV}\n")

    cap = open_camera()
    if cap is None:
        print("\nERROR: no camera could be opened.")
        print("Close any other app using the webcam (Teams/Zoom/Camera) and retry.")
        return

    print("\nSign HELP: a closed fist with the thumb WRAPPED across the fingers.")
    print(f"Recording starts in {COUNTDOWN} seconds and runs for {DURATION} seconds.")
    print("KEEP MOVING the whole time - rotate, tilt, change distance.\n")
    for i in range(COUNTDOWN, 0, -1):
        print(f"  {i}...", flush=True)
        time.sleep(1)

    print("\n>>> RECORDING <<<\n")

    saved = 0
    last_accepted = None
    last_capture_at = 0.0
    start = time.time()

    try:
        while True:
            elapsed = time.time() - start
            if elapsed >= DURATION:
                break

            ret, frame = cap.read()
            if not ret:
                print("ERROR: camera stopped returning frames.")
                break

            frame = cv2.flip(frame, 1)
            h, w, _ = frame.shape
            rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            results = hands.process(rgb)

            coords, hand_type = None, "Unknown"
            if results.multi_hand_landmarks and results.multi_handedness:
                for hand_landmarks, handedness in zip(
                    results.multi_hand_landmarks, results.multi_handedness
                ):
                    mp_draw.draw_landmarks(frame, hand_landmarks, mp_hands.HAND_CONNECTIONS)
                    hand_type = handedness.classification[0].label
                    coords = normalize_landmarks(
                        hand_landmarks.landmark, is_left=(hand_type == "Left")
                    )

            now = time.time()
            if (
                coords is not None
                and now - last_capture_at >= MIN_INTERVAL
                and (
                    last_accepted is None
                    or float(np.mean(np.abs(np.array(last_accepted) - np.array(coords))))
                    >= MIN_CHANGE
                )
            ):
                with open(HELP_CSV, "a", newline="") as f:
                    csv.writer(f).writerow([HELP_LABEL] + coords)
                saved += 1
                last_accepted = coords
                last_capture_at = now
                print(f"  saved help #{saved:>3} ({hand_type})", flush=True)

            remaining = max(0.0, DURATION - elapsed)
            cv2.putText(frame, f"RECORDING  {remaining:4.0f}s left   saved: {saved}",
                        (15, 35), cv2.FONT_HERSHEY_SIMPLEX, 0.8, (0, 0, 255), 2, cv2.LINE_AA)
            cv2.putText(frame,
                        f"HAND: {hand_type}" if coords is not None else "NO HAND DETECTED",
                        (15, 70), cv2.FONT_HERSHEY_SIMPLEX, 0.7,
                        (0, 255, 0) if coords is not None else (0, 0, 255), 2, cv2.LINE_AA)
            cv2.putText(frame, "keep moving/rotating your hand", (15, h - 20),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 255, 255), 1, cv2.LINE_AA)
            cv2.imshow("SignBridge - auto help recorder", frame)
            cv2.waitKey(1)

    except KeyboardInterrupt:
        print("\ninterrupted by user")
    finally:
        cap.release()
        cv2.destroyAllWindows()

    print(f"\nDONE - {saved} samples this session, appended to:\n  {HELP_CSV}")
    if saved < 60:
        print("That is low. Re-run and keep the hand moving more; frozen poses are skipped.")


if __name__ == "__main__":
    main()
