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

## Setup Status

✅ **COMPLETED** - Info.plist has been properly configured and integrated into the Xcode project.

The `Info.plist` file is located at the project root and is automatically included in builds. No manual setup required!

## Testing Privacy Permissions

When you run the app and try to:
- **Record a voice message** → Microphone permission alert will appear
- **Take a photo** → Camera permission alert will appear
- **Select a photo/video** → Photo library permission alert will appear

The app will no longer crash when accessing these features!

## Troubleshooting

**Permission alert doesn't appear:**
1. Delete the app from simulator/device and reinstall
2. Reset simulator permissions: Device → Erase All Content and Settings
3. Check Privacy settings in simulator: Settings → Privacy & Security

**Need to verify Info.plist is included:**
```bash
# Check the built app's Info.plist
plutil -p ~/Library/Developer/Xcode/DerivedData/MessageAI*/Build/Products/Debug-iphonesimulator/MessageAI.app/Info.plist | grep Usage
```
