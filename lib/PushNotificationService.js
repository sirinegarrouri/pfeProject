class PushNotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  Future<void> init() async {
    // Request permission (iOS)
    NotificationSettings settings = await _fcm.requestPermission();

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('User granted permission');
    }

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Foreground message received: ${message.notification?.title}');
      // Navigate to the alert screen or show dialog
    });

    // Handle when app opened from background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('App opened from notification: ${message.notification?.title}');
      // Navigate to alert screen directly
    });
  }

  Future<String?> getDeviceToken() async {
    String? token = await _fcm.getToken();
    print('FCM Token: $token');
    return token;
  }
}
