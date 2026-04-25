import 'package:flutter/material.dart';
import 'package:iconly/iconly.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/routes/app_routes.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final supabase = Supabase.instance.client;
  bool _isLoading = false;
  Map<String, dynamic>? _profileData;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  // جلب البيانات من جدول profiles لضمان الدقة
  Future<void> _fetchProfile() async {
    setState(() => _isLoading = true);
    try {
      final userId = supabase.auth.currentUser!.id;
      final data = await supabase.from('profiles').select().eq('id', userId).single();
      setState(() {
        _profileData = data;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error fetching profile: $e");
      setState(() => _isLoading = false);
    }
  }

  // منطق تعديل الاسم أو الهاتف
  Future<void> _updateProfile(String field, String newValue) async {
    try {
      final userId = supabase.auth.currentUser!.id;
      await supabase.from('profiles').update({field: newValue}).eq('id', userId);
      
      // تحديث الميتا داتا في الـ Auth أيضاً لضمان التزامن
      await supabase.auth.updateUser(UserAttributes(
        data: {field == 'full_name' ? 'full_name' : field: newValue},
      ));

      _fetchProfile(); // إعادة جلب البيانات
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم التحديث بنجاح")));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("خطأ: $e")));
    }
  }

  void _showEditDialog(String title, String field, String currentValue) {
    final controller = TextEditingController(text: currentValue);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("تعديل $title"),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: "أدخل $title الجديد"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("إلغاء")),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _updateProfile(field, controller.text.trim());
            },
            child: const Text("حفظ"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final String fullName = _profileData?['full_name'] ?? 'مستخدم';
    final String phone = _profileData?['phone_number'] ?? 'غير مسجل';
    final String role = _profileData?['role'] ?? 'student';
    final String email = supabase.auth.currentUser?.email ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: const Text("حسابي الشخصي", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _buildHeader(fullName, role, email),
            const SizedBox(height: 32),
            _buildSectionTitle("المعلومات الشخصية"),
            const SizedBox(height: 12),
            _buildInfoCard([
              _buildInfoItem(IconlyLight.profile, "الاسم الكامل", fullName, () => _showEditDialog("الاسم", "full_name", fullName)),
              _buildInfoItem(IconlyLight.call, "رقم الهاتف", phone, () => _showEditDialog("الهاتف", "phone_number", phone)),
              _buildInfoItem(IconlyLight.message, "البريد الإلكتروني", email, null), // الإيميل لا يعدل بسهولة
            ]),
            const SizedBox(height: 32),
            _buildSectionTitle("الإعدادات والأمان"),
            const SizedBox(height: 12),
            _buildInfoCard([
              _buildInfoItem(IconlyLight.lock, "تغيير كلمة المرور", "********", () {}),
              _buildInfoItem(IconlyLight.setting, "إعدادات التطبيق", "العربية، المظهر الفاتح", () {}),
            ]),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: () async {
                await supabase.auth.signOut();
                if (!mounted) return;
                Navigator.pushReplacementNamed(context, AppRoutes.login);
              },
              icon: const Icon(IconlyLight.logout),
              label: const Text("تسجيل الخروج"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade50,
                foregroundColor: Colors.red,
                minimumSize: const Size(double.infinity, 56),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(String name, String role, String email) {
    return Column(
      children: [
        CircleAvatar(
          radius: 55,
          backgroundColor: Colors.blue.shade100,
          child: Text(
            name.isNotEmpty ? name.substring(0, 1).toUpperCase() : "?",
            style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.blue),
          ),
        ),
        const SizedBox(height: 16),
        Text(name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
          child: Text(
            role == 'teacher' ? "مدرس معتمد" : "طالب متعلم",
            style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Align(
      alignment: Alignment.centerRight,
      child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
    );
  }

  Widget _buildInfoCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20)],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value, VoidCallback? onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.blue.shade300, size: 22),
      title: Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
      subtitle: Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
      trailing: onTap != null ? const Icon(Icons.chevron_right, size: 18) : null,
      onTap: onTap,
    );
  }
}
