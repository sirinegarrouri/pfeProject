import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class AdminReclamationsScreen extends StatefulWidget {
  const AdminReclamationsScreen({super.key});
  @override
  _AdminReclamationsScreenState createState() => _AdminReclamationsScreenState();

  void refreshData() {}
}

class _AdminReclamationsScreenState extends State<AdminReclamationsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _adminNotesController = TextEditingController();
  List<DocumentSnapshot> _reclamations = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _error;
  String _filterStatus = 'all';
  String _searchQuery = '';
  bool _showStats = false;
  Map<String, int> _statusCounts = {};
  Map<String, bool> _isResponding = {};
  Map<String, bool> _isActionLoading = {};
  bool _isAdmin = false;
  DocumentSnapshot? _lastDocument;
  final List<String> _statusOptions = [
    'all',
    'pending',
    'in-progress',
    'resolved',
    'rejected',
  ];

  @override
  void initState() {
    super.initState();
    _checkAdminStatus().then((_) {
      refreshData();
    });
  }
  @override
  void dispose() {
    _adminNotesController.dispose();
    super.dispose();
  }

  void refreshData() {
    _loadReclamations();
    _loadStatusCounts();
  }

  Future<void> _checkAdminStatus() async {
    final user = _auth.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() {
          _isAdmin = false;
        });
      }
      return;
    }
    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (mounted) {
        setState(() {
          _isAdmin = userDoc.exists && userDoc.data()?['role'] == 'admin';
        });
      }
    } catch (e) {
      debugPrint('Error checking admin status: $e');
      if (mounted) {
        setState(() {
          _isAdmin = false;
        });
      }
    }
  }

  Future<void> _loadReclamations({bool loadMore = false}) async {
    if (loadMore && _lastDocument == null) return;

    try {
      if (mounted) {
        setState(() {
          if (loadMore) {
            _isLoadingMore = true;
          } else {
            _isLoading = true;
            _error = null;
          }
        });
      }

      Query query = _firestore
          .collection('reclamations')
          .orderBy('createdAt', descending: true)
          .limit(20);

      if (_filterStatus != 'all') {
        query = query.where('status', isEqualTo: _filterStatus);
      }

      if (_searchQuery.isNotEmpty) {
        query = query.where('searchKeywords', arrayContains: _searchQuery.toLowerCase());
      }

      if (loadMore && _lastDocument != null) {
        query = query.startAfterDocument(_lastDocument!);
      }

      final snapshot = await query.get();

      if (mounted) {
        setState(() {
          if (loadMore) {
            _reclamations.addAll(snapshot.docs);
          } else {
            _reclamations = snapshot.docs;
          }
          _lastDocument = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
          _isResponding = {for (var doc in _reclamations) doc.id: false};
          _isActionLoading = {for (var doc in _reclamations) doc.id: false};
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load reclamations: ${e.toString()}';
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  Future<void> _loadStatusCounts() async {
    if (!_isAdmin) return;

    try {
      final counts = await _firestore.collection('reclamation_stats').doc('counts').get();
      if (counts.exists && mounted) {
        setState(() {
          _statusCounts = Map<String, int>.from(counts.data() ?? {});
        });
      }
    } catch (e) {
      debugPrint('Error loading status counts: $e');
    }
  }

  Future<void> _updateReclamationStatus(String docId, String newStatus) async {
    if (!_isAdmin) {
      _showPermissionDeniedSnackbar();
      return;
    }

    if (mounted) {
      setState(() {
        _isActionLoading[docId] = true;
      });
    }

    try {
      await _firestore.collection('reclamations').doc(docId).update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
        'adminId': _auth.currentUser?.uid,
      });
      await _updateStatsCounter(newStatus);
      await _loadReclamations();
    } catch (e) {
      _handleError('Failed to update status', e);
    } finally {
      if (mounted) {
        setState(() {
          _isActionLoading[docId] = false;
        });
      }
    }
  }

  Future<void> _updateStatsCounter(String newStatus) async {
    if (!_isAdmin) return;

    final docRef = _firestore.collection('reclamation_stats').doc('counts');
    for (int i = 0; i < 3; i++) {
      try {
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
        return;
      } catch (e) {
        debugPrint('Attempt ${i + 1} failed: $e');
        if (i == 2) {
          _showSnackbar('Failed to update stats after retries');
        }
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
  }

  Future<void> _deleteReclamation(String docId) async {
    if (!_isAdmin) {
      _showPermissionDeniedSnackbar();
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: const Text('Are you sure you want to delete this reclamation?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    if (mounted) {
      setState(() {
        _isActionLoading[docId] = true;
      });
    }

    try {
      await _firestore.collection('reclamations').doc(docId).delete();
      await _loadReclamations();
    } catch (e) {
      _handleError('Failed to delete', e);
    } finally {
      if (mounted) {
        setState(() {
          _isActionLoading[docId] = false;
        });
      }
    }
  }

  Future<void> _addAdminResponse(String docId, String response) async {
    // Validate input
    final trimmedResponse = response.trim();
    if (trimmedResponse.isEmpty) {
      _showSnackbar('Response cannot be empty');
      return;
    }

    // Check admin privileges
    if (!_isAdmin) {
      _showPermissionDeniedSnackbar();
      return;
    }

    // Set loading state
    if (mounted) {
      setState(() {
        _isActionLoading[docId] = true;
        _isResponding[docId] = true;
      });
    }

    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final responseData = {
        'message': trimmedResponse,
        'createdAt': Timestamp.now(), // Use Timestamp.now() instead of FieldValue.serverTimestamp()
        'adminId': user.uid,
        'adminName': user.displayName ?? 'Admin',
      };

      final docRef = _firestore.collection('reclamations').doc(docId);

      // Use a transaction to ensure atomic updates
      await _firestore.runTransaction((transaction) async {
        final docSnapshot = await transaction.get(docRef);
        if (!docSnapshot.exists) {
          throw Exception('Reclamation document not found');
        }

        // Get the current adminResponses array (or initialize as empty)
        final currentResponses = (docSnapshot.data()?['adminResponses'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];

        // Append the new response
        currentResponses.add(responseData);

        // Update the document with the full array and other fields
        transaction.update(docRef, {
          'adminResponses': currentResponses,
          'updatedAt': Timestamp.now(), // Use Timestamp.now() for consistency
          'status': 'in-progress',
          'adminId': user.uid,
        });
      });

      // Update stats counter
      await _updateStatsCounter('in-progress');

      // Clear input and reset responding state
      _adminNotesController.clear();
      if (mounted) {
        setState(() {
          _isResponding[docId] = false;
        });
      }

      // Refresh reclamations list
      await _loadReclamations();

      _showSnackbar('Response added successfully');
    } catch (e) {
      // Enhanced error handling
      String errorMessage = 'Failed to add response';
      if (e is FirebaseException) {
        if (e.code == 'permission-denied') {
          errorMessage = 'Admin privileges required';
        } else if (e.code == 'not-found') {
          errorMessage = 'Reclamation not found';
        } else {
          errorMessage = '${e.code}: ${e.message}';
        }
      } else {
        errorMessage = '$errorMessage: ${e.toString()}';
        debugPrint('Error in _addAdminResponse: $e'); // Log for debugging
      }
      _showSnackbar(errorMessage);
    } finally {
      // Ensure loading state is reset
      if (mounted) {
        setState(() {
          _isActionLoading[docId] = false;
        });
      }
    }
  }
  void _showSnackbar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  void _showPermissionDeniedSnackbar() {
    _showSnackbar('Admin privileges required');

  }

  void _handleError(String prefix, dynamic error) {
    String errorMessage = prefix;

    if (error is FirebaseException) {
      if (error.code == 'permission-denied') {
        errorMessage = 'Admin privileges required for this action';
      } else {
        errorMessage = '${error.code}: ${error.message}';
      }
    } else {
      errorMessage = '$prefix: ${error.toString()}';
    }

    _showSnackbar(errorMessage);
  }

  Widget _buildAdminResponses(List<dynamic>? responses) {
    if (responses == null || responses.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Text('Admin Responses:', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...responses.map((response) {
          final data = response as Map<String, dynamic>;
          final date = data['createdAt']?.toDate() ?? DateTime.now();
          final formattedDate = DateFormat('MMM d, y h:mm a').format(date);
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            color: Colors.blue[50],
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(data['adminName'] ?? 'Admin',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(formattedDate, style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(data['message'] ?? ''),
                ],
              ),
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildResponseInput(String docId) {
    if (!_isAdmin) return const SizedBox.shrink();
    return Column(
      children: [
        const SizedBox(height: 16),
        TextField(
          controller: _adminNotesController,
          maxLines: 3,
          enabled: !_isActionLoading[docId]!,
          decoration: InputDecoration(
            labelText: 'Type your response...',
            border: const OutlineInputBorder(),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: _isActionLoading[docId]!
                      ? const CircularProgressIndicator(strokeWidth: 2)
                      : const Icon(Icons.send, color: Colors.blue),
                  onPressed: _isActionLoading[docId]!
                      ? null
                      : () {
                    final text = _adminNotesController.text.trim();
                    if (text.isNotEmpty) {
                      _addAdminResponse(docId, text);
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.red),
                  onPressed: _isActionLoading[docId]!
                      ? null
                      : () {
                    if (mounted) {
                      setState(() {
                        _isResponding[docId] = false;
                      });
                    }
                    _adminNotesController.clear();
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
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
    if (!_isAdmin) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Reclamation Stats',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                IconButton(
                  icon:
                  Icon(_showStats ? Icons.expand_less : Icons.expand_more),
                  onPressed: () => setState(() => _showStats = !_showStats),
                ),
              ],
            ),
            if (_showStats) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _statusOptions.where((s) => s != 'all').map((status) {
                  return Chip(
                    label: Text(
                        '${status.toUpperCase()}: ${_statusCounts[status] ?? 0}'),
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
      case 'pending':
        return Colors.orange;
      case 'in-progress':
        return Colors.blue;
      case 'resolved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildReclamationCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final createdAt = data['createdAt']?.toDate() ?? DateTime.now();
    final updatedAt = data['updatedAt']?.toDate();
    final formattedDate = DateFormat('MMM d, y').format(createdAt);
    final formattedTime = DateFormat('h:mm a').format(createdAt);
    final responses = data['adminResponses'] as List<dynamic>?;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: ExpansionTile(
        leading: _buildStatusChip(data['status'] ?? 'pending'),
        title: Text(
          data['subject'] ?? 'No Subject',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
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
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Submitted: $formattedDate at $formattedTime'),
                    if (data['adminId'] != null)
                      Chip(
                        label: const Text('Handled by admin'),
                        backgroundColor: Colors.blue.shade50,
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('Message:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(data['message'] ?? 'No message provided'),
                _buildAdminResponses(responses),
                if (_isAdmin && _isResponding[doc.id] == true)
                  _buildResponseInput(doc.id)
                else if (_isAdmin)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      icon: const Icon(Icons.reply),
                      label: const Text('Respond'),
                      onPressed: _isActionLoading[doc.id]!
                          ? null
                          : () {
                        if (mounted) {
                          setState(() {
                            _isResponding[doc.id] = true;
                          });
                        }
                      },
                    ),
                  ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (_isAdmin)
                      DropdownButton<String>(
                        value: data['status'],
                        items: _statusOptions
                            .where((s) => s != 'all')
                            .map((status) {
                          return DropdownMenuItem<String>(
                            value: status,
                            child: Text(status.toUpperCase()),
                          );
                        }).toList(),
                        onChanged: _isActionLoading[doc.id]!
                            ? null
                            : (newStatus) {
                          if (newStatus != null &&
                              newStatus != data['status']) {
                            _updateReclamationStatus(doc.id, newStatus);
                          }
                        },
                      )
                    else
                      const SizedBox(width: 100),
                    if (_isAdmin)
                      IconButton(
                        icon: _isActionLoading[doc.id]!
                            ? const CircularProgressIndicator(strokeWidth: 2)
                            : const Icon(Icons.delete, color: Colors.red),
                        onPressed: _isActionLoading[doc.id]!
                            ? null
                            : () => _deleteReclamation(doc.id),
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
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: FilterChip(
              label: Text(status == 'all' ? 'All' : status),
              selected: _filterStatus == status,
              onSelected: (selected) {
                if (mounted) {
                  setState(() {
                    _filterStatus = selected ? status : 'all';
                  });
                }
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
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        decoration: InputDecoration(
          labelText: 'Search reclamations',
          prefixIcon: const Icon(Icons.search),
          border: const OutlineInputBorder(),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () {
              if (mounted) {
                setState(() => _searchQuery = '');
              }
              _loadReclamations();
            },
          )
              : null,
        ),
        onChanged: (value) {
          if (mounted) {
            setState(() => _searchQuery = value.trim());
          }
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
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            const Text('Error loading reclamations'),
            const SizedBox(height: 8),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: refreshData,
              child: const Text('Retry'),
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
            const Icon(Icons.inbox, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('No reclamations found'),
            if (_filterStatus != 'all' || _searchQuery.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('Try changing filters or search query'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  if (mounted) {
                    setState(() {
                      _filterStatus = 'all';
                      _searchQuery = '';
                    });
                  }
                  _loadReclamations();
                },
                child: const Text('Reset Filters'),
              ),
            ],
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => refreshData(),
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification is ScrollEndNotification &&
              notification.metrics.extentAfter == 0 &&
              !_isLoadingMore &&
              _lastDocument != null) {
            _loadReclamations(loadMore: true);
          }
          return false;
        },
        child: ListView.builder(
          itemCount: _reclamations.length + (_lastDocument != null ? 3 : 2),
          itemBuilder: (context, index) {
            if (index == 0) return _buildStatsCard();
            if (index == 1) return const SizedBox(height: 16);
            if (index == _reclamations.length + 2 && _lastDocument != null) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: _isLoadingMore
                      ? const CircularProgressIndicator()
                      : ElevatedButton(
                    onPressed: () => _loadReclamations(loadMore: true),
                    child: const Text('Load More'),
                  ),
                ),
              );
            }
            final reclamationIndex = index - 2;
            if (reclamationIndex < _reclamations.length) {
              return _buildReclamationCard(_reclamations[reclamationIndex]);
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reclamation Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: refreshData,
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 8),
          _buildSearchField(),
          const SizedBox(height: 8),
          _buildFilterChips(),
          const SizedBox(height: 8),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }
}