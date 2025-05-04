import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class ReclamationDetailsScreen extends StatelessWidget {
  final String reclamationId;

  const ReclamationDetailsScreen({Key? key, required this.reclamationId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final FirebaseFirestore _firestore = FirebaseFirestore.instance;
    final FirebaseAuth _auth = FirebaseAuth.instance;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reclamation Details'),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _firestore.collection('reclamations').doc(reclamationId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(
              child: Text(
                'Reclamation not found',
                style: TextStyle(color: Colors.grey),
              ),
            );
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final userId = data['userId'] as String?;
          final currentUser = _auth.currentUser;

          if (userId != currentUser?.uid) {
            return const Center(
              child: Text(
                'You do not have permission to view this reclamation',
                style: TextStyle(color: Colors.red),
              ),
            );
          }

          final category = data['category'] as String? ?? 'N/A';
          final subject = data['subject'] as String? ?? 'N/A';
          final message = data['message'] as String? ?? 'N/A';
          final status = data['status'] as String? ?? 'Pending';
          final adminResponse = data['adminResponse'] as String? ?? 'No response yet';
          final createdAt = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
          final formattedDate = DateFormat('MMM d, y h:mm a').format(createdAt);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailCard(
                  context,
                  'Category',
                  category,
                  Icons.category,
                ),
                const SizedBox(height: 16),
                _buildDetailCard(
                  context,
                  'Subject',
                  subject,
                  Icons.subject,
                ),
                const SizedBox(height: 16),
                _buildDetailCard(
                  context,
                  'Message',
                  message,
                  Icons.message,

                ),
                const SizedBox(height: 16),
                _buildDetailCard(
                  context,
                  'Status',
                  status.capitalize(),
                  Icons.info,
                  statusColor(status),
                ),
                const SizedBox(height: 16),
                _buildDetailCard(
                  context,
                  'Admin Response',
                  adminResponse,
                  Icons.admin_panel_settings,

                ),
                const SizedBox(height: 16),
                _buildDetailCard(
                  context,
                  'Submitted On',
                  formattedDate,
                  Icons.calendar_today,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailCard(
      BuildContext context,
      String title,
      String content,
      IconData icon, [
        Color? textColor,
        int maxLines = 1,
      ]) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: Colors.teal),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.teal,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              content,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: textColor ?? Colors.black87,
              ),
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Color statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1).toLowerCase()}';
  }
}