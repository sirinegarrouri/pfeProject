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
  List<Map<String, dynamic>> _notifications = [];
  List<Map<String, dynamic>> _events = [];
  List<Map<String, dynamic>> _alerts = [];
  String? _error;
  String _searchQuery = '';
  int _selectedTabIndex = 0;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    if (_auth.currentUser == null) {
      setState(() {
        _error = 'User not authenticated';
        _isLoading = false;
      });
      return;
    }
    setState(() => _isLoading = true);
    await Future.wait([
      _loadNotifications(),
      _loadEvents(),
      _loadAlerts(),
    ]);
    setState(() => _isLoading = false);
  }

  Future<void> _loadNotifications() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        setState(() {
          _error = 'User not authenticated';
          _isLoading = false;
        });
        return;
      }

      final snapshot = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .where('isEmergency', isEqualTo: false)
          .orderBy('timestamp', descending: true)
          .get();

      setState(() {
        _notifications = snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'message': data['message'] ?? 'No message',
            'timestamp': (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
            'read': data['read'] ?? false,
            'category': data['category'] ?? 'Nothing',
            'isEmergency': data['isEmergency'] ?? false,
          };
        }).toList();
      });
    } catch (e) {
      print('Error loading notifications: $e');
      setState(() {
        _error = 'Failed to load notifications';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadEvents() async {
    try {
      final snapshot = await _firestore
          .collection('events')
          .where('dateTime', isGreaterThan: Timestamp.now())
          .orderBy('dateTime', descending: true)
          .get();

      setState(() {
        _events = snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'title': data['title'] ?? 'Untitled',
            'description': data['description'] ?? 'No description',
            'dateTime': (data['dateTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
          };
        }).toList();
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
      if (userId == null) {
        print('No authenticated user found');
        return;
      }

      // Fetch from notifications collection (for backward compatibility)
      final notificationsSnapshot = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .where('isEmergency', isEqualTo: true)
          .orderBy('timestamp', descending: true)
          .get();

      // Fetch from alerts collection
      final alertsSnapshot = await _firestore
          .collection('alerts')
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .get();

      final alerts = <Map<String, dynamic>>[];

      // Process notifications
      for (var doc in notificationsSnapshot.docs) {
        final data = doc.data();
        alerts.add({
          'id': doc.id,
          'message': data['message'] ?? 'No message',
          'timestamp': (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
          'read': data['read'] ?? false,
          'category': data['category'] ?? 'Nothing',
          'isEmergency': data['isEmergency'] ?? true,
          'collection': 'notifications',
        });
      }

      // Process alerts
      for (var doc in alertsSnapshot.docs) {
        final data = doc.data();
        alerts.add({
          'id': doc.id,
          'message': data['message'] ?? 'No message',
          'timestamp': (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
          'read': data['read'] ?? false,
          'category': data['category'] ?? 'Nothing',
          'isEmergency': data['isEmergency'] ?? true,
          'collection': 'alerts',
        });
      }

      // Sort alerts by timestamp
      alerts.sort((a, b) => b['timestamp'].compareTo(a['timestamp']));

      setState(() {
        _alerts = alerts;
      });

      print('Loaded ${alerts.length} alerts for user $userId');
    } catch (e) {
      print('Error loading alerts: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load alerts')),
      );
    }
  }

  Future<void> _markAsRead(String id, String collection) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      final doc = await _firestore.collection(collection).doc(id).get();
      if (!doc.exists || doc.data()?['userId'] != userId) {
        print("Notification not found or access denied");
        return;
      }

      await _firestore.collection(collection).doc(id).update({
        'read': true,
        'readAt': FieldValue.serverTimestamp(),
      });

      await _loadData();
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
      for (final notification in _notifications) {
        if (!notification['read']) {
          batch.update(_firestore.collection('notifications').doc(notification['id']), {
            'read': true,
            'readAt': FieldValue.serverTimestamp(),
          });
        }
      }
      for (final alert in _alerts) {
        if (!alert['read']) {
          batch.update(_firestore.collection(alert['collection']).doc(alert['id']), {
            'read': true,
            'readAt': FieldValue.serverTimestamp(),
          });
        }
      }
      await batch.commit();
      await _loadData();
    } catch (e) {
      print('Error marking all as read: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to mark all as read')),
      );
    }
  }

  Future<void> _deleteNotification(String id, String collection) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      final doc = await _firestore.collection(collection).doc(id).get();
      if (!doc.exists || doc.data()?['userId'] != userId) {
        print("Notification doesn't exist or doesn't belong to user");
        return;
      }

      await _firestore.collection(collection).doc(id).delete();
      await _loadData();
    } catch (e) {
      print('Error deleting notification: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete notification')),
      );
    }
  }

  Color _getCategoryColor(String? category) {
    switch (category?.toLowerCase()) {
      case 'fire':
        return Colors.redAccent;
      case 'earthquake':
        return Colors.amber;
      case 'tsunami':
        return Colors.blue;
      case 'nothing':
      default:
        return Colors.teal;
    }
  }

  Widget _buildNotificationItem(Map<String, dynamic> item) {
    final message = item['message'];
    final isRead = item['read'];
    final category = item['category'];
    final timestamp = item['timestamp'] as DateTime;
    final date = DateFormat('MMM d, y h:mm a').format(timestamp);
    final isEmergency = item['isEmergency'];
    final id = item['id'];
    final collection = item['collection'];

    if (_searchQuery.isNotEmpty &&
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
            isEmergency ? Icons.warning : (isRead ? Icons.mark_email_read : Icons.mark_email_unread),
            size: 16,
            color: _getCategoryColor(category),
          ),
        ),
        title: Text(
          message,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: isRead ? FontWeight.normal : FontWeight.w600,
            color: isEmergency ? Colors.red : null,
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
          onPressed: () => _deleteNotification(id, collection),
        ),
        onTap: () => _markAsRead(id, collection),
      ),
    );
  }

  Widget _buildEventItem(Map<String, dynamic> item) {
    final title = item['title'];
    final description = item['description'];
    final timestamp = item['dateTime'] as DateTime;
    final date = DateFormat('MMM d, y h:mm a').format(timestamp);

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
            SizedBox(height: 8),
            TextButton(
              onPressed: _loadAlerts,
              child: Text('Refresh Alerts'),
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
            Tab(text: 'Alerts'),
          ],
          onTap: (index) {
            setState(() {
              _selectedTabIndex = index;
              _searchQuery = '';
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
                  children: _events.map((item) => SizedBox(
                    width: MediaQuery.of(context).size.width > 1200
                        ? 300
                        : MediaQuery.of(context).size.width > 800
                        ? 250
                        : MediaQuery.of(context).size.width / 2 - 18,
                    child: _buildEventItem(item),
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