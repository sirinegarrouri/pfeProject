import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class AdminReclamationsScreen extends StatefulWidget {
  @override
  _AdminReclamationsScreenState createState() => _AdminReclamationsScreenState();
  void refreshData() {
    _AdminReclamationsScreenState()._loadReclamations();
    _AdminReclamationsScreenState()._loadStatusCounts();
  }
}

class _AdminReclamationsScreenState extends State<AdminReclamationsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _adminNotesController = TextEditingController();

  List<DocumentSnapshot> _reclamations = [];
  bool _isLoading = true;
  String? _error;
  String _filterStatus = 'all';
  String _searchQuery = '';
  bool _showStats = false;
  Map<String, int> _statusCounts = {};

  // Status options for filtering
  final List<String> _statusOptions = [
    'all',
    'pending',
    'in-progress',
    'resolved',
    'rejected'
  ];

  @override
  void initState() {
    super.initState();
    _loadReclamations();
    _loadStatusCounts();
  }

  @override
  void dispose() {
    _adminNotesController.dispose();
    super.dispose();
  }

  Future<void> _loadReclamations() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      Query query = _firestore.collection('reclamations')
          .orderBy('createdAt', descending: true);

      // Apply status filter if not 'all'
      if (_filterStatus != 'all') {
        query = query.where('status', isEqualTo: _filterStatus);
      }

      // Apply search query if not empty
      if (_searchQuery.isNotEmpty) {
        query = query.where('searchKeywords', arrayContains: _searchQuery.toLowerCase());
      }

      final snapshot = await query.limit(100).get();

      setState(() {
        _reclamations = snapshot.docs;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load reclamations: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadStatusCounts() async {
    try {
      final counts = await _firestore.collection('reclamation_stats').doc('counts').get();
      if (counts.exists) {
        setState(() {
          _statusCounts = Map<String, int>.from(counts.data() ?? {});
        });
      }
    } catch (e) {
      print('Error loading status counts: $e');
    }
  }

  Future<void> _updateReclamationStatus(String docId, String newStatus) async {
    try {
      await _firestore.collection('reclamations').doc(docId).update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
        'adminId': _auth.currentUser?.uid,
      });

      // Update stats
      await _updateStatsCounter(newStatus);

      await _loadReclamations(); // Refresh the list
    } catch (e) {
      setState(() {
        _error = 'Failed to update status: ${e.toString()}';
      });
    }
  }

  Future<void> _updateStatsCounter(String newStatus) async {
    final docRef = _firestore.collection('reclamation_stats').doc('counts');
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (snapshot.exists) {
        final currentCounts = Map<String, int>.from(snapshot.data() ?? {});
        currentCounts[newStatus] = (currentCounts[newStatus] ?? 0) + 1;
        transaction.update(docRef, currentCounts);
      } else {
        transaction.set(docRef, {newStatus: 1});
      }
    });
  }

  Future<void> _deleteReclamation(String docId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirm Deletion'),
        content: Text('Are you sure you want to delete this reclamation?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _firestore.collection('reclamations').doc(docId).delete();
        await _loadReclamations(); // Refresh the list
      } catch (e) {
        setState(() {
          _error = 'Failed to delete: ${e.toString()}';
        });
      }
    }
  }

  Future<void> _addAdminNotes(String docId, String notes) async {
    try {
      await _firestore.collection('reclamations').doc(docId).update({
        'adminNotes': notes,
        'updatedAt': FieldValue.serverTimestamp(),
        'adminId': _auth.currentUser?.uid,
      });
      await _loadReclamations(); // Refresh the list
    } catch (e) {
      setState(() {
        _error = 'Failed to add notes: ${e.toString()}';
      });
    }
  }

  Widget _buildStatusChip(String status) {
    Color backgroundColor;
    Color textColor;

    switch (status) {
      case 'pending':
        backgroundColor = Colors.orange.shade100;
        textColor = Colors.orange.shade800;
        break;
      case 'in-progress':
        backgroundColor = Colors.blue.shade100;
        textColor = Colors.blue.shade800;
        break;
      case 'resolved':
        backgroundColor = Colors.green.shade100;
        textColor = Colors.green.shade800;
        break;
      case 'rejected':
        backgroundColor = Colors.red.shade100;
        textColor = Colors.red.shade800;
        break;
      default:
        backgroundColor = Colors.grey.shade100;
        textColor = Colors.grey.shade800;
    }

    return Chip(
      label: Text(
        status.toUpperCase(),
        style: TextStyle(color: textColor, fontSize: 12),
      ),
      backgroundColor: backgroundColor,
    );
  }

  Widget _buildStatsCard() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Reclamation Stats', style: TextStyle(fontWeight: FontWeight.bold)),
                IconButton(
                  icon: Icon(_showStats ? Icons.expand_less : Icons.expand_more),
                  onPressed: () => setState(() => _showStats = !_showStats),
                ),
              ],
            ),
            if (_showStats) ...[
              SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _statusOptions.where((s) => s != 'all').map((status) {
                  return Chip(
                    label: Text('${status.toUpperCase()}: ${_statusCounts[status] ?? 0}'),
                    backgroundColor: _getStatusColor(status).withOpacity(0.2),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending': return Colors.orange;
      case 'in-progress': return Colors.blue;
      case 'resolved': return Colors.green;
      case 'rejected': return Colors.red;
      default: return Colors.grey;
    }
  }

  Widget _buildReclamationCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final createdAt = data['createdAt']?.toDate() ?? DateTime.now();
    final updatedAt = data['updatedAt']?.toDate();
    final formattedDate = DateFormat('MMM d, y').format(createdAt);
    final formattedTime = DateFormat('h:mm a').format(createdAt);

    return Card(
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: ExpansionTile(
        leading: _buildStatusChip(data['status'] ?? 'pending'),
        title: Text(data['subject'] ?? 'No Subject', maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('From: ${data['email'] ?? 'Unknown'}'),
            if (updatedAt != null)
              Text('Updated: ${DateFormat('MMM d').format(updatedAt)}'),
          ],
        ),
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Submitted: $formattedDate at $formattedTime'),
                    if (data['adminId'] != null)
                      Chip(
                        label: Text('Handled by admin'),
                        backgroundColor: Colors.blue.shade50,
                      ),
                  ],
                ),
                SizedBox(height: 16),
                Text('Message:', style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text(data['message'] ?? 'No message provided'),
                SizedBox(height: 16),
                if (data['adminNotes'] != null) ...[
                  Text('Admin Notes:', style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text(data['adminNotes']),
                  SizedBox(height: 16),
                ],
                TextField(
                  controller: _adminNotesController,
                  decoration: InputDecoration(
                    labelText: 'Add Admin Notes',
                    border: OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(Icons.send),
                      onPressed: () {
                        final text = _adminNotesController.text;
                        if (text.isNotEmpty) {
                          _addAdminNotes(doc.id, text);
                          _adminNotesController.clear();
                        }
                      },
                    ),
                  ),
                  onSubmitted: (text) {
                    if (text.isNotEmpty) {
                      _addAdminNotes(doc.id, text);
                      _adminNotesController.clear();
                    }
                  },
                ),
                SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    DropdownButton<String>(
                      value: data['status'],
                      items: _statusOptions.where((s) => s != 'all').map((status) {
                        return DropdownMenuItem<String>(
                          value: status,
                          child: Text(status.toUpperCase()),
                        );
                      }).toList(),
                      onChanged: (newStatus) {
                        if (newStatus != null && newStatus != data['status']) {
                          _updateReclamationStatus(doc.id, newStatus);
                        }
                      },
                    ),
                    IconButton(
                      icon: Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteReclamation(doc.id),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _statusOptions.map((status) {
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: FilterChip(
              label: Text(status == 'all' ? 'All' : status),
              selected: _filterStatus == status,
              onSelected: (selected) {
                setState(() {
                  _filterStatus = selected ? status : 'all';
                });
                _loadReclamations();
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        decoration: InputDecoration(
          labelText: 'Search reclamations',
          prefixIcon: Icon(Icons.search),
          border: OutlineInputBorder(),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
            icon: Icon(Icons.clear),
            onPressed: () {
              setState(() => _searchQuery = '');
              _loadReclamations();
            },
          )
              : null,
        ),
        onChanged: (value) {
          setState(() => _searchQuery = value.trim());
          if (value.isEmpty) {
            _loadReclamations();
          }
        },
        onSubmitted: (_) => _loadReclamations(),
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
            Icon(Icons.error, color: Colors.red, size: 48),
            SizedBox(height: 16),
            Text('Error loading reclamations'),
            SizedBox(height: 8),
            Text(_error!, textAlign: TextAlign.center),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadReclamations,
              child: Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_reclamations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text('No reclamations found'),
            if (_filterStatus != 'all' || _searchQuery.isNotEmpty) ...[
              SizedBox(height: 8),
              Text('Try changing filters or search query'),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _filterStatus = 'all';
                    _searchQuery = '';
                  });
                  _loadReclamations();
                },
                child: Text('Reset Filters'),
              ),
            ],
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadReclamations,
      child: ListView.builder(
        itemCount: _reclamations.length + 2, // +2 for the header and stats card
        itemBuilder: (context, index) {
          if (index == 0) return _buildStatsCard();
          if (index == 1) return SizedBox(height: 16);
          return _buildReclamationCard(_reclamations[index - 2]);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Reclamation Management'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              _loadReclamations();
              _loadStatusCounts();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(height: 8),
          _buildSearchField(),
          SizedBox(height: 8),
          _buildFilterChips(),
          SizedBox(height: 8),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }
}