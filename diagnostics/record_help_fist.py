# record_help_fist.py — record NEW samples of the user's actual `help` handshape.
#
# Why a separate script instead of python_scripts/record_landmarks.py:
#   * that script caps every class at TARGET_SAMPLES=500, and keypoint.csv already holds
#     exactly 500 per class, so it REFUSES to record more `help`;
#   * it appends into keypoint.csv directly, but we want to build the replacement dataset
#     deliberately (replace vs supplement the old `help` rows is a decision to test, not
#     to bake in while recording);
#   * it records one row per key press, which is easy to get wrong and hard to see.
#
# WHY CAPTURE IS DRIVEN FROM THE TERMINAL, NOT THE CAMERA WINDOW:
#   Two earlier attempts produced no data. The first lost every SPACE press (OpenCV's
#   Windows highgui backend swallows the spacebar); the second lost every key including
#   ones that had worked before, which points at the camera window never holding focus.
#   Reading commands from stdin in a background thread sidesteps the whole class of
#   problem: terminal input cannot be intercepted by a window manager. Keys still work in
#   the video window as a convenience, but they are no longer the only way in.
#
#   Every accepted sample is also appended to its CSV IMMEDIATELY, not at quit, so a crash
#   or a closed window can no longer discard a session's work.
#
# normalize_landmarks() below is copied VERBATIM from python_scripts/record_landmarks.py.
# Do not "tidy" it: the three steps (wrist-centre, mirror-left, scale by max|value|) are
# the contract the model is trained under, and any drift here silently produces data the
# app cannot match.
#
# Type in THIS terminal, pressing Enter after each:
#   (just Enter) or 'h'  -> capture a `help` sample   <-- the main one
#   'y'                  -> capture a `yes`  sample   (validation only, not trained on)
#   'c'                  -> discard this session's help samples so far
#   'q'                  -> quit
#
# Aim for ~200 help samples, varying hand distance, in-plane rotation and tilt between
# captures. A model trained on one frozen pose generalises no better than the old data did.

import csv
import os
import sys
import threading
import traceback

import cv2
import mediapipe as mp
import numpy as np

OUT_DIR = os.path.dirname(os.path.abspath(__file__))
HELP_CSV = os.path.join(OUT_DIR, "help_fist_new.csv")
YES_CSV = os.path.join(OUT_DIR, "yes_validation_new.csv")

# Mean absolute per-coordinate change required before a new sample is accepted. Consecutive
# frames of a held pose differ by ~0.003, so 0.012 forces a deliberate move/tilt between
# captures instead of banking sensor noise as if it were data.
MIN_CHANGE = 0.012

mp_hands = mp.solutions.hands
hands = mp_hands.Hands(
    static_image_mode=False,
    max_num_hands=1,
    min_detection_confidence=0.7,
    min_tracking_confidence=0.5,
)
mp_draw = mp.solutions.drawing_utils

# Written by the stdin thread, read by the render loop.
PENDING = {"help": 0, "yes": 0, "clear": 0}
STOP = threading.Event()


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


def stdin_reader():
    """Read capture commands from the terminal. Runs until 'q' or EOF."""
    while not STOP.is_set():
        try:
            line = sys.stdin.readline()
        except Exception:
            return
        if line == "":  # EOF / stdin closed
            print("\n[stdin closed — use the video window keys, or press 'q' there]")
            return
        cmd = line.strip().lower()
        if cmd in ("", "h", "help"):
            PENDING["help"] += 1
        elif cmd in ("y", "yes"):
            PENDING["yes"] += 1
        elif cmd in ("c", "clear"):
            PENDING["clear"] += 1
        elif cmd in ("q", "quit", "exit"):
            STOP.set()
            return


def append_row(path, label, values):
    """Append one sample and flush, so nothing is lost if we die immediately after."""
    with open(path, "a", newline="") as f:
        csv.writer(f).writerow([label] + values)


def main():
    print("=== SignBridge: 'help' re-recording ===")
    print(f"python: {sys.version.split()[0]}   cv2: {cv2.__version__}")
    print(f"stdin is a terminal: {sys.stdin.isatty()}")
    print(f"writing to: {OUT_DIR}")

    cap = cv2.VideoCapture(0)
    if not cap.isOpened():
        print("\nERROR: could not open camera 0.")
        print("If this laptop has more than one camera, try index 1:")
        print('  change cv2.VideoCapture(0) to cv2.VideoCapture(1)')
        return

    ok, probe = cap.read()
    print(f"camera opened: {ok}   frame size: {None if not ok else (probe.shape[1], probe.shape[0])}\n")

    if not sys.stdin.isatty():
        print("WARNING: stdin is not a terminal, so terminal capture is unavailable.")
        print("Run this script directly in a normal terminal window.\n")

    reader = threading.Thread(target=stdin_reader, daemon=True)
    reader.start()

    print("--- READY ---")
    print("Type in THIS terminal and press Enter:")
    print("   Enter  or  h  -> capture `help`   (main)")
    print("   y             -> capture `yes`    (validation only)")
    print("   c             -> clear this session's help samples")
    print("   q             -> quit\n")

    help_rows, yes_rows = [], []
    last_saved = "waiting for input..."

    try:
        while not STOP.is_set():
            ret, frame = cap.read()
            if not ret:
                print("ERROR: camera stopped returning frames.")
                break

            frame = cv2.flip(frame, 1)  # same as the original recorder
            h, w, _ = frame.shape

            rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            results = hands.process(rgb)

            normalized_coords, hand_type = None, "Unknown"
            if results.multi_hand_landmarks and results.multi_handedness:
                for hand_landmarks, handedness in zip(
                    results.multi_hand_landmarks, results.multi_handedness
                ):
                    mp_draw.draw_landmarks(frame, hand_landmarks, mp_hands.HAND_CONNECTIONS)
                    hand_type = handedness.classification[0].label
                    normalized_coords = normalize_landmarks(
                        hand_landmarks.landmark, is_left=(hand_type == "Left")
                    )

            # ── OpenCV-window keys (convenience; terminal is the reliable path) ──
            key = cv2.waitKey(1) & 0xFF
            if key in (ord("q"), 27):
                STOP.set()
                break
            elif key in (ord("h"), ord(" ")):
                PENDING["help"] += 1
            elif key == ord("y"):
                PENDING["yes"] += 1
            elif key == ord("c"):
                PENDING["clear"] += 1

            # ── Handle clear ──
            if PENDING["clear"]:
                PENDING["clear"] = 0
                print(f"  cleared {len(help_rows)} in-session help samples "
                      f"(CSV rows already written are kept)")
                help_rows = []

            # ── Handle captures ──
            for kind, rows, path, label in (
                ("help", help_rows, HELP_CSV, 3),
                ("yes", yes_rows, YES_CSV, 1),
            ):
                while PENDING[kind] > 0:
                    PENDING[kind] -= 1
                    if normalized_coords is None:
                        last_saved = f"{kind}: NO HAND DETECTED - not saved"
                        print(f"  {kind}: no hand detected - not saved")
                    elif rows and float(
                        np.mean(np.abs(np.array(rows[-1]) - np.array(normalized_coords)))
                    ) < MIN_CHANGE:
                        last_saved = f"{kind}: too similar - move/tilt your hand"
                        print(f"  {kind}: too similar to last - move/tilt your hand")
                    else:
                        rows.append(normalized_coords)
                        append_row(path, label, normalized_coords)
                        last_saved = f"saved {kind} #{len(rows)} ({hand_type})"
                        print(f"  saved {kind} #{len(rows):>3} ({hand_type})")

            # ── HUD ──
            detected = results.multi_hand_landmarks is not None
            cv2.putText(frame,
                        f"STATUS: {'HAND DETECTED (' + hand_type + ')' if detected else 'NO HAND'}",
                        (15, 35), cv2.FONT_HERSHEY_SIMPLEX, 0.6,
                        (0, 255, 0) if detected else (0, 0, 255), 2, cv2.LINE_AA)
            cv2.putText(frame, f"help: {len(help_rows)}   yes: {len(yes_rows)}",
                        (15, 70), cv2.FONT_HERSHEY_SIMPLEX, 0.8, (0, 255, 255), 2, cv2.LINE_AA)
            cv2.putText(frame, "type in terminal: Enter/h=help  y=yes  c=clear  q=quit",
                        (15, h - 20), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 255, 255), 1, cv2.LINE_AA)
            if last_saved:
                cv2.putText(frame, last_saved, (15, 105), cv2.FONT_HERSHEY_SIMPLEX,
                            0.55, (255, 255, 0), 1, cv2.LINE_AA)

            cv2.imshow("SignBridge - help re-record", frame)

    except Exception:
        print("\nCRASHED — full traceback follows:")
        traceback.print_exc()
    finally:
        cap.release()
        cv2.destroyAllWindows()
        print(f"\nsession: {len(help_rows)} help, {len(yes_rows)} yes "
              f"(help rows are already saved to {HELP_CSV})")


if __name__ == "__main__":
    main()
