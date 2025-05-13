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
    _tabController = TabController(length: 4, vsync: this, initialIndex: 0);
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
            'category': data['category'] ?? 'General',
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
          'reclamationId': data['reclamationId'],
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
          'reclamationId': data['reclamationId'],
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
      if (userId == null) {
        print('No authenticated user');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please sign in to mark notifications as read')),
        );
        return;
      }

      print('Attempting to mark as read with user: $userId, collection: $collection, id: $id');

      final docRef = _firestore.collection(collection).doc(id);
      final doc = await docRef.get();
      if (!doc.exists) {
        print('Notification not found: $id in $collection');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Notification not found')),
        );
        return;
      }
      final docData = doc.data() as Map<String, dynamic>?;
      if (docData == null || docData['userId'] != userId) {
        print('Access denied: Notification $id does not belong to user $userId, doc userId: ${docData?['userId']}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('You do not have permission to mark this notification as read')),
        );
        return;
      }

      await docRef.update({
        'read': true,
        'readAt': FieldValue.serverTimestamp(),
      });
      print('Successfully marked notification $id as read');
      setState(() {}); // Refresh UI
    } catch (e) {
      print('Error marking as read: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to mark as read: $e')),
      );
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        print('No authenticated user');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please sign in to mark notifications as read')),
        );
        return;
      }

      print('Marking all as read for user: $userId');

      final batch = _firestore.batch();

      // Fetch notifications
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

      // Fetch alerts
      final alertsSnapshot = await _firestore
          .collection('alerts')
          .where('userId', isEqualTo: userId)
          .get();
      for (final doc in alertsSnapshot.docs) {
        if (!(doc.data()['read'] ?? false)) {
          batch.update(_firestore.collection('alerts').doc(doc.id), {
            'read': true,
            'readAt': FieldValue.serverTimestamp(),
          });
        }
      }

      await batch.commit();
      print('Successfully marked all notifications and alerts as read');
      setState(() {}); // Refresh UI
    } catch (e) {
      print('Error marking all as read: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to mark all as read: $e')),
      );
    }
  }

  Future<void> _deleteNotification(String id, String collection) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        print('No authenticated user');
        return;
      }

      final doc = await _firestore.collection(collection).doc(id).get();
      if (!doc.exists || doc.data()?['userId'] != userId) {
        print("Notification doesn't exist or doesn't belong to user: $id");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cannot delete this notification')),
        );
        return;
      }

      await _firestore.collection(collection).doc(id).delete();
      print('Successfully deleted notification $id');
      setState(() {}); // Refresh UI
    } catch (e) {
      print('Error deleting notification: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete notification: $e')),
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
      case 'general':
      default:
        return Colors.grey;
    }
  }

  IconData _getCategoryIcon(String? category) {
    switch (category?.toLowerCase()) {
      case 'fire':
        return Icons.local_fire_department;
      case 'earthquake':
        return Icons.gradient_rounded;
      case 'tsunami':
        return Icons.waves;
      case 'reclamation update':
        return Icons.report;
      case 'general':
      default:
        return Icons.event;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'in-progress':
        return Colors.blue;
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
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
          if (category == 'Reclamation Update' && reclamationId != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ReclamationDetailsScreen(reclamationId: reclamationId),
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildEventItem(Map<String, dynamic> item) {
    final title = item['title'] as String;
    final description = item['description'] as String;
    final timestamp = item['dateTime'] as DateTime;
    final category = item['category'] as String;
    final date = DateFormat('MMM d, y h:mm a').format(timestamp);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      margin: EdgeInsets.all(8),
      child: InkWell(
        onTap: () {
          // Placeholder for event details navigation
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Event: $title clicked')),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _getCategoryColor(category).withOpacity(0.1),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Icon(
                    _getCategoryIcon(category),
                    color: _getCategoryColor(category),
                    size: 24,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.black54,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.calendar_today, size: 16, color: Colors.black45),
                      SizedBox(width: 4),
                      Text(
                        date,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.black45,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildReclamationItem(Map<String, dynamic> item) {
    final subject = item['subject'] as String;
    final status = item['status'] as String;
    final category = item['category'] as String;
    final timestamp = item['createdAt'] as DateTime;
    final adminResponse = item['adminResponse'] as String?;
    final date = DateFormat('MMM d, y h:mm a').format(timestamp);
    final id = item['id'] as String;

    print('Reclamation $id: subject=$subject, status=$status, adminResponse=$adminResponse');

    if (_searchQuery.isNotEmpty &&
        !subject.toLowerCase().contains(_searchQuery.toLowerCase())) {
      return SizedBox.shrink();
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      margin: EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ReclamationDetailsScreen(reclamationId: id),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status Indicator
              Container(
                width: 10,
                height: 10,
                margin: EdgeInsets.only(top: 6, right: 12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _getStatusColor(status),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Subject
                    Text(
                      subject,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4),
                    // Category and Status
                    Row(
                      children: [
                        Icon(
                          Icons.category,
                          size: 14,
                          color: Colors.black45,
                        ),
                        SizedBox(width: 4),
                        Text(
                          category,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.black45,
                          ),
                        ),
                        SizedBox(width: 12),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _getStatusColor(status).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            StringExtension(status).capitalize(),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: _getStatusColor(status),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    // Date
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 14,
                          color: Colors.black45,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Submitted: $date',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.black45,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    // Admin Response
                    Text(
                      'Response: ${adminResponse != null && adminResponse.isNotEmpty
                          ? (adminResponse.length > 50
                          ? adminResponse.substring(0, 50) + '...'
                          : adminResponse)
                          : 'No response yet'}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.black54,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.teal),
            SizedBox(height: 16),
            Text(
              'Loading...',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black54),
            ),
          ],
        ),
      );
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
              hintText: 'Search ${_selectedTabIndex == 3 ? 'reclamations' : _selectedTabIndex == 0 ? 'alerts' : _selectedTabIndex == 1 ? 'notifications' : 'events'}...',
              prefixIcon: Icon(Icons.search, size: 20, color: Colors.black54),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.teal),
              ),
              contentPadding: EdgeInsets.symmetric(vertical: 10),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
            style: Theme.of(context).textTheme.bodyMedium,
            onChanged: (value) => setState(() => _searchQuery = value),
          ),
        ),
        TabBar(
          controller: _tabController,
          labelStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          unselectedLabelColor: Colors.black54,
          labelColor: Colors.teal,
          indicatorColor: Colors.teal,
          padding: EdgeInsets.symmetric(horizontal: 8),
          tabs: [
            Tab(icon: Icon(Icons.warning_amber, size: 20), text: 'Alerts'),
            Tab(icon: Icon(Icons.notifications, size: 20), text: 'Notifications'),
            Tab(icon: Icon(Icons.event, size: 20), text: 'Events'),
            Tab(icon: Icon(Icons.report, size: 20), text: 'Reclamations'),
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
            color: Colors.teal,
            child: _selectedTabIndex == 0
                ? ListView.builder(
              itemCount: _alerts.length,
              itemBuilder: (context, index) {
                return _buildNotificationItem(_alerts[index]);
              },
            )
                : _selectedTabIndex == 1
                ? StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('notifications')
                  .where('userId', isEqualTo: _auth.currentUser?.uid)
                  .where('isEmergency', isEqualTo: false)
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator(color: Colors.teal));
                }
                if (snapshot.hasError) {
                  print('Notification StreamBuilder error: ${snapshot.error}');
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                        SizedBox(height: 16),
                        Text(
                          'Error: ${snapshot.error}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => setState(() {}),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }
                final notifications = snapshot.data?.docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  print('Notification ${doc.id}: $data');
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
                        SizedBox(height: 8),
                        Text(
                          'You\'ll see updates here when available.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
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
                            icon: Icon(Icons.mark_email_read, size: 16, color: Colors.teal),
                            label: Text(
                              'Mark all as read',
                              style: TextStyle(fontSize: 12, color: Colors.teal),
                            ),
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.teal.withOpacity(0.1),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
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
                : _selectedTabIndex == 2
                ? _events.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.event_busy, size: 48, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No upcoming events',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Check back later for new events.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                  ),
                ],
              ),
            )
                : GridView.builder(
              padding: EdgeInsets.all(12),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: MediaQuery.of(context).size.width > 1200
                    ? 4
                    : MediaQuery.of(context).size.width > 800
                    ? 3
                    : 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.75,
              ),
              itemCount: _events
                  .where((item) =>
              _searchQuery.isEmpty ||
                  item['title'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
                  item['description'].toString().toLowerCase().contains(_searchQuery.toLowerCase()))
                  .length,
              itemBuilder: (context, index) {
                final filteredEvents = _events
                    .where((item) =>
                _searchQuery.isEmpty ||
                    item['title'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
                    item['description'].toString().toLowerCase().contains(_searchQuery.toLowerCase()))
                    .toList();
                return _buildEventItem(filteredEvents[index]);
              },
            )
                : StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('reclamations')
                  .where('userId', isEqualTo: _auth.currentUser?.uid)
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator(color: Colors.teal));
                }
                if (snapshot.hasError) {
                  print('Reclamation StreamBuilder error: ${snapshot.error}');
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                        SizedBox(height: 16),
                        Text(
                          'Error: ${snapshot.error}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => setState(() {}),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }
                final reclamations = snapshot.data?.docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  print('Reclamation ${doc.id}: $data');
                  String? latestResponse;
                  final adminResponses = data['adminResponses'] as List<dynamic>?;
                  if (adminResponses != null && adminResponses.isNotEmpty) {
                    adminResponses.sort((a, b) {
                      final aTime = (a['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
                      final bTime = (b['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
                      return bTime.compareTo(aTime);
                    });
                    latestResponse = adminResponses.first['message']?.toString();
                  }
                  return {
                    'id': doc.id,
                    'subject': data['subject'] ?? 'No subject',
                    'category': data['category'] ?? 'N/A',
                    'status': data['status'] ?? 'Pending',
                    'adminResponse': latestResponse,
                    'createdAt': (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
                  };
                }).toList() ??
                    [];
                if (reclamations.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.report_off, size: 48, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No reclamations yet',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Submit a reclamation to get started.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: reclamations.length,
                  itemBuilder: (context, index) => _buildReclamationItem(reclamations[index]),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDrawer() {
    final userEmail = _auth.currentUser?.email ?? 'No email available';

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
                  userEmail,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
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
          _buildDrawerItem(
            icon: Icons.notifications,
            title: 'Notifications',
            isSelected: true,
            onTap: () => Navigator.pop(context),
          ),
          _buildDrawerItem(
            icon: Icons.report_problem,
            title: 'Reclamation',
            onTap: _navigateToReclamation,
          ),
          _buildDrawerItem(
            icon: Icons.settings,
            title: 'Account Settings',
            onTap: _navigateToAccountSettings,
          ),
          Divider(color: Colors.grey.shade300),
          _buildDrawerItem(
            icon: Icons.exit_to_app,
            title: 'Sign Out',
            onTap: () async {
              await _auth.signOut();
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isSelected = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        color: isSelected ? Colors.teal.withOpacity(0.1) : Colors.transparent,
        child: ListTile(
          leading: Icon(icon, size: 20, color: isSelected ? Colors.teal : Colors.black54),
          title: Text(
            title,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: isSelected ? Colors.teal : Colors.black87,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          hoverColor: Colors.teal.withOpacity(0.05),
        ),
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
              ? 'Alerts'
              : _selectedTabIndex == 1
              ? 'Notifications'
              : _selectedTabIndex == 2
              ? 'Events'
              : 'Reclamations',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 0,
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

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1).toLowerCase()}';
  }
}