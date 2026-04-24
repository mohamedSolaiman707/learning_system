import 'package:flutter/material.dart';
import 'package:iconly/iconly.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../core/routes/app_routes.dart';

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
      // 1. محاولة تسجيل الدخول
      final response = await supabase.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (response.user != null) {
        // 2. محاولة جلب البروفايل
        var userData = await supabase
            .from('profiles')
            .select('role')
            .eq('id', response.user!.id)
            .maybeSingle();

        // 3. (حماية إضافية) إذا لم يجد البروفايل، نقوم بإنشائه الآن
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

        // 4. التوجيه بناءً على الدور
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
        SnackBar(content: Text('خطأ في الدخول: البريد أو كلمة المرور غير صحيحة')),
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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 50),
              Center(
                child: SvgPicture.asset(
                  'assets/icons/logo.svg',
                  width: 80,
                  height: 80,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                "مرحباً بك مجدداً",
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              const Text(
                "سجل دخولك للمتابعة في EduConnect",
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
              ElevatedButton(
                onPressed: _isLoading ? null : _handleLogin,
                child: _isLoading 
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text("دخول"),
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
          ),
        ),
      ),
    );
  }
}
