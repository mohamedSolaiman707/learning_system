import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/services/database_service.dart';

class UsersManagementScreen extends StatefulWidget {
  const UsersManagementScreen({super.key});

  @override
  State<UsersManagementScreen> createState() => _UsersManagementScreenState();
}

class _UsersManagementScreenState extends State<UsersManagementScreen> {
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  bool _isLoading = true;
  String? _error;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _searchController.addListener(_filterUsers);
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final dbService = Provider.of<DatabaseService>(context, listen: false);
      final users = await dbService.getAllUsers();
      if (mounted) {
        setState(() {
          _users = users;
          _filteredUsers = users;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "فشل تحميل المستخدمين";
          _isLoading = false;
        });
      }
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

  Future<void> _updateRole(String id, String newRole) async {
    try {
      final dbService = Provider.of<DatabaseService>(context, listen: false);
      await dbService.updateUserRole(id, newRole);
      _loadUsers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم تحديث الرتبة إلى $newRole'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('فشل التحديث'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteUser(String id) async {
    try {
      final dbService = Provider.of<DatabaseService>(context, listen: false);
      // تأكد من إضافة دالة deleteUser في DatabaseService
      await dbService.deleteUser(id); 
      _loadUsers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حذف المستخدم بنجاح'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('خطأ أثناء الحذف'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _confirmDelete(String id, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("تأكيد الحذف"),
        content: Text("هل أنت متأكد من حذف المستخدم $name؟ لا يمكن التراجع عن هذا الإجراء."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("إلغاء")),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteUser(id);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("حذف الآن"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: const Text("إدارة المستخدمين"),
        elevation: 0,
        actions: [
          IconButton(onPressed: _loadUsers, icon: const Icon(Icons.refresh)),
          const SizedBox(width: 10),
        ],
      ),
      body: Column(
        children: [
          _buildSearchHeader(),
          Expanded(
            child: _isLoading 
                ? _buildLoadingState()
                : _error != null 
                    ? _buildErrorState()
                    : _filteredUsers.isEmpty 
                        ? _buildEmptyState()
                        : Responsive(
                            mobile: _buildMobileList(),
                            desktop: _buildDesktopTable(),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "بحث عن مستخدم بالاسم أو الرتبة...",
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopTable() {
    return Container(
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
      ),
      child: SingleChildScrollView(
        child: DataTable(
          horizontalMargin: 24,
          columnSpacing: 40,
          headingRowHeight: 60,
          columns: const [
            DataColumn(label: Text('المستخدم', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('الرتبة', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('الإجراءات', style: TextStyle(fontWeight: FontWeight.bold))),
          ],
          rows: _filteredUsers.map((user) => DataRow(cells: [
            DataCell(Row(
              children: [
                CircleAvatar(backgroundColor: Colors.blue.withOpacity(0.1), child: Text(user['full_name']?[0] ?? 'U', style: const TextStyle(color: Colors.blue))),
                const SizedBox(width: 12),
                Text(user['full_name'] ?? 'بدون اسم', style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            )),
            DataCell(_buildRoleChip(user['role'])),
            DataCell(Row(
              children: [
                _buildActionMenu(user),
                IconButton(
                  onPressed: () => _confirmDelete(user['id'], user['full_name'] ?? 'مستخدم'),
                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                ),
              ],
            )),
          ])).toList(),
        ),
      ),
    );
  }

  Widget _buildMobileList() {
    return ListView.builder(
      padding: const EdgeInsets.all(15),
      itemCount: _filteredUsers.length,
      itemBuilder: (context, index) {
        final user = _filteredUsers[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(child: Text(user['full_name']?[0] ?? 'U')),
            title: Text(user['full_name'] ?? 'بدون اسم', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: _buildRoleChip(user['role']),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildActionMenu(user),
                IconButton(
                  onPressed: () => _confirmDelete(user['id'], user['full_name'] ?? 'مستخدم'),
                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRoleChip(String? role) {
    Color color = Colors.blue;
    String label = "طالب";
    if (role == 'teacher') { color = Colors.orange; label = "مدرس"; }
    if (role == 'admin') { color = Colors.red; label = "مسؤول"; }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildActionMenu(Map<String, dynamic> user) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: Colors.grey),
      onSelected: (role) => _updateRole(user['id'], role),
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'student', child: Text('تعيين كطالب')),
        const PopupMenuItem(value: 'teacher', child: Text('تعيين كمدرس')),
        const PopupMenuItem(value: 'admin', child: Text('تعيين كمسؤول')),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: 8,
        itemBuilder: (_, __) => Container(height: 70, margin: const EdgeInsets.only(bottom: 15), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12))),
      ),
    );
  }

  Widget _buildErrorState() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [ const Icon(Icons.error_outline, size: 50, color: Colors.red), const SizedBox(height: 10), Text(_error!), TextButton(onPressed: _loadUsers, child: const Text("إعادة المحاولة"))]));
  
  Widget _buildEmptyState() => const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.search, size: 50, color: Colors.grey), SizedBox(height: 10), Text("لم يتم العثور على مستخدمين")]));
}
