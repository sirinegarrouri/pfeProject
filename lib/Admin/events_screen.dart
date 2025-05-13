import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Optional for loading animation

// EventService class to handle Firebase operations
class EventService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> createEvent({
    required String title,
    required String description,
    required DateTime dateTime,
    required bool sendNotification,
  }) async {
    final eventData = {
      'title': title,
      'description': description,
      'dateTime': Timestamp.fromDate(dateTime),
      'createdBy': _auth.currentUser?.uid,
      'createdAt': FieldValue.serverTimestamp(),
    };

    await _firestore.collection('events').add(eventData);

    if (sendNotification) {
      final usersSnapshot = await _firestore.collection('users').get();
      final userIds = usersSnapshot.docs.map((doc) => doc.id).toList();
      final batch = _firestore.batch();

      for (final userId in userIds) {
        final docRef = _firestore.collection('notifications').doc();
        batch.set(docRef, {
          'message': 'New Event: $title on ${DateFormat('MMM d, h:mm a').format(dateTime)}',
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
  }

  Future<List<Map<String, dynamic>>> loadUsers() async {
    final snapshot = await _firestore.collection('users').get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        'email': data['email'] ?? 'No email',
        'name': data['name'] ?? 'No name',
      };
    }).toList();
  }

  Future<int> getTotalUsers() async {
    final countSnapshot = await _firestore.collection('users').count().get();
    return countSnapshot.count ?? 0;
  }
}

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  _EventsScreenState createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  final EventService _eventService = EventService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
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
      final users = await _eventService.loadUsers();
      final totalUsers = await _eventService.getTotalUsers();
      setState(() {
        _users = users;
        _totalUsers = totalUsers;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load users')),
      );
    }
  }

  Future<void> _createEvent() async {
    if (!_formKey.currentState!.validate() || _selectedDateTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    setState(() => _isCreating = true);

    try {
      await _eventService.createEvent(
        title: _titleController.text,
        description: _descriptionController.text,
        dateTime: _selectedDateTime!,
        sendNotification: _sendNotification,
      );
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
    } on FirebaseException catch (e) {
      _showErrorDialog('Firebase Error', 'Error: ${e.message}');
    } catch (e) {
      _showErrorDialog('Unexpected Error', 'An unexpected error occurred: $e');
    } finally {
      setState(() => _isCreating = false);
    }
  }

  Future<void> _selectDateTime(BuildContext context) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
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

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _loadUsers,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.event, color: Colors.teal, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Create Event',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const Divider(height: 24, thickness: 1),
                          TextFormField(
                            controller: _titleController,
                            decoration: InputDecoration(
                              labelText: 'Event Title',
                              prefixIcon: const Icon(Icons.title, color: Colors.teal),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              focusedBorder: OutlineInputBorder(
                                borderSide: const BorderSide(color: Colors.teal, width: 2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                            ),
                            validator: (value) => value!.isEmpty ? 'Title is required' : null,
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _descriptionController,
                            maxLines: 3,
                            decoration: InputDecoration(
                              labelText: 'Description',
                              prefixIcon: const Icon(Icons.description, color: Colors.teal),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              focusedBorder: OutlineInputBorder(
                                borderSide: const BorderSide(color: Colors.teal, width: 2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                            ),
                            validator: (value) => value!.isEmpty ? 'Description is required' : null,
                          ),
                          const SizedBox(height: 12),
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
                                child: const Text('Choose', style: TextStyle(fontSize: 12)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
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
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isCreating ? null : _createEvent,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: Text(
                                _isCreating ? 'Creating...' : 'Create Event',
                                style: const TextStyle(fontSize: 14, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.history, color: Colors.teal, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Recent Events',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const Divider(height: 24, thickness: 1),
                        _buildEventList(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_isCreating)
          Container(
            color: Colors.black.withOpacity(0.3),
            child: const Center(
              child: CircularProgressIndicator(color: Colors.teal),
            ),
          ),
      ],
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
          return const Center(child: CircularProgressIndicator(color: Colors.teal));
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(child: Text('No events found', style: Theme.of(context).textTheme.bodyMedium));
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 300,
            childAspectRatio: 0.75,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final title = data['title'] ?? 'Untitled';
            final description = data['description'] ?? 'No description';
            final timestamp = data['dateTime'] as Timestamp?;
            final date = timestamp != null
                ? DateFormat('MMM d, h:mm a').format(timestamp.toDate())
                : 'Unknown date';

            return Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodyMedium,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Text(
                      'When: $date',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}