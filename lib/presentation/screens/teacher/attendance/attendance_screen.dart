import 'package:flutter/material.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final List<Map<String, dynamic>> _students = [
    {'name': 'أحمد محمد', 'present': true},
    {'name': 'سارة أحمد', 'present': true},
    {'name': 'ياسين علي', 'present': false},
    {'name': 'ليلى محمود', 'present': true},
    {'name': 'عمر خالد', 'present': true},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("تسجيل الحضور"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("حفظ", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _students.length,
        separatorBuilder: (context, index) => const Divider(),
        itemBuilder: (context, index) {
          return CheckboxListTile(
            title: Text(_students[index]['name']),
            subtitle: Text(_students[index]['present'] ? "حاضر" : "غائب"),
            value: _students[index]['present'],
            activeColor: Theme.of(context).primaryColor,
            onChanged: (value) {
              setState(() {
                _students[index]['present'] = value;
              });
            },
            secondary: CircleAvatar(
              backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
              child: Text(_students[index]['name'][0]),
            ),
          );
        },
      ),
    );
  }
}
