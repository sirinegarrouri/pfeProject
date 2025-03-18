import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class GradesReportsScreen extends StatefulWidget {
  @override
  _GradesReportsScreenState createState() => _GradesReportsScreenState();
}

class _GradesReportsScreenState extends State<GradesReportsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? selectedSubjectId;
  String? selectedStudentId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Grades Reports'),
        backgroundColor: theme.colorScheme.primary, // dynamic!
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildFilters(theme),
            const SizedBox(height: 16),
            Expanded(child: _buildGradesList(theme, isDarkMode)),
            _buildAddGradeButton(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters(ThemeData theme) {
    return Row(
      children: [
        Expanded(child: _subjectDropdown(theme)),
        const SizedBox(width: 10),
        Expanded(child: _studentDropdown(theme)),
      ],
    );
  }

  Widget _subjectDropdown(ThemeData theme) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('subjects').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const CircularProgressIndicator();

        var subjects = snapshot.data!.docs;

        return DropdownButtonFormField<String>(
          value: selectedSubjectId,
          decoration: InputDecoration(
            labelText: "Select Subject",
            labelStyle: TextStyle(color: theme.textTheme.bodyLarge!.color),
            filled: true,
            fillColor: theme.cardColor,
            border: const OutlineInputBorder(),
          ),
          dropdownColor: theme.cardColor,
          onChanged: (value) {
            setState(() {
              selectedSubjectId = value;
            });
          },
          items: subjects.map((doc) {
            return DropdownMenuItem(
              value: doc.id,
              child: Text(doc['name'], style: theme.textTheme.bodyLarge),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _studentDropdown(ThemeData theme) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const CircularProgressIndicator();

        var students = snapshot.data!.docs;

        return DropdownButtonFormField<String>(
          value: selectedStudentId,
          decoration: InputDecoration(
            labelText: "Select Student",
            labelStyle: TextStyle(color: theme.textTheme.bodyLarge!.color),
            filled: true,
            fillColor: theme.cardColor,
            border: const OutlineInputBorder(),
          ),
          dropdownColor: theme.cardColor,
          onChanged: (value) {
            setState(() {
              selectedStudentId = value;
            });
          },
          items: students.map((doc) {
            return DropdownMenuItem(
              value: doc.id,
              child: Text(doc['email'], style: theme.textTheme.bodyLarge),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildGradesList(ThemeData theme, bool isDarkMode) {
    Query query = _firestore.collection('grades');

    if (selectedSubjectId != null) {
      query = query.where('subjectId', isEqualTo: selectedSubjectId);
    }
    if (selectedStudentId != null) {
      query = query.where('studentId', isEqualTo: selectedStudentId);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        if (snapshot.data!.docs.isEmpty) {
          return Center(child: Text("No grades found", style: theme.textTheme.bodyLarge));
        }

        return ListView(
          children: snapshot.data!.docs.map((doc) {
            var grade = doc['grade'];
            var remarks = doc['remarks'] ?? '';
            var studentId = doc['studentId'];
            var subjectId = doc['subjectId'];

            return Card(
              color: theme.cardColor,
              elevation: 4,
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: ListTile(
                title: Text('Grade: $grade', style: theme.textTheme.titleMedium),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FutureBuilder<DocumentSnapshot>(
                      future: _firestore.collection('subjects').doc(subjectId).get(),
                      builder: (context, subjectSnap) {
                        if (!subjectSnap.hasData) return const Text("Loading subject...");
                        return Text("Subject: ${subjectSnap.data!['name']}", style: theme.textTheme.bodyLarge);
                      },
                    ),
                    FutureBuilder<DocumentSnapshot>(
                      future: _firestore.collection('users').doc(studentId).get(),
                      builder: (context, studentSnap) {
                        if (!studentSnap.hasData) return const Text("Loading student...");
                        return Text("Student: ${studentSnap.data!['email']}", style: theme.textTheme.bodyLarge);
                      },
                    ),
                    Text("Remarks: $remarks", style: theme.textTheme.bodyLarge),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.edit, color: theme.colorScheme.secondary),
                      onPressed: () => _editGradeDialog(doc.id, grade, remarks, theme),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete, color: Colors.redAccent),
                      onPressed: () => _deleteGrade(doc.id, theme),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildAddGradeButton(ThemeData theme) {
    return ElevatedButton.icon(
      onPressed: () => _addGradeDialog(theme),
      icon: const Icon(Icons.add),
      label: const Text("Add Grade"),
      style: ElevatedButton.styleFrom(
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
      ),
    );
  }

  void _addGradeDialog(ThemeData theme) {
    double? gradeValue;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.dialogBackgroundColor,
        title: const Text("Add Grade"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _subjectDropdown(theme),
            const SizedBox(height: 10),
            _studentDropdown(theme),
            const SizedBox(height: 10),
            TextField(
              decoration: const InputDecoration(labelText: "Grade"),
              keyboardType: TextInputType.number,
              onChanged: (val) => gradeValue = double.tryParse(val),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (selectedSubjectId == null || selectedStudentId == null || gradeValue == null) return;

              await _firestore.collection('grades').add({
                'subjectId': selectedSubjectId,
                'studentId': selectedStudentId,
                'grade': gradeValue,
              });

              Navigator.pop(context);
            },
            child: const Text("Add"),
          ),
        ],
      ),
    );
  }

  void _editGradeDialog(String docId, double currentGrade, String remarks, ThemeData theme) {
    double? updatedGrade = currentGrade;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.dialogBackgroundColor,
        title: const Text("Edit Grade"),
        content: TextField(
          decoration: const InputDecoration(labelText: "Grade"),
          keyboardType: TextInputType.number,
          controller: TextEditingController(text: currentGrade.toString()),
          onChanged: (val) => updatedGrade = double.tryParse(val),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              if (updatedGrade == null) return;

              await _firestore.collection('grades').doc(docId).update({
                'grade': updatedGrade,
              });

              Navigator.pop(context);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  void _deleteGrade(String docId, ThemeData theme) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.dialogBackgroundColor,
        title: const Text("Delete Grade"),
        content: const Text("Are you sure you want to delete this grade?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              await _firestore.collection('grades').doc(docId).delete();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }
}
