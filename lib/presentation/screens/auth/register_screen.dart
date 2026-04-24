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
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final name = _nameController.text.trim();

    if (email.isEmpty || password.isEmpty || name.isEmpty) {
      _showErrorSnackBar('يرجى ملء جميع الحقول الأساسية');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. محاولة إنشاء الحساب
      final response = await supabase.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': name, 'role': 'student'},
      );

      // 2. إذا نجح التسجيل أو استرجع بيانات المستخدم
      if (response.user != null) {
        // تحديث أو إنشاء البروفايل لضمان وجود البيانات
        await supabase.from('profiles').upsert({
          'id': response.user!.id,
          'full_name': name,
          'phone_number': _phoneController.text.trim(),
          'role': 'student',
        });

        if (!mounted) return;

        // إذا حصلنا على جلسة (Session) فهذا يعني أن الدخول نجح فوراً
        if (response.session != null) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إنشاء الحساب والدخول بنجاح!')));
          Navigator.pushReplacementNamed(context, AppRoutes.studentHome);
        } else {
          // إذا لم تكن هناك جلسة، فهذا يعني أن سوبابيس لا يزال يطلب التأكيد
          _showInfoDialog("تم إنشاء الحساب! ولكن يبدو أن نظام التأكيد لا يزال مفعلاً في سوبابيس. يرجى تفعيل حسابك من الإيميل.");
        }
      }
    } on AuthApiException catch (e) {
      if (!mounted) return;

      // إذا كان الحساب موجوداً بالفعل (ربما من تجربة سابقة)
      if (e.message.contains('already registered')) {
        try {
          // نحاول تسجيل الدخول مباشرة بالبيانات التي أدخلها المستخدم
          final loginRes = await supabase.auth.signInWithPassword(email: email, password: password);
          if (loginRes.session != null) {
            Navigator.pushReplacementNamed(context, AppRoutes.studentHome);
            return;
          }
        } catch (loginError) {
          _showErrorSnackBar("هذا الحساب موجود بالفعل، ولكن كلمة المرور غير صحيحة أو الحساب غير مفعل.");
        }
      } else {
        _showErrorSnackBar(e.message);
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar("حدث خطأ غير متوقع: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
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
                decoration: const InputDecoration(hintText: "رقم الواتساب", prefixIcon: Icon(IconlyLight.call)),
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
                child: _isLoading 
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                    : const Text("إنشاء الحساب"),
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
