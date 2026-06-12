import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/routes/app_routes.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isUploading = false;

  Future<void> _pickAndUploadImage(AuthProvider authProvider) async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.image,
        withData: true,
      );

      if (result != null && result.files.first.bytes != null) {
        setState(() => _isUploading = true);
        final file = result.files.first;
        await authProvider.uploadAvatar(file.bytes!, file.name);
        
        if (mounted) {
          _showSnackBar("تم تحديث صورة الملف الشخصي بنجاح ✅", Colors.green);
        }
      }
    } catch (e) {
      if (mounted) _showSnackBar("فشل رفع الصورة: $e", Colors.red);
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        margin: const EdgeInsets.all(20),
      ),
    );
  }

  void _showEditDialog(String title, String field, String currentValue) {
    final controller = TextEditingController(text: currentValue);
    final confirmController = TextEditingController();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final bool isPassword = field == 'password';
    final formKey = GlobalKey<FormState>();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        title: Text(
          isPassword ? "تغيير كلمة المرور" : "تعديل $title",
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, fontFamily: 'Cairo', color: Color(0xFF102A43)),
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: controller,
                    obscureText: isPassword,
                    style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      hintText: isPassword ? "كلمة المرور الجديدة" : "أدخل $title الجديد",
                      filled: true,
                      fillColor: const Color(0xFFF0F4F8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return "هذا الحقل مطلوب";
                      if (isPassword && value.length < 6) return "يجب أن تكون 6 أحرف على الأقل";
                      return null;
                    },
                  ),
                  if (isPassword) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: confirmController,
                      obscureText: true,
                      style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        hintText: "تأكيد كلمة المرور الجديدة",
                        filled: true,
                        fillColor: const Color(0xFFF0F4F8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                      ),
                      validator: (value) {
                        if (value != controller.text) return "كلمات المرور غير متطابقة";
                        return null;
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(0, 0, 24, 24),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: const Text("إلغاء", style: TextStyle(color: Colors.blueGrey, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              
              try {
                if (isPassword) {
                  await authProvider.updatePassword(controller.text);
                } else {
                  await authProvider.updateProfile({field: controller.text});
                }
                if (context.mounted) {
                  Navigator.pop(context);
                  _showSnackBar(isPassword ? "تم تغيير كلمة المرور بنجاح 🔒" : "تم تحديث البيانات بنجاح ✅", Colors.green);
                }
              } catch (e) {
                if (context.mounted) _showSnackBar("فشل التحديث: $e", Colors.red);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF102A43),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text("حفظ", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
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
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: Color(0xFF102A43))));
    }

    final bool isDesktop = Responsive.isDesktop(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Padding(
              padding: EdgeInsets.all(isDesktop ? 40 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isDesktop) ...[
                    const Text("الملف الشخصي", style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Color(0xFF102A43), fontFamily: 'Cairo')),
                    const SizedBox(height: 8),
                    const Text("إدارة معلوماتك الشخصية وإعدادات الحساب", style: TextStyle(color: Colors.blueGrey, fontSize: 16, fontFamily: 'Cairo')),
                    const SizedBox(height: 40),
                  ],
                  
                  if (isDesktop)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 2, child: _buildInfoSection(profile)),
                        const SizedBox(width: 40),
                        Expanded(flex: 1, child: _buildSideSummary(profile, authProvider)),
                      ],
                    )
                  else ...[
                    _buildSideSummary(profile, authProvider),
                    const SizedBox(height: 30),
                    _buildInfoSection(profile),
                  ],
                  const SizedBox(height: 40),
                  _buildLogoutButton(authProvider),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSideSummary(Map<String, dynamic> profile, AuthProvider auth) {
    final String name = profile['full_name'] ?? 'مستخدم';
    final String role = profile['role'] ?? 'student';
    final String? avatarUrl = profile['avatar_url'];

    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        children: [
          _buildAvatarStack(name, avatarUrl, auth),
          const SizedBox(height: 20),
          Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF102A43), fontFamily: 'Cairo'), textAlign: TextAlign.center),
          const SizedBox(height: 10),
          _buildRoleBadge(role),
          const SizedBox(height: 30),
          const Divider(height: 1),
          const SizedBox(height: 30),
          _buildQuickStats(role),
        ],
      ),
    );
  }

  Widget _buildAvatarStack(String name, String? avatarUrl, AuthProvider auth) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 130, height: 130,
          decoration: BoxDecoration(
            color: const Color(0xFFF0F4F8),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 4),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 15)],
            image: avatarUrl != null ? DecorationImage(image: NetworkImage(avatarUrl), fit: BoxFit.cover, opacity: _isUploading ? 0.3 : 1.0) : null,
          ),
          child: avatarUrl == null 
            ? Center(child: Text(name.isNotEmpty ? name[0].toUpperCase() : "U", style: TextStyle(fontSize: 50, fontWeight: FontWeight.w900, color: const Color(0xFF102A43).withValues(alpha: _isUploading ? 0.2 : 1.0))))
            : null,
        ),
        if (_isUploading) const CircularProgressIndicator(color: Color(0xFF102A43), strokeWidth: 3),
        Positioned(
          bottom: 2, right: 2,
          child: InkWell(
            onTap: () => _pickAndUploadImage(auth),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFF102A43), shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3)),
              child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 18),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRoleBadge(String role) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(color: const Color(0xFF102A43).withValues(alpha: 0.06), borderRadius: BorderRadius.circular(20)),
      child: Text(
        role == 'admin' ? "مدير النظام" : (role == 'teacher' ? "معلم معتمد" : "طالب"),
        style: const TextStyle(color: Color(0xFF102A43), fontWeight: FontWeight.w800, fontSize: 12, fontFamily: 'Cairo'),
      ),
    );
  }

  Widget _buildQuickStats(String role) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildStatItem(role == 'teacher' ? "حصة" : "درس", "12"),
        _buildStatItem("ساعة", "48"),
        _buildStatItem("تقييم", "4.9"),
      ],
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF102A43))),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.blueGrey, fontFamily: 'Cairo', fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildInfoSection(Map<String, dynamic> profile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader("المعلومات الشخصية"),
        const SizedBox(height: 20),
        _buildInfoCard([
          _buildInfoItem(Icons.person_outline_rounded, "الاسم الكامل", profile['full_name'] ?? '', onEdit: () => _showEditDialog("الاسم", "full_name", profile['full_name'] ?? "")),
          _buildInfoItem(Icons.alternate_email_rounded, "اسم المستخدم", "@${profile['username'] ?? 'user'}", onEdit: () => _showEditDialog("اسم المستخدم", "username", profile['username'] ?? "")),
          _buildInfoItem(Icons.email_outlined, "البريد الإلكتروني", profile['email'] ?? '', isReadOnly: true),
        ]),
        const SizedBox(height: 40),
        _buildSectionHeader("الأمان والخصوصية"),
        const SizedBox(height: 20),
        _buildInfoCard([
          _buildInfoItem(Icons.lock_open_rounded, "كلمة المرور", "••••••••", onEdit: () => _showEditDialog("كلمة المرور", "password", "")),
          _buildInfoItem(Icons.verified_user_outlined, "حالة الحساب", "حساب موثق ونشط ✅", isReadOnly: true),
        ]),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF102A43), fontFamily: 'Cairo'));
  }

  Widget _buildInfoCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value, {VoidCallback? onEdit, bool isReadOnly = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFF102A43).withValues(alpha: 0.05), borderRadius: BorderRadius.circular(15)),
            child: Icon(icon, color: const Color(0xFF102A43), size: 24),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, color: Colors.blueGrey, fontFamily: 'Cairo')),
                Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF102A43), fontFamily: 'Cairo')),
              ],
            ),
          ),
          if (!isReadOnly)
            IconButton(
              icon: const Icon(Icons.edit_note_rounded, color: Colors.blueGrey),
              onPressed: onEdit,
            ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton(AuthProvider auth) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            await auth.logout();
            if (mounted) Navigator.pushReplacementNamed(context, AppRoutes.login);
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.logout_rounded, color: Colors.red),
                SizedBox(width: 15),
                Text("تسجيل الخروج من الحساب", style: TextStyle(color: Colors.red, fontWeight: FontWeight.w900, fontFamily: 'Cairo', fontSize: 16)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
