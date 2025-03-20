import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'auth_service.dart';
import 'firebase_options.dart';
import 'AdminScreen.dart';
import 'UserScreen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 15),
            backgroundColor: Colors.blueAccent,
          ),
        ),
      ),
      home: AuthScreen(),
      routes: {
        '/login': (context) => AuthScreen(),
        '/admin': (context) => AdminScreen(),
        '/user': (context) => UserScreen(),
      },
    );
  }
}

class AuthScreen extends StatefulWidget {
  @override
  _AuthScreenState createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController roleController = TextEditingController();

  bool isSignUp = false;

  void _showDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text("OK"),
            ),
          ],
        );
      },
    );
  }
  void _initFirebaseMessaging() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    // Get the token
    String? token = await messaging.getToken();

    if (token != null) {
      print('🔥 Device FCM Token: $token');

      // Show it in a popup dialog (optional)
      _showDialog("Device FCM Token", token);
    }

    // Listen for token refresh (optional)
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      print('🔄 Token refreshed: $newToken');
    });
  }
  @override
  void initState() {
    super.initState();

    _initFirebaseMessaging();  // ➡️ Get FCM token when screen loads
  }

  // Get the FCM token and save it to Firestore
  Future<void> _saveFcmToken(User user) async {
    String? fcmToken = await FirebaseMessaging.instance.getToken();
    if (fcmToken != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'fcmToken': fcmToken,
      });
    }
  }


  // SIGN UP
  // SIGN UP
  // SIGN UP
  void _signUp() async {
    String email = emailController.text.trim();
    String password = passwordController.text.trim();
    String phone = phoneController.text.trim();
    String role = roleController.text.trim().toLowerCase();

    if (email.isEmpty || password.isEmpty || phone.isEmpty || role.isEmpty) {
      _showDialog("Error", "❌ All fields are required for sign up.");
      return;
    }

    if (role != 'admin' && role != 'user') {
      _showDialog("Error", "❌ Please enter a valid role (admin/user).");
      return;
    }

    try {
      User? user = await _authService.signUpWithEmail(email, password);

      if (user == null) {
        _showDialog("Error", "❌ Sign-up failed. Please try again.");
        return;
      }

      // Save user info to Firestore
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'email': email,
        'phone': phone,
        'role': role,
      });

      // Save FCM token
      await _saveFcmToken(user);

      print('✅ User signed up with role: $role');

      if (!mounted) return;

      // Navigate to respective screen
      _navigateBasedOnRole(role);
    } catch (e) {
      print('❌ Sign-up error: $e');
      if (!mounted) return;
      _showDialog("Error", "❌ ${e.toString()}");
    }
  }

// SIGN IN
  void _signIn() async {
    String email = emailController.text.trim();
    String password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showDialog("Error", "❌ Email and password are required.");
      return;
    }

    try {
      User? user = await _authService.signInWithEmail(email, password);

      if (user == null) {
        _showDialog("Error", "❌ Sign-in failed. Email or password is incorrect.");
        return;
      }

      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        _showDialog("Error", "❌ User data not found in the database.");
        return;
      }

      String role = userDoc.get('role').toString().toLowerCase();

      print('✅ Signed in as $role');

      if (!mounted) return;

      // Navigate to respective screen
      _navigateBasedOnRole(role);
    } catch (e) {
      print('❌ Sign-in error: $e');
      if (!mounted) return;
      _showDialog("Error", "❌ ${e.toString()}");
    }
  }

// Navigate based on role
  void _navigateBasedOnRole(String role) {
    if (role == 'admin') {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => AdminScreen()),
      );
    } else if (role == 'user') {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => UserScreen()),
      );
    } else {
      _showDialog("Error", "❌ Invalid role. Contact support.");
    }
  }


  void _signOut() async {
    await _authService.signOut();
    if (!mounted) return;
    _showDialog("Success", "👋 User signed out");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Alertii"),
        backgroundColor: Colors.blueAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: "Email",
                    prefixIcon: Icon(Icons.email),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: "Password",
                    prefixIcon: Icon(Icons.lock),
                  ),
                ),
                if (isSignUp) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: phoneController,
                    decoration: const InputDecoration(
                      labelText: "Phone Number",
                      prefixIcon: Icon(Icons.phone),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: roleController,
                    decoration: const InputDecoration(
                      labelText: "Role (admin/user)",
                      prefixIcon: Icon(Icons.person),
                    ),
                  ),
                ],
                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: isSignUp ? _signUp : _signIn,
                  child: Text(isSignUp ? "Sign Up" : "Sign In"),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    setState(() {
                      isSignUp = !isSignUp;
                    });
                  },
                  child: Text(
                    isSignUp
                        ? "Already have an account? Sign In"
                        : "Don't have an account? Sign Up",
                  ),
                ),
                const SizedBox(height: 16),
                if (!isSignUp)
                  ElevatedButton(
                    onPressed: _signOut,
                    child: const Text("Sign Out"),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
