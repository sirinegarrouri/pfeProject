import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../Admin/AdminScreen.dart';
import '../User/UserScreen.dart';
import 'waiting_page.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final phoneController = TextEditingController();

  String _selectedRole = 'user';
  bool _showSignUpForm = false;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  bool _isLoading = false;

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

      DocumentSnapshot userDoc =
      await _firestore.collection('users').doc(user.uid).get();

      if (!userDoc.exists) {
        print("❌ No user data found for UID: ${user.uid}");
        _showDialog("Error", "No user data found. Please contact support.");
        setState(() => _isLoading = false);
        return;
      }

      String role = userDoc['role'] ?? 'user';
      String status = userDoc['status'] ?? 'pending';
      print("✅ User role: $role | Status: $status");

      await _saveFcmToken(user);

      if (status == 'pending') {
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => WaitingPage()));
      } else if (status == 'approved') {
        await _navigateBasedOnRole(role);
      } else if (status == 'rejected') {
        _showDialog("Error", "Your account was rejected by the admin.");
        await _auth.signOut();
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => LoginScreen()));
      }
    } catch (e) {
      print("❌ Login error: $e");
      _showDialog("Error", e.toString());
    }

    setState(() => _isLoading = false);
  }

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
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user!;
      print("✅ Sign-up successful: ${user.email} | UID: ${user.uid}");

      await _firestore.collection('users').doc(user.uid).set({
        'email': email,
        'role': _selectedRole,
        'phone': phone,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      await _saveFcmToken(user);

      _showDialog("Success", "Account created successfully! Waiting for admin approval.");

      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => WaitingPage()));
    } catch (e) {
      print("❌ Sign-up error: $e");
      _showDialog("Error", e.toString());
    }

    setState(() => _isLoading = false);
  }

  void _signInWithGoogle() async {
    setState(() => _isLoading = true);

    try {
      print("Initializing Google Sign-In...");
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        print("Google Sign-In canceled by user");
        setState(() => _isLoading = false);
        return;
      }

      print("Google Sign-In user: ${googleUser.email}");
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user!;
      print("✅ Google Sign-In successful: ${user.email} | UID: ${user.uid}");

      DocumentSnapshot userDoc =
      await _firestore.collection('users').doc(user.uid).get();

      if (!userDoc.exists) {
        await _firestore.collection('users').doc(user.uid).set({
          'email': user.email,
          'role': 'user',
          'phone': '',
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
        });
        print("✅ New user added to Firestore: ${user.uid}");
      } else {
        print("✅ Existing user found: ${user.uid}");
      }

      await _saveFcmToken(user);

      userDoc = await _firestore.collection('users').doc(user.uid).get();
      String role = userDoc['role'] ?? 'user';
      String status = userDoc['status'] ?? 'pending';

      if (status == 'pending') {
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => WaitingPage()));
      } else if (status == 'approved') {
        await _navigateBasedOnRole(role);
      } else if (status == 'rejected') {
        _showDialog("Error", "Your account was rejected by the admin.");
        await _auth.signOut();
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => LoginScreen()));
      }
    } catch (e) {
      print("❌ Google Sign-In error: $e");
      _showDialog("Error", e.toString());
    }

    setState(() => _isLoading = false);
  }

  Future<void> _navigateBasedOnRole(String role) async {
    if (role == 'admin') {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => AdminDashboard()));
    } else {
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => UserScreen()));
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

  bool _isValidPhoneNumber(String phone) {
    final numericRegex = RegExp(r'^[0-9]+$');
    return numericRegex.hasMatch(phone) && phone.length >= 8 && phone.length <= 15;
  }

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
                  _buildTextField(
                      emailController, "Email", Icons.email_outlined, false),
                  SizedBox(height: 20),
                  _buildTextField(
                      passwordController, "Password", Icons.lock_outline, true),
                  if (_showSignUpForm) ...[
                    SizedBox(height: 20),
                    _buildTextField(phoneController, "Phone Number",
                        Icons.phone_android, false),
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
                  _buildGoogleSignInButton(),
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

  Widget _buildTextField(TextEditingController controller, String label,
      IconData icon, bool obscureText) {
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

  Widget _buildButton(String text, VoidCallback onPressed, Color color) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 15),
          child: Text(
            text,
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
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

  Widget _buildGoogleSignInButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: _signInWithGoogle,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 15),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/google_logo.png',
                height: 24,
              ),
              SizedBox(width: 10),
              Text(
                'Sign in with Google',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.blue[700],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.blue[700]!),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

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