# Phase 13: Saved Contacts & Contact Support Testing Guide

**Last Updated:** June 8, 2026

This guide documents the implementation changes completed in **Phase 13** and outlines a step-by-step workflow to verify and test WebRTC video calling between two real physical devices using the newly created **Saved Contacts** directory.

---

## 🛠️ 1. Tracking Implementation Changes

We completed the following integrations to enhance call reliability and contact management:

| Component | File Path | Change Description |
|---|---|---|
| **Data Model** | `lib/data/models/contact.dart` | Created `Contact` model supporting `id` (peer shortId), `name`, and `userRole`. Generated Hive adapters. |
| **Database** | `lib/data/local/hive_db.dart` | Registered `ContactAdapter` and opened the `saved_contacts` box for local persistence. |
| **Repository** | `lib/data/repositories/contacts_repository.dart` | Built CRUD services (`save`, `getAll`, `delete`) with automatic alphabetical sorting. |
| **Signaling** | `lib/services/webrtc/signaling_service.dart` | Updated `createCall()` to use the caller's unique User ID (`selfId`) as the Firestore room ID, eliminating random codes. Added a candidate auto-purger that clears out old WebRTC session ICE tokens on room creation. |
| **Speech STT** | `lib/services/ai/speech_service.dart` | Resolved plugin deprecations by wrapping speech listen parameters in `SpeechListenOptions`. |
| **Dashboard UI** | `lib/ui/screens/home_screen.dart` | Added the Neumorphic "Saved Contacts" entry point card. |
| **Settings UI** | `lib/ui/screens/settings_screen.dart` | Integrated a localized "Contact Support" list tile pointing to `futurekelly360@gmail.com` using `url_launcher`. Cleaned up deprecated `activeColor` layout parameters. |
| **Contacts UI** | `lib/ui/screens/contacts_screen.dart` | Built a responsive list of saved peers featuring search, dropdown role selections, delete prompts, and a bottom sheet launcher. |
| **Routes** | `lib/core/routes.dart` | Registered `/contacts` route pointing to `ContactsScreen()`. |

---

## 📱 2. Step-by-Step Guide: Testing on Two Physical Devices

Since the room signaling now utilizes static User IDs, you no longer need to copy, paste, or manually share random call tokens. Testing on two devices (Device A and Device B) is straightforward:

### Step 1: Install and Launch the App
1. Connect both physical devices to your development computer.
2. Build and run the application on both devices in debug or release mode:
   ```bash
   flutter run -d <device_a_id>
   flutter run -d <device_b_id>
   ```

### Step 2: Retrieve User IDs
* On the home dashboard of **Device A**, view your profile header or click copy next to **Your ID:** (e.g. `MsrrVJoh...`).
* Repeat the same on **Device B** to view/copy its User ID.

### Step 3: Save Each Other as Contacts
1. On **Device A**:
   - Tap **Saved Contacts** from the home screen options.
   - Click **Add Contact** (Floating Action Button).
   - Enter **Device B**'s Name and paste **Device B**'s User ID. Set their communication role and click **Save**.
2. On **Device B**:
   - Go to **Saved Contacts** -> **Add Contact**.
   - Enter **Device A**'s Name and paste **Device A**'s User ID, then select **Save**.

### Step 4: Host the Call (Caller)
* On **Device A**: Tap **Create Call** on the Home screen.
* Device A will create a room inside Firestore under its own User ID (e.g. `calls/MsrrVJoh...`), initialize its local camera feed, and display the *"Waiting for peer..."* overlay.

### Step 5: Join the Call (Callee)
* On **Device B**:
   - Tap **Saved Contacts** on the Home screen.
   - Tap on **Device A**'s contact card in the list.
   - Select **Join Call** from the popup bottom options sheet.
* Device B will automatically look up Device A's User ID (which is saved in B's contacts) and join the Firestore document matching that ID.

### Step 6: Connect and Talk
* Firestore will detect the join action and bridge the WebRTC SDP offer/answer exchange.
* Both cameras will connect, and you will see each other's live streams. You can toggle audio mute, switch cameras, and read captions in real time!

---

## 📄 3. Verification & Security Note
* **Secret Protection:** The Firebase `google-services.json` file is ignored in git to ensure credentials remain secure, but it is kept locally so that your devices connect to Firestore properly.
* **Analyzer Check:** Running `flutter analyze` compiles with **0 lints or warnings** across all updated screens.
