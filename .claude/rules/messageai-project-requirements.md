# MessageAI Project Requirements

## Project Overview
Building a Cross-Platform Messaging App with AI Features - A one-week sprint project combining production-quality messaging infrastructure with intelligent AI features tailored to specific user personas.

## Timeline & Deadlines
- **MVP**: Tuesday (24 hours)
- **Early Submission**: Friday (4 days)
- **Final**: Sunday (7 days)

---

## MVP Requirements (24 Hours - HARD GATE)

Must have ALL of the following:

### Core Messaging
- [ ] One-on-one chat functionality
- [ ] Real-time message delivery between 2+ users
- [ ] Message persistence (survives app restarts)
- [ ] Optimistic UI updates (messages appear instantly before server confirmation)
- [ ] Online/offline status indicators
- [ ] Message timestamps
- [ ] User authentication (users have accounts/profiles)

### Group Features
- [ ] Basic group chat functionality (3+ users in one conversation)
- [ ] Message read receipts
- [ ] Push notifications working (at least in foreground)

### Deployment
- [ ] Running on local emulator/simulator with deployed backend
- [ ] TestFlight/APK/Expo Go if possible (not required for MVP)

**CRITICAL**: The MVP is about proving messaging infrastructure is solid. A simple chat app with reliable message delivery is worth more than a feature-rich app with messages that don't sync reliably.

---

## Platform Requirements

Choose ONE of:
- Swift (iOS native) - SwiftUI or UIKit
- Kotlin (Android native) - Jetpack Compose or XML
- React Native with Expo - Must use Expo Go or custom dev client

---

## Core Messaging Infrastructure

### Essential Features
1. **One-on-One Chat**
   - Real-time message delivery
   - Messages persist locally
   - Text messages with timestamps
   - Read receipts
   - Online/offline presence indicators
   - Typing indicators
   - Message delivery states: sending, sent, delivered, read

2. **Media Support**
   - At minimum: send and receive images
   - Profile pictures and display names

3. **Group Chat**
   - Support 3+ users
   - Proper message attribution
   - Delivery tracking

### Real-Time Messaging Requirements
- Every message appears instantly for online recipients
- Messages queue when offline and send when connectivity returns
- Handle poor network conditions (3G, packet loss, intermittent connectivity)
- Optimistic UI updates
- Messages never get lost (even if app crashes mid-send)

### Testing Scenarios (Will Be Tested)
1. Two devices chatting in real-time
2. One device going offline, receiving messages, then coming back online
3. Messages sent while app is backgrounded
4. App force-quit and reopened to verify persistence
5. Poor network conditions (airplane mode, throttled connection)
6. Rapid-fire messages (20+ messages sent quickly)
7. Group chat with 3+ participants

---

## User Persona Selection

**MUST choose ONE persona** and build for their specific needs.

### Remote Team Professional
**Who**: Software engineers, designers, PMs in distributed teams

**Pain Points**:
- Drowning in threads
- Missing important messages
- Context switching
- Time zone coordination

**Required AI Features (ALL 5)**:
1. Thread summarization
2. Action item extraction
3. Smart search
4. Priority message detection
5. Decision tracking

**Advanced Features (Choose 1)**:
A) Multi-Step Agent: Plans team offsites, coordinates schedules autonomously
B) Proactive Assistant: Auto-suggests meeting times, detects scheduling needs

### International Communicator
**Who**: People with friends/family/colleagues speaking different languages

**Pain Points**:
- Language barriers
- Translation nuances
- Copy-paste overhead
- Learning difficulty

**Required AI Features (ALL 5)**:
1. Real-time translation (inline)
2. Language detection & auto-translate
3. Cultural context hints
4. Formality level adjustment
5. Slang/idiom explanations

**Advanced Features (Choose 1)**:
A) Context-Aware Smart Replies: Learns your style in multiple languages
B) Intelligent Processing: Extracts structured data from multilingual conversations

### Busy Parent/Caregiver
**Who**: Parents coordinating schedules, managing multiple responsibilities

**Pain Points**:
- Schedule juggling
- Missing dates/appointments
- Decision fatigue
- Information overload

**Required AI Features (ALL 5)**:
1. Smart calendar extraction
2. Decision summarization
3. Priority message highlighting
4. RSVP tracking
5. Deadline/reminder extraction

**Advanced Features (Choose 1)**:
A) Proactive Assistant: Detects scheduling conflicts, suggests solutions
B) Multi-Step Agent: Plans weekend activities based on family preferences

### Content Creator/Influencer
**Who**: YouTubers, TikTokers managing fan communication

**Pain Points**:
- Hundreds of DMs daily
- Repetitive questions
- Spam vs opportunities
- Maintaining authentic voice

**Required AI Features (ALL 5)**:
1. Auto-categorization (fan/business/spam/urgent)
2. Response drafting in creator's voice
3. FAQ auto-responder
4. Sentiment analysis
5. Collaboration opportunity scoring

**Advanced Features (Choose 1)**:
A) Context-Aware Smart Replies: Generates authentic replies matching personality
B) Multi-Step Agent: Handles daily DMs, auto-responds to FAQs, flags key messages

---

## AI Features Implementation

### Technical Requirements
- Built using LLMs (GPT-4 or Claude)
- Function calling/tool use
- RAG pipelines for conversation history
- Not about training ML models - leverage existing AI capabilities

### AI Architecture Options

**Option 1: AI Chat Interface**
- Dedicated AI assistant in special chat
- Users ask questions about conversations
- Request actions ("Translate my last message to Spanish")
- Get proactive suggestions

**Option 2: Contextual AI Features**
- Embedded directly in conversations
- Long-press message → translate/summarize/extract action
- Toolbar buttons for quick AI actions
- Inline suggestions as users type

**Option 3: Hybrid Approach**
- Both dedicated AI assistant AND contextual features

### AI Integration Requirements

**Recommended Agent Frameworks**:
- AI SDK by Vercel - streamlined agent development with tool calling
- OpenAI Agent SDK (Swarm) - lightweight multi-agent orchestration
- LangChain - comprehensive agent framework with extensive tools

**Agent Must Have**:
- Conversation history retrieval (RAG pipeline)
- User preference storage
- Function calling capabilities
- Memory/state management across interactions
- Error handling and recovery

---

## Technical Stack

### Recommended: The Golden Path - Firebase + Swift

**Backend**:
- Firebase Firestore - real-time database
- Firebase Cloud Functions - serverless backend for AI calls
- Firebase Auth - user authentication
- Firebase Cloud Messaging (FCM) - push notifications

**Mobile (iOS)**:
- Swift with SwiftUI
- SwiftData for local storage
- URLSession for networking
- Firebase SDK
- Deploy via TestFlight

**AI Integration**:
- OpenAI GPT-4 or Anthropic Claude (called from Cloud Functions)
- Function calling / tool use
- AI SDK by Vercel or LangChain for agents

**Why This Stack**:
- Firebase handles real-time sync out of the box
- Cloud Functions keep API keys secure
- SwiftUI is fastest for iOS development
- Everything deploys easily

### Alternative Stacks

**React Native**:
- Expo Router, Expo SQLite, Expo Notifications
- Deploy via Expo Go
- Still use Firebase backend

**Android**:
- Kotlin with Jetpack Compose
- Room Database
- Firebase SDK
- Deploy via APK

**Other Backends**:
- AWS (DynamoDB, Lambda, API Gateway, SNS)
- Supabase (PostgreSQL, Realtime, Auth)

---

## Build Strategy

### 1. Start with Messages First
Get basic messaging working end-to-end before anything else:
1. Send a text message from User A → appears on User B's device
2. Messages persist locally (works offline)
3. Messages sync on reconnect
4. Handle app lifecycle (background/foreground)

**Only after messaging is solid should you add AI features.**

### 2. Build Vertically
Finish one slice at a time. Don't have 10 half-working features.

### 3. Test on Real Hardware
Simulators don't accurately represent performance, networking, or app lifecycle. Use physical devices.

### 4. For AI Features
- Start with simple prompts, iterate to improve accuracy
- Use RAG to give the LLM conversation context
- Test with edge cases (empty conversations, mixed languages, etc.)
- Cache common AI responses to reduce costs

---

## Final Submission Requirements

Submit by **Sunday 10:59 PM CT**:

### 1. GitHub Repository
- Comprehensive README with setup instructions

### 2. Demo Video (5-7 minutes)
Must show:
- Real-time messaging between two devices
- Group chat with 3+ participants
- Offline scenario (go offline, receive messages, come online)
- App lifecycle handling (background, foreground, force quit)
- All 5 required AI features in action with clear examples
- Your advanced AI capability with specific use cases

### 3. Deployed Application
- iOS: TestFlight link
- Android: APK download link or Google Play internal testing link
- React Native: Expo Go link
- Note: If deployment blocked, provide detailed local setup instructions

### 4. Persona Brainlift (1-page document)
Explain:
- Your chosen persona and why
- Their specific pain points you're addressing
- How each AI feature solves a real problem
- Key technical decisions you made

### 5. Social Post
Share on X (Twitter) or LinkedIn with:
- Brief description (2-3 sentences)
- Key features and chosen persona
- Demo video or screenshots
- Tag @GauntletAI

---

## Key Principles

> **"WhatsApp was built by two developers in months. With modern AI coding tools, you can build something comparable in one week and push it even further with intelligent features that didn't exist back then."**

### Remember:
- Simple, reliable messaging + truly useful AI features > feature-rich app with flaky delivery
- The MVP isn't about features - it's about proving messaging infrastructure is solid
- Build something people would actually want to use every day
- Test, test, test on real devices with poor network conditions

---

## Success Criteria

A successful MessageAI project:
1. ✅ Messages are delivered reliably and instantly
2. ✅ Works offline and syncs perfectly when back online
3. ✅ Handles app lifecycle gracefully (no lost messages)
4. ✅ All 5 required AI features work well for chosen persona
5. ✅ Advanced AI capability is impressive and useful
6. ✅ Professional UX/UI that feels polished
7. ✅ Clear documentation and easy setup
8. ✅ Deployed and accessible for testing

**The closer you get to the WhatsApp experience, the more you'll understand what it takes to build the next generation of messaging apps.**