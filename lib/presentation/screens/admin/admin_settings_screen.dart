import 'package:flutter/material.dart';
import 'package:iconly/iconly.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../profile/profile_screen.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  bool _maintenanceMode = false;
  bool _allowGuestRegistration = true;
  final supabase = Supabase.instance.client;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: const Text("إعدادات النظام", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle("إعدادات المنصة"),
            const SizedBox(height: 12),
            _buildSettingsCard([
              _buildSwitchItem(
                IconlyLight.work,
                "وضع الصيانة",
                "منع الطلاب من دخول الحصص مؤقتاً",
                _maintenanceMode,
                (val) => setState(() => _maintenanceMode = val),
              ),
              _buildSwitchItem(
                IconlyLight.add_user,
                "تسجيل الطلاب الجدد",
                "السماح بإنشاء حسابات طلاب جديدة",
                _allowGuestRegistration,
                (val) => setState(() => _allowGuestRegistration = val),
              ),
            ]),
            const SizedBox(height: 32),
            _buildSectionTitle("إعدادات الخصوصية"),
            const SizedBox(height: 12),
            _buildSettingsCard([
              _buildSimpleItem(IconlyLight.profile, "تعديل ملفي الشخصي", "الاسم، الهاتف، الصورة", () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen()));
              }),
              _buildSimpleItem(IconlyLight.lock, "تغيير كلمة المرor", "تحديث كلمة مرور المشرف", () {
                // منطق إرسال إيميل إعادة التعيين
                _handlePasswordReset();
              }),
            ]),
            const SizedBox(height: 32),
            _buildSectionTitle("النظام"),
            const SizedBox(height: 12),
            _buildSettingsCard([
              _buildSimpleItem(IconlyLight.info_square, "نسخة التطبيق", "EduConnect Pro v1.0.0", null),
              _buildSimpleItem(IconlyLight.danger, "مسح السجلات القديمة", "حذف بيانات الحصص المنتهية (خطر)", () {
                _showDeleteConfirm();
              }, color: Colors.red),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey));
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20)],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSwitchItem(IconData icon, String title, String sub, bool value, Function(bool) onChanged) {
    return ListTile(
      leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: Colors.blue, size: 20)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(sub, style: const TextStyle(fontSize: 12)),
      trailing: Switch.adaptive(value: value, onChanged: onChanged),
    );
  }

  Widget _buildSimpleItem(IconData icon, String title, String sub, VoidCallback? onTap, {Color? color}) {
    return ListTile(
      leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: (color ?? Colors.blue).withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: color ?? Colors.blue, size: 20)),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
      subtitle: Text(sub, style: const TextStyle(fontSize: 12)),
      trailing: const Icon(Icons.chevron_right, size: 18),
      onTap: onTap,
    );
  }

  void _handlePasswordReset() async {
    final email = supabase.auth.currentUser?.email;
    if (email != null) {
      await supabase.auth.resetPasswordForEmail(email);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم إرسال رابط إعادة تعيين كلمة المرور إلى بريدك")));
    }
  }

  void _showDeleteConfirm() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("تنبيه خطير"),
        content: const Text("هذا الإجراء سيقوم بحذف سجلات قديمة من النظام. هل أنت متأكد؟"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("إلغاء")),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("حذف", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }
}
