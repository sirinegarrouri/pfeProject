import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AdminDashboard extends StatefulWidget {
  @override
  _AdminDashboardState createState() => _AdminDashboardState();
}

class NotificationStats {
  final String day;
  final int count;
  final Color color;

  NotificationStats({
    required this.day,
    required this.count,
    this.color = Colors.blue,
  });
}

class _AdminDashboardState extends State<AdminDashboard> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _notificationController = TextEditingController();

  bool _isLoading = true;
  bool _isSending = false;
  String? _selectedUserId;

  List<Map<String, dynamic>> _users = [];
  List<NotificationStats> _weeklyStats = [];

  int _totalNotifications = 0;
  int _readNotifications = 0;
  int _totalUsers = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      await Future.wait([
        _loadNotificationStats(),
        _loadUsers(),
      ]);
    } catch (e) {
      print('Error loading data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load data: ${e.toString()}')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadNotificationStats() async {
    try {
      // Get total notifications count
      final totalQuery = await _firestore.collection('notifications').count().get();
      setState(() => _totalNotifications = totalQuery.count!);

      // Get read notifications count
      final readQuery = await _firestore.collection('notifications')
          .where('read', isEqualTo: true)
          .count()
          .get();
      setState(() => _readNotifications = readQuery.count!);

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
          final dayOfWeek = date.weekday - 1; // 0-6 where 0 is Monday
          dailyCounts[dayOfWeek] = (dailyCounts[dayOfWeek] ?? 0) + 1;
        }
      }

      final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      setState(() {
        _weeklyStats = dailyCounts.entries.map((entry) {
          return NotificationStats(
            day: weekdays[entry.key],
            count: entry.value,
            color: _getColorForDay(entry.key),
          );
        }).toList();
      });
    } catch (e) {
      print('Error loading notification stats: $e');
      throw e;
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

  Future<void> _loadUsers() async {
    try {
      final snapshot = await _firestore.collection('users').get();
      setState(() {
        _users = snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'email': data['email'] ?? 'No email',
            'name': data['name'] ?? 'No name',
          };
        }).toList();
        _totalUsers = _users.length;
      });
    } catch (e) {
      print('Error loading users: $e');
      throw e;
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
      await _loadNotificationStats(); // Refresh stats
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send: ${e.toString()}')),
      );
    } finally {
      setState(() => _isSending = false);
    }
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
            Row(
              children: [
                Text(
                  'Notifications This Week',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Spacer(),
                IconButton(
                  icon: Icon(Icons.refresh, size: 20),
                  onPressed: _loadNotificationStats,
                ),
              ],
            ),
            SizedBox(height: 16),
            SizedBox(
              height: 200,
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
                      showingTooltipIndicators: [0],
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
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.black,
                              ),
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
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.black,
                            ),
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

  Widget _buildNotificationForm() {
    return Card(
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
            DropdownButtonFormField<String>(
              value: _selectedUserId,
              decoration: InputDecoration(
                labelText: 'Select User',
                border: OutlineInputBorder(),
              ),
              items: _users.map((user) {
                return DropdownMenuItem<String>(
                  value: user['id'],
                  child: Text('${user['name']} (${user['email']})'),
                );
              }).toList(),
              onChanged: (value) => setState(() => _selectedUserId = value),
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
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSending ? null : _sendNotification,
                icon: Icon(Icons.send),
                label: Text(_isSending ? 'Sending...' : 'Send Notification'),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentNotifications() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Recent Notifications',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Spacer(),
                IconButton(
                  icon: Icon(Icons.refresh),
                  onPressed: _loadNotificationStats,
                ),
              ],
            ),
            SizedBox(height: 8),
            StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('notifications')
                  .orderBy('timestamp', descending: true)
                  .limit(5)
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
                      onTap: () {
                        // Add navigation to notification details if needed
                      },
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading Dashboard...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Admin Dashboard'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh Data',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            // Stats Cards Row
            GridView.count(
              crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2,
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              childAspectRatio: 1,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              children: [
                _buildStatsCard('Total Users', _totalUsers.toString(), Icons.people, Colors.blue),
                _buildStatsCard('Notifications', _totalNotifications.toString(), Icons.notifications, Colors.green),
                if (MediaQuery.of(context).size.width > 600 || _totalNotifications == 0)
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
            SizedBox(height: 16),

            // Notification Chart
            _buildNotificationChart(),
            SizedBox(height: 16),

            // Notification Form
            _buildNotificationForm(),
            SizedBox(height: 16),

            // Recent Notifications
            _buildRecentNotifications(),
          ],
        ),
      ),
    );
  }
}