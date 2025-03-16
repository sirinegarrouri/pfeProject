import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class UserDetailsScreen extends StatefulWidget {
  final String userId;

  const UserDetailsScreen({required this.userId, super.key});

  @override
  State<UserDetailsScreen> createState() => _UserDetailsScreenState();
}

class _UserDetailsScreenState extends State<UserDetailsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isEditing = false;
  bool _isDarkMode = false;

  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _roleController;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
    _phoneController = TextEditingController();
    _roleController = TextEditingController();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      DocumentSnapshot doc =
      await _firestore.collection('users').doc(widget.userId).get();
      if (!doc.exists) return;

      var userData = doc.data() as Map<String, dynamic>;
      _emailController.text = userData['email'] ?? '';
      _phoneController.text = userData['phone'] ?? '';
      _roleController.text = userData['role'] ?? '';
    } catch (e) {
      debugPrint("Error loading user: $e");
    }
  }

  Future<void> _saveUserData() async {
    try {
      await _firestore.collection('users').doc(widget.userId).update({
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'role': _roleController.text.trim(),
      });

      setState(() => _isEditing = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User updated successfully!')),
      );
    } catch (e) {
      debugPrint("Error saving user: $e");
    }
  }

  Future<void> _deleteUser() async {
    try {
      await _firestore.collection('users').doc(widget.userId).delete();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User deleted successfully!')),
      );

      Navigator.pop(context);
    } catch (e) {
      debugPrint("Error deleting user: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    Color backgroundColor =
    _isDarkMode ? const Color(0xFF121212) : Colors.grey[200]!;
    Color textColor = _isDarkMode ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: _isDarkMode ? Colors.black : Colors.blueAccent,
        title: const Text('User Details'),
        actions: [
          IconButton(
            icon: Icon(_isDarkMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: () => setState(() => _isDarkMode = !_isDarkMode),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: FutureBuilder<DocumentSnapshot>(
          future: _firestore.collection('users').doc(widget.userId).get(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Text('Error: ${snapshot.error}',
                    style: TextStyle(color: textColor)),
              );
            }

            if (!snapshot.hasData || !snapshot.data!.exists) {
              return Center(
                child: Text('User not found',
                    style: TextStyle(color: textColor)),
              );
            }

            return SingleChildScrollView(
              child: Column(
                children: [
                  Card(
                    color: _isDarkMode
                        ? Colors.white.withOpacity(0.05)
                        : Colors.white.withOpacity(0.9),
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        gradient: _isDarkMode
                            ? LinearGradient(
                          colors: [
                            Color(0xFF1E1E1E),
                            Color(0xFF121212)
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                            : LinearGradient(
                          colors: [
                            Colors.white,
                            Colors.grey[100]!
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _isDarkMode
                                ? Colors.black.withOpacity(0.3)
                                : Colors.grey.withOpacity(0.3),
                            blurRadius: 20,
                            offset: Offset(0, 10),
                          ),
                        ],
                        border: Border.all(
                          color: _isDarkMode
                              ? Colors.white.withOpacity(0.1)
                              : Colors.grey.withOpacity(0.2),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 30),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundColor: _isDarkMode
                                ? Colors.grey[800]
                                : Colors.blueAccent,
                            child: Icon(
                              Icons.person,
                              color: Colors.white,
                              size: 50,
                            ),
                          ),
                          const SizedBox(height: 30),

                          // Email Row
                          _isEditing
                              ? _buildTextField(
                            controller: _emailController,
                            label: 'Email',
                            icon: Icons.email,
                            textColor: textColor,
                          )
                              : _buildInfoRow(
                              "📧 Email", _emailController.text, textColor),

                          const SizedBox(height: 24),

                          // Phone Row
                          _isEditing
                              ? _buildTextField(
                            controller: _phoneController,
                            label: 'Phone',
                            icon: Icons.phone,
                            textColor: textColor,
                          )
                              : _buildInfoRow(
                              "📞 Phone", _phoneController.text, textColor),

                          const SizedBox(height: 24),

                          // Role Row
                          _isEditing
                              ? _buildTextField(
                            controller: _roleController,
                            label: 'Role',
                            icon: Icons.person,
                            textColor: textColor,
                          )
                              : _buildInfoRow(
                              "🔹 Role", _roleController.text, textColor),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      if (_isEditing)
                        ElevatedButton.icon(
                          icon: const Icon(Icons.save),
                          label: const Text('Save'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: _saveUserData,
                        ),
                      if (!_isEditing)
                        ElevatedButton.icon(
                          icon: const Icon(Icons.edit),
                          label: const Text('Edit'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: () =>
                              setState(() => _isEditing = true),
                        ),
                      if (!_isEditing)
                        ElevatedButton.icon(
                          icon: const Icon(Icons.delete),
                          label: const Text('Delete'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: _deleteUser,
                        ),
                    ],
                  )
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required Color textColor,
  }) {
    return TextFormField(
      controller: controller,
      style: TextStyle(color: textColor, fontSize: 18),
      textAlign: TextAlign.center,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: textColor.withOpacity(0.7)),
        filled: true,
        fillColor: _isDarkMode ? Colors.grey[800] : Colors.grey[100],
        labelStyle: TextStyle(color: textColor),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: textColor.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: textColor),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: TextStyle(
            color: textColor.withOpacity(0.7),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        Text(
          value,
          style: TextStyle(
            color: textColor,
            fontSize: 24, // Bigger font size for emphasis
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
