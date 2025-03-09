import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class UserDetailsScreen extends StatefulWidget {
  final String userId;
  UserDetailsScreen({required this.userId});

  @override
  _UserDetailsScreenState createState() => _UserDetailsScreenState();
}

class _UserDetailsScreenState extends State<UserDetailsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isEditing = false; // Toggle between edit mode and view mode
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _roleController;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
    _phoneController = TextEditingController();
    _roleController = TextEditingController();
    _loadUserData();
  }

  // Fetch user details by ID
  Future<void> _loadUserData() async {
    DocumentSnapshot doc = await _firestore.collection('users').doc(widget.userId).get();
    var userData = doc.data() as Map<String, dynamic>;

    _emailController.text = userData['email'];
    _phoneController.text = userData['phone'];
    _roleController.text = userData['role'];
  }

  // Save the edited data
  void _saveUserData() async {
    await _firestore.collection('users').doc(widget.userId).update({
      'email': _emailController.text,
      'phone': _phoneController.text,
      'role': _roleController.text,
    });

    setState(() {
      _isEditing = false;
    });

    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("User details updated successfully!")),
    );
  }

  // Function to delete the user
  Future<void> _deleteUser() async {
    await _firestore.collection('users').doc(widget.userId).delete();
    Navigator.pop(context); // Return to previous screen after deletion
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("User deleted successfully!")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("User Details"),
        backgroundColor: Colors.blueAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: FutureBuilder<DocumentSnapshot>(
          future: _firestore.collection('users').doc(widget.userId).get(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return const Center(child: Text("Error loading user details"));
            }

            if (!snapshot.hasData) {
              return const Center(child: Text("User not found"));
            }

            var user = snapshot.data!.data() as Map<String, dynamic>;

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // User details
                  _isEditing
                      ? TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: "Email",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email),
                    ),
                  )
                      : Text(
                    "Email: ${user['email']}",
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _isEditing
                      ? TextFormField(
                    controller: _phoneController,
                    decoration: const InputDecoration(
                      labelText: "Phone Number",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.phone),
                    ),
                  )
                      : Text(
                    "Phone: ${user['phone']}",
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _isEditing
                      ? TextFormField(
                    controller: _roleController,
                    decoration: const InputDecoration(
                      labelText: "Role",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                  )
                      : Text(
                    "Role: ${user['role']}",
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  // Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Save button only visible in edit mode
                      if (_isEditing)
                        ElevatedButton(
                          onPressed: _saveUserData,
                          child: const Text("Save Changes"),
                        ),
                      // Edit button visible only in view mode
                      if (!_isEditing)
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _isEditing = true; // Toggle to edit mode
                            });
                          },
                          child: const Text("Edit"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange, // Customize color for edit button
                          ),
                        ),
                      // Delete button visible in view mode
                      if (!_isEditing)
                        ElevatedButton(
                          onPressed: () {
                            _deleteUser();
                          },
                          child: const Text("Delete"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red, // Red color for delete button
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
