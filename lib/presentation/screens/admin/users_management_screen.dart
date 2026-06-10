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
          SnackBar(
            content: Text('تم تحديث الرتبة بنجاح ✅', style: const TextStyle(fontFamily: 'Cairo')), 
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('فشل التحديث', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteUser(String id) async {
    try {
      final dbService = Provider.of<DatabaseService>(context, listen: false);
      await dbService.deleteUser(id); 
      _loadUsers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حذف المستخدم بنجاح', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('خطأ أثناء الحذف', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _confirmDelete(String id, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("تأكيد الحذف", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        content: Text("هل أنت متأكد من حذف المستخدم $name؟ لا يمكن التراجع عن هذا الإجراء.", style: const TextStyle(fontFamily: 'Cairo')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("إلغاء", style: TextStyle(fontFamily: 'Cairo'))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteUser(id);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text("حذف الآن", style: TextStyle(fontFamily: 'Cairo', color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: const Text("إدارة المستخدمين", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(onPressed: _loadUsers, icon: const Icon(Icons.refresh)),
          const SizedBox(width: 10),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              _buildSearchHeader(isDesktop),
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
        ),
      ),
    );
  }

  Widget _buildSearchHeader(bool isDesktop) {
    return Container(
      padding: EdgeInsets.all(isDesktop ? 30 : 20),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(fontFamily: 'Cairo'),
        decoration: InputDecoration(
          hintText: "بحث عن مستخدم بالاسم أو الرتبة...",
          hintStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 14),
          prefixIcon: const Icon(Icons.search_rounded),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey.shade100),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Colors.blue, width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopTable() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 5))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: SingleChildScrollView(
          child: DataTable(
            horizontalMargin: 24,
            columnSpacing: 40,
            headingRowHeight: 70,
            dataRowMaxHeight: 70,
            headingTextStyle: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 15),
            columns: const [
              DataColumn(label: Text('المستخدم')),
              DataColumn(label: Text('الرتبة')),
              DataColumn(label: Text('الإجراءات')),
            ],
            rows: _filteredUsers.map((user) => DataRow(cells: [
              DataCell(Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.blue.withOpacity(0.1), 
                    child: Text(user['full_name']?[0].toUpperCase() ?? 'U', style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontFamily: 'Cairo'))
                  ),
                  const SizedBox(width: 16),
                  Text(user['full_name'] ?? 'بدون اسم', style: const TextStyle(fontWeight: FontWeight.w600, fontFamily: 'Cairo')),
                ],
              )),
              DataCell(_buildRoleChip(user['role'])),
              DataCell(Row(
                children: [
                  _buildActionMenu(user),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => _confirmDelete(user['id'], user['full_name'] ?? 'مستخدم'),
                    icon: const Icon(Icons.delete_sweep_outlined, color: Colors.redAccent, size: 22),
                    tooltip: "حذف المستخدم",
                  ),
                ],
              )),
            ])).toList(),
          ),
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
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: Colors.blue.withOpacity(0.1),
              child: Text(user['full_name']?[0].toUpperCase() ?? 'U', style: const TextStyle(color: Colors.blue, fontFamily: 'Cairo'))
            ),
            title: Text(user['full_name'] ?? 'بدون اسم', style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 15)),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: _buildRoleChip(user['role']),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildActionMenu(user),
                IconButton(
                  onPressed: () => _confirmDelete(user['id'], user['full_name'] ?? 'مستخدم'),
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 22),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
      child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
    );
  }

  Widget _buildActionMenu(Map<String, dynamic> user) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.tune_rounded, color: Colors.blueGrey, size: 22),
      tooltip: "تغيير الرتبة",
      onSelected: (role) => _updateRole(user['id'], role),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'student', child: Text('تعيين كطالب', style: TextStyle(fontFamily: 'Cairo'))),
        const PopupMenuItem(value: 'teacher', child: Text('تعيين كمدرس', style: TextStyle(fontFamily: 'Cairo'))),
        const PopupMenuItem(value: 'admin', child: Text('تعيين كمسؤول', style: TextStyle(fontFamily: 'Cairo'))),
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
        itemBuilder: (_, __) => Container(height: 75, margin: const EdgeInsets.only(bottom: 15), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16))),
      ),
    );
  }

  Widget _buildErrorState() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [ const Icon(Icons.error_outline, size: 60, color: Colors.redAccent), const SizedBox(height: 16), Text(_error!, style: const TextStyle(fontFamily: 'Cairo', fontSize: 16)), TextButton(onPressed: _loadUsers, child: const Text("إعادة المحاولة", style: TextStyle(fontFamily: 'Cairo')))]));
  
  Widget _buildEmptyState() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.person_search_outlined, size: 80, color: Colors.grey.shade300), const SizedBox(height: 16), const Text("لم يتم العثور على مستخدمين مطابقين لبحثك", style: TextStyle(fontFamily: 'Cairo', color: Colors.grey))]));
}
