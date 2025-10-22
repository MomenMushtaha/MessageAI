# WhatsApp Clone

A SwiftUI-based messaging app that replicates the core functionality of WhatsApp, built for iOS with modern Apple technologies.

## Features

- 💬 Real-time messaging with Firebase Firestore
- 🔐 Email/password authentication
- 🌐 Offline persistence and sync
- 📱 Native iOS design with SwiftUI
- 💾 Local data persistence with SwiftData
- 🔔 Push notifications (FCM)
- 👥 Group chat support
- ✓ Read receipts and online status
- 🎨 Message bubble UI similar to WhatsApp

## Technologies Used

- **SwiftUI** - Modern declarative UI framework
- **SwiftData** - Core Data successor for data persistence
- **Firebase Auth** - Email/password authentication
- **Firebase Firestore** - Real-time database with offline support
- **Firebase Cloud Messaging (FCM)** - Push notifications
- **iOS 17+** - Target platform

## Requirements

- iOS 17.0+
- Xcode 16.0+
- Swift 5.0+
- Firebase account

## Firebase Setup

Before running the app, you need to configure Firebase:

1. **Create a Firebase Project**
   - Go to [Firebase Console](https://console.firebase.google.com/)
   - Create a new project or use an existing one
   - Register your iOS app with bundle ID: `LAEF.whatsapp-clone`

2. **Download GoogleService-Info.plist**
   - In Firebase Console, download the `GoogleService-Info.plist` file
   - Add it to your Xcode project (already configured if present)

3. **Enable Firebase Services**
   - Enable **Authentication** → Email/Password provider
   - Enable **Firestore Database** → Start in test mode (update security rules later)
   - Enable **Cloud Messaging** for push notifications
   - (Optional) Enable **Cloud Functions** for advanced features

4. **Configure APNs (for Push Notifications)**
   - Generate APNs key in Apple Developer Console
   - Upload the APNs key to Firebase Console under Project Settings → Cloud Messaging

## Getting Started

1. Clone the repository
```bash
git clone https://github.com/your-username/whatsapp-clone.git
```

2. Open the project in Xcode
```bash
cd whatsapp-clone
open whatsapp-clone.xcodeproj
```

3. Wait for Swift Package Manager to resolve dependencies (Firebase SDK will be downloaded automatically)

4. Build and run the project on the iOS Simulator or your device

## Firebase Dependencies

The following Firebase packages are automatically installed via Swift Package Manager:

- **FirebaseAuth** - User authentication
- **FirebaseFirestore** - Real-time database (includes Codable/Swift support)
- **FirebaseMessaging** - Push notifications
- **FirebaseAnalytics** - Analytics tracking

All packages are configured for Firebase iOS SDK v11.15.0

### Firebase Configuration Status

✅ Firebase SDK installed via Swift Package Manager  
✅ Firebase initialized in app with offline persistence enabled  
✅ iOS deployment target set to iOS 17.0  
✅ GoogleService-Info.plist configured  
✅ Build verified successfully

## Project Structure

```
whatsapp-clone/
├── whatsapp_cloneApp.swift      # Main app entry point
├── MainAppView.swift            # Main app container
├── ContentView.swift            # Chat interface
├── MessageBubbleView.swift      # Message UI components
├── Message.swift                # Data model
├── WelcomeView.swift           # Onboarding screen
├── SettingsView.swift          # App settings
└── Tests/                      # Unit and UI tests
```

## Contributing

1. Fork the project
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License

This project is created for educational purposes. Please respect WhatsApp's intellectual property and use this as a learning resource.

## Author

Created by Momen Mush - October 2025