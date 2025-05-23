import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io' show File, Platform;
import 'package:share_plus/share_plus.dart';
import 'package:universal_html/html.dart' as html;

class SettingsScreen extends StatefulWidget {
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _currentPasswordController;
  late TextEditingController _newPasswordController;

  bool _isLoading = true;
  bool _isEditing = false;
  bool _isChangingPassword = false;
  bool _showCurrentPassword = false;
  bool _showNewPassword = false;
  bool _isDarkMode = false;
  bool _is2FAEnabled = false;
  bool _isLoginNotificationsEnabled = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _currentPasswordController = TextEditingController();
    _newPasswordController = TextEditingController();
    _loadUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final doc = await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists) {
          final data = doc.data()!;
          setState(() {
            _nameController.text = data['name'] ?? '';
            _emailController.text = user.email ?? '';
            _isDarkMode = data['darkMode'] ?? false;
            _is2FAEnabled = data['twoFactorEnabled'] ?? false;
            _isLoginNotificationsEnabled = data['loginNotifications'] ?? false;
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load user data: ${e.toString()}')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isEditing = true);
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).update({
          'name': _nameController.text,
          'darkMode': _isDarkMode,
          'twoFactorEnabled': _is2FAEnabled,
          'loginNotifications': _isLoginNotificationsEnabled,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Profile updated successfully')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update profile: ${e.toString()}')),
      );
    } finally {
      setState(() => _isEditing = false);
    }
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isChangingPassword = true);
    try {
      final user = _auth.currentUser;
      if (user != null && user.email != null) {
        final cred = EmailAuthProvider.credential(
          email: user.email!,
          password: _currentPasswordController.text,
        );
        await user.reauthenticateWithCredential(cred);

        await user.updatePassword(_newPasswordController.text);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Password changed successfully')),
        );

        _currentPasswordController.clear();
        _newPasswordController.clear();
      }
    } on FirebaseAuthException catch (e) {
      String message = 'Password change failed';
      if (e.code == 'wrong-password') {
        message = 'Current password is incorrect';
      } else if (e.code == 'weak-password') {
        message = 'New password is too weak';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to change password: ${e.toString()}')),
      );
    } finally {
      setState(() => _isChangingPassword = false);
    }
  }

  Future<void> _toggle2FA(bool enable) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        if (enable) {
          // Send verification email for 2FA
          await user.sendEmailVerification();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Verification email sent. Please verify to enable 2FA.'),
            ),
          );
        }

        await _firestore.collection('users').doc(user.uid).update({
          'twoFactorEnabled': enable,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        setState(() => _is2FAEnabled = enable);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('2-Factor Authentication ${enable ? 'enabled' : 'disabled'}'),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update 2FA settings: ${e.toString()}')),
      );
    }
  }

  Future<void> _toggleLoginNotifications(bool enable) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).update({
          'loginNotifications': enable,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        setState(() => _isLoginNotificationsEnabled = enable);

        // Log login attempt if notifications are enabled
        if (enable) {
          await _firestore.collection('login_notifications').add({
            'userId': user.uid,
            'timestamp': FieldValue.serverTimestamp(),
            'deviceInfo': await _getDeviceInfo(),
          });
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Login notifications ${enable ? 'enabled' : 'disabled'}'),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update notification settings: ${e.toString()}')),
      );
    }
  }

  Future<String> _getDeviceInfo() async {
    // In a real app, you'd use device_info_plus package
    return 'Device: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}';
  }

  Future<void> _exportUserData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      setState(() => _isLoading = true);

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) return;

      final userData = userDoc.data()!;
      final serializableData = _convertFirestoreData(userData);
      final jsonString = JsonEncoder.withIndent('  ').convert(serializableData);
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final fileName = 'user_data_$timestamp.json';

      if (kIsWeb) {
        final bytes = Uint8List.fromList(utf8.encode(jsonString));
        final blob = html.Blob([bytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute('download', fileName)
          ..click();
        html.Url.revokeObjectUrl(url);
      } else {
        final directory = await getTemporaryDirectory();
        final file = File('${directory.path}/$fileName');
        await file.writeAsString(jsonString);
        await Share.shareXFiles([XFile(file.path)], text: 'Here is my exported data');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data exported successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to export data: ${e.toString()}')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Map<String, dynamic> _convertFirestoreData(Map<String, dynamic> data) {
    return data.map((key, value) {
      if (value is Timestamp) {
        return MapEntry(key, value.toDate().toIso8601String());
      } else if (value is Map<String, dynamic>) {
        return MapEntry(key, _convertFirestoreData(value));
      } else if (value is List) {
        return MapEntry(key, value.map((item) {
          if (item is Timestamp) return item.toDate().toIso8601String();
          if (item is Map<String, dynamic>) return _convertFirestoreData(item);
          return item;
        }).toList());
      }
      return MapEntry(key, value);
    });
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? Center(child: CircularProgressIndicator())
        : Theme(
      data: _isDarkMode
          ? ThemeData.dark().copyWith(
        primaryColor: Colors.blueGrey,
        scaffoldBackgroundColor: Colors.black,
        textTheme: ThemeData.dark().textTheme.apply(
          bodyColor: Colors.white,
          displayColor: Colors.white,
        ),
      )
          : ThemeData.light().copyWith(
        primaryColor: Colors.blue,
        scaffoldBackgroundColor: Colors.white,
        textTheme: ThemeData.light().textTheme.apply(
          bodyColor: Colors.black,
          displayColor: Colors.black,
        ),
      ),
      child: DefaultTabController(
        length: 3,
        child: Scaffold(
          appBar: AppBar(
            title: Text('Settings'),
            bottom: TabBar(
              tabs: [
                Tab(icon: Icon(Icons.person)),
                Tab(icon: Icon(Icons.security)),
                Tab(icon: Icon(Icons.settings)),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              _buildProfileTab(),
              _buildSecurityTab(),
              _buildPreferencesTab(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Profile Information',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
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
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
              enabled: false,
            ),
            SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isEditing ? null : _updateProfile,
                child: _isEditing
                    ? CircularProgressIndicator(color: Colors.white)
                    : Text('Save Profile'),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecurityTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Change Password',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: _currentPasswordController,
              decoration: InputDecoration(
                labelText: 'Current Password',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock),
                suffixIcon: IconButton(
                  icon: Icon(
                    _showCurrentPassword ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () => setState(
                          () => _showCurrentPassword = !_showCurrentPassword),
                ),
              ),
              obscureText: !_showCurrentPassword,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your current password';
                }
                if (value.length < 6) {
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
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    _showNewPassword ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () => setState(() => _showNewPassword = !_showNewPassword),
                ),
              ),
              obscureText: !_showNewPassword,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a new password';
                }
                if (value.length < 8) {
                  return 'Password must be at least 8 characters';
                }
                return null;
              },
            ),
            SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isChangingPassword ? null : _changePassword,
                child: _isChangingPassword
                    ? CircularProgressIndicator(color: Colors.white)
                    : Text('Change Password'),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            SizedBox(height: 32),
            Text(
              'Security Settings',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            SizedBox(height: 16),
            SwitchListTile(
              title: Text('Two-Factor Authentication'),
              subtitle: Text('Add an extra layer of security with email verification'),
              value: _is2FAEnabled,
              onChanged: (value) => _toggle2FA(value),
            ),
            SwitchListTile(
              title: Text('Login Notifications'),
              subtitle: Text('Receive notifications for account login attempts'),
              value: _isLoginNotificationsEnabled,
              onChanged: (value) => _toggleLoginNotifications(value),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreferencesTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Appearance',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          SizedBox(height: 16),
          SwitchListTile(
            title: Text('Dark Mode'),
            value: _isDarkMode,
            onChanged: (value) {
              setState(() {
                _isDarkMode = value;
              });
              _updateProfile();
            },
          ),
          SizedBox(height: 24),
          Text(
            'Data Management',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          SizedBox(height: 16),
          ListTile(
            leading: Icon(Icons.backup),
            title: Text('Export Data'),
            subtitle: Text('Download a copy of your data'),
            onTap: _exportUserData,
          ),
        ],
      ),
    );
  }
}