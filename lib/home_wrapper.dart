import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'AdminScreen.dart';
import 'UserScreen.dart';
import 'AlertScreen.dart'; // create this later!

class HomeWrapper extends StatefulWidget {
  final String role;

  const HomeWrapper({required this.role});

  @override
  _HomeWrapperState createState() => _HomeWrapperState();
}

class _HomeWrapperState extends State<HomeWrapper> {
  @override
  void initState() {
    super.initState();
    _setupFCMListeners();
  }

  void _setupFCMListeners() async {
    // When app is in background and user taps the notification
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleMessage(message);
    });

    // When app is terminated and opened via notification
    RemoteMessage? initialMessage =
    await FirebaseMessaging.instance.getInitialMessage();

    if (initialMessage != null) {
      _handleMessage(initialMessage);
    }
  }

  void _handleMessage(RemoteMessage message) {
    String title = message.notification?.title ?? 'Alert';
    String body = message.notification?.body ?? 'Follow instructions.';
    String zone = message.data['zone'] ?? 'Unknown';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AlertScreen(
          title: title,
          body: body,
          zone: zone,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.role == 'admin') {
      return AdminDashboard();
    } else {
      return UserScreen();
    }
  }
}
