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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Grades Reports'),
        backgroundColor: Colors.blueAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildFilters(),   // 🔎 Filter dropdowns
            const SizedBox(height: 16),
            Expanded(child: _buildGradesList()),  // 📋 List of grades
            _buildAddGradeButton(),   // ➕ Add grade button
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Row(
      children: [
        Expanded(child: _subjectDropdown()),
        const SizedBox(width: 10),
        Expanded(child: _studentDropdown()),
      ],
    );
  }

  // 🔽 Dropdown for Subjects
  Widget _subjectDropdown() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('subjects').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const CircularProgressIndicator();

        var subjects = snapshot.data!.docs;

        return DropdownButton<String>(
          value: selectedSubjectId,
          hint: const Text("Select Subject"),
          onChanged: (value) {
            setState(() {
              selectedSubjectId = value;
            });
          },
          items: subjects.map((doc) {
            return DropdownMenuItem(
              value: doc.id,
              child: Text(doc['name']),
            );
          }).toList(),
        );
      },
    );
  }

  // 🔽 Dropdown for Students
  Widget _studentDropdown() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const CircularProgressIndicator();

        var students = snapshot.data!.docs;

        return DropdownButton<String>(
          value: selectedStudentId,
          hint: const Text("Select Student"),
          onChanged: (value) {
            setState(() {
              selectedStudentId = value;
            });
          },
          items: students.map((doc) {
            return DropdownMenuItem(
              value: doc.id,
              child: Text(doc['email']),
            );
          }).toList(),
        );
      },
    );
  }

  // 📋 List of Grades
  Widget _buildGradesList() {
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
          return const Center(child: Text("No grades found"));
        }

        return ListView(
          children: snapshot.data!.docs.map((doc) {
            var grade = doc['grade'];
            var remarks = doc['remarks'] ?? '';
            var studentId = doc['studentId'];
            var subjectId = doc['subjectId'];

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: ListTile(
                title: Text('Grade: $grade'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FutureBuilder<DocumentSnapshot>(
                      future: _firestore.collection('subjects').doc(subjectId).get(),
                      builder: (context, subjectSnap) {
                        if (!subjectSnap.hasData) return const Text("Loading subject...");
                        return Text("Subject: ${subjectSnap.data!['name']}");
                      },
                    ),
                    FutureBuilder<DocumentSnapshot>(
                      future: _firestore.collection('users').doc(studentId).get(),
                      builder: (context, studentSnap) {
                        if (!studentSnap.hasData) return const Text("Loading student...");
                        return Text("Student: ${studentSnap.data!['email']}");
                      },
                    ),
                    Text("Remarks: $remarks"),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.orange),
                      onPressed: () => _editGradeDialog(doc.id, grade, remarks),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteGrade(doc.id),
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

  // ➕ Add Grade Button
  Widget _buildAddGradeButton() {
    return ElevatedButton.icon(
      onPressed: () => _addGradeDialog(),
      icon: const Icon(Icons.add),
      label: const Text("Add Grade"),
    );
  }

  // ➕ Add Grade Dialog
  void _addGradeDialog() {
    String? selectedStudent;
    String? selectedSubject;
    double? gradeValue;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Add Grade"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _subjectDropdown(),
            _studentDropdown(),
            TextField(
              decoration: const InputDecoration(labelText: "Grade"),
              keyboardType: TextInputType.number,
              onChanged: (val) => gradeValue = double.tryParse(val),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
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

  // ✏️ Edit Grade Dialog
  void _editGradeDialog(String docId, double currentGrade, String remarks) {
    double? updatedGrade = currentGrade;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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

  // ❌ Delete Grade
  void _deleteGrade(String docId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Grade"),
        content: const Text("Are you sure you want to delete this grade?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              await _firestore.collection('grades').doc(docId).delete();
              Navigator.pop(context);
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
