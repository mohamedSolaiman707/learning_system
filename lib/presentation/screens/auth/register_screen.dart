import 'package:flutter/material.dart';
import 'package:iconly/iconly.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/routes/app_routes.dart';

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

  final supabase = Supabase.instance.client;

  Future<void> _handleRegister() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty || _nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى ملء جميع الحقول الأساسية')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      // 1. إنشاء الحساب في Supabase Auth
      final response = await supabase.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        data: {
          'full_name': _nameController.text.trim(),
          'role': 'student', // القيمة الافتراضية دائماً طالب
        },
      );

      if (response.user != null) {
        // 2. تحديث رقم الهاتف في البروفايل (الذي تم إنشاؤه تلقائياً بواسطة الـ Trigger)
        await supabase.from('profiles').update({
          'phone_number': _phoneController.text.trim(),
        }).eq('id', response.user!.id);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إنشاء الحساب بنجاح!')));
        Navigator.pushReplacementNamed(context, AppRoutes.studentHome);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: ${e.toString()}')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(elevation: 0, backgroundColor: Colors.transparent),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "إنشاء حساب جديد",
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text("انضم إلينا كطالب وابدأ رحلتك التعليمية", style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 32),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(hintText: "الاسم الكامل", prefixIcon: Icon(IconlyLight.user)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(hintText: "البريد الإلكتروني", prefixIcon: Icon(IconlyLight.message)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _phoneController,
                decoration: const InputDecoration(hintText: "رقم الواتساب (مثال: 2010...)", prefixIcon: Icon(IconlyLight.call)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(hintText: "كلمة المرور", prefixIcon: Icon(IconlyLight.lock)),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _handleRegister,
                child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("إنشاء الحساب"),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("لديك حساب بالفعل؟"),
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text("سجل دخولك")),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
