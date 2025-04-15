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
  List<Map<String, dynamic>> _users = [];
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
      setState(() {
        _users = snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'email': data['email'] ?? 'No email',
            'name': data['name'] ?? 'No name',
            'role': data['role'] ?? 'user',
            'createdAt': data['createdAt']?.toDate(),
            'isActive': data['isActive'] ?? true,
          };
        }).toList();
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

  Future<void> _toggleUserStatus(String userId, bool isActive) async {
    try {
      await _firestore.collection('users').doc(userId).update({'isActive': !isActive});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('User status updated successfully')),
      );
      _loadUsers();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update status: ${e.toString()}')),
      );
    }
  }

  List<Map<String, dynamic>> get _filteredUsers {
    return _users.where((user) {
      final matchesSearch = user['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
          user['email'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesRole = _selectedRole == null || user['role'] == _selectedRole;
      return matchesSearch && matchesRole;
    }).toList();
  }

  List<Map<String, dynamic>> get _paginatedUsers {
    final startIndex = _currentPage * _rowsPerPage;
    final endIndex = startIndex + _rowsPerPage;
    return _filteredUsers.sublist(
      startIndex,
      endIndex > _filteredUsers.length ? _filteredUsers.length : endIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
        children: [
          _buildToolbar(),
          Expanded(
            child: SingleChildScrollView(
              child: _buildUsersTable(),
            ),
          ),
          _buildPaginationControls(),
        ],
      ),
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
              DropdownMenuItem(child: Text('Moderator'), value: 'moderator'),
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

  Widget _buildUsersTable() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Name')),
          DataColumn(label: Text('Email')),
          DataColumn(label: Text('Role')),
          DataColumn(label: Text('Status')),
          DataColumn(label: Text('Actions')),
        ],
        rows: _paginatedUsers.map((user) {
          return DataRow(
            cells: [
              DataCell(Text(user['name'])),
              DataCell(Text(user['email'])),
              DataCell(
                DropdownButton<String>(
                  value: user['role'],
                  items: ['admin', 'moderator', 'user'].map((role) {
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
                Switch(
                  value: user['isActive'],
                  onChanged: (value) => _toggleUserStatus(user['id'], user['isActive']),
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

  Widget _buildPaginationControls() {
    final totalPages = (_filteredUsers.length / _rowsPerPage).ceil();
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
    final nameController = TextEditingController(text: user['name']);
    final emailController = TextEditingController(text: user['email']);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit User'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(labelText: 'Name'),
            ),
            TextField(
              controller: emailController,
              decoration: InputDecoration(labelText: 'Email'),
              enabled: false, // Email shouldn't be changed
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
                  'name': nameController.text,
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
        // First delete the user's auth record
    // await _auth.deleteUser(user['id']);

        // Then delete the user document
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
}
