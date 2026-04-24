import 'package:flutter/material.dart';
import 'package:iconly/iconly.dart';

class UsersManagementScreen extends StatefulWidget {
  const UsersManagementScreen({super.key});

  @override
  State<UsersManagementScreen> createState() => _UsersManagementScreenState();
}

class _UsersManagementScreenState extends State<UsersManagementScreen> {
  final List<Map<String, String>> _users = [
    {'name': 'أحمد محمد', 'role': 'طالب', 'email': 'ahmed@example.com'},
    {'name': 'سارة أحمد', 'role': 'طالبة', 'email': 'sara@example.com'},
    {'name': 'أ. محمد علي', 'role': 'مدرس', 'email': 'mohamed@example.com'},
    {'name': 'أ. ليلى محمود', 'role': 'مدرس', 'email': 'laila@example.com'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("إدارة المستخدمين"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: "بحث عن مستخدم...",
                      prefixIcon: const Icon(IconlyLight.search),
                      fillColor: Colors.grey.shade100,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.add),
                  label: const Text("إضافة مستخدم"),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(150, 50),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('الاسم')),
                      DataColumn(label: Text('الدور')),
                      DataColumn(label: Text('البريد الإلكتروني')),
                      DataColumn(label: Text('الإجراءات')),
                    ],
                    rows: _users.map((user) {
                      return DataRow(cells: [
                        DataCell(Text(user['name']!)),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: user['role']!.contains('مدرس') 
                                  ? Colors.orange.shade50 
                                  : Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              user['role']!,
                              style: TextStyle(
                                color: user['role']!.contains('مدرس') 
                                    ? Colors.orange 
                                    : Colors.blue,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                        DataCell(Text(user['email']!)),
                        DataCell(
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(IconlyLight.edit, color: Colors.blue, size: 20),
                                onPressed: () {},
                              ),
                              IconButton(
                                icon: const Icon(IconlyLight.delete, color: Colors.red, size: 20),
                                onPressed: () {},
                              ),
                            ],
                          ),
                        ),
                      ]);
                    }).toList(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
