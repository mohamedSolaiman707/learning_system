import 'package:flutter/material.dart';
import 'package:iconly/iconly.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/utils/responsive.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscureText = true;
  bool _isLoading = false;
  final supabase = Supabase.instance.client;

  Future<void> _handleLogin() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى إدخال البريد الإلكتروني وكلمة المرور')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final response = await supabase.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (response.user != null) {
        var userData = await supabase
            .from('profiles')
            .select('role')
            .eq('id', response.user!.id)
            .maybeSingle();

        if (userData == null) {
          final String fullName = response.user!.userMetadata?['full_name'] ?? 'مستخدم';
          final String role = response.user!.userMetadata?['role'] ?? 'student';
          
          await supabase.from('profiles').insert({
            'id': response.user!.id,
            'full_name': fullName,
            'role': role,
          });
          
          userData = {'role': role};
        }

        final String role = userData['role'];

        if (!mounted) return;

        if (role == 'teacher') {
          Navigator.pushReplacementNamed(context, AppRoutes.teacherHome);
        } else if (role == 'admin') {
          Navigator.pushReplacementNamed(context, AppRoutes.adminHome);
        } else {
          Navigator.pushReplacementNamed(context, AppRoutes.studentHome);
        }
      }
    } on AuthApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('خطأ في الدخول: البريد أو كلمة المرور غير صحيحة')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ: ${e.toString()}')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
          child: _buildLoginForm(),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        // الجانب الأيسر: واجهة ترحيبية
        Expanded(
          flex: 3,
          child: Container(
            color: const Color(0xFFF0F7FF),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.school_rounded, size: 120, color: Colors.blue),
                const SizedBox(height: 40),
                const Text(
                  "مرحباً بك في منصة التعلم الذكي",
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF1A1C1E)),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 50),
                  child: Text(
                    "نحن نجمع المعلمين والطلاب في مكان واحد لتجربة تعليمية فريدة واحترافية.",
                    style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
        // الجانب الأيمن: نموذج تسجيل الدخول
        Expanded(
          flex: 2,
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 60),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: _buildLoginForm(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginForm() {
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
          "تسجيل الدخول",
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1A1C1E)),
        ),
        const SizedBox(height: 8),
        const Text(
          "سجل دخولك للمتابعة في المنصة",
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 40),
        TextField(
          controller: _emailController,
          decoration: const InputDecoration(
            hintText: "البريد الإلكتروني",
            prefixIcon: Icon(IconlyLight.message),
          ),
        ),
        const SizedBox(height: 20),
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
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () {},
            child: const Text("نسيت كلمة المرور؟", style: TextStyle(fontSize: 13)),
          ),
        ),
        const SizedBox(height: 30),
        SizedBox(
          width: double.infinity,
          height: 55,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handleLogin,
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isLoading 
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text("دخول", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("ليس لديك حساب؟"),
            TextButton(
              onPressed: () => Navigator.pushNamed(context, AppRoutes.register),
              child: const Text("أنشئ حسابك الآن"),
            ),
          ],
        ),
      ],
    );
  }
}
