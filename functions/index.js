/**
 * Cloud Functions for MessageAI
 *
 * Handles push notifications when new messages are created
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

/**
 * Send push notification when a new message is created
 *
 * Triggers on: /conversations/{conversationId}/messages/{messageId}
 *
 * Behavior:
 * - Gets all participants in the conversation
 * - Excludes the sender from notification recipients
 * - Fetches FCM tokens for each recipient
 * - Sends notification with message preview
 * - Includes conversationId for deep linking
 */
exports.sendMessageNotification = functions.firestore
  .document('conversations/{conversationId}/messages/{messageId}')
  .onCreate(async (snapshot, context) => {
    const message = snapshot.data();
    const conversationId = context.params.conversationId;
    const messageId = context.params.messageId;

    console.log(`📬 New message created in conversation ${conversationId}`);

    try {
      // Get conversation to find participants
      const conversationRef = admin.firestore()
        .collection('conversations')
        .doc(conversationId);

      const conversationDoc = await conversationRef.get();

      if (!conversationDoc.exists) {
        console.error(`❌ Conversation ${conversationId} not found`);
        return null;
      }

      const conversation = conversationDoc.data();
      const participantIds = conversation.participantIds || [];
      const senderId = message.senderId;

      // Get sender info for notification
      const senderDoc = await admin.firestore()
        .collection('users')
        .doc(senderId)
        .get();

      const senderName = senderDoc.exists
        ? senderDoc.data().displayName
        : 'Someone';

      // Get recipients (exclude sender)
      const recipientIds = participantIds.filter(id => id !== senderId);

      if (recipientIds.length === 0) {
        console.log('⚠️ No recipients to notify');
        return null;
      }

      console.log(`📤 Sending notifications to ${recipientIds.length} recipients`);

      // Collect all FCM tokens for recipients
      const tokens = [];

      for (const recipientId of recipientIds) {
        // Get all FCM tokens for this user
        const tokensSnapshot = await admin.firestore()
          .collection('users')
          .doc(recipientId)
          .collection('fcmTokens')
          .get();

        tokensSnapshot.forEach(doc => {
          const tokenData = doc.data();
          tokens.push(tokenData.token);
        });
      }

      if (tokens.length === 0) {
        console.log('⚠️ No FCM tokens found for recipients');
        return null;
      }

      console.log(`📱 Found ${tokens.length} FCM tokens`);

      // Prepare notification payload
      const notificationTitle = conversation.type === 'group'
        ? `${senderName} in ${conversation.groupName || 'Group Chat'}`
        : senderName;

      const notificationBody = message.mediaType === 'image'
        ? '📷 Image'
        : message.text || 'New message';

      const payload = {
        notification: {
          title: notificationTitle,
          body: notificationBody,
          sound: 'default',
        },
        data: {
          conversationId: conversationId,
          messageId: messageId,
          senderId: senderId,
          type: 'new_message',
        },
      };

      // Send notification to all tokens
      const response = await admin.messaging().sendToDevice(tokens, payload);

      console.log(`✅ Sent ${response.successCount} notifications`);

      if (response.failureCount > 0) {
        console.warn(`⚠️ Failed to send ${response.failureCount} notifications`);

        // Clean up invalid tokens
        const tokensToRemove = [];
        response.results.forEach((result, index) => {
          const error = result.error;
          if (error) {
            console.error(`Error sending to token ${tokens[index]}:`, error);

            // Remove invalid tokens
            if (
              error.code === 'messaging/invalid-registration-token' ||
              error.code === 'messaging/registration-token-not-registered'
            ) {
              tokensToRemove.push(tokens[index]);
            }
          }
        });

        // Delete invalid tokens from Firestore
        if (tokensToRemove.length > 0) {
          console.log(`🗑️ Removing ${tokensToRemove.length} invalid tokens`);

          for (const recipientId of recipientIds) {
            for (const token of tokensToRemove) {
              try {
                await admin.firestore()
                  .collection('users')
                  .doc(recipientId)
                  .collection('fcmTokens')
                  .doc(token)
                  .delete();
              } catch (deleteError) {
                console.error(`Error deleting token ${token}:`, deleteError);
              }
            }
          }
        }
      }

      return response;
    } catch (error) {
      console.error('❌ Error sending notification:', error);
      return null;
    }
  });

/**
 * Clean up old FCM tokens
 *
 * Runs daily to remove tokens older than 90 days
 */
exports.cleanupOldTokens = functions.pubsub
  .schedule('every 24 hours')
  .onRun(async (context) => {
    console.log('🧹 Starting token cleanup...');

    const now = admin.firestore.Timestamp.now();
    const ninetyDaysAgo = new Date(now.toDate().getTime() - 90 * 24 * 60 * 60 * 1000);

    try {
      const usersSnapshot = await admin.firestore()
        .collection('users')
        .get();

      let deletedCount = 0;

      for (const userDoc of usersSnapshot.docs) {
        const tokensSnapshot = await userDoc.ref
          .collection('fcmTokens')
          .where('createdAt', '<', ninetyDaysAgo)
          .get();

        for (const tokenDoc of tokensSnapshot.docs) {
          await tokenDoc.ref.delete();
          deletedCount++;
        }
      }

      console.log(`✅ Cleaned up ${deletedCount} old tokens`);
      return null;
    } catch (error) {
      console.error('❌ Error cleaning up tokens:', error);
      return null;
    }
  });
