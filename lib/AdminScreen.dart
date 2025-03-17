import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'UserDetailsScreen.dart';
import 'grades_reports_screen.dart'; // Import Grades Report Screen

class AdminScreen extends StatefulWidget {
  @override
  _AdminScreenState createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool isDarkMode = false;
  int _selectedPage = 0; // 0 = Blank Page, 1 = Users Page, 2 = Grades Page

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: isDarkMode ? Colors.black : Colors.grey[200],
      appBar: AppBar(
        title: const Text("Admin Panel"),
        backgroundColor: Colors.blueAccent,
      ),
      drawer: _buildDrawer(),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: _selectedPage == 0
            ? _buildBlankPage() // Default page
            : _selectedPage == 1
            ? _buildUsersPage() // Users page
            : _selectedPage == 2
            ? GradesReportsScreen() // Corrected to call GradesReportsScreen
            : Container(), // Placeholder for future pages
      ),
    );
  }

  // 🔵 Drawer
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
                  const Icon(Icons.admin_panel_settings, color: Colors.white, size: 50),
                  const SizedBox(width: 10),
                  const Text('Admin Panel', style: TextStyle(color: Colors.white, fontSize: 24)),
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
            _buildDrawerItem(Icons.home, "Home", () {
              setState(() {
                _selectedPage = 0;
              });
              Navigator.pop(context);
            }),
            _buildDrawerItem(Icons.list, "Users List", () {
              setState(() {
                _selectedPage = 1;
              });
              Navigator.pop(context);
            }),
            _buildDrawerItem(Icons.grade, "Grades Report", () {
              setState(() {
                _selectedPage = 2;
              });
              Navigator.pop(context);
            }),
            _buildDrawerItem(Icons.logout, "Logout", () {
              _logout();
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

  // 🔵 Welcome Page
  Widget _buildBlankPage() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.admin_panel_settings, size: 100, color: Colors.blueAccent),
          const SizedBox(height: 20),
          Text(
            "Welcome, Admin!",
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            "Select an option from the drawer to get started.",
            style: TextStyle(
              fontSize: 16,
              color: isDarkMode ? Colors.white70 : Colors.black87,
            ),
          ),
          const SizedBox(height: 30),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
            ),
            icon: const Icon(Icons.list),
            label: const Text("View Users"),
            onPressed: () {
              setState(() {
                _selectedPage = 1;
              });
            },
          )
        ],
      ),
    );
  }

  // 🔵 Users Page (User List)
  Widget _buildUsersPage() {
    return StreamBuilder<QuerySnapshot>(
      stream: _getUsers(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(child: Text("Error loading users"));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("No users found"));
        }
        return _buildUserList(context, snapshot.data!);
      },
    );
  }

  // 🔵 Firestore stream for users
  Stream<QuerySnapshot> _getUsers() {
    return _firestore.collection('users').snapshots();
  }

  // 🔵 User list builder
  Widget _buildUserList(BuildContext context, QuerySnapshot snapshot) {
    return ListView.builder(
      itemCount: snapshot.docs.length,
      itemBuilder: (context, index) {
        var user = snapshot.docs[index].data() as Map<String, dynamic>;
        var userId = snapshot.docs[index].id;

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 15),
          elevation: 6,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          color: isDarkMode ? Colors.grey[900] : Colors.white,
          child: ListTile(
            contentPadding: const EdgeInsets.all(15),
            leading: CircleAvatar(
              backgroundColor: Colors.blueAccent,
              child: Icon(Icons.person, color: Colors.white),
            ),
            title: Text(
              user['email'] ?? "No Email",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("📞 ${user['phone'] ?? 'No Phone'}",
                    style: TextStyle(fontSize: 14, color: isDarkMode ? Colors.white70 : Colors.black87)),
                Text("🔹 Role: ${user['role'] ?? 'Unknown'}",
                    style: TextStyle(fontSize: 14, color: isDarkMode ? Colors.white70 : Colors.black87)),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.orange),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => UserDetailsScreen(userId: userId)),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () {
                    _confirmDelete(context, userId);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // 🔴 Delete Confirmation Dialog
  void _confirmDelete(BuildContext context, String userId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Confirm Deletion"),
          content: const Text("Are you sure you want to delete this user?"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // ❌ Close dialog
              },
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () async {
                await _firestore.collection('users').doc(userId).delete();
                Navigator.of(context).pop(); // ✅ Close dialog
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("User deleted successfully")),
                );
              },
              child: const Text("Delete", style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  // 🔵 Logout functionality
  void _logout() async {
    try {
      await FirebaseAuth.instance.signOut();
      Navigator.of(context).pushReplacementNamed('/login');
    } catch (e) {
      print("Error logging out: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to log out")),
      );
    }
  }
}
