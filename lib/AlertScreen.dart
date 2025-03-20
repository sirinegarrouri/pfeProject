import 'package:flutter/material.dart';

class AlertScreen extends StatelessWidget {
  final String title;
  final String body;
  final String zone;

  const AlertScreen({
    required this.title,
    required this.body,
    required this.zone,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.red[50],
      appBar: AppBar(
        title: Text("🚨 EMERGENCY ALERT"),
        backgroundColor: Colors.redAccent,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                style: TextStyle(fontSize: 24, color: Colors.red, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Text(
                body,
                style: TextStyle(fontSize: 18),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Text(
                "Evacuation Zone: $zone",
                style: TextStyle(fontSize: 18, color: Colors.black87),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                icon: Icon(Icons.map),
                label: Text("View Map"),
                onPressed: () {
                  // You can add map logic later
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
