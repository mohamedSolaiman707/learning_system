import 'package:flutter/material.dart';
import 'package:iconly/iconly.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/widgets/custom_text_field.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscureText = true;

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    try {
      final success = await authProvider.login(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      if (success && mounted) {
        final role = authProvider.role;
        if (role == 'teacher') {
          Navigator.pushReplacementNamed(context, AppRoutes.teacherHome);
        } else if (role == 'admin') {
          Navigator.pushReplacementNamed(context, AppRoutes.adminHome);
        } else {
          Navigator.pushReplacementNamed(context, AppRoutes.studentHome);
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('فشل الدخول: البريد أو كلمة المرور غير صحيحة'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = Provider.of<AuthProvider>(context).isLoading;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Responsive(
        mobile: _buildMobileLayout(isLoading),
        desktop: _buildDesktopLayout(isLoading),
      ),
    );
  }

  Widget _buildMobileLayout(bool isLoading) {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: _buildLoginForm(isLoading),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout(bool isLoading) {
    return Row(
      children: [
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
                    "نظام متكامل يجمع المعلمين والطلاب في بيئة تعليمية احترافية ومتجاوبة.",
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
                child: _buildLoginForm(isLoading),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginForm(bool isLoading) {
    return Form(
      key: _formKey,
      child: Column(
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
          const SizedBox(height: 40),
          CustomTextField(
            controller: _emailController,
            hintText: "البريد الإلكتروني",
            prefixIcon: IconlyLight.message,
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || value.isEmpty) return "يرجى إدخال البريد الإلكتروني";
              if (!RegExp(r'\S+@\S+\.\S+').hasMatch(value)) return "يرجى إدخال بريد صحيح";
              return null;
            },
          ),
          const SizedBox(height: 20),
          CustomTextField(
            controller: _passwordController,
            hintText: "كلمة المرور",
            prefixIcon: IconlyLight.lock,
            isPassword: _obscureText,
            suffixIcon: IconButton(
              icon: Icon(_obscureText ? IconlyLight.hide : IconlyLight.show),
              onPressed: () => setState(() => _obscureText = !_obscureText),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) return "يرجى إدخال كلمة المرور";
              if (value.length < 6) return "يجب أن تكون 6 أحرف على الأقل";
              return null;
            },
          ),
          const SizedBox(height: 30),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              onPressed: isLoading ? null : _handleLogin,
              child: isLoading 
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
      ),
    );
  }
}
