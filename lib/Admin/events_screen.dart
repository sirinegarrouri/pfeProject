import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class EventsScreen extends StatefulWidget {
  @override
  _EventsScreenState createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  DateTime? _selectedDateTime;
  bool _sendNotification = false;
  bool _isCreating = false;
  List<Map<String, dynamic>> _users = [];
  int _totalUsers = 0;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    try {
      final snapshot = await _firestore.collection('users').get();
      final countSnapshot = await _firestore.collection('users').count().get();

      setState(() {
        _users = snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'email': data['email'] ?? 'No email',
            'name': data['name'] ?? 'No name',
          };
        }).toList();
        _totalUsers = countSnapshot.count!;
      });
    } catch (e) {
      print('Error loading users: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load users')),
      );
    }
  }

  Future<void> _createEvent() async {
    if (_titleController.text.isEmpty ||
        _descriptionController.text.isEmpty ||
        _selectedDateTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    setState(() => _isCreating = true);

    try {
      final eventData = {
        'title': _titleController.text,
        'description': _descriptionController.text,
        'dateTime': Timestamp.fromDate(_selectedDateTime!),
        'createdBy': _auth.currentUser?.uid,
        'createdAt': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('events').add(eventData);
      if (_sendNotification) {
        final usersSnapshot = await _firestore.collection('users').get();
        final userIds = usersSnapshot.docs.map((doc) => doc.id).toList();
        final batch = _firestore.batch();

        for (final userId in userIds) {
          final docRef = _firestore.collection('notifications').doc();
          batch.set(docRef, {
            'message': 'New Event: ${_titleController.text} on ${DateFormat('MMM d, h:mm a').format(_selectedDateTime!)}',
            'timestamp': FieldValue.serverTimestamp(),
            'read': false,
            'userId': userId,
            'senderId': _auth.currentUser?.uid,
            'senderRole': 'admin',
            'category': 'Event',
            'isEmergency': false,
          });
        }
        await batch.commit();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_sendNotification
              ? 'Event created and notifications sent to $_totalUsers users'
              : 'Event created successfully'),
        ),
      );

      _titleController.clear();
      _descriptionController.clear();
      setState(() {
        _selectedDateTime = null;
        _sendNotification = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create event: ${e.toString()}')),
      );
    } finally {
      setState(() => _isCreating = false);
    }
  }

  Future<void> _selectDateTime(BuildContext context) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(Duration(days: 365)),
    );
    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );
      if (pickedTime != null) {
        setState(() {
          _selectedDateTime = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(12),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Create Event',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  SizedBox(height: 12),
                  TextField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      labelText: 'Event Title',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    ),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  SizedBox(height: 12),
                  TextField(
                    controller: _descriptionController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    ),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _selectedDateTime == null
                              ? 'Select Date & Time'
                              : DateFormat('MMM d, h:mm a').format(_selectedDateTime!),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      TextButton(
                        onPressed: () => _selectDateTime(context),
                        child: Text('Choose', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Send notification to all users',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    value: _sendNotification,
                    onChanged: (value) => setState(() => _sendNotification = value),
                    activeColor: Colors.teal,
                  ),
                  SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isCreating ? null : _createEvent,
                      child: Text(
                        _isCreating ? 'Creating...' : 'Create Event',
                        style: TextStyle(fontSize: 12),
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: Colors.teal,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recent Events',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  SizedBox(height: 12),
                  _buildEventList(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('events')
          .orderBy('createdAt', descending: true)
          .limit(20)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}', style: Theme.of(context).textTheme.bodyMedium);
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(child: Text('No events found', style: Theme.of(context).textTheme.bodyMedium));
        }

        final screenWidth = MediaQuery.of(context).size.width;
        final cardWidth = screenWidth > 1200
            ? 300.0
            : screenWidth > 800
            ? 250.0
            : screenWidth / 2 - 18;

        return Wrap(
          spacing: 12.0,
          runSpacing: 12.0,
          children: docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final title = data['title'] as String? ?? 'Untitled';
            final description = data['description'] as String? ?? 'No description';
            final timestamp = data['dateTime'] as Timestamp?;
            final date = timestamp != null
                ? DateFormat('MMM d, h:mm a').format(timestamp.toDate())
                : 'Unknown date';

            return SizedBox(
              width: cardWidth,
              child: Card(
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
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black45),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}