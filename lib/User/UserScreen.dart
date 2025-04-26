import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'reclamation_screen.dart';
import 'account_settings_screen.dart';
import 'reclamation_details_screen.dart';

class UserScreen extends StatefulWidget {
  @override
  _UserScreenState createState() => _UserScreenState();
}

class _UserScreenState extends State<UserScreen> with SingleTickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
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
      _loadEvents(),
      _loadAlerts(),
    ]);
    setState(() => _isLoading = false);
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

      final notificationsSnapshot = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .where('isEmergency', isEqualTo: true)
          .orderBy('timestamp', descending: true)
          .get();

      final alertsSnapshot = await _firestore
          .collection('alerts')
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .get();

      final alerts = <Map<String, dynamic>>[];

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

      alerts.sort((a, b) => b['timestamp'].compareTo(a['timestamp']));

      setState(() {
        _alerts = alerts;
      });
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
      final notificationsSnapshot = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .where('isEmergency', isEqualTo: false)
          .get();
      for (final doc in notificationsSnapshot.docs) {
        if (!(doc.data()['read'] ?? false)) {
          batch.update(_firestore.collection('notifications').doc(doc.id), {
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
      case 'reclamation update':
        return Colors.teal;
      case 'nothing':
      default:
        return Colors.grey;
    }
  }

  Widget _buildNotificationItem(Map<String, dynamic> item) {
    final message = item['message'] as String;
    final isRead = item['read'] as bool;
    final category = item['category'] as String;
    final timestamp = item['timestamp'] as DateTime;
    final date = DateFormat('MMM d, y h:mm a').format(timestamp);
    final isEmergency = item['isEmergency'] as bool;
    final id = item['id'] as String;
    final collection = item['collection'] as String;
    final reclamationId = item['reclamationId'] as String?;

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
            category == 'Reclamation Update'
                ? Icons.report
                : isEmergency
                ? Icons.warning
                : (isRead ? Icons.mark_email_read : Icons.mark_email_unread),
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
        onTap: () async {
          await _markAsRead(id, collection);
          if (category == 'Reclamation Update') {
            if (reclamationId != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ReclamationDetailsScreen(reclamationId: reclamationId),
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Reclamation details not available')),
              );
            }
          }
        },
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
                ? StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('notifications')
                  .where('userId', isEqualTo: _auth.currentUser?.uid)
                  .where('isEmergency', isEqualTo: false)
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                final notifications = snapshot.data?.docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return {
                    'id': doc.id,
                    'message': data['message'] ?? 'No message',
                    'timestamp': (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
                    'read': data['read'] ?? false,
                    'category': data['category'] ?? 'Nothing',
                    'isEmergency': data['isEmergency'] ?? false,
                    'reclamationId': data['reclamationId'],
                    'collection': 'notifications',
                  };
                }).toList() ??
                    [];
                if (notifications.isEmpty) {
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
                return Column(
                  children: [
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
                    Expanded(
                      child: ListView.builder(
                        itemCount: notifications.length,
                        itemBuilder: (context, index) => _buildNotificationItem(notifications[index]),
                      ),
                    ),
                  ],
                );
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