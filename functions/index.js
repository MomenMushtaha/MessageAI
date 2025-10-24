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
exports.sendMessageNotification = functions.database
  .ref('/conversations/{conversationId}/messages/{messageId}')
  .onCreate(async (snapshot, context) => {
    const message = snapshot.val();
    const conversationId = context.params.conversationId;
    const messageId = context.params.messageId;

    console.log(`📬 New message created in conversation ${conversationId}`);

    try {
      // Get conversation to find participants
      const conversationSnapshot = await admin.database()
        .ref(`conversations/${conversationId}`)
        .once('value');

      if (!conversationSnapshot.exists()) {
        console.error(`❌ Conversation ${conversationId} not found`);
        return null;
      }

      const conversation = conversationSnapshot.val();
      const participantIds = conversation.participantIds || [];
      const senderId = message.senderId;

      // Get sender info for notification
      const senderSnapshot = await admin.database()
        .ref(`users/${senderId}`)
        .once('value');

      const senderName = senderSnapshot.exists()
        ? senderSnapshot.val().displayName
        : 'Someone';

      // Get recipients (exclude sender)
      const recipientIds = participantIds.filter(id => id !== senderId);

      if (recipientIds.length === 0) {
        console.log('⚠️ No recipients to notify');
        return null;
      }

      console.log(`📤 Sending notifications to ${recipientIds.length} recipients`);

      // Increment unread count for all recipients
      const unreadUpdates = {};
      recipientIds.forEach(recipientId => {
        unreadUpdates[`unreadCounts/${recipientId}`] = admin.database.ServerValue.increment(1);
      });

      await admin.database()
        .ref(`conversations/${conversationId}`)
        .update(unreadUpdates);
      console.log('✅ Updated unread counts for recipients');

      // Collect FCM tokens and badge counts per recipient
      const recipientNotifications = [];

      for (const recipientId of recipientIds) {
        // Get all FCM tokens for this user
        const tokensSnapshot = await admin.database()
          .ref(`users/${recipientId}/fcmTokens`)
          .once('value');

        // Calculate badge count for this user
        const userConversationsSnapshot = await admin.database()
          .ref('conversations')
          .orderByChild(`participantIds/${recipientId}`)
          .equalTo(true)
          .once('value');

        let badgeCount = 0;
        if (userConversationsSnapshot.exists()) {
          userConversationsSnapshot.forEach(convSnapshot => {
            const conv = convSnapshot.val();
            const unreadCounts = conv.unreadCounts || {};
            badgeCount += (unreadCounts[recipientId] || 0);
          });
        }

        if (tokensSnapshot.exists()) {
          tokensSnapshot.forEach(tokenSnapshot => {
            const tokenData = tokenSnapshot.val();
            recipientNotifications.push({
              token: tokenData.token,
              badgeCount: badgeCount,
              recipientId: recipientId,
              tokenKey: tokenSnapshot.key,
            });
          });
        }
      }

      if (recipientNotifications.length === 0) {
        console.log('⚠️ No FCM tokens found for recipients');
        return null;
      }

      console.log(`📱 Found ${recipientNotifications.length} FCM tokens`);

      // Prepare notification payload
      const notificationTitle = conversation.type === 'group'
        ? `${senderName} in ${conversation.groupName || 'Group Chat'}`
        : senderName;

      const notificationBody = message.mediaType === 'image'
        ? '📷 Image'
        : message.text || 'New message';

      // Send individual notifications with proper badge counts
      const sendPromises = recipientNotifications.map(async (recipient) => {
        const payload = {
          notification: {
            title: notificationTitle,
            body: notificationBody,
            sound: 'default',
            badge: recipient.badgeCount.toString(),
          },
          data: {
            conversationId: conversationId,
            messageId: messageId,
            senderId: senderId,
            type: 'new_message',
          },
        };

        try {
          await admin.messaging().sendToDevice(recipient.token, payload);
          return { success: true, token: recipient.token, recipientId: recipient.recipientId, tokenKey: recipient.tokenKey };
        } catch (error) {
          console.error(`Error sending to token ${recipient.token}:`, error);
          return { success: false, token: recipient.token, recipientId: recipient.recipientId, tokenKey: recipient.tokenKey, error: error };
        }
      });

      const results = await Promise.all(sendPromises);
      const successCount = results.filter(r => r.success).length;
      const failureCount = results.filter(r => !r.success).length;

      console.log(`✅ Sent ${successCount} notifications`);

      if (failureCount > 0) {
        console.warn(`⚠️ Failed to send ${failureCount} notifications`);

        // Clean up invalid tokens
        const tokensToRemove = [];
        results.forEach((result) => {
          if (!result.success && result.error) {
            const error = result.error;
            console.error(`Error sending to token ${result.token}:`, error);

            // Remove invalid tokens
            if (
              error.code === 'messaging/invalid-registration-token' ||
              error.code === 'messaging/registration-token-not-registered'
            ) {
              tokensToRemove.push({
                recipientId: result.recipientId,
                tokenKey: result.tokenKey,
              });
            }
          }
        });

        // Delete invalid tokens from Realtime Database
        if (tokensToRemove.length > 0) {
          console.log(`🗑️ Removing ${tokensToRemove.length} invalid tokens`);

          for (const tokenInfo of tokensToRemove) {
            try {
              await admin.database()
                .ref(`users/${tokenInfo.recipientId}/fcmTokens/${tokenInfo.tokenKey}`)
                .remove();
            } catch (deleteError) {
              console.error(`Error deleting token ${tokenInfo.tokenKey}:`, deleteError);
            }
          }
        }
      }

      return { successCount, failureCount };
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

    const now = Date.now();
    const ninetyDaysAgo = now - (90 * 24 * 60 * 60 * 1000);

    try {
      const usersSnapshot = await admin.database()
        .ref('users')
        .once('value');

      let deletedCount = 0;

      if (usersSnapshot.exists()) {
        const deletePromises = [];

        usersSnapshot.forEach(userSnapshot => {
          const userId = userSnapshot.key;
          const tokensSnapshot = userSnapshot.child('fcmTokens');

          if (tokensSnapshot.exists()) {
            tokensSnapshot.forEach(tokenSnapshot => {
              const tokenData = tokenSnapshot.val();
              const createdAt = tokenData.createdAt || 0;

              if (createdAt < ninetyDaysAgo) {
                deletePromises.push(
                  admin.database()
                    .ref(`users/${userId}/fcmTokens/${tokenSnapshot.key}`)
                    .remove()
                    .then(() => {
                      deletedCount++;
                    })
                );
              }
            });
          }
        });

        await Promise.all(deletePromises);
      }

      console.log(`✅ Cleaned up ${deletedCount} old tokens`);
      return null;
    } catch (error) {
      console.error('❌ Error cleaning up tokens:', error);
      return null;
    }
  });
