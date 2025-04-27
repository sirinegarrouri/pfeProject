import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'Admin/AdminScreen.dart';
import 'User/UserScreen.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Controllers
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final phoneController = TextEditingController();

  String _selectedRole = 'user'; // Default role for sign up
  bool _showSignUpForm = false; // Default to login form

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = false;

  // ---------------- LOGIN ----------------
  void _login() async {
    String email = emailController.text.trim();
    String password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showDialog("Error", "Please enter both email and password.");
      return;
    }

    setState(() => _isLoading = true);

    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user!;
      print("✅ Login successful: ${user.email} | UID: ${user.uid}");

      // Fetch user data from Firestore using UID
      DocumentSnapshot userDoc =
      await _firestore.collection('users').doc(user.uid).get();

      if (!userDoc.exists) {
        print("❌ No user data found for UID: ${user.uid}");
        _showDialog("Error", "No user data found. Please contact support.");
        setState(() => _isLoading = false);
        return;
      }

      // Extract the role from Firestore data
      String role = userDoc['role'] ?? 'user'; // Default to 'user' if not found
      print("✅ User role from Firestore: $role");

      // Save FCM token after successful login
      await _saveFcmToken(user);

      // Navigate based on role from Firestore
      await _navigateBasedOnRole(role);
    } catch (e) {
      print("❌ Login error: $e");
      _showDialog("Error", e.toString());
    }

    setState(() => _isLoading = false);
  }

  // ---------------- SIGN UP ----------------
  void _signUp() async {
    String email = emailController.text.trim();
    String password = passwordController.text.trim();
    String phone = phoneController.text.trim();

    if (email.isEmpty || password.isEmpty || phone.isEmpty) {
      _showDialog("Error", "Please fill all fields.");
      return;
    }

    if (!_isValidPhoneNumber(phone)) {
      _showDialog("Error", "Invalid phone number. It must be numeric and 8-15 digits.");
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Register the user with Firebase Authentication
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user!;
      print("✅ Sign-up successful: ${user.email} | UID: ${user.uid}");

      // Add the user data to Firestore
      await _firestore.collection('users').doc(user.uid).set({
        'email': email,
        'role': _selectedRole,
        'phone': phone,
      });

      // Save the FCM token
      await _saveFcmToken(user);

      // Show success dialog
      _showDialog("Success", "Account created successfully!");

      // Navigate based on selected role
      await _navigateBasedOnRole(_selectedRole);
    } catch (e) {
      print("❌ Sign-up error: $e");
      _showDialog("Error", e.toString());
    }

    setState(() => _isLoading = false);
  }

  Future<void> _navigateBasedOnRole(String role) async {
    if (role == 'admin') {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => AdminDashboard()));
    } else {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => UserScreen()));
    }
  }

  Future<void> _saveFcmToken(User user) async {
    try {
      String? token = await _messaging.getToken();
      if (token != null) {
        await _firestore.collection('users').doc(user.uid).update({
          'fcmToken': token,
        });
        print("✅ Token saved for ${user.uid}");
      }
    } catch (e) {
      print("❌ Error saving token: $e");
    }
  }

  // ---------------- VALIDATE PHONE ----------------
  bool _isValidPhoneNumber(String phone) {
    final numericRegex = RegExp(r'^[0-9]+$');
    return numericRegex.hasMatch(phone) && phone.length >= 8 && phone.length <= 15;
  }

  // ---------------- SHOW DIALOG ----------------
  void _showDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title, style: TextStyle(color: Colors.blue)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("OK", style: TextStyle(color: Colors.blue)),
          )
        ],
      ),
    );
  }

  // ---------------- UI BUILD ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 30.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.account_circle, size: 100.0, color: Colors.blue),
                  SizedBox(height: 20),

                  Text(
                    _showSignUpForm ? 'Create Account' : 'Welcome Back!',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[800],
                    ),
                  ),

                  SizedBox(height: 10),

                  Text(
                    _showSignUpForm ? 'Sign up to get started' : 'Login to continue',
                    style: TextStyle(fontSize: 16, color: Colors.blue[400]),
                  ),

                  SizedBox(height: 40),

                  _buildTextField(emailController, "Email", Icons.email_outlined, false),
                  SizedBox(height: 20),
                  _buildTextField(passwordController, "Password", Icons.lock_outline, true),

                  if (_showSignUpForm) ...[
                    SizedBox(height: 20),
                    _buildTextField(phoneController, "Phone Number", Icons.phone_android, false),
                    SizedBox(height: 20),
                    _buildRoleDropdown(),
                  ],

                  SizedBox(height: 30),

                  _buildButton(
                    _showSignUpForm ? "Sign Up" : "Sign In",
                    _showSignUpForm ? _signUp : _login,
                    Colors.blue[700]!,
                  ),

                  SizedBox(height: 15),

                  TextButton(
                    onPressed: () {
                      setState(() {
                        _showSignUpForm = !_showSignUpForm;
                        emailController.clear();
                        passwordController.clear();
                        phoneController.clear();
                      });
                    },
                    child: Text(
                      _showSignUpForm
                          ? 'Already have an account? Sign In'
                          : 'Don\'t have an account? Sign Up',
                      style: TextStyle(color: Colors.blue),
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: Center(child: CircularProgressIndicator(color: Colors.blue)),
            ),
        ],
      ),
    );
  }

  // ---------------- BUILD TEXT FIELD ----------------
  Widget _buildTextField(TextEditingController controller, String label, IconData icon, bool obscureText) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: label.contains("Phone") ? TextInputType.phone : TextInputType.text,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.blue),
        labelText: label,
        labelStyle: TextStyle(color: Colors.blue[800]),
        filled: true,
        fillColor: Colors.blue[50],
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.blue, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.blue.shade100),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  // ---------------- BUILD BUTTON ----------------
  Widget _buildButton(String text, VoidCallback onPressed, Color color) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 15),
          child: Text(
            text,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  // ---------------- BUILD ROLE DROPDOWN ----------------
  Widget _buildRoleDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedRole,
      decoration: InputDecoration(
        prefixIcon: Icon(Icons.person_outline, color: Colors.blue),
        labelText: 'Select Role',
        labelStyle: TextStyle(color: Colors.blue[800]),
        filled: true,
        fillColor: Colors.blue[50],
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.blue, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.blue.shade100),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      items: ['user', 'admin']
          .map((role) => DropdownMenuItem(value: role, child: Text(role.toUpperCase())))
          .toList(),
      onChanged: (value) {
        setState(() {
          _selectedRole = value!;
        });
      },
    );
  }
}
