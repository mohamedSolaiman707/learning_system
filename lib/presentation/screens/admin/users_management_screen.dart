import 'package:flutter/material.dart';
import 'package:iconly/iconly.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UsersManagementScreen extends StatefulWidget {
  const UsersManagementScreen({super.key});

  @override
  State<UsersManagementScreen> createState() => _UsersManagementScreenState();
}

class _UsersManagementScreenState extends State<UsersManagementScreen> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  bool _isLoading = true;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchUsers();
    _searchController.addListener(_filterUsers);
  }

  Future<void> _fetchUsers() async {
    setState(() => _isLoading = true);
    try {
      final response = await supabase
          .from('profiles')
          .select('id, full_name, role, phone_number')
          .order('full_name', ascending: true);
      
      setState(() {
        _users = List<Map<String, dynamic>>.from(response);
        _filteredUsers = _users;
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching users: $e');
      setState(() => _isLoading = false);
    }
  }

  void _filterUsers() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredUsers = _users.where((user) {
        final name = (user['full_name'] ?? '').toString().toLowerCase();
        final role = (user['role'] ?? '').toString().toLowerCase();
        return name.contains(query) || role.contains(query);
      }).toList();
    });
  }

  Future<void> _updateUserRole(String id, String newRole) async {
    try {
      await supabase.from('profiles').update({'role': newRole}).eq('id', id);
      _fetchUsers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم تغيير الرتبة إلى $newRole')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ أثناء التحديث: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("إدارة المستخدمين")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "بحث عن مستخدم بالاسم أو الدور...",
                prefixIcon: const Icon(IconlyLight.search),
                fillColor: Colors.grey.shade100,
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: _isLoading 
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SingleChildScrollView(
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('الاسم')),
                          DataColumn(label: Text('الدور')),
                          DataColumn(label: Text('رقم الهاتف')),
                          DataColumn(label: Text('الإجراءات')),
                        ],
                        rows: _filteredUsers.map((user) {
                          return DataRow(cells: [
                            DataCell(Text(user['full_name'] ?? '')),
                            DataCell(_buildRoleTag(user['role'] ?? '')),
                            DataCell(Text(user['phone_number'] ?? '---')),
                            DataCell(
                              Row(
                                children: [
                                  PopupMenuButton<String>(
                                    icon: const Icon(IconlyLight.edit, color: Colors.blue),
                                    onSelected: (newRole) => _updateUserRole(user['id'], newRole),
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(value: 'student', child: Text('جعل طالب')),
                                      const PopupMenuItem(value: 'teacher', child: Text('جعل مدرس')),
                                      const PopupMenuItem(value: 'admin', child: Text('جعل مسؤول')),
                                    ],
                                  ),
                                  IconButton(
                                    icon: const Icon(IconlyLight.delete, color: Colors.red),
                                    onPressed: () => _showDeleteDialog(user['id'], user['full_name']),
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

  Widget _buildRoleTag(String role) {
    Color color = Colors.blue;
    String label = role == 'teacher' ? 'مدرس' : role == 'student' ? 'طالب' : 'مسؤول';
    if (role == 'teacher') color = Colors.orange;
    if (role == 'student') color = Colors.green;
    if (role == 'admin') color = Colors.red;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }

  void _showDeleteDialog(String id, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("تأكيد الحذف"),
        content: Text("هل أنت متأكد من حذف المستخدم $name؟"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("إلغاء")),
          TextButton(onPressed: () { Navigator.pop(context); _fetchUsers(); }, child: const Text("حذف", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }
}
