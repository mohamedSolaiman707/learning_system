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
          .select('id, full_name, role, phone_number');
      
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
        final name = user['full_name'].toString().toLowerCase();
        final role = user['role'].toString().toLowerCase();
        return name.contains(query) || role.contains(query);
      }).toList();
    });
  }

  Future<void> _deleteUser(String id) async {
    try {
      // ملحوظة: حذف المستخدم من auth.users يتطلب Service Role Key أو استخدام Edge Function
      // هنا سنحذفه من جدول profiles (الذي سيتم حظره أو السماح به بناءً على RLS)
      await supabase.from('profiles').delete().eq('id', id);
      _fetchUsers(); // تحديث القائمة
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حذف المستخدم بنجاح')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ أثناء الحذف: $e')),
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: "بحث عن مستخدم بالاسم أو الدور...",
                      prefixIcon: const Icon(IconlyLight.search),
                      fillColor: Colors.grey.shade100,
                      suffixIcon: _searchController.text.isNotEmpty 
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => _searchController.clear(),
                          )
                        : null,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    // هنا يمكن فتح Dialog لإضافة مستخدم جديد عبر Edge Function
                  },
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
              child: _isLoading 
                ? const Center(child: CircularProgressIndicator())
                : _filteredUsers.isEmpty
                  ? const Center(child: Text("لا يوجد مستخدمين مطابقين للبحث"))
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
                                    IconButton(
                                      icon: const Icon(IconlyLight.edit, color: Colors.blue, size: 20),
                                      onPressed: () {},
                                    ),
                                    IconButton(
                                      icon: const Icon(IconlyLight.delete, color: Colors.red, size: 20),
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
    String label = role;
    if (role == 'teacher') {
      color = Colors.orange;
      label = 'مدرس';
    } else if (role == 'student') {
      color = Colors.green;
      label = 'طالب';
    } else if (role == 'admin') {
      color = Colors.red;
      label = 'مشرف';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }

  void _showDeleteDialog(String id, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("تأكيد الحذف"),
        content: Text("هل أنت متأكد من حذف المستخدم $name؟"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("إلغاء"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteUser(id);
            },
            child: const Text("حذف", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
