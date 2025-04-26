import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ReclamationDetailsScreen extends StatefulWidget {
  final String reclamationId;

  const ReclamationDetailsScreen({Key? key, required this.reclamationId}) : super(key: key);

  @override
  _ReclamationDetailsScreenState createState() => _ReclamationDetailsScreenState();
}

class _ReclamationDetailsScreenState extends State<ReclamationDetailsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  Map<String, dynamic>? _reclamation;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadReclamation();
  }

  Future<void> _loadReclamation() async {
    setState(() => _isLoading = true);
    try {
      final doc = await _firestore.collection('reclamations').doc(widget.reclamationId).get();
      if (!doc.exists) {
        setState(() {
          _error = 'Reclamation not found';
          _isLoading = false;
        });
        return;
      }
      setState(() {
        _reclamation = doc.data();
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading reclamation: $e');
      setState(() {
        _error = 'Failed to load reclamation: $e';
        _isLoading = false;
      });
    }
  }

  Widget _buildStatusChip(String status) {
    Color backgroundColor;
    Color textColor;

    switch (status.toLowerCase()) {
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

  Widget _buildAdminResponses(List<dynamic>? responses) {
    if (responses == null || responses.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 16.0),
        child: Text(
          'No admin responses yet',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(
          'Admin Responses:',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        ...responses.map((response) {
          final data = response as Map<String, dynamic>;
          final date = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
          final formattedDate = DateFormat('MMM d, y h:mm a').format(date);
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            color: Colors.teal.shade50,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        data['adminName'] ?? 'Admin',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        formattedDate,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    data['message'] ?? '',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text('Reclamation Details')),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: Text('Reclamation Details')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
              SizedBox(height: 16),
              Text(
                _error!,
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadReclamation,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text('Retry', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
      );
    }

    final createdAt = (_reclamation?['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    final formattedDate = DateFormat('MMM d, y h:mm a').format(createdAt);

    return Scaffold(
      appBar: AppBar(
        title: Text('Reclamation Details'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _reclamation?['subject'] ?? 'No Subject',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            _buildStatusChip(_reclamation?['status'] ?? 'pending'),
            SizedBox(height: 16),
            Text(
              'Submitted: $formattedDate',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
            ),
            SizedBox(height: 16),
            Text(
              'Message:',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 8),
            Text(
              _reclamation?['message'] ?? 'No message provided',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            _buildAdminResponses(_reclamation?['adminResponses'] as List<dynamic>?),
          ],
        ),
      ),
    );
  }
}