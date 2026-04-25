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
  
  String _getUserRoleLabel(String? role) {
    if (role == 'teacher') return 'مدرس';
    if (role == 'admin') return 'مسؤول النظام';
    return 'طالب';
  }

  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentUser;
    final String fullName = user?.userMetadata?['full_name'] ?? 'مستخدم';
    final String role = user?.userMetadata?['role'] ?? 'student';
    final String email = user?.email ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text("الملف الشخصي"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const CircleAvatar(
              radius: 50,
              backgroundColor: Colors.blue,
              child: Icon(IconlyBold.profile, size: 50, color: Colors.white),
            ),
            const SizedBox(height: 16),
            Text(
              fullName,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            Text(
              _getUserRoleLabel(role),
              style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.w600),
            ),
            Text(
              email,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 32),
            _buildProfileItem(
              icon: IconlyLight.profile,
              title: "تعديل البيانات",
              onTap: () {},
            ),
            _buildProfileItem(
              icon: IconlyLight.setting,
              title: "الإعدادات",
              onTap: () {},
            ),
            _buildProfileItem(
              icon: IconlyLight.info_square,
              title: "عن التطبيق",
              onTap: () {},
            ),
            const SizedBox(height: 20),
            _buildProfileItem(
              icon: IconlyLight.logout,
              title: "تسجيل الخروج",
              color: Colors.red,
              onTap: () async {
                await supabase.auth.signOut();
                if (!mounted) return;
                Navigator.pushReplacementNamed(context, AppRoutes.login);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? color,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, color: color ?? Colors.blue),
        title: Text(
          title,
          style: TextStyle(color: color, fontWeight: FontWeight.w500),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}
