import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'user_management_screen.dart';
import 'settings_screen.dart';

void main() {
  runApp(MaterialApp(
    title: 'Admin Dashboard',
    theme: ThemeData(
      primarySwatch: Colors.green,
      visualDensity: VisualDensity.adaptivePlatformDensity,
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

  final List<Widget> _screens = [
    DashboardScreen(),
    NotificationsScreen(),
    UserManagementScreen(),
    ReclamationScreen(),
    SettingsScreen(),
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
        title: Text(_getAppBarTitle()),
        leading: IconButton(
          icon: Icon(Icons.menu),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        actions: [
          if (_selectedIndex != 4) // Don't show refresh on settings page
            IconButton(
              icon: Icon(Icons.refresh),
              onPressed: () {
                if (_selectedIndex == 0) {
                  (_screens[0] as DashboardScreen).refreshData();
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
                  child: Text(choice),
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
      case 0: return 'Dashboard';
      case 1: return 'Notifications';
      case 2: return 'User Management';
      case 3: return 'Reclamations';
      case 4: return 'Settings';
      default: return 'Admin Panel';
    }
  }

  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Colors.blue,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.person, size: 40, color: Colors.blue),
                ),
                SizedBox(height: 10),
                Text(
                  'Admin Panel',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Welcome back',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: Icon(Icons.dashboard),
            title: Text('Dashboard'),
            selected: _selectedIndex == 0,
            onTap: () => _onItemTapped(0),
          ),
          ExpansionTile(
            leading: Icon(Icons.notifications),
            title: Text('Notifications'),
            initiallyExpanded: _selectedIndex == 1,
            children: [
              ListTile(
                leading: SizedBox(width: 20),
                title: Text('Send Notification'),
                selected: _selectedIndex == 1,
                onTap: () => _onItemTapped(1),
              ),
              ListTile(
                leading: SizedBox(width: 20),
                title: Text('Notification List'),
                selected: _selectedIndex == 1,
                onTap: () => _onItemTapped(1),
              ),
            ],
          ),
          ListTile(
            leading: Icon(Icons.people),
            title: Text('User Management'),
            selected: _selectedIndex == 2,
            onTap: () => _onItemTapped(2),
          ),
          ListTile(
            leading: Icon(Icons.report),
            title: Text('Reclamations'),
            selected: _selectedIndex == 3,
            onTap: () => _onItemTapped(3),
          ),
          ListTile(
            leading: Icon(Icons.settings),
            title: Text('Settings'),
            selected: _selectedIndex == 4,
            onTap: () => _onItemTapped(4),
          ),
          Divider(),
          ListTile(
            leading: Icon(Icons.logout),
            title: Text('Logout'),
            onTap: _logout,
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
class DashboardScreen extends StatefulWidget {
  @override
  _DashboardScreenState createState() => _DashboardScreenState();

  void refreshData() {
    _DashboardScreenState()._loadData();
  }
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

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // Get total notifications count
      final totalQuery = await _firestore.collection('notifications').count().get();
      // Get read notifications count
      final readQuery = await _firestore.collection('notifications')
          .where('read', isEqualTo: true)
          .count()
          .get();
      // Get total users count
      final usersQuery = await _firestore.collection('users').count().get();

      // Get weekly stats
      final now = DateTime.now();
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      final snapshot = await _firestore.collection('notifications')
          .where('timestamp', isGreaterThan: Timestamp.fromDate(startOfWeek))
          .get();

      // Group by day of week
      final dailyCounts = <int, int>{};
      for (var i = 0; i < 7; i++) {
        dailyCounts[i] = 0;
      }

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final timestamp = data['timestamp'] as Timestamp?;
        if (timestamp != null) {
          final date = timestamp.toDate();
          final dayOfWeek = date.weekday - 1;
          dailyCounts[dayOfWeek] = (dailyCounts[dayOfWeek] ?? 0) + 1;
        }
      }

      final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

      setState(() {
        _totalNotifications = totalQuery.count!;
        _readNotifications = readQuery.count!;
        _totalUsers = usersQuery.count!;
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
        SnackBar(content: Text('Failed to load dashboard data')),
      );
    }
  }

  Color _getColorForDay(int dayIndex) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.red,
      Colors.purple,
      Colors.teal,
      Colors.indigo,
    ];
    return colors[dayIndex % colors.length];
  }

  Widget _buildStatsCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 30, color: color),
            SizedBox(height: 8),
            Text(title, style: TextStyle(color: Colors.grey, fontSize: 12)),
            SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationChart() {
    if (_weeklyStats.isEmpty) {
      return Center(child: Text('No notification data available'));
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Notifications This Week',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            SizedBox(
              height: 400,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: _weeklyStats.map((e) => e.count.toDouble()).reduce((a, b) => a > b ? a : b) * 1.2,
                  barGroups: _weeklyStats.map((stats) {
                    return BarChartGroupData(
                      x: _weeklyStats.indexOf(stats),
                      barRods: [
                        BarChartRodData(
                          toY: stats.count.toDouble(),
                          color: stats.color,
                          width: 16,
                          borderRadius: BorderRadius.circular(4),
                          backDrawRodData: BackgroundBarChartRodData(
                            show: true,
                            toY: _weeklyStats.map((e) => e.count.toDouble()).reduce((a, b) => a > b ? a : b) * 1.2,
                            color: Colors.grey[200],
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
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              _weeklyStats[value.toInt()].day,
                              style: TextStyle(fontSize: 10),
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
                            style: TextStyle(fontSize: 10),
                          );
                        },
                        reservedSize: 28,
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
                      color: Colors.grey[300],
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border(
                      bottom: BorderSide(color: Colors.grey, width: 1),
                      left: BorderSide(color: Colors.grey, width: 1),
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
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          GridView.count(
            crossAxisCount: MediaQuery.of(context).size.width > 200 ? 3 : 2,
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            childAspectRatio: 1,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            children: [
              _buildStatsCard('Total Users', _totalUsers.toString(), Icons.people, Colors.blue),
              _buildStatsCard('Notifications', _totalNotifications.toString(), Icons.notifications, Colors.green),
              _buildStatsCard(
                  'Read',
                  _totalNotifications > 0
                      ? '${(_readNotifications/_totalNotifications*100).toStringAsFixed(0)}%'
                      : '0%',
                  Icons.mark_email_read,
                  Colors.orange
              ),
            ],
          ),
          SizedBox(height: 6),
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
            'email': data['email'] ?? 'No email',
            'name': data['name'] ?? 'No name',
          };
        }).toList();
        _totalUsers = countSnapshot.count!;
      });
    } catch (e) {
      print('Error loading users: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load users')),
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
      await _firestore.collection('notifications').add({
        'message': _notificationController.text,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
        'userId': _selectedUserId,
        'senderId': _auth.currentUser?.uid,
        'senderRole': 'admin',
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notification sent successfully')),
      );

      _notificationController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send: ${e.toString()}')),
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
      // Get all user IDs
      final usersSnapshot = await _firestore.collection('users').get();
      final userIds = usersSnapshot.docs.map((doc) => doc.id).toList();

      // Batch write for better performance
      final batch = _firestore.batch();
      final notificationsCollection = _firestore.collection('notifications');

      for (final userId in userIds) {
        final docRef = notificationsCollection.doc();
        batch.set(docRef, {
          'message': _notificationController.text,
          'timestamp': FieldValue.serverTimestamp(),
          'read': false,
          'userId': userId,
          'senderId': _auth.currentUser?.uid,
          'senderRole': 'admin',
        });
      }

      await batch.commit();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Notification sent to all $_totalUsers users')),
      );

      _notificationController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send to all users: ${e.toString()}')),
      );
    } finally {
      setState(() => _isSendingToAll = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Send Notification',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 16),
                  TextField(
                    controller: _notificationController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Message',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedUserId,
                          decoration: InputDecoration(
                            labelText: 'Select User',
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            DropdownMenuItem<String>(
                              value: null,
                              child: Text('Select a user'),
                            ),
                            ..._users.map((user) {
                              return DropdownMenuItem<String>(
                                value: user['id'],
                                child: Text('${user['name']} (${user['email']})'),
                              );
                            }).toList(),
                          ],
                          onChanged: (value) => setState(() => _selectedUserId = value),
                        ),
                      ),
                      SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: _isSending ? null : _sendNotification,
                        child: Text(_isSending ? 'Sending...' : 'Send'),
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: (_isSendingToAll || _users.isEmpty) ? null : _sendNotificationToAllUsers,
                      icon: Icon(Icons.group), // Changed from Icons.send_to_all to Icons.group
                      label: Text(_isSendingToAll
                          ? 'Sending to all $_totalUsers users...'
                          : 'Send to all $_totalUsers users'),
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.blue[700],
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 16),
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recent Notifications',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  _buildNotificationList(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('notifications')
          .orderBy('timestamp', descending: true)
          .limit(20)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text('No notifications found'));
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final timestamp = data['timestamp'] as Timestamp?;
            final date = timestamp != null
                ? DateFormat('MMM d, h:mm a').format(timestamp.toDate())
                : 'Unknown date';

            final user = _users.firstWhere(
                  (u) => u['id'] == data['userId'],
              orElse: () => {'name': 'Unknown', 'email': ''},
            );

            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: Colors.blue[100],
                child: Text(
                  user['name'].isNotEmpty ? user['name'][0] : '?',
                  style: TextStyle(color: Colors.blue),
                ),
              ),
              title: Text(data['message'] ?? 'No message'),
              subtitle: Text('To: ${user['name']} • $date'),
              trailing: Icon(
                data['read'] == true ? Icons.mark_email_read : Icons.mark_email_unread,
                color: data['read'] == true ? Colors.green : Colors.blue,
              ),
            );
          },
        );
      },
    );
  }
}
class ReclamationScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text('Reclamation Screen'),
    );
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