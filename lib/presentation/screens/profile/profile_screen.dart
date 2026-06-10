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
        setState(() {
          _isUploading = true;
        });

        final file = result.files.first;
        await authProvider.uploadAvatar(file.bytes!, file.name);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("تم تحديث صورة الملف الشخصي بنجاح ✅", style: TextStyle(fontFamily: 'Cairo')),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("فشل رفع الصورة: $e", style: const TextStyle(fontFamily: 'Cairo')),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  void _showEditDialog(String title, String field, String currentValue) {
    final controller = TextEditingController(text: currentValue);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    showDialog(
      context: context,
      builder: (context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Text("تعديل $title", style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
            content: TextField(
              controller: controller,
              style: const TextStyle(fontFamily: 'Cairo'),
              decoration: InputDecoration(
                hintText: "أدخل $title الجديد",
                filled: true,
                fillColor: Colors.grey.withOpacity(0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context), 
                child: const Text("إلغاء", style: TextStyle(color: Colors.grey, fontFamily: 'Cairo')),
              ),
              ElevatedButton(
                onPressed: () async {
                  try {
                    await authProvider.updateProfile({field: controller.text});
                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("تم تحديث البيانات بنجاح ✅", style: TextStyle(fontFamily: 'Cairo')), 
                          backgroundColor: Colors.green,
                          behavior: SnackBarBehavior.floating,
                        )
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("فشل التحديث: $e", style: const TextStyle(fontFamily: 'Cairo')), 
                          backgroundColor: Colors.red,
                          behavior: SnackBarBehavior.floating,
                        )
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF102A43),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("حفظ التعديلات", style: TextStyle(fontFamily: 'Cairo')),
              ),
            ],
          ),
        ),
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
          ? AppBar(
              title: const Text("الملف الشخصي", style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo')), 
              elevation: 0,
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
            )
          : null,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1400),
          child: Responsive(
            mobile: _buildMobileLayout(profile, authProvider),
            desktop: _buildDesktopLayout(profile, authProvider),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileLayout(Map<String, dynamic> profile, AuthProvider auth) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildSummaryCard(profile, auth),
          const SizedBox(height: 24),
          _buildSettingsSection(profile),
          const SizedBox(height: 32),
          _buildLogoutButton(auth),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout(Map<String, dynamic> profile, AuthProvider auth) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Side: Settings
        Expanded(
          flex: 3,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(60),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "إعدادات الحساب الشخصي", 
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF1A1C1E), fontFamily: 'Cairo')
                ),
                const SizedBox(height: 8),
                const Text("تحكم في بياناتك الشخصية وإعدادات الأمان الخاصة بك", style: TextStyle(color: Colors.grey, fontFamily: 'Cairo', fontSize: 16)),
                const SizedBox(height: 48),
                _buildSettingsSection(profile),
              ],
            ),
          ),
        ),
        
        const VerticalDivider(width: 1, color: Colors.black12),
        
        // Right Side: Summary
        Expanded(
          flex: 2,
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.all(60),
            child: Column(
              children: [
                _buildSummaryCard(profile, auth),
                const Spacer(),
                _buildLogoutButton(auth),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(Map<String, dynamic> profile, AuthProvider auth) {
    final String name = profile['full_name'] ?? 'مستخدم';
    final String role = profile['role'] ?? 'student';
    final String? avatarUrl = profile['avatar_url'];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04), 
            blurRadius: 30, 
            offset: const Offset(0, 10)
          )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              GestureDetector(
                onTap: _isUploading ? null : () => _pickAndUploadImage(auth),
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.05),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                    boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
                    image: avatarUrl != null 
                        ? DecorationImage(
                            image: NetworkImage(avatarUrl), 
                            fit: BoxFit.cover,
                            opacity: _isUploading ? 0.5 : 1.0,
                          )
                        : null,
                  ),
                  child: avatarUrl == null 
                      ? Center(
                          child: Text(
                            name.isNotEmpty ? name.substring(0, 1).toUpperCase() : "U",
                            style: TextStyle(
                              fontSize: 56, 
                              fontWeight: FontWeight.bold, 
                              fontFamily: 'Cairo',
                              color: const Color(0xFF102A43).withOpacity(_isUploading ? 0.3 : 1.0),
                            ),
                          ),
                        )
                      : null,
                ),
              ),
              if (_isUploading)
                const SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(strokeWidth: 3, color: Color(0xFF102A43)),
                ),
              Positioned(
                bottom: 5,
                right: 5,
                child: GestureDetector(
                  onTap: _isUploading ? null : () => _pickAndUploadImage(auth),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _isUploading ? Colors.grey : const Color(0xFF102A43),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                    child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            name, 
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1A1C1E), fontFamily: 'Cairo'),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF102A43).withOpacity(0.1),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Text(
              role == 'admin' ? "مدير النظام" : (role == 'teacher' ? "مدرس معتمد" : "طالب"),
              style: const TextStyle(
                color: Color(0xFF102A43),
                fontWeight: FontWeight.bold,
                fontSize: 13,
                fontFamily: 'Cairo',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection(Map<String, dynamic> profile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("المعلومات الأساسية", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87, fontFamily: 'Cairo')),
        const SizedBox(height: 20),
        _buildInfoCard([
          _buildInfoItem(
            icon: Icons.person_outline_rounded, 
            label: "الاسم الكامل", 
            value: profile['full_name'] ?? '', 
            onEdit: () => _showEditDialog("الاسم", "full_name", profile['full_name'] ?? ""),
          ),
          const Divider(height: 1, indent: 70),
          _buildInfoItem(
            icon: Icons.email_outlined, 
            label: "البريد الإلكتروني", 
            value: profile['email'] ?? 'جاري التحميل...', 
          ),
        ]),
        
        const SizedBox(height: 40),
        
        const Text("الأمان والحساب", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87, fontFamily: 'Cairo')),
        const SizedBox(height: 20),
        _buildInfoCard([
          _buildInfoItem(
            icon: Icons.lock_outline_rounded, 
            label: "كلمة المرور", 
            value: "********", 
            onEdit: () {
               ScaffoldMessenger.of(context).showSnackBar(
                 const SnackBar(
                   content: Text("يمكنك تغيير كلمة المرور من خلال بريدك الإلكتروني", style: TextStyle(fontFamily: 'Cairo')),
                   behavior: SnackBarBehavior.floating,
                 )
               );
            },
          ),
          const Divider(height: 1, indent: 70),
          _buildInfoItem(
            icon: Icons.verified_user_outlined, 
            label: "حالة الحساب", 
            value: "نشط وموثق", 
          ),
        ]),
      ],
    );
  }

  Widget _buildInfoCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02), 
            blurRadius: 20, 
            offset: const Offset(0, 4)
          )
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildInfoItem({
    required IconData icon, 
    required String label, 
    required String value, 
    VoidCallback? onEdit
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF102A43).withOpacity(0.05), 
              borderRadius: BorderRadius.circular(14)
            ),
            child: Icon(icon, size: 24, color: const Color(0xFF102A43)),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500, fontFamily: 'Cairo')),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1A1C1E), fontFamily: 'Cairo')),
              ],
            ),
          ),
          if (onEdit != null)
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.edit_note_rounded, size: 22, color: Color(0xFF102A43)),
              ),
              onPressed: onEdit,
              tooltip: "تعديل",
            ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton(AuthProvider auth) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () async {
          await auth.logout();
          if (mounted) Navigator.pushReplacementNamed(context, AppRoutes.login);
        },
        icon: const Icon(Icons.logout_rounded, size: 20),
        label: const Text("تسجيل الخروج من الحساب", style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFFEBEE),
          foregroundColor: Colors.red,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
      ),
    );
  }
}
