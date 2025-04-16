import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';

class AccountSettingsScreen extends StatefulWidget {
  @override
  _AccountSettingsScreenState createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  TextEditingController _currentPasswordController = TextEditingController();
  TextEditingController _newPasswordController = TextEditingController();

  bool _isLoading = true;
  bool _emailVerified = false;
  String? _error;
  String? _success;
  User? _user;

  // Preferences
  bool _darkMode = false;
  bool _notificationsEnabled = true;
  String _language = 'English';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      _user = _auth.currentUser;
      if (_user == null) return;

      _emailVerified = _user!.emailVerified;

      // Load user profile data from Firestore
      final doc = await _firestore.collection('users').doc(_user!.uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        _nameController = TextEditingController(text: data['name'] ?? '');
        _phoneController = TextEditingController(text: data['phone'] ?? '');

        // Load preferences
        _darkMode = data['preferences']?['darkMode'] ?? false;
        _notificationsEnabled = data['preferences']?['notifications'] ?? true;
        _language = data['preferences']?['language'] ?? 'English';
      } else {
        _nameController = TextEditingController();
        _phoneController = TextEditingController();
      }

      _emailController = TextEditingController(text: _user!.email);

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load user data: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      setState(() {
        _isLoading = true;
        _error = null;
        _success = null;
      });

      await _firestore.collection('users').doc(_user!.uid).set({
        'name': _nameController.text,
        'phone': _phoneController.text,
        'lastUpdated': FieldValue.serverTimestamp(),
        'preferences': {
          'darkMode': _darkMode,
          'notifications': _notificationsEnabled,
          'language': _language,
        }
      }, SetOptions(merge: true));

      setState(() {
        _success = 'Profile updated successfully!';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to update profile: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _updateEmail() async {
    if (_emailController.text.isEmpty) return;
    if (_emailController.text == _user!.email) return;

    try {
      setState(() {
        _isLoading = true;
        _error = null;
        _success = null;
      });

      // Reauthenticate first
      await _reauthenticate();

      await _user!.verifyBeforeUpdateEmail(_emailController.text);

      setState(() {
        _success = 'Verification email sent to ${_emailController.text}. '
            'Please verify your new email address.';
        _isLoading = false;
        _emailVerified = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to update email: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _updatePassword() async {
    if (_newPasswordController.text.isEmpty) return;

    try {
      setState(() {
        _isLoading = true;
        _error = null;
        _success = null;
      });

      // Reauthenticate first
      await _reauthenticate();

      await _user!.updatePassword(_newPasswordController.text);

      setState(() {
        _success = 'Password updated successfully!';
        _isLoading = false;
        _currentPasswordController.clear();
        _newPasswordController.clear();
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to update password: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _reauthenticate() async {
    try {
      final credential = EmailAuthProvider.credential(
        email: _user!.email!,
        password: _currentPasswordController.text,
      );
      await _user!.reauthenticateWithCredential(credential);
    } catch (e) {
      throw Exception('Current password is incorrect');
    }
  }

  Future<void> _sendVerificationEmail() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      await _user!.sendEmailVerification();

      setState(() {
        _success = 'Verification email sent to ${_user!.email}';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to send verification email: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirm Account Deletion'),
        content: Text('Are you sure you want to delete your account? '
            'This action cannot be undone.'),
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

    if (confirmed != true) return;

    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Reauthenticate first
      await _reauthenticate();

      // Delete from Firestore
      await _firestore.collection('users').doc(_user!.uid).delete();

      // Delete from Auth
      await _user!.delete();

      // Navigate to login screen
      Navigator.pushNamedAndRemoveUntil(
          context, '/login', (route) => false);

    } catch (e) {
      setState(() {
        _error = 'Failed to delete account: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  Widget _buildProfileSection() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Profile Information', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Full Name',
                      prefixIcon: Icon(Icons.person),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your name';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 16),
                  TextFormField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email),
                      suffixIcon: _emailVerified
                          ? Tooltip(
                          message: 'Email verified',
                          child: Icon(Icons.verified, color: Colors.green))
                          : IconButton(
                        icon: Icon(Icons.warning, color: Colors.orange),
                        onPressed: _sendVerificationEmail,
                        tooltip: 'Email not verified. Click to resend verification',
                      ),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email';
                      }
                      if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 16),
                  TextFormField(
                    controller: _phoneController,
                    decoration: InputDecoration(
                      labelText: 'Phone Number',
                      prefixIcon: Icon(Icons.phone),
                    ),
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                  ),
                  SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _updateProfile,
                      child: _isLoading
                          ? CircularProgressIndicator()
                          : Text('Save Profile Changes'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecuritySection() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Security', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            TextFormField(
              controller: _currentPasswordController,
              decoration: InputDecoration(
                labelText: 'Current Password',
                prefixIcon: Icon(Icons.lock),
              ),
              obscureText: true,
              validator: (value) {
                if (value != null && value.isNotEmpty && value.length < 6) {
                  return 'Password must be at least 6 characters';
                }
                return null;
              },
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: _newPasswordController,
              decoration: InputDecoration(
                labelText: 'New Password',
                prefixIcon: Icon(Icons.lock_outline),
              ),
              obscureText: true,
              validator: (value) {
                if (value != null && value.isNotEmpty && value.length < 6) {
                  return 'Password must be at least 6 characters';
                }
                return null;
              },
            ),
            SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _updatePassword,
                child: _isLoading
                    ? CircularProgressIndicator()
                    : Text('Update Password'),
              ),
            ),
            SizedBox(height: 16),
            Divider(),
            SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _updateEmail,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade50,
                  foregroundColor: Colors.blue,
                ),
                child: _isLoading
                    ? CircularProgressIndicator()
                    : Text('Update Email Address'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreferencesSection() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Preferences', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            SwitchListTile(
              title: Text('Dark Mode'),
              value: _darkMode,
              onChanged: _isLoading ? null : (value) {
                setState(() => _darkMode = value);
                _updateProfile(); // Auto-save preference
              },
            ),
            SwitchListTile(
              title: Text('Enable Notifications'),
              value: _notificationsEnabled,
              onChanged: _isLoading ? null : (value) {
                setState(() => _notificationsEnabled = value);
                _updateProfile(); // Auto-save preference
              },
            ),
            ListTile(
              title: Text('Language'),
              trailing: DropdownButton<String>(
                value: _language,
                items: ['English', 'French', 'Spanish', 'German']
                    .map((lang) => DropdownMenuItem(
                  value: lang,
                  child: Text(lang),
                ))
                    .toList(),
                onChanged: _isLoading ? null : (value) {
                  if (value != null) {
                    setState(() => _language = value);
                    _updateProfile(); // Auto-save preference
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDangerZone() {
    return Card(
      color: Colors.red.shade50,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Danger Zone', style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            )),
            SizedBox(height: 16),
            Text('These actions are irreversible. Proceed with caution.',
                style: TextStyle(color: Colors.red.shade700)),
            SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _deleteAccount,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade100,
                  foregroundColor: Colors.red,
                ),
                child: Text('Delete Account'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _user == null) {
      return Scaffold(
        appBar: AppBar(title: Text('Account Settings')),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_user == null) {
      return Scaffold(
        appBar: AppBar(title: Text('Account Settings')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red),
              SizedBox(height: 20),
              Text('You need to be logged in to access settings'),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/login');
                },
                child: Text('Go to Login'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Account Settings'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadUserData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            if (_error != null)
              Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Text(
                  _error!,
                  style: TextStyle(color: Colors.red),
                ),
              ),
            if (_success != null)
              Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Text(
                  _success!,
                  style: TextStyle(color: Colors.green),
                ),
              ),
            _buildProfileSection(),
            SizedBox(height: 16),
            _buildSecuritySection(),
            SizedBox(height: 16),
            _buildPreferencesSection(),
            SizedBox(height: 16),
            _buildDangerZone(),
          ],
        ),
      ),
    );
  }
}