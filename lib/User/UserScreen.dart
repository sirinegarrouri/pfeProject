import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'reclamation_screen.dart';
import 'account_settings_screen.dart';

class UserScreen extends StatefulWidget {
  @override
  _UserScreenState createState() => _UserScreenState();
}

class _UserScreenState extends State<UserScreen> with SingleTickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  List<DocumentSnapshot> _notifications = [];
  List<DocumentSnapshot> _events = [];
  List<DocumentSnapshot> _alerts = []; // New list for alerts
  String? _error;
  String _searchQuery = '';
  int _selectedTabIndex = 0;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this); // Updated to 3 tabs
    _loadData();
  }

  Future<void> _loadData() async {
    await Future.wait([
      _loadNotifications(),
      _loadEvents(),
      _loadAlerts(), // New method for alerts
    ]);
  }

  Future<void> _loadNotifications() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        setState(() {
          _error = 'User not authenticated';
          _isLoading = false;
        });
        return;
      }

      final query = _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true);
      final snapshot = await query.get();

      setState(() {
        _notifications = snapshot.docs;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
      print('Error loading notifications: $e');
    }
  }

  Future<void> _loadEvents() async {
    try {
      final query = _firestore
          .collection('events')
          .where('dateTime', isGreaterThan: Timestamp.now())
          .orderBy('dateTime', descending: true);
      final snapshot = await query.get();

      setState(() {
        _events = snapshot.docs;
      });
    } catch (e) {
      print('Error loading events: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load events')),
      );
    }
  }

  Future<void> _loadAlerts() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      final query = _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .where('category', isEqualTo: 'Alert')
          .orderBy('timestamp', descending: true);
      final snapshot = await query.get();

      setState(() {
        _alerts = snapshot.docs;
      });
    } catch (e) {
      print('Error loading alerts: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load alerts')),
      );
    }
  }

  Future<void> _markAsRead(String notificationId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      final doc = await _firestore.collection('notifications').doc(notificationId).get();
      if (!doc.exists || doc.data()?['userId'] != userId) {
        print("Notification not found or access denied");
        return;
      }

      await _firestore.collection('notifications').doc(notificationId).update({
        'read': true,
        'readAt': FieldValue.serverTimestamp(),
      });

      await Future.wait([
        _loadNotifications(),
        _loadAlerts(), // Refresh alerts too
      ]);
    } catch (e) {
      print('Error marking as read: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to mark as read')),
      );
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      final batch = _firestore.batch();
      for (final doc in _notifications) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['userId'] == userId && !(data['read'] ?? false)) {
          batch.update(_firestore.collection('notifications').doc(doc.id), {
            'read': true,
            'readAt': FieldValue.serverTimestamp(),
          });
        }
      }
      await batch.commit();
      await Future.wait([
        _loadNotifications(),
        _loadAlerts(), // Refresh alerts too
      ]);
    } catch (e) {
      print('Error marking all as read: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to mark all as read')),
      );
    }
  }

  Future<void> _deleteNotification(String notificationId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      final doc = await _firestore.collection('notifications').doc(notificationId).get();
      if (!doc.exists || doc.data()?['userId'] != userId) {
        print("Notification doesn't exist or doesn't belong to user");
        return;
      }

      await _firestore.collection('notifications').doc(notificationId).delete();
      await Future.wait([
        _loadNotifications(),
        _loadAlerts(), // Refresh alerts too
      ]);
    } catch (e) {
      print('Error deleting notification: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete notification')),
      );
    }
  }

  Color _getCategoryColor(String? category) {
    switch (category) {
      case 'Alert':
        return Colors.red; // Distinct color for alerts
      case 'Fire':
        return Colors.redAccent;
      case 'Earthquake':
        return Colors.amber;
      case 'Tsunami':
        return Colors.blue;
      case 'Event':
        return Colors.green;
      default:
        return Colors.teal;
    }
  }

  Widget _buildNotificationItem(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final message = data['message'] ?? 'No message';
    final isRead = data['read'] ?? false;
    final category = data['category'] as String? ?? 'Nothing';
    final timestamp = data['timestamp'] as Timestamp?;
    final date = timestamp != null
        ? DateFormat('MMM d, y h:mm a').format(timestamp.toDate())
        : 'Unknown date';

    // Always show alerts, even if they don't match the search query
    if (_searchQuery.isNotEmpty &&
        category != 'Alert' &&
        !message.toLowerCase().contains(_searchQuery.toLowerCase())) {
      return SizedBox.shrink();
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 3,
      margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: ListTile(
        leading: CircleAvatar(
          radius: 16,
          backgroundColor: _getCategoryColor(category).withOpacity(0.2),
          child: Icon(
            isRead ? Icons.mark_email_read : Icons.mark_email_unread,
            size: 16,
            color: _getCategoryColor(category),
          ),
        ),
        title: Text(
          message,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: isRead ? FontWeight.normal : FontWeight.w600,
            color: category == 'Alert' ? Colors.red : null, // Highlight alerts
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '$date • $category',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Colors.black45,
          ),
        ),
        trailing: IconButton(
          icon: Icon(Icons.delete, color: Colors.red, size: 20),
          onPressed: () => _deleteNotification(doc.id),
        ),
        onTap: () => _markAsRead(doc.id),
      ),
    );
  }

  Widget _buildEventItem(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final title = data['title'] ?? 'Untitled';
    final description = data['description'] ?? 'No description';
    final timestamp = data['dateTime'] as Timestamp?;
    final date = timestamp != null
        ? DateFormat('MMM d, y h:mm a').format(timestamp.toDate())
        : 'Unknown date';

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 3,
      margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 4),
            Text(
              description,
              style: Theme.of(context).textTheme.bodyMedium,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 4),
            Text(
              'When: $date',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.black45,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
            SizedBox(height: 16),
            Text(
              'Error loading data',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey,
              ),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadData,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text('Retry', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      );
    }

    if (_selectedTabIndex == 0 && _notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_off, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No notifications yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      );
    }

    if (_selectedTabIndex == 1 && _events.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No upcoming events',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      );
    }

    if (_selectedTabIndex == 2 && _alerts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.warning_amber, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No alerts yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search notifications...',
              prefixIcon: Icon(Icons.search, size: 20),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: EdgeInsets.symmetric(vertical: 10),
            ),
            style: Theme.of(context).textTheme.bodyMedium,
            onChanged: (value) => setState(() => _searchQuery = value),
          ),
        ),
        if (_selectedTabIndex == 0 && _notifications.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: _markAllAsRead,
                  icon: Icon(Icons.mark_email_read, size: 16),
                  label: Text('Mark all as read', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
        TabBar(
          controller: _tabController,
          labelStyle: Theme.of(context).textTheme.bodyMedium,
          unselectedLabelColor: Colors.black54,
          labelColor: Colors.teal,
          indicatorColor: Colors.teal,
          tabs: [
            Tab(text: 'Notifications'),
            Tab(text: 'Events'),
            Tab(text: 'Alerts'), // New tab
          ],
          onTap: (index) {
            setState(() {
              _selectedTabIndex = index;
              _searchQuery = ''; // Reset search when switching tabs
            });
          },
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadData,
            child: _selectedTabIndex == 0
                ? ListView.builder(
              itemCount: _notifications.length,
              itemBuilder: (context, index) {
                return _buildNotificationItem(_notifications[index]);
              },
            )
                : _selectedTabIndex == 1
                ? SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: _events.map((doc) => SizedBox(
                    width: MediaQuery.of(context).size.width > 1200
                        ? 300
                        : MediaQuery.of(context).size.width > 800
                        ? 250
                        : MediaQuery.of(context).size.width / 2 - 18,
                    child: _buildEventItem(doc),
                  )).toList(),
                ),
              ),
            )
                : ListView.builder(
              itemCount: _alerts.length,
              itemBuilder: (context, index) {
                return _buildNotificationItem(_alerts[index]);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.teal, Colors.tealAccent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.person, size: 32, color: Colors.teal),
                ),
                SizedBox(height: 8),
                Text(
                  'User Panel',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Welcome back',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: Icon(Icons.notifications, size: 20),
            title: Text('Notifications', style: Theme.of(context).textTheme.bodyMedium),
            selected: true,
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: Icon(Icons.report_problem, size: 20),
            title: Text('Reclamation', style: Theme.of(context).textTheme.bodyMedium),
            onTap: _navigateToReclamation,
          ),
          ListTile(
            leading: Icon(Icons.settings, size: 20),
            title: Text('Account Settings', style: Theme.of(context).textTheme.bodyMedium),
            onTap: _navigateToAccountSettings,
          ),
          Divider(),
          ListTile(
            leading: Icon(Icons.exit_to_app, size: 20),
            title: Text('Sign Out', style: Theme.of(context).textTheme.bodyMedium),
            onTap: () async {
              await _auth.signOut();
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  void _navigateToReclamation() {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ReclamationScreen()),
    );
  }

  void _navigateToAccountSettings() {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AccountSettingsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _selectedTabIndex == 0
              ? 'Notifications'
              : _selectedTabIndex == 1
              ? 'Events'
              : 'Alerts',
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, size: 20),
            onPressed: _loadData,
          ),
        ],
      ),
      drawer: _buildDrawer(),
      body: _buildBody(),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}