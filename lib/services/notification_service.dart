import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

class NotificationService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  
  // Initialize notification service
  Future<void> initialize() async {
    // Initialize timezone data
    tz_data.initializeTimeZones();
    
    // Configure Firebase Messaging
    await _configureFirebaseMessaging();
    
    // Initialize local notifications
    await _initializeLocalNotifications();
  }
  
  // Configure Firebase Messaging
  Future<void> _configureFirebaseMessaging() async {
    // Request permission
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    
    print('Firebase Messaging Authorization Status: ${settings.authorizationStatus}');
    
    // Get FCM token
    String? token = await _firebaseMessaging.getToken();
    print('Firebase Messaging Token: $token');
    
    // Configure message handling
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Got a message whilst in the foreground!');
      print('Message data: ${message.data}');
      
      if (message.notification != null) {
        print('Message also contained a notification: ${message.notification}');
        _showLocalNotification(
          id: message.hashCode,
          title: message.notification?.title ?? 'TeamWork',
          body: message.notification?.body ?? '',
          payload: message.data.toString(),
        );
      }
    });
    
    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }
  
  // Initialize local notifications
  Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    final DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
      onDidReceiveLocalNotification: _onDidReceiveLocalNotification,
    );
    
    final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );
    
    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onDidReceiveNotificationResponse,
    );
    
    // Create notification channels for Android
    await _createNotificationChannels();
  }
  
  // Create notification channels for Android
  Future<void> _createNotificationChannels() async {
    const AndroidNotificationChannel attendanceChannel = AndroidNotificationChannel(
      'attendance_channel',
      'Attendance Notifications',
      description: 'Notifications related to attendance check-in and check-out',
      importance: Importance.high,
    );
    
    const AndroidNotificationChannel teamChannel = AndroidNotificationChannel(
      'team_channel',
      'Team Notifications',
      description: 'Notifications related to team activities and updates',
      importance: Importance.high,
    );
    
    const AndroidNotificationChannel generalChannel = AndroidNotificationChannel(
      'general_channel',
      'General Notifications',
      description: 'General notifications from the TeamWork app',
      importance: Importance.default_,
    );
    
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(attendanceChannel);
    
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(teamChannel);
    
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(generalChannel);
  }
  
  // Show local notification
  Future<void> _showLocalNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    String channelId = 'general_channel',
  }) async {
    AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      channelId,
      channelId == 'attendance_channel'
          ? 'Attendance Notifications'
          : channelId == 'team_channel'
              ? 'Team Notifications'
              : 'General Notifications',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );
    
    DarwinNotificationDetails iosDetails = const DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    
    NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    await _localNotifications.show(
      id,
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }
  
  // Schedule local notification
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
    String channelId = 'general_channel',
  }) async {
    AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      channelId,
      channelId == 'attendance_channel'
          ? 'Attendance Notifications'
          : channelId == 'team_channel'
              ? 'Team Notifications'
              : 'General Notifications',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );
    
    DarwinNotificationDetails iosDetails = const DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    
    NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    await _localNotifications.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledDate, tz.local),
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );
  }
  
  // Cancel notification by ID
  Future<void> cancelNotification(int id) async {
    await _localNotifications.cancel(id);
  }
  
  // Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _localNotifications.cancelAll();
  }
  
  // Subscribe to topic
  Future<void> subscribeToTopic(String topic) async {
    await _firebaseMessaging.subscribeToTopic(topic);
  }
  
  // Unsubscribe from topic
  Future<void> unsubscribeFromTopic(String topic) async {
    await _firebaseMessaging.unsubscribeFromTopic(topic);
  }
  
  // Handle local notification tap
  void _onDidReceiveNotificationResponse(NotificationResponse response) {
    print('Notification response: ${response.payload}');
    // Handle notification tap
    // You can navigate to a specific screen based on the payload
  }
  
  // Handle iOS notification when app is in foreground (iOS < 10)
  void _onDidReceiveLocalNotification(
    int id,
    String? title,
    String? body,
    String? payload,
  ) {
    print('Local notification: $id, $title, $body, $payload');
    // Handle iOS notification
  }
}

// Background message handler
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('Handling a background message: ${message.messageId}');
  print('Message data: ${message.data}');
  print('Message notification: ${message.notification?.title}');
}
