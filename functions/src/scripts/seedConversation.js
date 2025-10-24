/**
 * Seed test conversation with sample messages
 * Usage: node src/scripts/seedConversation.js [convId]
 */

const admin = require("firebase-admin");

// Initialize Firebase Admin
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.database();

async function main() {
  const convId = process.argv[2] || "conv_demo";
  const authorId = "test_user_1";
  const now = Date.now();

  console.log(`🌱 Seeding conversation: ${convId}`);

  // Sample messages simulating a software team chat
  const texts = [
    "Kickoff: we need a design review for the new onboarding flow.",
    "ETA to ship is next Friday if QA passes all test cases.",
    "Bug found in payment webhook retry logic - investigating root cause.",
    "Decision: go with Option B for the UI after team vote.",
    "Please @Sam prepare the migration script by Thursday EOD.",
    "Updated the API docs with the new endpoints. Link in shared drive.",
    "PR #123 is ready for review - added unit tests and updated README.",
    "Sprint retro notes: we should improve our code review turnaround time.",
    "Security audit flagged the authentication flow - needs attention ASAP.",
    "Great work everyone! Shipped v2.0 to production successfully.",
  ];

  try {
    // Create or update conversation metadata
    await db.ref(`/conversations/${convId}`).set({
      type: "group",
      groupName: "Engineering Team",
      participantIds: [authorId, "test_user_2", "test_user_3"],
      createdAt: now,
      lastMessageAt: now + texts.length * 1000,
    });

    console.log(`✅ Created conversation metadata`);

    // Add messages
    for (let i = 0; i < texts.length; i++) {
      const msgId = db.ref().push().key;
      await db.ref(`/conversations/${convId}/messages/${msgId}`).set({
        text: texts[i],
        type: "text",
        senderId: authorId,
        timestamp: now + i * 1000,
        status: "sent",
      });

      console.log(`  ✓ Message ${i + 1}/${texts.length}: "${texts[i].substring(0, 50)}..."`);
    }

    console.log(`\n🎉 Successfully seeded ${texts.length} messages in conversation ${convId}`);
    console.log(`\n📝 Next steps:`);
    console.log(`   1. Deploy functions: firebase deploy --only functions`);
    console.log(`   2. Check Pinecone dashboard for vectors`);
    console.log(`   3. Test summarize endpoint with this convId`);

    process.exit(0);
  } catch (error) {
    console.error("❌ Error seeding conversation:", error);
    process.exit(1);
  }
}

main().catch(console.error);
