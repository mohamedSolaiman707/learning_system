import 'package:flutter/material.dart';
import 'package:iconly/iconly.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/utils/responsive.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscureText = true;

  final supabase = Supabase.instance.client;

  Future<void> _handleRegister() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final phone = _phoneController.text.trim();
    final name = _nameController.text.trim();

    if (email.isEmpty || password.isEmpty || name.isEmpty) {
      _showErrorSnackBar('يرجى ملء جميع الحقول الأساسية');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await supabase.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': name, 'role': 'student'},
      );

      if (response.user != null) {
        await supabase.from('profiles').upsert({
          'id': response.user!.id,
          'full_name': name,
          'phone_number': phone,
          'role': 'student',
        });

        if (!mounted) return;

        if (response.session != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم إنشاء الحساب والدخول بنجاح!')),
          );
          Navigator.pushReplacementNamed(context, AppRoutes.studentHome);
        } else {
          _showInfoDialog("تم إنشاء الحساب! يرجى تفعيل حسابك إذا كان نظام التأكيد مفعلاً.");
        }
      }
    } on AuthApiException catch (e) {
      if (!mounted) return;
      _showErrorSnackBar(e.message);
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar("حدث خطأ غير متوقع: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showInfoDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("تنبيه"),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("حسناً")),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Responsive(
        mobile: _buildMobileLayout(),
        desktop: _buildDesktopLayout(),
      ),
    );
  }

  Widget _buildMobileLayout() {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: _buildRegisterForm(),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Container(
            color: const Color(0xFFF0F7FF),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.person_add_rounded, size: 120, color: Colors.blue),
                const SizedBox(height: 40),
                const Text(
                  "انضم إلى مجتمعنا التعليمي",
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF1A1C1E)),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 50),
                  child: Text(
                    "ابدأ رحلتك التعليمية اليوم مع أفضل الأدوات والتقنيات للتواصل والتعلم عن بعد.",
                    style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 60),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: _buildRegisterForm(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRegisterForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: SvgPicture.asset(
              'assets/icons/logo.svg',
              width: 50,
              height: 50,
              placeholderBuilder: (context) => const Icon(Icons.school, size: 50, color: Colors.blue),
            ),
          ),
        ),
        const SizedBox(height: 40),
        const Text(
          "إنشاء حساب جديد",
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1A1C1E)),
        ),
        const SizedBox(height: 8),
        const Text(
          "املأ البيانات التالية للبدء في المنصة",
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 32),
        TextField(
          controller: _nameController,
          decoration: const InputDecoration(
            hintText: "الاسم الكامل",
            prefixIcon: Icon(IconlyLight.user),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _emailController,
          decoration: const InputDecoration(
            hintText: "البريد الإلكتروني",
            prefixIcon: Icon(IconlyLight.message),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _phoneController,
          decoration: const InputDecoration(
            hintText: "رقم الهاتف",
            prefixIcon: Icon(IconlyLight.call),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _passwordController,
          obscureText: _obscureText,
          decoration: InputDecoration(
            hintText: "كلمة المرور",
            prefixIcon: const Icon(IconlyLight.lock),
            suffixIcon: IconButton(
              icon: Icon(_obscureText ? IconlyLight.hide : IconlyLight.show),
              onPressed: () => setState(() => _obscureText = !_obscureText),
            ),
          ),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 55,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handleRegister,
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isLoading 
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text("إنشاء الحساب", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("لديك حساب بالفعل؟"),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("سجل دخولك الآن"),
            ),
          ],
        ),
      ],
    );
  }
}
