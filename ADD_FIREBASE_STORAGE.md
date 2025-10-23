# Add Firebase Storage to MessageAI Project

## Problem
The `import FirebaseStorage` fails because FirebaseStorage is not added to the Xcode project's dependencies.

## Solution: Add via Xcode (Recommended - 2 minutes)

### Steps:
1. **Open the project in Xcode:**
   ```bash
   open /Users/momenmush/Downloads/MessageAI/MessageAI.xcodeproj
   ```

2. **Select the project in the navigator** (top-most "MessageAI" item)

3. **Select the "MessageAI" target** (not the project, the target under TARGETS)

4. **Go to "Frameworks, Libraries, and Embedded Content" section**

5. **Click the "+" button** at the bottom

6. **In the search box, type:** `FirebaseStorage`

7. **Select "FirebaseStorage"** from the list

8. **Click "Add"**

9. **Build the project** (⌘B)

## Verification

After adding, the build should succeed. Verify by running:
```bash
xcodebuild -scheme MessageAI -sdk iphonesimulator build
```

You should see `BUILD SUCCEEDED` instead of the "Unable to find module dependency" error.

## What This Enables

Once FirebaseStorage is added, the following will work:
- ✅ Image uploads to Firebase Storage
- ✅ Thumbnail generation and upload
- ✅ Download URL retrieval
- ✅ Progress tracking during upload
- ✅ All Phase 3 media features

## Alternative: Command Line (Advanced)

If you prefer command-line, I can help modify the project.pbxproj file directly, but this is more error-prone. The Xcode GUI method above is recommended.

## Next Steps After Adding

Once Firebase Storage is added and the build succeeds:
1. I'll implement `sendImageMessage()` in ChatService
2. Add photo picker UI to ConversationDetailView
3. Create ImageMessageView component for display
4. Add full-screen image viewer with zoom
5. Implement "Save to Photos" feature
6. Test end-to-end image messaging flow

## Current Status

- MediaService.swift: ✅ Ready (upload code uncommented)
- Firebase Storage dependency: ❌ Needs manual addition in Xcode
- Message model: ✅ Already has media fields
- Estimated time after adding: 2-3 hours to complete image messaging
