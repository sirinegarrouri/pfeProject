import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'user_management_screen.dart';
import 'settings_screen.dart';
import 'admin_reclamations_screen.dart';
import 'events_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MaterialApp(
    title: 'Admin Dashboard',
    theme: ThemeData(
      primarySwatch: Colors.teal,
      scaffoldBackgroundColor: Colors.grey[100],
      cardTheme: CardTheme(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: EdgeInsets.zero,
      ),
      textTheme: TextTheme(
        titleLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87),
        titleMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black54),
        bodyMedium: TextStyle(fontSize: 12, color: Colors.black54),
      ),
      buttonTheme: ButtonThemeData(
        buttonColor: Colors.teal,
        textTheme: ButtonTextTheme.primary,
      ),
      visualDensity: VisualDensity.compact,
    ),
    home: AdminDashboard(),
  ));
}

class AdminDashboard extends StatefulWidget {
  @override
  _AdminDashboardState createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final List<Widget> _screens = [
    DashboardScreen(),
    NotificationsScreen(),
    UserManagementScreen(),
    AdminReclamationsScreen(),
    SettingsScreen(),
    EventsScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    _scaffoldKey.currentState?.closeDrawer();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text(_getAppBarTitle(), style: Theme.of(context).textTheme.titleLarge),
        leading: IconButton(
          icon: Icon(Icons.menu, size: 20),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        actions: [
          if (_selectedIndex != 4)
            IconButton(
              icon: Icon(Icons.refresh, size: 20),
              onPressed: () {
                if (_selectedIndex == 0) {
                  (_screens[0] as DashboardScreen).refreshData();
                } else if (_selectedIndex == 3) {
                  (_screens[3] as AdminReclamationsScreen).refreshData();
                }
              },
            ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'logout') {
                _logout();
              }
            },
            itemBuilder: (BuildContext context) {
              return {'Logout'}.map((String choice) {
                return PopupMenuItem<String>(
                  value: choice.toLowerCase(),
                  child: Text(choice, style: Theme.of(context).textTheme.bodyMedium),
                );
              }).toList();
            },
          ),
        ],
      ),
      drawer: _buildDrawer(),
      body: _screens[_selectedIndex],
    );
  }

  String _getAppBarTitle() {
    switch (_selectedIndex) {
      case 0:
        return 'Dashboard';
      case 1:
        return 'Notifications';
      case 2:
        return 'User Management';
      case 3:
        return 'Reclamations';
      case 4:
        return 'Settings';
      case 5:
        return 'Events';
      default:
        return 'Admin Panel';
    }
  }

  Widget _buildDrawer() {
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
                  'Admin Panel',
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
            leading: Icon(Icons.dashboard, size: 20),
            title: Text('Dashboard', style: Theme.of(context).textTheme.bodyMedium),
            selected: _selectedIndex == 0,
            onTap: () => _onItemTapped(0),
          ),
          ListTile(
            leading: Icon(Icons.notifications, size: 20),
            title: Text('Alerts', style: Theme.of(context).textTheme.bodyMedium),
            selected: _selectedIndex == 1,
            onTap: () => _onItemTapped(1),
          ),
          ListTile(
            leading: Icon(Icons.people, size: 20),
            title: Text('User Management', style: Theme.of(context).textTheme.bodyMedium),
            selected: _selectedIndex == 2,
            onTap: () => _onItemTapped(2),
          ),
          ListTile(
            leading: Icon(Icons.report, size: 20),
            title: Text('Reclamations', style: Theme.of(context).textTheme.bodyMedium),
            selected: _selectedIndex == 3,
            onTap: () => _onItemTapped(3),
          ),
          ListTile(
            leading: Icon(Icons.settings, size: 20),
            title: Text('Settings', style: Theme.of(context).textTheme.bodyMedium),
            selected: _selectedIndex == 4,
            onTap: () => _onItemTapped(4),
          ),
          ListTile(
            leading: Icon(Icons.event, size: 20),
            title: Text('Events', style: Theme.of(context).textTheme.bodyMedium),
            selected: _selectedIndex == 5,
            onTap: () => _onItemTapped(5),
          ),
          ListTile(
            leading: Icon(Icons.exit_to_app, size: 20),
            title: Text('Sign Out', style: Theme.of(context).textTheme.bodyMedium),
            onTap: () async {
              await _auth.signOut();
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    try {
      await FirebaseAuth.instance.signOut();
      Navigator.pushReplacementNamed(context, '/login');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Logout failed: ${e.toString()}')),
      );
    }
  }
}

class NotificationStats {
  final String day;
  final int count;
  final Color color;
  NotificationStats({
    required this.day,
    required this.count,
    required this.color,
  });
}

class DashboardScreen extends StatefulWidget {
  @override
  _DashboardScreenState createState() => _DashboardScreenState();

  void refreshData() {}
}

class _DashboardScreenState extends State<DashboardScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  int _totalNotifications = 0;
  int _readNotifications = 0;
  int _totalUsers = 0;
  List<NotificationStats> _weeklyStats = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void refreshData() {
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // Fetch total notifications count
      final totalQuery = await _firestore.collection('notifications').count().get();
      final totalAlertsQuery = await _firestore.collection('alerts').count().get();
      print('Total notifications count: ${totalQuery.count}');
      print('Total alerts count: ${totalAlertsQuery.count}');

      // Fetch read notifications count
      final readQuery = await _firestore
          .collection('notifications')
          .where('read', isEqualTo: true)
          .count()
          .get();
      final readAlertsQuery = await _firestore
          .collection('alerts')
          .where('read', isEqualTo: true)
          .count()
          .get();
      // Fetch total users count
      final usersQuery = await _firestore.collection('users').count().get();


      // Fetch notifications and alerts for weekly stats (last 30 days)
      final now = DateTime.now();
      final startOfPeriod = now.subtract(Duration(days: 30));
      final notificationsSnapshot = await _firestore
          .collection('notifications')
          .where('timestamp', isGreaterThan: Timestamp.fromDate(startOfPeriod))
          .get();
      final alertsSnapshot = await _firestore
          .collection('alerts')
          .where('timestamp', isGreaterThan: Timestamp.fromDate(startOfPeriod))
          .get();


      final dailyCounts = <int, int>{};
      for (var i = 0; i < 7; i++) {
        dailyCounts[i] = 0;
      }

      // Process notifications
      for (final doc in notificationsSnapshot.docs) {
        final data = doc.data();
        final timestamp = data['timestamp'] as Timestamp?;
        if (timestamp != null) {
          final date = timestamp.toDate();
          final dayOfWeek = date.weekday - 1;
          dailyCounts[dayOfWeek] = (dailyCounts[dayOfWeek] ?? 0) + 1;

        } else {

        }
      }

      // Process alerts
      for (final doc in alertsSnapshot.docs) {
        final data = doc.data();
        final timestamp = data['timestamp'] as Timestamp?;
        if (timestamp != null) {
          final date = timestamp.toDate();
          final dayOfWeek = date.weekday - 1;
          dailyCounts[dayOfWeek] = (dailyCounts[dayOfWeek] ?? 0) + 1;

        } else {

        }
      }

      final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

      setState(() {
        _totalNotifications = (totalQuery.count ?? 0) + (totalAlertsQuery.count ?? 0);
        _readNotifications = (readQuery.count ?? 0) + (readAlertsQuery.count ?? 0);
        _totalUsers = usersQuery.count ?? 0;
        _weeklyStats = dailyCounts.entries.map((entry) {
          return NotificationStats(
            day: weekdays[entry.key],
            count: entry.value,
            color: _getColorForDay(entry.key),
          );
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading dashboard data: $e');
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load dashboard data: $e')),
      );
    }
  }

  Color _getColorForDay(int dayIndex) {
    final colors = [
      Colors.teal,
      Colors.blue,
      Colors.amber,
      Colors.redAccent,
      Colors.purple,
      Colors.green,
      Colors.indigo,
    ];
    return colors[dayIndex % colors.length];
  }

  Widget _buildStatsCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: color.withOpacity(0.1),
              child: Icon(icon, size: 20, color: color),
            ),
            SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.bodyMedium),
                SizedBox(height: 4),
                Text(value, style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationChart() {
    if (_weeklyStats.isEmpty || _weeklyStats.every((stat) => stat.count == 0)) {
      return Center(child: Text('No notification data available', style: Theme.of(context).textTheme.bodyMedium));
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Weekly Notifications',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: _weeklyStats
                      .map((e) => e.count.toDouble())
                      .reduce((a, b) => a > b ? a : b) *
                      1.2,
                  barGroups: _weeklyStats.asMap().entries.map((entry) {
                    final stats = entry.value;
                    return BarChartGroupData(
                      x: entry.key,
                      barRods: [
                        BarChartRodData(
                          toY: stats.count.toDouble(),
                          color: stats.color,
                          width: 10,
                          borderRadius: BorderRadius.circular(4),
                          backDrawRodData: BackgroundBarChartRodData(
                            show: true,
                            toY: _weeklyStats
                                .map((e) => e.count.toDouble())
                                .reduce((a, b) => a > b ? a : b) *
                                1.2,
                            color: Colors.grey[100],
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              _weeklyStats[value.toInt()].day,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toInt().toString(),
                            style: Theme.of(context).textTheme.bodyMedium,
                          );
                        },
                        reservedSize: 24,
                      ),
                    ),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 1,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: Colors.grey[200]!,
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border(
                      bottom: BorderSide(color: Colors.grey[300]!, width: 1),
                      left: BorderSide(color: Colors.grey[300]!, width: 1),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 200,
                child: _buildStatsCard('Total Users', _totalUsers.toString(), Icons.people, Colors.teal),
              ),
              SizedBox(
                width: 200,
                child: _buildStatsCard(
                    'Notifications', _totalNotifications.toString(), Icons.notifications, Colors.blue),
              ),
              SizedBox(
                width: 200,
                child: _buildStatsCard(
                    'Read',
                    _totalNotifications > 0
                        ? '${(_readNotifications / _totalNotifications * 100).toStringAsFixed(0)}%'
                        : '0%',
                    Icons.mark_email_read,
                    Colors.amber),
              ),
            ],
          ),
          SizedBox(height: 12),
          _buildNotificationChart(),
        ],
      ),
    );
  }
}

class NotificationsScreen extends StatefulWidget {
  @override
  _NotificationsScreenState createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _notificationController = TextEditingController();
  bool _isSending = false;
  bool _isSendingToAll = false;
  String? _selectedUserId;
  String _selectedCategory = 'Nothing';
  List<Map<String, dynamic>> _users = [];
  int _totalUsers = 0;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    try {
      final snapshot = await _firestore.collection('users').get();
      final countSnapshot = await _firestore.collection('users').count().get();

      setState(() {
        _users = snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'email': data['email'] as String? ?? 'No email',
            'name': data['name'] as String? ?? 'No name',
          };
        }).toList();
        _totalUsers = countSnapshot.count ?? 0;
      });
    } catch (e) {
      print('Error loading users: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load users: $e')),
      );
    }
  }

  Future<void> _sendNotification() async {
    if (_notificationController.text.isEmpty || _selectedUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a user and enter a message')),
      );
      return;
    }

    setState(() => _isSending = true);

    try {
      final notificationData = {
        'message': _notificationController.text,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
        'userId': _selectedUserId,
        'senderId': _auth.currentUser?.uid ?? 'unknown',
        'senderRole': 'admin',
        'category': _selectedCategory,
        'isEmergency': _selectedCategory != 'Nothing',
      };

      final collection = _selectedCategory == 'Nothing' ? 'notifications' : 'alerts';
      print('Sending to $collection: $notificationData');
      await _firestore.collection(collection).add(notificationData);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_selectedCategory == 'Nothing'
              ? 'Notification sent successfully'
              : 'Emergency alert sent successfully'),
        ),
      );

      _notificationController.clear();
      setState(() => _selectedCategory = 'Nothing');
    } catch (e) {
      print('Error sending notification: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send: $e')),
      );
    } finally {
      setState(() => _isSending = false);
    }
  }

  Future<void> _sendNotificationToAllUsers() async {
    if (_notificationController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a message to send to all users')),
      );
      return;
    }

    setState(() => _isSendingToAll = true);

    try {
      final usersSnapshot = await _firestore.collection('users').get();
      final userIds = usersSnapshot.docs.map((doc) => doc.id).toList();
      final collection = _selectedCategory == 'Nothing'
          ? _firestore.collection('notifications')
          : _firestore.collection('alerts');

      const batchSize = 500;
      for (var i = 0; i < userIds.length; i += batchSize) {
        final batch = _firestore.batch();
        final subList = userIds.sublist(
          i,
          i + batchSize > userIds.length ? userIds.length : i + batchSize,
        );

        print('Preparing batch for ${subList.length} users in ${collection.path}');
        for (final userId in subList) {
          final docRef = collection.doc();
          batch.set(docRef, {
            'message': _notificationController.text,
            'timestamp': FieldValue.serverTimestamp(),
            'read': false,
            'userId': userId,
            'senderId': _auth.currentUser?.uid ?? 'unknown',
            'senderRole': 'admin',
            'category': _selectedCategory,
            'isEmergency': _selectedCategory != 'Nothing',
          });
        }
        await batch.commit();
        print('Batch committed for ${subList.length} users');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_selectedCategory == 'Nothing'
              ? 'Notification sent to all $_totalUsers users'
              : 'Emergency alert sent to all $_totalUsers users'),
        ),
      );
      _notificationController.clear();
      setState(() => _selectedCategory = 'Nothing');
    } catch (e) {
      print('Error sending to all users: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send to all users: $e')),
      );
    } finally {
      setState(() => _isSendingToAll = false);
    }
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Fire':
        return Colors.redAccent;
      case 'Earthquake':
        return Colors.amber;
      case 'Tsunami':
        return Colors.blue;
      case 'Nothing':
      default:
        return Colors.teal;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(12),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Send Notification',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  SizedBox(height: 12),
                  TextField(
                    controller: _notificationController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Message',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    ),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    decoration: InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    ),
                    items: ['Fire', 'Earthquake', 'Tsunami', 'Nothing'].map((category) {
                      return DropdownMenuItem<String>(
                        value: category,
                        child: Text(category, style: Theme.of(context).textTheme.bodyMedium),
                      );
                    }).toList(),
                    onChanged: (value) => setState(() => _selectedCategory = value!),
                  ),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedUserId,
                          decoration: InputDecoration(
                            labelText: 'Select User',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                          ),
                          items: [
                            ..._users.map((user) {
                              return DropdownMenuItem<String>(
                                value: user['id'],
                                child: Text(
                                  '${user['name']} (${user['email']})',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                          ],
                          onChanged: (value) => setState(() => _selectedUserId = value),
                        ),
                      ),
                      SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _isSending ? null : _sendNotification,
                        child: Text(_isSending ? 'Sending...' : 'Send', style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          backgroundColor: _getCategoryColor(_selectedCategory),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: (_isSendingToAll || _users.isEmpty) ? null : _sendNotificationToAllUsers,
                      icon: Icon(Icons.group, size: 16),
                      label: Text(
                        _isSendingToAll
                            ? 'Sending to all $_totalUsers users...'
                            : 'Send to all $_totalUsers users',
                        style: TextStyle(fontSize: 12),
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: _getCategoryColor(_selectedCategory),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}