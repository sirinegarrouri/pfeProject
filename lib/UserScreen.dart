import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class UserScreen extends StatefulWidget {
  @override
  _UserScreenState createState() => _UserScreenState();
}

class _UserScreenState extends State<UserScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool isDarkMode = false;
  String? userEmail;
  String? userPhone;
  String? userRole;
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _roleController = TextEditingController();

  // Fetch the authenticated user's UID and data
  Future<void> _getUserData() async {
    User? user = _auth.currentUser; // Get current authenticated user
    if (user != null) {
      var userDoc = await _firestore.collection('users').doc(user.uid).get(); // Use UID to fetch user data from Firestore
      if (userDoc.exists) {
        setState(() {
          // Set the user data
          userEmail = user.email;
          userPhone = userDoc['phone'];
          userRole = userDoc['role'];

          // Update controllers
          _emailController.text = userDoc['email'] ?? '';
          _phoneController.text = userDoc['phone'] ?? '';
          _roleController.text = userDoc['role'] ?? '';
        });
      }
    }
  }

  // Update user information in Firestore
  Future<void> _updateUserData() async {
    User? user = _auth.currentUser;
    if (user != null) {
      await _firestore.collection('users').doc(user.uid).update({
        'email': _emailController.text,
        'phone': _phoneController.text,
        'role': _roleController.text,
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('User information updated successfully!')),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _getUserData();
  }

  Widget _buildUserInfoForm() {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 15),
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: isDarkMode ? Colors.grey[900] : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(15.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'User Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
            ),
            SizedBox(height: 15),
            TextFormField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: 'Email',
                labelStyle: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                hintText: 'Enter your email',
                hintStyle: TextStyle(color: isDarkMode ? Colors.grey[400] : Colors.grey[600]),
                filled: true,
                fillColor: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                border: OutlineInputBorder(),
              ),
              style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
            ),
            SizedBox(height: 10),
            TextFormField(
              controller: _phoneController,
              decoration: InputDecoration(
                labelText: 'Phone',
                labelStyle: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                hintText: 'Enter your phone number',
                hintStyle: TextStyle(color: isDarkMode ? Colors.grey[400] : Colors.grey[600]),
                filled: true,
                fillColor: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                border: OutlineInputBorder(),
              ),
              style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
            ),
            SizedBox(height: 10),
            TextFormField(
              controller: _roleController,
              decoration: InputDecoration(
                labelText: 'Role',
                labelStyle: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                hintText: 'Enter your role',
                hintStyle: TextStyle(color: isDarkMode ? Colors.grey[400] : Colors.grey[600]),
                filled: true,
                fillColor: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                border: OutlineInputBorder(),
              ),
              style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _updateUserData,
              child: Text('Update Information'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                padding: EdgeInsets.symmetric(vertical: 12, horizontal: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Container(
        color: isDarkMode ? Colors.grey[900] : Colors.white,
        child: Column(
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blueAccent, Colors.lightBlue],
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person, color: Colors.white, size: 50),
                  const SizedBox(width: 10),
                  const Text('User Panel', style: TextStyle(color: Colors.white, fontSize: 24)),
                  const Spacer(),
                  Switch(
                    value: isDarkMode,
                    onChanged: (value) {
                      setState(() {
                        isDarkMode = value;
                      });
                    },
                  ),
                ],
              ),
            ),
            _buildDrawerItem(Icons.settings, "Settings", () {}),
            _buildDrawerItem(Icons.logout, "Logout", () async {
              await _auth.signOut(); // Log out the user
              Navigator.pushReplacementNamed(context, '/login'); // Navigate to login screen
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: isDarkMode ? Colors.white70 : Colors.black),
      title: Text(title, style: TextStyle(color: isDarkMode ? Colors.white : Colors.black)),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: isDarkMode ? Colors.black : Colors.grey[200],
      appBar: AppBar(
        title: const Text("User Dashboard"),
        backgroundColor: Colors.blueAccent,
      ),
      drawer: _buildDrawer(),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: userEmail == null // Check for userEmail instead of userName
            ? const Center(child: CircularProgressIndicator())
            : _buildUserInfoForm(),
      ),
    );
  }
}
