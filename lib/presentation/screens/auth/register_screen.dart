import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/custom_text_field.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscureText = true;

  final supabase = Supabase.instance.client;

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final response = await supabase.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        data: {
          'full_name': _nameController.text.trim(),
          'role': 'student',
        },
      );

      if (response.user != null) {
        await supabase.from('profiles').upsert({
          'id': response.user!.id,
          'full_name': _nameController.text.trim(),
          'phone_number': _phoneController.text.trim(),
          'role': 'student',
          'email': _emailController.text.trim(),
        });

        if (!mounted) return;

        if (response.session != null) {
          Navigator.pushReplacementNamed(context, AppRoutes.studentHome);
        } else {
          _showSuccessDialog("تم إنشاء الحساب بنجاح! يرجى مراجعة بريدك الإلكتروني لتفعيل الحساب.");
        }
      }
    } on AuthApiException catch (e) {
      _handleAuthError(e);
    } catch (e) {
      _showErrorSnackBar("حدث خطأ غير متوقع، يرجى المحاولة مرة أخرى");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleAuthError(AuthApiException e) {
    String message = "فشل إنشاء الحساب";
    if (e.message.contains("already registered")) {
      message = "هذا البريد الإلكتروني مسجل بالفعل";
    } else if (e.message.contains("Password should be")) {
      message = "كلمة المرور ضعيفة جداً";
    }
    _showErrorSnackBar(message);
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 10),
            Text("نجاح"),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text("فهمت"),
          ),
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
                  "ابدأ رحلتك التعليمية",
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF1A1C1E)),
                ),
                const SizedBox(height: 16),
                Text(
                  "انضم لآلاف الطلاب والمعلمين في بيئة تفاعلية",
                  style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: _buildRegisterForm(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRegisterForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: SvgPicture.asset('assets/icons/logo.svg', width: 40, height: 40, 
                  placeholderBuilder: (_) => const Icon(Icons.school, color: Colors.blue)),
            ),
          ),
          const SizedBox(height: 32),
          const Text("إنشاء حساب جديد", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const Text("سجل بياناتك للوصول إلى كافة الدروس والمصادر", style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 32),
          
          CustomTextField(
            controller: _nameController,
            hintText: "الاسم الكامل",
            prefixIcon: Icons.person_outline_rounded,
            autofillHints: const [AutofillHints.name],
            validator: (v) => (v == null || v.isEmpty) ? "يرجى إدخال اسمك" : null,
          ),
          const SizedBox(height: 16),
          
          CustomTextField(
            controller: _emailController,
            hintText: "البريد الإلكتروني",
            prefixIcon: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            validator: (v) => (v == null || !v.contains('@')) ? "بريد إلكتروني غير صالح" : null,
          ),
          const SizedBox(height: 16),

          // CustomTextField(
          //   controller: _phoneController,
          //   hintText: "رقم الهاتف",
          //   prefixIcon: Icons.phone_outlined,
          //   keyboardType: TextInputType.phone,
          //   autofillHints: const [AutofillHints.telephoneNumber],
          //   validator: (v) => (v == null || v.length < 8) ? "رقم هاتف غير صحيح" : null,
          // ),
          // const SizedBox(height: 16),

          CustomTextField(
            controller: _passwordController,
            hintText: "كلمة المرور",
            prefixIcon: Icons.lock_outline_rounded,
            isPassword: _obscureText,
            autofillHints: const [AutofillHints.newPassword],
            suffixIcon: IconButton(
              icon: Icon(_obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined),
              onPressed: () => setState(() => _obscureText = !_obscureText),
            ),
            validator: (v) => (v == null || v.length < 6) ? "يجب أن تكون 6 أحرف على الأقل" : null,
          ),
          
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleRegister,
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: _isLoading 
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text("إنشاء حساب", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () {
               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("سيتم تفعيل الدخول الموحد عبر Blackboard قريباً")));
            },
            icon: const Icon(Icons.account_balance_rounded, size: 20),
            label: const Text("الدخول عبر حساب الجامعة"),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 55),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),

          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("لديك حساب بالفعل؟"),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("سجل دخولك"),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
