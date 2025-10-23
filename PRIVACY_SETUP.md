# Privacy Permissions Setup

## Required Privacy Descriptions

The app requires the following privacy permissions for its features to work correctly:

### 1. Microphone Access (Voice Messages)
- **Key**: `NSMicrophoneUsageDescription`
- **Description**: "MessageAI needs access to your microphone to record and send voice messages to your contacts."
- **Used in**: Voice message recording feature (Phase 8.2)

### 2. Camera Access (Photo/Video Capture)
- **Key**: `NSCameraUsageDescription`
- **Description**: "MessageAI needs access to your camera to take photos and videos to share with your contacts."
- **Used in**: Camera capture for media messages

### 3. Photo Library Access (Media Selection)
- **Key**: `NSPhotoLibraryUsageDescription`
- **Description**: "MessageAI needs access to your photo library to select photos and videos to share with your contacts."
- **Used in**: Photo picker for images and videos (Phase 3)

### 4. Photo Library Add (Save Media)
- **Key**: `NSPhotoLibraryAddUsageDescription`
- **Description**: "MessageAI needs permission to save photos and videos to your photo library."
- **Used in**: Saving received media to photo library

## How to Add to Xcode Project

### Option 1: Using Info.plist file (Recommended)
1. The `Info.plist` file has been created in `MessageAI/Info.plist`
2. Add it to the Xcode project:
   - Open Xcode
   - Right-click on the "MessageAI" folder in Project Navigator
   - Select "Add Files to MessageAI..."
   - Select `Info.plist`
   - Make sure "Copy items if needed" is checked
   - Make sure "MessageAI" target is selected
   - Click "Add"

### Option 2: Using Target Settings (Alternative)
1. Open the Xcode project
2. Select the "MessageAI" target
3. Go to the "Info" tab
4. Click the "+" button under "Custom iOS Target Properties"
5. Add each of the following keys with their descriptions:
   - Privacy - Microphone Usage Description
   - Privacy - Camera Usage Description
   - Privacy - Photo Library Usage Description
   - Privacy - Photo Library Additions Usage Description

## Testing Privacy Permissions

After adding the privacy descriptions:

1. Clean build folder (Cmd + Shift + K)
2. Rebuild the project (Cmd + B)
3. Delete the app from the simulator/device
4. Reinstall and run the app
5. When you try to:
   - Record a voice message → Microphone permission alert should appear
   - Take a photo → Camera permission alert should appear
   - Select a photo/video → Photo library permission alert should appear

## Current Status

✅ Privacy descriptions created in `Info.plist`
⚠️ Need to add `Info.plist` to Xcode project (see instructions above)

## Troubleshooting

**App still crashes after adding Info.plist:**
1. Make sure Info.plist is in the "Copy Bundle Resources" build phase
2. Clean build folder and delete derived data
3. Delete app from simulator and reinstall

**Permission alert doesn't appear:**
1. Check that the correct key names are used
2. Verify the Info.plist is correctly formatted XML
3. Reset simulator (Device → Erase All Content and Settings)
