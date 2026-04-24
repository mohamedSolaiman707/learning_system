import 'package:flutter/material.dart';
import 'package:iconly/iconly.dart';
import '../../../core/routes/app_routes.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
              backgroundImage: NetworkImage('https://via.placeholder.com/150'),
            ),
            const SizedBox(height: 16),
            const Text(
              "أحمد محمد",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const Text(
              "طالب - الصف الثالث الثانوي",
              style: TextStyle(color: Colors.grey),
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
              onTap: () {
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
