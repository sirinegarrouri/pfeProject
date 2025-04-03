import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class UserScreen extends StatefulWidget {
  @override
  _UserScreenState createState() => _UserScreenState();
}

class _UserScreenState extends State<UserScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;

  Future<void> _refreshNotifications() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 500));
    setState(() => _isLoading = false);
  }

  Widget _buildAuthRequired() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.login, size: 48, color: Colors.blue),
          const SizedBox(height: 16),
          const Text('Authentication required'),
          const SizedBox(height: 8),
          const Text('Please sign in to view notifications'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => Navigator.pushNamed(context, '/login'),
            child: const Text('Sign In'),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Loading notifications...'),
        ],
      ),
    );
  }

  Widget _buildErrorState(dynamic error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          const Text('Couldn\'t load notifications'),
          const SizedBox(height: 8),
          Text(
            _getErrorText(error),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _refreshNotifications,
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_off, size: 48, color: Colors.grey),
          SizedBox(height: 16),
          Text('No notifications yet'),
          SizedBox(height: 8),
          Text('You\'ll see notifications here when they arrive'),
        ],
      ),
    );
  }

  Stream<QuerySnapshot> _getNotificationStream() {
    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: _auth.currentUser!.uid)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  Widget _buildNotificationList(List<QueryDocumentSnapshot> docs) {
    return ListView.builder(
      itemCount: docs.length,
      itemBuilder: (context, index) {
        final doc = docs[index];
        final data = doc.data() as Map<String, dynamic>;
        final notification = NotificationModel(
          id: doc.id,
          message: data['message'] ?? '',
          read: data['read'] ?? false,
          timestamp: data['timestamp'] ?? Timestamp.now(),
          userId: data['userId'] ?? '',
        );

        final formattedDate = DateFormat('MMM d, y • h:mm a')
            .format(notification.timestamp.toDate());

        return Dismissible(
          key: Key(notification.id),
          background: Container(color: Colors.red),
          confirmDismiss: (direction) async {
            await _markAsRead(notification.id);
            return false;
          },
          child: Card(
            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: notification.read ? Colors.grey : Colors.blue,
                child: Icon(
                  notification.read ? Icons.notifications_none : Icons.notifications,
                  color: Colors.white,
                ),
              ),
              title: Text(
                notification.message,
                style: TextStyle(
                  fontWeight: notification.read ? FontWeight.normal : FontWeight.bold,
                ),
              ),
              subtitle: Text(formattedDate),
              trailing: IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => _deleteNotification(notification.id),
              ),
              onTap: () => _markAsRead(notification.id),
            ),
          ),
        );
      },
    );
  }

  Future<void> _markAsRead(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).update({
        'read': true,
        'readAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error marking as read: $e');
    }
  }

  Future<void> _deleteNotification(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).delete();
    } catch (e) {
      print('Error deleting notification: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete notification')),
      );
    }
  }

  String _getErrorText(dynamic error) {
    if (error is FirebaseException) {
      switch (error.code) {
        case 'resource-exhausted':
          return 'Too many requests. Please wait.';
        case 'permission-denied':
          return 'You don\'t have permission to view notifications';
        case 'unavailable':
          return 'Network unavailable. Check your connection';
        default:
          return 'Please try again later';
      }
    }
    return 'An unexpected error occurred';
  }

  Widget _buildNotificationContent() {
    if (_auth.currentUser == null) {
      return _buildAuthRequired();
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _getNotificationStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingIndicator();
        }

        if (snapshot.hasError) {
          return _buildErrorState(snapshot.error);
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState();
        }

        return RefreshIndicator(
          onRefresh: _refreshNotifications,
          child: _buildNotificationList(snapshot.data!.docs),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshNotifications,
          ),
        ],
      ),
      body: _buildNotificationContent(),
    );
  }
}

class NotificationModel {
  final String id;
  final String message;
  final bool read;
  final Timestamp timestamp;
  final String userId;

  NotificationModel({
    required this.id,
    required this.message,
    required this.read,
    required this.timestamp,
    required this.userId,
  });
}