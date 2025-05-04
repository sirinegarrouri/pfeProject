import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserManagementScreen extends StatefulWidget {
  @override
  _UserManagementScreenState createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<Map<String, dynamic>> _approvedUsers = [];
  List<Map<String, dynamic>> _pendingUsers = [];
  bool _isLoading = true;
  String _searchQuery = '';
  int _rowsPerPage = 10;
  int _currentPage = 0;
  String? _selectedRole;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final snapshot = await _firestore.collection('users').get();
      final approved = <Map<String, dynamic>>[];
      final pending = <Map<String, dynamic>>[];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final user = {
          'id': doc.id,
          'email': data['email'] ?? 'No email',
          'phone': data['phone'] ?? '',
          'role': data['role'] ?? 'user',
          'status': data['status'] ?? 'pending',
          'createdAt': data['createdAt']?.toDate(),
        };
        if (user['status'] == 'approved') {
          approved.add(user);
        } else if (user['status'] == 'pending') {
          pending.add(user);
        }
      }

      setState(() {
        _approvedUsers = approved;
        _pendingUsers = pending;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load users: ${e.toString()}')),
      );
    }
  }

  Future<void> _updateUserRole(String userId, String newRole) async {
    try {
      await _firestore.collection('users').doc(userId).update({'role': newRole});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('User role updated successfully')),
      );
      _loadUsers();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update role: ${e.toString()}')),
      );
    }
  }

  Future<void> _approveUser(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'status': 'approved',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('User approved successfully')),
      );
      _loadUsers();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to approve user: ${e.toString()}')),
      );
    }
  }

  Future<void> _rejectUser(String userId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirm Reject'),
        content: Text('Are you sure you want to reject this user? This will delete their account.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Reject', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _firestore.collection('users').doc(userId).delete();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('User rejected and removed')),
        );
        _loadUsers();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to reject user: ${e.toString()}')),
        );
      }
    }
  }

  List<Map<String, dynamic>> get _filteredApprovedUsers {
    return _approvedUsers.where((user) {
      final matchesSearch = user['email'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesRole = _selectedRole == null || user['role'] == _selectedRole;
      return matchesSearch && matchesRole;
    }).toList();
  }

  List<Map<String, dynamic>> get _paginatedApprovedUsers {
    final startIndex = _currentPage * _rowsPerPage;
    final endIndex = startIndex + _rowsPerPage;
    return _filteredApprovedUsers.sublist(
      startIndex,
      endIndex > _filteredApprovedUsers.length ? _filteredApprovedUsers.length : endIndex,
    );
  }

  Widget _buildToolbar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                labelText: 'Search users',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() {
                _searchQuery = value;
                _currentPage = 0;
              }),
            ),
          ),
          SizedBox(width: 16),
          DropdownButton<String>(
            value: _selectedRole,
            hint: Text('Filter by role'),
            items: [
              DropdownMenuItem(child: Text('All roles'), value: null),
              DropdownMenuItem(child: Text('Admin'), value: 'admin'),
              DropdownMenuItem(child: Text('User'), value: 'user'),
            ],
            onChanged: (value) => setState(() {
              _selectedRole = value;
              _currentPage = 0;
            }),
          ),
          SizedBox(width: 16),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadUsers,
            tooltip: 'Refresh users',
          ),
        ],
      ),
    );
  }

  Widget _buildApprovedUsersTable() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Email')),
          DataColumn(label: Text('Phone')),
          DataColumn(label: Text('Role')),
          DataColumn(label: Text('Actions')),
        ],
        rows: _paginatedApprovedUsers.map((user) {
          return DataRow(
            cells: [
              DataCell(Text(user['email'])),
              DataCell(Text(user['phone'] ?? 'No phone')),
              DataCell(
                DropdownButton<String>(
                  value: user['role'],
                  items: ['admin', 'user'].map((role) {
                    return DropdownMenuItem<String>(
                      value: role,
                      child: Text(role),
                    );
                  }).toList(),
                  onChanged: (newRole) {
                    if (newRole != null) {
                      _updateUserRole(user['id'], newRole);
                    }
                  },
                ),
              ),
              DataCell(
                Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.edit, color: Colors.blue),
                      onPressed: () => _showEditUserDialog(user),
                    ),
                    if (user['id'] != _auth.currentUser?.uid)
                      IconButton(
                        icon: Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _confirmDeleteUser(user),
                      ),
                  ],
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPendingUsersList() {
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _pendingUsers.length,
      itemBuilder: (context, index) {
        final user = _pendingUsers[index];
        return Card(
          margin: EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.amber.withOpacity(0.1),
              child: Icon(Icons.person, color: Colors.amber, size: 20),
            ),
            title: Text(user['email']),
            subtitle: Text('Phone: ${user['phone'] ?? 'No phone'}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.check, color: Colors.green),
                  onPressed: () => _approveUser(user['id']),
                  tooltip: 'Approve',
                ),
                IconButton(
                  icon: Icon(Icons.close, color: Colors.red),
                  onPressed: () => _rejectUser(user['id']),
                  tooltip: 'Reject',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPaginationControls() {
    final totalPages = (_filteredApprovedUsers.length / _rowsPerPage).ceil();
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: Icon(Icons.chevron_left),
            onPressed: _currentPage > 0
                ? () => setState(() => _currentPage--)
                : null,
          ),
          Text('Page ${_currentPage + 1} of $totalPages'),
          IconButton(
            icon: Icon(Icons.chevron_right),
            onPressed: _currentPage < totalPages - 1
                ? () => setState(() => _currentPage++)
                : null,
          ),
          SizedBox(width: 20),
          DropdownButton<int>(
            value: _rowsPerPage,
            items: [5, 10, 25, 50].map((value) {
              return DropdownMenuItem<int>(
                value: value,
                child: Text('$value per page'),
              );
            }).toList(),
            onChanged: (value) => setState(() {
              _rowsPerPage = value!;
              _currentPage = 0;
            }),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditUserDialog(Map<String, dynamic> user) async {
    final phoneController = TextEditingController(text: user['phone'] ?? '');
    final emailController = TextEditingController(text: user['email']);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit User'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: phoneController,
              decoration: InputDecoration(labelText: 'Phone'),
              keyboardType: TextInputType.phone,
            ),
            TextField(
              controller: emailController,
              decoration: InputDecoration(labelText: 'Email'),
              enabled: false,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await _firestore.collection('users').doc(user['id']).update({
                  'phone': phoneController.text,
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('User updated successfully')),
                );
                _loadUsers();
                Navigator.pop(context);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to update user: ${e.toString()}')),
                );
              }
            },
            child: Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteUser(Map<String, dynamic> user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirm Delete'),
        content: Text('Are you sure you want to delete ${user['email']}?'),
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
        await _firestore.collection('users').doc(user['id']).delete();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('User deleted successfully')),
        );
        _loadUsers();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete user: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('User Management', style: Theme.of(context).textTheme.titleLarge),
          bottom: TabBar(
            tabs: [
              Tab(text: 'Approved Users'),
              Tab(text: 'Pending Users'),
            ],
            labelStyle: Theme.of(context).textTheme.titleMedium,
            unselectedLabelStyle: Theme.of(context).textTheme.bodyMedium,
            indicatorColor: Theme.of(context).primaryColor,
          ),
        ),
        body: _isLoading
            ? Center(child: CircularProgressIndicator())
            : TabBarView(
          children: [
            // Approved Users Tab
            Column(
              children: [
                _buildToolbar(),
                Expanded(
                  child: SingleChildScrollView(
                    child: _buildApprovedUsersTable(),
                  ),
                ),
                _buildPaginationControls(),
              ],
            ),
            // Pending Users Tab
            _pendingUsers.isEmpty
                ? Center(
              child: Text(
                'No pending users',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            )
                : _buildPendingUsersList(),
          ],
        ),
      ),
    );
  }
}