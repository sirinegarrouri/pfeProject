import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../Admin/AdminScreen.dart';
import '../User/UserScreen.dart';
import 'LoginScreen.dart';

class WaitingPage extends StatefulWidget {
  @override
  _WaitingPageState createState() => _WaitingPageState();
}

class _WaitingPageState extends State<WaitingPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Timer? _statusCheckTimer;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Start periodically checking the user's status
    _startStatusCheck();
  }

  @override
  void dispose() {
    _statusCheckTimer?.cancel();
    super.dispose();
  }

  void _startStatusCheck() {
    _statusCheckTimer = Timer.periodic(Duration(seconds: 10), (timer) async {
      if (_isLoading) return;
      await _checkUserStatus();
    });
  }

  Future<void> _checkUserStatus() async {
    setState(() => _isLoading = true);
    try {
      final user = _auth.currentUser;
      if (user == null) {
        _navigateToLogin();
        return;
      }

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) {
        _showDialog("Error", "User data not found. Please contact support.");
        await _auth.signOut();
        _navigateToLogin();
        return;
      }

      final status = userDoc['status'] ?? 'pending';
      final role = userDoc['role'] ?? 'user';

      if (status == 'approved') {
        _statusCheckTimer?.cancel();
        await _navigateBasedOnRole(role);
      } else if (status == 'rejected') {
        _statusCheckTimer?.cancel();
        _showDialog("Error", "Your account was rejected by the admin.");
        await _auth.signOut();
        _navigateToLogin();
      }
    } catch (e) {
      print("Error checking status: $e");
      _showDialog("Error", "Failed to check status: ${e.toString()}");
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

  void _navigateToLogin() {
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => LoginScreen()));
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
          ),
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
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 30.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.hourglass_empty, size: 100.0, color: Colors.blue),
                  SizedBox(height: 20),
                  Text(
                    'Awaiting Approval',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[800],
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Your account is under review by an admin.\nYou will be notified once approved.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.blue[400]),
                  ),
                  SizedBox(height: 30),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _checkUserStatus,
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                      child: Text(
                        'Check Status Now',
                        style: TextStyle(fontSize: 18, color: Colors.white),
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[700],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  SizedBox(height: 15),
                  TextButton(
                    onPressed: () async {
                      await _auth.signOut();
                      _navigateToLogin();
                    },
                    child: Text(
                      'Sign Out',
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
}