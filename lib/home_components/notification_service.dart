import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  // Your server's API endpoint for sending FCM messages
  static const String _serverEndpoint = 'YOUR_SERVER_ENDPOINT_HERE';

  // Initialize both local notifications and FCM
  static Future<void> initialize() async {
    print('🔔 Starting notification initialization...');
    
    try {
      // Initialize local notifications
      await _initializeLocalNotifications();
      
      // Initialize FCM
      await _initializeFCM();
      
      print('✅ Notifications fully initialized');
    } catch (e) {
      print('❌ Notification initialization failed: $e');
    }
  }

  static Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    await _createNotificationChannels();
    await _requestPermissions();
  }

  static Future<void> _initializeFCM() async {
    // Request FCM permissions
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    print('FCM Permission granted: ${settings.authorizationStatus}');

    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle when app is opened from notification
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);
  }

  // Store user's FCM token in Firestore
  static Future<void> saveUserToken(String userId) async {
    try {
      String? token = await _firebaseMessaging.getToken();
      if (token != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .update({'fcmToken': token});
        print('✅ FCM Token saved: $token');
      }
    } catch (e) {
      print('❌ Error saving FCM token: $e');
    }
  }

  // FIXED: Send birthday wish with FCM
  static Future<void> sendBirthdayWish({
    required String senderId,
    required String senderName,
    required String recipientId,
    required String recipientName,
    required String communityId,
  }) async {
    print('🎂 === BIRTHDAY WISH SERVICE START ===');
    
    try {
      // 1. Save to Firestore (for in-app notifications)
      await FirebaseFirestore.instance
          .collection('users')
          .doc(recipientId)
          .collection('notifications')
          .add({
        'type': 'birthday_wish',
        'title': 'Birthday Wish 🎉',
        'message': '$senderName sent you birthday wishes!',
        'senderName': senderName,
        'senderId': senderId,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
        'communityId': communityId,
      });

      // 2. Send FCM push notification to recipient
      await _sendFCMNotification(
        recipientId: recipientId,
        title: '🎉 Birthday Wish Received!',
        body: '$senderName sent you birthday wishes! 🎂',
        data: {
          'type': 'birthday_wish',
          'senderId': senderId,
          'senderName': senderName,
          'communityId': communityId,
        },
      );

      print('✅ Birthday wish sent successfully');
    } catch (e) {
      print('❌ Error sending birthday wish: $e');
      throw e;
    }
  }

  // Send FCM notification to specific user
  static Future<void> _sendFCMNotification({
    required String recipientId,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    try {
      // Get recipient's FCM token
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(recipientId)
          .get();

      if (!userDoc.exists) {
        print('❌ User document not found');
        return;
      }

      Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
      String? fcmToken = userData['fcmToken'];

      if (fcmToken == null || fcmToken.isEmpty) {
        print('❌ No FCM token found for user');
        return;
      }

      // Send FCM message via your server
      await _sendFCMViaServer(
        token: fcmToken,
        title: title,
        body: body,
        data: data ?? {},
      );

    } catch (e) {
      print('❌ Error sending FCM notification: $e');
    }
  }

  // Send FCM via your server (recommended approach)
  static Future<void> _sendFCMViaServer({
    required String token,
    required String title,
    required String body,
    required Map<String, String> data,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_serverEndpoint/send-notification'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'token': token,
          'title': title,
          'body': body,
          'data': data,
        }),
      );

      if (response.statusCode == 200) {
        print('✅ FCM notification sent via server');
      } else {
        print('❌ Server error: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error sending FCM via server: $e');
    }
  }

  // Handle background FCM messages
  static Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
    print('Handling background message: ${message.messageId}');
    // Handle background message logic here
  }

  // Handle foreground FCM messages
  static void _handleForegroundMessage(RemoteMessage message) {
    print('Handling foreground message: ${message.messageId}');
    
    // Show local notification for foreground messages
    _showLocalNotificationFromFCM(message);
  }

  // Handle when app is opened from notification
  static void _handleMessageOpenedApp(RemoteMessage message) {
    print('Message opened app: ${message.messageId}');
    // Handle navigation logic here
  }

  // Convert FCM message to local notification
  static Future<void> _showLocalNotificationFromFCM(RemoteMessage message) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'birthday_channel',
      'Birthday Notifications',
      channelDescription: 'Birthday wishes and celebrations',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      message.notification?.title ?? 'New Notification',
      message.notification?.body ?? '',
      notificationDetails,
      payload: jsonEncode(message.data),
    );
  }

  // Rest of your existing methods...
  static Future<void> _createNotificationChannels() async {
    if (Platform.isAndroid) {
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'birthday_channel',
        'Birthday Notifications',
        description: 'Birthday wishes and celebrations',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      );

      await _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }
  }

  static Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      await Permission.notification.request();
    } else if (Platform.isIOS) {
      await _notificationsPlugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    }
  }

  static Future<void> _onNotificationTapped(NotificationResponse response) async {
    print('Notification tapped: ${response.payload}');
  }

  // Your existing helper methods remain the same...
  static Future<bool> areNotificationsEnabled() async {
    try {
      if (Platform.isAndroid) {
        final status = await Permission.notification.status;
        return status.isGranted;
      }
      return true;
    } catch (e) {
      print('Error checking notification status: $e');
      return false;
    }
  }

  static Future<int> getUnreadCount(String userId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .where('read', isEqualTo: false)
          .get();
      
      return snapshot.docs.length;
    } catch (e) {
      print('Error getting unread count: $e');
      return 0;
    }
  }

  static Future<void> markAllAsRead(String userId) async {
    try {
      final unreadNotifications = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .where('read', isEqualTo: false)
          .get();

      final batch = FirebaseFirestore.instance.batch();
      for (var doc in unreadNotifications.docs) {
        batch.update(doc.reference, {'read': true});
      }
      await batch.commit();
    } catch (e) {
      print('Error marking notifications as read: $e');
    }
  }

  static Future<void> clearAll(String userId) async {
    try {
      final notifications = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .get();

      final batch = FirebaseFirestore.instance.batch();
      for (var doc in notifications.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      print('Error clearing notifications: $e');
      throw e;
    }
  }

  static Future<void> cancelAllNotifications() async {
    try {
      await _notificationsPlugin.cancelAll();
    } catch (e) {
      print('Error cancelling local notifications: $e');
    }
  }
}