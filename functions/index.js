const {setGlobalOptions} = require("firebase-functions");
const {onDocumentUpdated} = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");
const logger = require("firebase-functions/logger");

admin.initializeApp();
setGlobalOptions({maxInstances: 10});

/**
 * Triggered when an Order document is updated.
 * Handles:
 * 1. Customer notifications (status changes: preparing, ready, delivery, etc)
 * 2. Driver notifications (new delivery offer)
 * 3. Restaurant notifications (order canceled)
 */
exports.onOrderStatusChanged = onDocumentUpdated("orders/{orderId}",
    async (event) => {
      const newValue = event.data.after.data();
      const previousValue = event.data.before.data();

      // Ensure data exists
      if (!newValue || !previousValue) {
        return;
      }

      const orderId = event.params.orderId;
      const currentStatus = newValue.status;
      const previousStatus = previousValue.status;

      // Check if status actually changed
      if (currentStatus === previousStatus) {
        return;
      }

      logger.info(
          `Processing order ${orderId} status ` +
      `change: ${previousStatus} -> ${currentStatus}`,
      );

      try {
        await notifyCustomer(newValue, currentStatus);

        // Check if driver was just assigned
        const currentDriverId = newValue.driverId;
        const previousDriverId = previousValue.driverId;

        if (currentDriverId && currentDriverId !== previousDriverId) {
          await notifyDriver(newValue, currentDriverId);
        }

        if (currentStatus === "cancelled") {
          await notifyRestaurant(newValue);
        }
      } catch (error) {
        logger.error(`Error sending notification for order ${orderId}:`, error);
      }
    });

/**
 * Notify the customer about an order status change
 * @param {Object} order - The order object
 * @param {string} status - The new status
 */
async function notifyCustomer(order, status) {
  const customerId = order.customerId;
  if (!customerId) return;

  const userDoc = await admin.firestore()
      .collection("users")
      .doc(customerId).get();
  if (!userDoc.exists) return;

  const userData = userDoc.data();
  const token = userData.fcmToken;

  if (!token) {
    logger.warn(`No FCM token for customer ${customerId}`);
    return;
  }

  let title;
  let body;
  switch (status) {
    case "preparing":
      title = "Order Accepted!";
      body = "The restaurant has started preparing your order.";
      break;
    case "ready":
      title = "Order Ready!";
      body = "Your order is ready and waiting for a driver.";
      break;
    case "picked_up":
      title = "Out for Delivery!";
      body = "Your driver is on the way with your food.";
      break;
    case "delivered":
      title = "Order Delivered!";
      body = "Your food has arrived. Enjoy!";
      break;
    case "cancelled":
      title = "Order Cancelled";
      body = "Your order has been cancelled.";
      break;
    default:
      return; // Don't notify for other status changes
  }

  const message = {
    token: token,
    notification: {
      title: title,
      body: body,
    },
    data: {
      type: "order_update",
      orderId: order.id || "",
      status: status,
    },
    android: {
      notification: {
        channelId: "high_importance_channel",
        priority: "high",
      },
    },
    apns: {
      payload: {
        aps: {
          sound: "default",
          badge: 1,
        },
      },
    },
  };

  const response = await admin.messaging().send(message);
  logger.info("Successfully sent message to customer:", response);
}

/**
 * Notify the assigned driver about a new delivery
 * @param {Object} order - The order object
 * @param {string} driverId - The driver ID
 */
async function notifyDriver(order, driverId) {
  const userDoc = await admin.firestore()
      .collection("users")
      .doc(driverId).get();
  if (!userDoc.exists) return;

  const userData = userDoc.data();
  const token = userData.fcmToken;

  if (!token) {
    logger.warn(`No FCM token for driver ${driverId}`);
    return;
  }

  const restaurantName = order.restaurantName || "the restaurant";
  const deliveryFee = order.deliveryFee || 0;

  const message = {
    token: token,
    notification: {
      title: "New Delivery Offer!",
      body: `Pick up from ${restaurantName}. Earn $${deliveryFee.toFixed(2)}.`,
    },
    data: {
      type: "new_delivery",
      orderId: order.id || "",
    },
    android: {
      priority: "high",
      notification: {
        channelId: "high_importance_channel",
        priority: "high",
        defaultSound: true,
        defaultVibrateTimings: true,
      },
    },
    apns: {
      payload: {
        aps: {
          "sound": "default",
          "badge": 1,
          "interruption-level": "time-sensitive",
        },
      },
    },
  };

  const response = await admin.messaging().send(message);
  logger.info("Successfully sent offer to driver:", response);
}

/**
 * Notify the restaurant about a canceled order
 * @param {Object} order - The order object
 */
async function notifyRestaurant(order) {
  const restaurantId = order.restaurantId;
  if (!restaurantId) return;

  const userDoc = await admin.firestore()
      .collection("users")
      .doc(restaurantId).get();
  if (!userDoc.exists) return;

  const userData = userDoc.data();
  const token = userData.fcmToken;

  if (!token) {
    logger.warn(`No FCM token for restaurant ${restaurantId}`);
    return;
  }

  const message = {
    token: token,
    notification: {
      title: "Order Cancelled",
      body: "An order was just cancelled.",
    },
    data: {
      type: "order_cancelled",
      orderId: order.id || "",
    },
    android: {
      notification: {
        channelId: "high_importance_channel",
        priority: "high",
      },
    },
  };

  const response = await admin.messaging().send(message);
  logger.info("Successfully sent cancellation to restaurant:", response);
}
