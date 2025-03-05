import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'auth_service.dart';

class ProfileScreen extends StatefulWidget {
@override
_ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
final FirebaseAuth _auth = FirebaseAuth.instance;
final AuthService _authService = AuthService();
late User _user;
Map<String, dynamic>? _userData;

@override
void initState() {
super.initState();
_user = _auth.currentUser!;
_fetchUserData();
}

// Fetch user data from Firestore
Future<void> _fetchUserData() async {
DocumentSnapshot userDoc =
await FirebaseFirestore.instance.collection('users').doc(_user.uid).get();

if (userDoc.exists) {
setState(() {
_userData = userDoc.data() as Map<String, dynamic>;
_userData?['phone'] = _userData?['phone'] ?? 'Not set';
_userData?['role'] = _userData?['role'] ?? 'Not set';
});
}
}

// Edit profile function
void _editProfile() {
TextEditingController emailController = TextEditingController(text: _user.email);
TextEditingController phoneController = TextEditingController(text: _userData?['phone'] ?? '');
TextEditingController roleController = TextEditingController(text: _userData?['role'] ?? '');

showDialog(
context: context,
builder: (BuildContext context) {
return AlertDialog(
title: const Text("Edit Profile"),
content: SingleChildScrollView(
child: Column(
mainAxisSize: MainAxisSize.min,
children: [
TextField(
controller: emailController,
decoration: const InputDecoration(labelText: "Email"),
),
const SizedBox(height: 10),
TextField(
controller: phoneController,
decoration: const InputDecoration(labelText: "Phone"),
),
const SizedBox(height: 10),
TextField(
controller: roleController,
decoration: const InputDecoration(labelText: "Role"),
),
],
),
),
actions: [
TextButton(
onPressed: () {
Navigator.pop(context);
},
child: const Text("Cancel"),
),
TextButton(
onPressed: () async {
try {
await _user.updateEmail(emailController.text);
await FirebaseFirestore.instance
    .collection('users')
    .doc(_user.uid)
    .update({
'phone': phoneController.text,
'role': roleController.text,
});

setState(() {
_userData?['phone'] = phoneController.text;
_userData?['role'] = roleController.text;
});

Navigator.pop(context);
_showMessage("Profile updated successfully.");
} catch (e) {
_showMessage("Error updating profile: $e");
}
},
child: const Text("Update"),
),
],
);
},
);
}

// Show message dialog
void _showMessage(String message) {
showDialog(
context: context,
builder: (BuildContext context) {
return AlertDialog(
title: const Text("Message"),
content: Text(message),
actions: [
TextButton(
onPressed: () {
Navigator.pop(context);
},
child: const Text("OK"),
),
],
);
},
);
}

// Sign out function
void _signOut() async {
await _authService.signOut();
Navigator.pushReplacementNamed(context, '/');
}

@override
Widget build(BuildContext context) {
return Scaffold(
appBar: AppBar(
title: const Text("Profile"),
backgroundColor: Colors.blueAccent,
),
body: _userData == null
? const Center(child: CircularProgressIndicator())
    : Padding(
padding: const EdgeInsets.all(16.0),
child: Column(
children: [
Card(
elevation: 8.0,
shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(12.0),
),
child: Padding(
padding: const EdgeInsets.all(16.0),
child: Column(
children: [
// Smaller CircleAvatar
CircleAvatar(
radius: 40.0,
backgroundColor: Colors.grey[200],
child: Icon(
Icons.account_circle,
size: 80.0,
color: Colors.blueAccent,
),
),
const SizedBox(height: 20),
// Reduced spacing and font size for the profile section
Text(
'Email: ${_user.email}',
style: const TextStyle(
fontSize: 16,
fontWeight: FontWeight.bold,
),
),
const SizedBox(height: 10),
Text(
'Phone: ${_userData?['phone'] ?? 'Not set'}',
style: const TextStyle(fontSize: 14),
),
const SizedBox(height: 10),
Text(
'Role: ${_userData?['role'] ?? 'Not set'}',
style: const TextStyle(fontSize: 14),
),
const SizedBox(height: 20),
ElevatedButton(
style: ElevatedButton.styleFrom(
backgroundColor: Colors.blueAccent,
padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(10.0),
),
),
onPressed: _editProfile,
child: const Text(
"Edit Profile",
style: TextStyle(fontSize: 16),
),
),
const SizedBox(height: 15),
ElevatedButton(
style: ElevatedButton.styleFrom(
backgroundColor: Colors.redAccent,
padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(10.0),
),
),
onPressed: _signOut,
child: const Text(
"Sign Out",
style: TextStyle(fontSize: 16),
),
),
],
),
),
),
],
),
),
);
}
}