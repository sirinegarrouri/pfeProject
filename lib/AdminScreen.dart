import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'UserDetailsScreen.dart';
import 'grades_reports_screen.dart';

class AdminScreen extends StatefulWidget {
  @override
  _AdminScreenState createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _notificationController = TextEditingController();

  bool isDarkMode = false;
  int _selectedPage = 0;
  String _searchQuery = '';

  bool _showAlert = false;
  String _alertMessage = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: isDarkMode ? Colors.black : Colors.grey[200],
      appBar: AppBar(
        title: Text("Admin Panel"),
        backgroundColor: Colors.blueAccent,
        actions: [
          IconButton(
            icon: Icon(isDarkMode ? Icons.wb_sunny : Icons.nightlight_round),
            onPressed: () {
              setState(() {
                isDarkMode = !isDarkMode;
              });
            },
          ),
        ],
      ),
      drawer: _buildDrawer(),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: _selectedPage == 0
                ? _buildBlankPage()
                : _selectedPage == 1
                ? _buildUsersPage()
                : _selectedPage == 2
                ? GradesReportsScreen()
                : Container(),
          ),
          _buildAlertSection(), // Optional floating alert banner
        ],
      ),
      floatingActionButton: _selectedPage == 1
          ? FloatingActionButton(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Add user functionality coming soon!")),
          );
        },
        child: Icon(Icons.add),
        backgroundColor: Colors.blueAccent,
      )
          : null,
    );
  }

  // Drawer
  Widget _buildDrawer() {
    return Drawer(
      child: Container(
        color: isDarkMode ? Colors.grey[900] : Colors.white,
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [Colors.blueAccent, Colors.lightBlue]),
              ),
              accountName: Text("Admin", style: TextStyle(fontSize: 18)),
              accountEmail: Text(FirebaseAuth.instance.currentUser?.email ?? ""),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.admin_panel_settings, color: Colors.blueAccent, size: 40),
              ),
            ),
            _buildDrawerItem(Icons.home, "Home", () {
              setState(() => _selectedPage = 0);
              Navigator.pop(context);
            }),
            _buildDrawerItem(Icons.list, "Users List", () {
              setState(() => _selectedPage = 1);
              Navigator.pop(context);
            }),
            _buildDrawerItem(Icons.grade, "Grades Report", () {
              setState(() => _selectedPage = 2);
              Navigator.pop(context);
            }),
            Divider(),
            _buildDrawerItem(Icons.logout, "Logout", () {
              _confirmLogout();
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

  // Home Page
  Widget _buildBlankPage() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.admin_panel_settings, size: 100, color: Colors.blueAccent),
          SizedBox(height: 20),
          Text(
            "Welcome, Admin!",
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black),
          ),
          SizedBox(height: 10),
          Text(
            "Select an option from the drawer to get started.",
            style: TextStyle(fontSize: 16, color: isDarkMode ? Colors.white70 : Colors.black87),
          ),
          SizedBox(height: 30),
          ElevatedButton.icon(
            icon: Icon(Icons.notifications_active),
            label: Text("Send Notification"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            onPressed: () {
              _showNotificationDialog();
            },
          ),
        ],
      ),
    );
  }

  // Users List Page
  Widget _buildUsersPage() {
    return Column(
      children: [
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search by email...',
            prefixIcon: Icon(Icons.search),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
              icon: Icon(Icons.clear),
              onPressed: () {
                _searchController.clear();
                setState(() => _searchQuery = '');
              },
            )
                : null,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onChanged: (value) {
            setState(() {
              _searchQuery = value.toLowerCase();
            });
          },
        ),
        SizedBox(height: 10),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _firestore.collection('users').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text("Error loading users"));
              }

              var users = snapshot.data!.docs.where((doc) {
                var data = doc.data() as Map<String, dynamic>;
                String email = (data['email'] ?? '').toString().toLowerCase();
                return email.contains(_searchQuery);
              }).toList();

              if (users.isEmpty) {
                return Center(child: Text("No users found"));
              }

              return ListView.builder(
                itemCount: users.length,
                itemBuilder: (context, index) {
                  var user = users[index].data() as Map<String, dynamic>;
                  var userId = users[index].id;

                  return Card(
                    margin: EdgeInsets.symmetric(vertical: 8, horizontal: 15),
                    elevation: 6,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    color: isDarkMode ? Colors.grey[900] : Colors.white,
                    child: ListTile(
                      contentPadding: EdgeInsets.all(15),
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
                            icon: Icon(Icons.edit, color: Colors.orange),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => UserDetailsScreen(userId: userId),
                                ),
                              );
                            },
                          ),
                          IconButton(
                            icon: Icon(Icons.delete, color: Colors.redAccent),
                            onPressed: () {
                              _confirmDeleteUser(userId);
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // Send Notification Dialog
  void _showNotificationDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Send Notification'),
          content: TextField(
            controller: _notificationController,
            decoration: InputDecoration(hintText: "Enter your message..."),
            maxLines: 3,
          ),
          actions: [
            TextButton(
              onPressed: () {
                _notificationController.clear();
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                _sendNotification();
              },
              child: Text('Send'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _sendNotification() async {
    final message = _notificationController.text.trim();

    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Notification message cannot be empty!')),
      );
      return;
    }

    try {
      await _firestore.collection('notifications').add({
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
        'sender': FirebaseAuth.instance.currentUser?.email ?? "Admin",
      });

      _notificationController.clear();
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Notification sent successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending notification: $e')),
      );
    }
  }

  // Confirm Delete User
  void _confirmDeleteUser(String userId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete User'),
        content: Text('Are you sure you want to delete this user?'),
        actions: [
          TextButton(
            child: Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            child: Text('Delete'),
            onPressed: () {
              _deleteUser(userId);
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _deleteUser(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).delete();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('User deleted successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting user: $e')),
      );
    }
  }

  // Optional Alert Banner (if needed)
  Widget _buildAlertSection() {
    return Visibility(
      visible: _showAlert,
      child: Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: Container(
          color: Colors.redAccent,
          padding: EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  _alertMessage,
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, color: Colors.white),
                onPressed: () {
                  setState(() => _showAlert = false);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Logout'),
        content: Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            child: Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            child: Text('Logout'),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
          ),
        ],
      ),
    );
  }
}
