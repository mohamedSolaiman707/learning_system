import 'package:flutter/material.dart';
import 'package:iconly/iconly.dart';
import 'package:provider/provider.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/routes/app_routes.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isEditing = false;

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
              // هنا يمكن إضافة منطق التحديث عبر AuthProvider مستقبلاً
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("سيتم تفعيل التحديث قريباً")));
            },
            child: const Text("حفظ"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final profile = authProvider.profile;
    
    if (profile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: Responsive.isMobile(context) 
          ? AppBar(title: const Text("الملف الشخصي"), elevation: 0)
          : null,
      body: Responsive(
        mobile: _buildMobileLayout(profile, authProvider),
        desktop: _buildDesktopLayout(profile, authProvider),
      ),
    );
  }

  Widget _buildMobileLayout(Map<String, dynamic> profile, AuthProvider auth) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildAvatarSection(profile),
          const SizedBox(height: 30),
          _buildDetailsSection(profile),
          const SizedBox(height: 30),
          _buildLogoutButton(auth),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout(Map<String, dynamic> profile, AuthProvider auth) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(40),
            child: Column(
              children: [
                _buildAvatarSection(profile),
                const SizedBox(height: 40),
                _buildLogoutButton(auth),
              ],
            ),
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          flex: 5,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("إعدادات الحساب", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                const SizedBox(height: 30),
                _buildDetailsSection(profile),
                const SizedBox(height: 30),
                _buildSecuritySection(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAvatarSection(Map<String, dynamic> profile) {
    final String name = profile['full_name'] ?? 'مستخدم';
    final String role = profile['role'] ?? 'student';

    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20)],
      ),
      child: Column(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 60,
                backgroundColor: Colors.blue.withOpacity(0.1),
                child: Text(
                  name.substring(0, 1).toUpperCase(),
                  style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.blue),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
                  child: const Icon(IconlyLight.camera, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: role == 'admin' ? Colors.red.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              role == 'admin' ? "مدير النظام" : (role == 'teacher' ? "مدرس معتمد" : "طالب"),
              style: TextStyle(
                color: role == 'admin' ? Colors.red : Colors.blue,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsSection(Map<String, dynamic> profile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("المعلومات الشخصية", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 15),
        _buildInfoCard([
          _buildInfoItem(IconlyLight.profile, "الاسم الكامل", profile['full_name'] ?? '', () => _showEditDialog("الاسم", "full_name", profile['full_name'])),
          _buildInfoItem(IconlyLight.call, "رقم الهاتف", profile['phone_number'] ?? 'غير مسجل', () => _showEditDialog("الهاتف", "phone_number", profile['phone_number'] ?? '')),
          _buildInfoItem(IconlyLight.message, "البريد الإلكتروني", profile['email'] ?? 'جاري التحميل...', null),
        ]),
      ],
    );
  }

  Widget _buildSecuritySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("الأمان والخصوصية", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 15),
        _buildInfoCard([
          _buildInfoItem(IconlyLight.lock, "كلمة المرور", "********", () {}),
          _buildInfoItem(IconlyLight.shield_done, "التحقق بخطوتين", "مفعل", null),
        ]),
      ],
    );
  }

  Widget _buildInfoCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value, VoidCallback? onTap) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Colors.grey.withOpacity(0.05), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, size: 20, color: Colors.blue.shade400),
      ),
      title: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      subtitle: Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF1A1C1E))),
      trailing: onTap != null ? const Icon(Icons.edit_outlined, size: 18, color: Colors.grey) : null,
      onTap: onTap,
    );
  }

  Widget _buildLogoutButton(AuthProvider auth) {
    return ElevatedButton.icon(
      onPressed: () {
        auth.logout();
        Navigator.pushReplacementNamed(context, AppRoutes.login);
      },
      icon: const Icon(IconlyLight.logout),
      label: const Text("تسجيل الخروج"),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.red.withOpacity(0.05),
        foregroundColor: Colors.red,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.red.withOpacity(0.1))),
      ),
    );
  }
}
