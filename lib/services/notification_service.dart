import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    // Request permissions
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('User granted permission');
    }

    // Initialize local notifications for foreground
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await _localNotifications.initialize(initializationSettings);

    // Get FCM Token
    await updateToken();

    // Listen for foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _showLocalNotification(message);
    });
  }

  Future<void> updateToken() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        String? token = await _messaging.getToken();
        if (token != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set({'fcmToken': token}, SetOptions(merge: true));
          debugPrint("FCM Token updated for user: ${user.uid}");
        }
      } catch (e) {
        debugPrint("Error updating FCM token: $e");
      }
    }
  }

  void _showLocalNotification(RemoteMessage message) {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'food_channel',
          'Food Donations',
          importance: Importance.max,
          priority: Priority.high,
        );
    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
    );

    _localNotifications.show(
      DateTime.now().millisecond,
      message.notification?.title ?? 'New Food Alert!',
      message.notification?.body ?? 'Someone has added a food donation nearby.',
      details,
    );
  }

  /// Notifies NGOs within a 5km radius of the given location.
  Future<void> notifyNearbyNGOs({
    required String foodId,
    required double lat,
    required double lng,
    required String foodName,
    required String quantity,
    Timestamp? expiryTime,
  }) async {
    try {
      debugPrint("Starting to notify nearby NGOs for: $foodName");
      var ngoDocs = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'ngo')
          .get();

      debugPrint("Found ${ngoDocs.docs.length} NGOs in total.");

      List<Future> notificationTasks = [];

      for (var doc in ngoDocs.docs) {
        var data = doc.data();

        if (data['lat'] != null && data['lng'] != null) {
          double distance = Geolocator.distanceBetween(
            lat,
            lng,
            data['lat'],
            data['lng'],
          );

          debugPrint(
            "NGO ${data['name'] ?? doc.id} distance: ${distance.toStringAsFixed(2)}m",
          );

          if (distance <= 5000) {
            // 5km
            debugPrint(
              "NGO ${data['name'] ?? doc.id} is within 5km. Queueing notification.",
            );

            // 1. Add to notifications sub-collection for in-app alert
            notificationTasks.add(
              FirebaseFirestore.instance
                  .collection('users')
                  .doc(doc.id)
                  .collection('notifications')
                  .add({
                    'title': 'New Food Donation Nearby!',
                    'body':
                        '$foodName ($quantity) is available within 5km of your location.',
                    'timestamp': FieldValue.serverTimestamp(),
                    'isRead': false,
                    'foodId': foodId,
                    'foodLat': lat,
                    'foodLng': lng,
                    'expiryTime': expiryTime,
                  })
                  .then((_) {})
                  .catchError((e) {
                    debugPrint(
                      "Failed to write notification for ${doc.id}: $e",
                    );
                    return null;
                  }),
            );

            // 2. Log push notification intent
            if (data['fcmToken'] != null) {
              debugPrint(
                "Push notification would be sent to token: ${data['fcmToken']}",
              );
            }
          }
        }
      }

      if (notificationTasks.isNotEmpty) {
        await Future.wait(notificationTasks);
        debugPrint(
          "Successfully processed ${notificationTasks.length} notifications.",
        );
      } else {
        debugPrint("No NGOs found within 5km radius.");
      }
    } catch (e) {
      debugPrint("Error in notifyNearbyNGOs: $e");
    }
  }

  /// Deletes all notifications related to a specific food item across all NGOs.
  Future<void> clearNotificationsForFood(String foodId) async {
    try {
      debugPrint("Clearing notifications for food: $foodId");

      // Get all NGOs
      var ngoDocs = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'ngo')
          .get();

      for (var ngoDoc in ngoDocs.docs) {
        // Find and delete matching notifications in each NGO's sub-collection
        var notifications = await FirebaseFirestore.instance
            .collection('users')
            .doc(ngoDoc.id)
            .collection('notifications')
            .where('foodId', isEqualTo: foodId)
            .get();

        for (var notif in notifications.docs) {
          await notif.reference.delete();
        }
      }
      debugPrint("Notifications cleared successfully.");
    } catch (e) {
      debugPrint("Error clearing notifications: $e");
    }
  }

  /// Notifies the organization that their food donation has been claimed by an NGO.
  Future<void> notifyOrganizationOnClaim({
    required String orgId,
    required String ngoName,
    required String foodName,
  }) async {
    if (orgId.isEmpty) {
      debugPrint("notifyOrganizationOnClaim: orgId is empty, cannot send notification.");
      return;
    }
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(orgId)
          .collection('notifications')
          .add({
            'title': 'Donation Claimed!',
            'body': '$ngoName claimed your donation ($foodName).',
            'timestamp': FieldValue.serverTimestamp(),
            'isRead': false,
            'type': 'claim',
          });
      debugPrint("Organization $orgId notified of claim by $ngoName.");
    } catch (e) {
      debugPrint("Error notifying organization on claim: $e");
    }
  }

  /// Deletes notifications older than 24 hours for the current user.
  Future<void> cleanupOldNotifications() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      DateTime twentyFourHoursAgo = DateTime.now().subtract(
        const Duration(days: 1),
      );

      var oldNotifications = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .where(
            'timestamp',
            isLessThan: Timestamp.fromDate(twentyFourHoursAgo),
          )
          .get();

      if (oldNotifications.docs.isNotEmpty) {
        debugPrint(
          "Cleaning up ${oldNotifications.docs.length} old notifications.",
        );
        for (var doc in oldNotifications.docs) {
          await doc.reference.delete();
        }
      }
    } catch (e) {
      debugPrint("Error cleaning up old notifications: $e");
    }
  }
}
