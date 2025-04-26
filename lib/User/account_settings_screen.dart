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
  bool _darkMode = false;
  bool _notificationsEnabled = true;
  String _language = 'English';
  ThemeMode _themeMode = ThemeMode.light;
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

      final doc = await _firestore.collection('users').doc(_user!.uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        _nameController = TextEditingController(text: data['name'] ?? '');
        _phoneController = TextEditingController(text: data['phone'] ?? '');

        _darkMode = data['preferences']?['darkMode'] ?? false;
        _notificationsEnabled = data['preferences']?['notifications'] ?? true;
        _language = data['preferences']?['language'] ?? 'English';
        _themeMode = _darkMode ? ThemeMode.dark : ThemeMode.light;
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

  Future<void> _savePreferences() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
        _success = null;
      });
      await _firestore.collection('users').doc(_user!.uid).set({
        'preferences': {
          'darkMode': _darkMode,
          'notifications': _notificationsEnabled,
          'language': _language,
        }
      }, SetOptions(merge: true));
      setState(() {
        _success = 'Preferences saved successfully!';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to save preferences: ${e.toString()}';
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
      await _reauthenticate();
      await _firestore.collection('users').doc(_user!.uid).delete();
      await _user!.delete();
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
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

  // Theme definitions
  ThemeData get _lightTheme => ThemeData(
    brightness: Brightness.light,
    primarySwatch: Colors.green,
    scaffoldBackgroundColor: Colors.white,
    cardTheme: CardTheme(
      elevation: 2,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        padding: EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      filled: true,
      fillColor: Colors.grey[100],
    ),
    textTheme: TextTheme(
      bodyMedium: TextStyle(color: Colors.black87),
    ),
  );

  ThemeData get _darkTheme => ThemeData(
    brightness: Brightness.dark,
    primarySwatch: Colors.green,
    scaffoldBackgroundColor: Colors.grey[900],
    cardTheme: CardTheme(
      elevation: 2,
      color: Colors.grey[800],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.grey[850],
      foregroundColor: Colors.white,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        padding: EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      filled: true,
      fillColor: Colors.grey[800],
    ),
    textTheme: TextTheme(
      bodyMedium: TextStyle(color: Colors.white70),
    ),
  );

  Widget _buildProfileSection() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Profile Information',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                        tooltip:
                        'Email not verified. Click to resend verification',
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
            Text('Security',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
            Text('Preferences',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            SwitchListTile(
              title: Text('Dark Mode'),
              value: _darkMode,
              onChanged: _isLoading
                  ? null
                  : (value) {
                setState(() {
                  _darkMode = value;
                  _themeMode = value ? ThemeMode.dark : ThemeMode.light;
                });
                _savePreferences();
              },
            ),
            SwitchListTile(
              title: Text('Enable Notifications'),
              value: _notificationsEnabled,
              onChanged: _isLoading
                  ? null
                  : (value) {
                setState(() => _notificationsEnabled = value);
                _savePreferences();
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
                onChanged: _isLoading
                    ? null
                    : (value) {
                  if (value != null) {
                    setState(() => _language = value);
                    _savePreferences();
                  }
                },
              ),
            ),
            SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _savePreferences,
                child: _isLoading
                    ? CircularProgressIndicator()
                    : Text('Save Preferences'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDangerZone() {
    return Card(
      color: _darkMode ? Colors.red.shade900 : Colors.red.shade50,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Danger Zone',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                )),
            SizedBox(height: 16),
            Text(
                'These actions are irreversible. Proceed with caution.',
                style: TextStyle(
                    color: _darkMode ? Colors.red.shade300 : Colors.red.shade700)),
            SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _deleteAccount,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                  _darkMode ? Colors.red.shade800 : Colors.red.shade100,
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
      return MaterialApp(
        theme: _lightTheme,
        darkTheme: _darkTheme,
        themeMode: _themeMode,
        home: Scaffold(
          appBar: AppBar(title: Text('Account Settings')),
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    if (_user == null) {
      return MaterialApp(
        theme: _lightTheme,
        darkTheme: _darkTheme,
        themeMode: _themeMode,
        home: Scaffold(
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
        ),
      );
    }

    return MaterialApp(
      theme: _lightTheme,
      darkTheme: _darkTheme,
      themeMode: _themeMode,
      home: Scaffold(
        appBar: AppBar(
          title: Text('Account Settings'),
          actions: [
            IconButton(
              icon: Icon(Icons.refresh, size: 20),
              onPressed: _loadUserData,
              tooltip: 'Refresh',
            ),
          ],
        ),
        drawer: _buildDrawer(context),
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
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.teal, Colors.tealAccent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.person, size: 32, color: Colors.teal),
                ),
                SizedBox(height: 8),
                Text(
                  'User Panel',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Welcome back',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: Icon(Icons.notifications),
            title: Text('Notifications'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/notifications');
            },
          ),
          ListTile(
            leading: Icon(Icons.report_problem),
            title: Text('Reclamation'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/reclamation');
            },
          ),
          ListTile(
            leading: Icon(Icons.settings),
            title: Text('Account Settings'),
            selected: true,
            onTap: () {
              Navigator.pop(context);
            },
          ),
          Divider(),
          ListTile(
            leading: Icon(Icons.logout, color: Colors.red),
            title: Text('Logout', style: TextStyle(color: Colors.red)),
            onTap: () async {
              Navigator.pop(context);
              try {
                await _auth.signOut();
                Navigator.pushNamedAndRemoveUntil(
                    context, '/login', (route) => false);
              } catch (e) {
                setState(() {
                  _error = 'Failed to sign out: ${e.toString()}';
                });
              }
            },
          ),
        ],
      ),
    );
  }
}