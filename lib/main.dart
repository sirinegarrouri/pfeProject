import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  FirebaseMessaging messaging = FirebaseMessaging.instance;

  // Request permission for notifications
  NotificationSettings settings = await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  if (settings.authorizationStatus == AuthorizationStatus.authorized) {
    print("✅ Notifications permission granted!");
  } else {
    print("❌ Notifications permission denied!");
  }

  // Get Firebase Token
  String? token = await messaging.getToken();
  print("🔥 Firebase Token: $token");

  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print("📩 Foreground message received: ${message.notification?.title}");
  });

  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    print("🔄 App opened via notification: ${message.notification?.title}");
  });

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text("FCM Web Test")),
        body: const Center(child: Text("Check console for FCM logs!")),
      ),
    );
  }
}
