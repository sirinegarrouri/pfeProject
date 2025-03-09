import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore
import 'auth_service.dart';
import 'firebase_options.dart';
import 'profile_screen.dart';
import 'AdminScreen.dart'; // Create AdminScreen
import 'UserScreen.dart'; // Create UserScreen

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

  bool isSignUp = false; // Permet de basculer entre Sign In et Sign Up

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

  void _signUp() async {
    User? user = await _authService.signUpWithEmail(
      emailController.text,
      passwordController.text,
    );
    if (user != null) {
      // Add the user to Firestore with the new fields
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'email': emailController.text,
        'phone': phoneController.text,
        'role': roleController.text,
      });

      // Fetch the user's role from Firestore
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        String role = userDoc['role']; // Get the role

        // Check the role and navigate accordingly
        if (role == 'admin') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => AdminScreen()), // Redirect to Admin screen
          );
        } else if (role == 'user') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => UserScreen()), // Redirect to User screen
          );
        } else {
          _showDialog("Error", "❌ Invalid role found.");
        }
      } else {
        _showDialog("Error", "❌ User data not found.");
      }

      _showDialog("Success", "✅ User signed up: ${user.email}");
    } else {
      _showDialog("Error", "❌ Sign-up failed");
    }
  }


  void _signIn() async {
    User? user = await _authService.signInWithEmail(
      emailController.text,
      passwordController.text,
    );
    if (user != null) {
      // Fetch the user's role from Firestore
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        String role = userDoc['role']; // Get the role

        // Check the role and navigate accordingly
        if (role == 'admin') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => AdminScreen()), // Redirect admin
          );
        } else if (role == 'user') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => UserScreen()), // Redirect regular user
          );
        } else {
          _showDialog("Error", "❌ Invalid role found.");
        }
      } else {
        _showDialog("Error", "❌ User data not found.");
      }
    } else {
      _showDialog("Error", "❌ Sign-in failed, Email or password is wrong");
    }
  }


  void _signOut() async {
    await _authService.signOut();
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
                    labelText: "Role",
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
                    isSignUp = !isSignUp; // Change de formulaire
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
    );
  }
}
