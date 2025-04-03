import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AdminScreen extends StatefulWidget {
  @override
  _AdminScreenState createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _notificationController = TextEditingController();
  bool _isDarkMode = false;
  bool _isSending = false;
  bool _isLoadingUsers = false;
  String? _selectedUserId;
  List<Map<String, dynamic>> _users = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _verifyAdminStatus();
  }

  Future<void> _verifyAdminStatus() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        _navigateToLogin();
        return;
      }

      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (!doc.exists || doc.data()?['role'] != 'admin') {
        setState(() => _errorMessage = 'Admin access required');
        await _auth.signOut();
        _navigateToLogin();
        return;
      }

      await _loadUsers();
    } on FirebaseException catch (e) {
      setState(() => _errorMessage = 'Error verifying admin status: ${e.message}');
    } catch (e) {
      setState(() => _errorMessage = 'Unexpected error: ${e.toString()}');
    }
  }

  void _navigateToLogin() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.pushReplacementNamed(context, '/login');
    });
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoadingUsers = true;
      _errorMessage = null;
    });

    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      final snapshot = await _firestore.collection('users').get();

      if (snapshot.size == 0) {
        throw Exception('No users found');
      }

      setState(() {
        _users = snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'email': data['email'] ?? 'No email',
            'role': data['role'] ?? 'No role',
            'name': data['name'] ?? 'No name',
          };
        }).toList();
      });
    } on FirebaseException catch (e) {
      setState(() => _errorMessage = 'Firestore error: ${e.message ?? e.code}');
    } catch (e) {
      setState(() => _errorMessage = 'Error loading users: ${e.toString()}');
    } finally {
      setState(() => _isLoadingUsers = false);
    }
  }

  Future<void> _sendNotification() async {
    if (_notificationController.text.isEmpty || _selectedUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a user and enter a message')),
      );
      return;
    }

    setState(() => _isSending = true);

    try {
      await _firestore.collection('notifications').add({
        'message': _notificationController.text,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
        'userId': _selectedUserId,
        'senderId': _auth.currentUser?.uid,
        'senderRole': 'admin',
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notification sent successfully')),
      );

      _notificationController.clear();
      setState(() => _selectedUserId = null);
    } on FirebaseException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Firestore error: ${e.message ?? e.code}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send: ${e.toString()}')),
      );
    } finally {
      setState(() => _isSending = false);
    }
  }

  Widget _buildUserDropdown() {
    if (_isLoadingUsers) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Column(
        children: [
          Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: _loadUsers,
            child: const Text('Retry'),
          ),
        ],
      );
    }

    if (_users.isEmpty) {
      return const Column(
        children: [
          Text('No users available', style: TextStyle(color: Colors.grey)),
          SizedBox(height: 10),
        ],
      );
    }

    return DropdownButtonFormField<String>(
      value: _selectedUserId,
      decoration: InputDecoration(
        labelText: 'Select User',
        border: const OutlineInputBorder(),
        filled: true,
        fillColor: _isDarkMode ? Colors.grey[800] : Colors.grey[200],
      ),
      items: _users.map((user) {
        return DropdownMenuItem<String>(
          value: user['id'],
          child: Text('${user['name']} (${user['email']})'),
        );
      }).toList(),
      onChanged: (value) => setState(() => _selectedUserId = value),
      validator: (value) => value == null ? 'Please select a user' : null,
    );
  }

  Widget _buildNotificationForm() {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Send Notification',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: _isDarkMode ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 16),
            _buildUserDropdown(),
            const SizedBox(height: 16),
            TextField(
              controller: _notificationController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Message',
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: _isDarkMode ? Colors.grey[800] : Colors.grey[200],
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isSending ? null : _sendNotification,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isSending
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Send Notification'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentNotifications() {
    return Expanded(
      child: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('notifications')
            .orderBy('timestamp', descending: true)
            .limit(10)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'No notifications sent yet',
                style: TextStyle(color: Colors.grey),
              ),
            );
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final timestamp = data['timestamp'] as Timestamp?;
              final date = timestamp != null
                  ? DateFormat('MMM d, y - h:mm a').format(timestamp.toDate())
                  : 'Unknown date';

              final user = _users.firstWhere(
                    (u) => u['id'] == data['userId'],
                orElse: () => {'name': 'Unknown', 'email': ''},
              );

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  leading: Icon(
                    data['read'] == true ? Icons.mark_email_read : Icons.mark_email_unread,
                    color: data['read'] == true ? Colors.green : Colors.blue,
                  ),
                  title: Text(data['message'] ?? 'No message'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('To: ${user['name']} (${user['email']})'),
                      Text(date),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteNotification(doc.id),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _deleteNotification(String id) async {
    try {
      await _firestore.collection('notifications').doc(id).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notification deleted')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete: ${e.toString()}')),
      );
    }
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Container(
        color: _isDarkMode ? Colors.grey[900] : Colors.white,
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
                    value: _isDarkMode,
                    onChanged: (value) => setState(() => _isDarkMode = value),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: Icon(Icons.people, color: _isDarkMode ? Colors.white70 : Colors.black),
              title: Text('User Management', style: TextStyle(color: _isDarkMode ? Colors.white : Colors.black)),
              onTap: () {},
            ),
            ListTile(
              leading: Icon(Icons.notifications, color: _isDarkMode ? Colors.white70 : Colors.black),
              title: Text('Notifications', style: TextStyle(color: _isDarkMode ? Colors.white : Colors.black)),
              onTap: () {},
            ),
            const Divider(),
            ListTile(
              leading: Icon(Icons.logout, color: _isDarkMode ? Colors.white70 : Colors.black),
              title: Text('Logout', style: TextStyle(color: _isDarkMode ? Colors.white : Colors.black)),
              onTap: () async {
                await _auth.signOut();
                Navigator.pushReplacementNamed(context, '/login');
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage == 'Admin access required') {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Admin access required', style: TextStyle(fontSize: 20)),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
                child: const Text('Go to Login'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadUsers,
          ),
        ],
      ),
      drawer: _buildDrawer(),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildNotificationForm(),
            const SizedBox(height: 16),
            Text(
              'Recent Notifications',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: _isDarkMode ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            _buildRecentNotifications(),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _notificationController.dispose();
    super.dispose();
  }
}