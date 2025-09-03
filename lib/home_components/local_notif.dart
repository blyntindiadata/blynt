import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

class LocalNotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    print('🔔 Initializing local notifications...');
    
    // Android initialization
    const AndroidInitializationSettings androidInitializationSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS initialization
    const DarwinInitializationSettings iosInitializationSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: androidInitializationSettings,
      iOS: iosInitializationSettings,
    );

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: onNotificationTapped,
    );

    // Request permissions
    await _requestPermissions();
    print('✅ Local notifications initialized successfully');
  }

  static Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      await Permission.notification.request();
    } else if (Platform.isIOS) {
      await _notificationsPlugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
    }
  }

  static Future<void> onNotificationTapped(NotificationResponse notificationResponse) async {
    print('🔔 Notification tapped: ${notificationResponse.payload}');
  }

  static Future<void> showBirthdayNotification({
    required String senderName,
    required String recipientName,
    String? customMessage,
  }) async {
    try {
      print('🎂 Sending birthday notification: $senderName → $recipientName');
      
      const AndroidNotificationDetails androidNotificationDetails =
          AndroidNotificationDetails(
        'birthday_channel',
        'Birthday Notifications',
        channelDescription: 'Notifications for birthday wishes',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        playSound: true,
        enableVibration: true,
      );

      const DarwinNotificationDetails iosNotificationDetails =
          DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails notificationDetails = NotificationDetails(
        android: androidNotificationDetails,
        iOS: iosNotificationDetails,
      );

      await _notificationsPlugin.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        '🎉 Birthday Wish Received!',
        customMessage ?? '$senderName sent you birthday wishes!',
        notificationDetails,
        payload: 'birthday_wish',
      );
      
      print('✅ Birthday notification sent successfully');
    } catch (e) {
      print('❌ Error sending birthday notification: $e');
    }
  }

  static Future<bool> areNotificationsEnabled() async {
    if (Platform.isAndroid) {
      return await Permission.notification.isGranted;
    }
    return true;
  }
}