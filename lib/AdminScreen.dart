import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // For nice date formatting
import 'UserDetailsScreen.dart';
import 'grades_reports_screen.dart'; // Grades Report Screen

class AdminScreen extends StatefulWidget {
  @override
  _AdminScreenState createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();

  bool isDarkMode = false;
  int _selectedPage = 0;
  String _searchQuery = '';

  // Variables for the alert section
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
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: _selectedPage == 0
            ? _buildBlankPage()
            : _selectedPage == 1
            ? _buildUsersPage()
            : _selectedPage == 2
            ? GradesReportsScreen()
            : Container(),
      ),
      floatingActionButton: _selectedPage == 1
          ? FloatingActionButton(
        onPressed: () {
          // Future: Navigate to Add User Page
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

  // Widget for alert section (floating banner)
  Widget _buildAlertSection() {
    return Visibility(
      visible: _showAlert, // Show or hide based on the state
      child: Container(
        color: Colors.redAccent,
        padding: EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _alertMessage,
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: Icon(Icons.close, color: Colors.white),
              onPressed: () {
                setState(() {
                  _showAlert = false;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  // Function to show the alert

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
        ],
      ),
    );
  }

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
                          Text("📞 ${user['phone'] ?? 'No Phone'}", style: TextStyle(fontSize: 14, color: isDarkMode ? Colors.white70 : Colors.black87)),
                          Text("🔹 Role: ${user['role'] ?? 'Unknown'}", style: TextStyle(fontSize: 14, color: isDarkMode ? Colors.white70 : Colors.black87)),
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
                                MaterialPageRoute(builder: (context) => UserDetailsScreen(userId: userId)),
                              );
                            },
                          ),
                          IconButton(
                            icon: Icon(Icons.delete, color: Colors.red),
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
            },
          ),
        ),
      ],
    );
  }

  void _confirmDelete(BuildContext context, String userId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Confirm Deletion"),
          content: Text("Are you sure you want to delete this user?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text("Cancel"),
            ),
            TextButton(
              onPressed: () async {
                await _firestore.collection('users').doc(userId).delete();
                Navigator.of(context).pop();
                _showAlert;  // Show alert section
              },
              child: Text("Delete", style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Logout"),
        content: Text("Are you sure you want to log out?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.of(context).pushReplacementNamed('/login');
            },
            child: Text("Logout", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
