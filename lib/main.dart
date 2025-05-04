import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'Login/firebase_options.dart';
import 'Admin/AdminScreen.dart';
import 'User/UserScreen.dart';
import 'Login/LoginScreen.dart';
import 'Login/waiting_page.dart'; // Import WaitingPage

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  runApp(MyApp());
}

Future<void> _firebaseBackgroundMessageHandler(RemoteMessage message) async {
  print("🔔 Background message received: ${message.notification?.title}");
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sys-Alert App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
      ),
      home: AuthChecker(),
    );
  }
}

class AuthChecker extends StatefulWidget {
  @override
  _AuthCheckerState createState() => _AuthCheckerState();
}

class _AuthCheckerState extends State<AuthChecker> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  @override
  void initState() {
    super.initState();
    _setupFCMTokenManagement();
    _setupNotificationListeners();
  }

  void _setupFCMTokenManagement() async {
    _auth.authStateChanges().listen((User? user) async {
      if (user != null) {
        await _saveFcmToken(user);
      }
    });

    _messaging.onTokenRefresh.listen((newToken) async {
      print('🔄 Token refreshed: $newToken');
      final user = _auth.currentUser;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).update({
          'fcmToken': newToken,
        });
        print("✅ Refreshed token updated in Firestore");
      }
    });
  }

  Future<void> _saveFcmToken(User user) async {
    try {
      String? token = await _messaging.getToken();
      if (token != null) {
        print('📲 FCM Token for ${user.email}: $token');
        await _firestore.collection('users').doc(user.uid).update({
          'fcmToken': token,
        });
        print("✅ Token saved in Firestore for ${user.uid}");
      } else {
        print("❌ Couldn't get FCM token");
      }
    } catch (e) {
      print("❌ Error getting FCM token: $e");
    }
  }

  void _setupNotificationListeners() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        print("🔔 Message received in foreground: ${message.notification!.title}");
        _showNotificationDialog(message);
      }
    });
  }

  void _showNotificationDialog(RemoteMessage message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(message.notification?.title ?? "No title"),
        content: Text(message.notification?.body ?? "No content"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text("Close"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _auth.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!snapshot.hasData || snapshot.data == null) {
          print("👤 No user is logged in");
          return LoginScreen();
        }

        User currentUser = snapshot.data!;
        print("👤 Logged in user: ${currentUser.email} | UID: ${currentUser.uid}");

        return FutureBuilder<DocumentSnapshot>(
          future: _firestore.collection('users').doc(currentUser.uid).get(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
              print("❌ No user data found for UID: ${currentUser.uid}");
              return Scaffold(
                body: Center(
                  child: Text(
                    'User data not found. Contact admin!',
                    style: TextStyle(fontSize: 20, color: Colors.red),
                  ),
                ),
              );
            }

            var userData = userSnapshot.data!.data() as Map<String, dynamic>?;
            String status = (userData?['status'] ?? 'pending').toString().toLowerCase();
            String role = (userData?['role'] ?? 'user').toString().toLowerCase();

            print("✅ User status: $status | role: $role");

            if (status == 'pending') {
              return WaitingPage();
            } else if (status == 'rejected') {
              _auth.signOut();
              return LoginScreen();
            } else if (status == 'approved') {
              if (role == 'admin') {
                return AdminDashboard();
              } else if (role == 'user') {
                return UserScreen();
              } else {
                return Scaffold(
                  body: Center(
                    child: Text(
                      'Unknown role: $role',
                      style: TextStyle(fontSize: 20, color: Colors.red),
                    ),
                  ),
                );
              }
            } else {
              return Scaffold(
                body: Center(
                  child: Text(
                    'Unknown status: $status',
                    style: TextStyle(fontSize: 20, color: Colors.red),
                  ),
                ),
              );
            }
          },
        );
      },
    );
  }
}