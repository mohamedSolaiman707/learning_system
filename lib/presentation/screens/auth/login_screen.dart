import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_iconly/flutter_iconly.dart'; // التحديث هنا
import 'package:provider/provider.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/widgets/custom_text_field.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  
  bool _isLogin = true; 
  bool _obscureText = true;
  bool _rememberMe = true;
  
  bool _isEmailValidFormat = false;
  bool _isCheckingEmail = false;
  bool? _isEmailAvailable;

  double _passwordStrength = 0;
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutBack),
    );
    _animController.forward();

    _emailController.addListener(_onEmailChanged);
    _passwordController.addListener(_checkPasswordStrength);
  }

  void _onEmailChanged() async {
    final email = _emailController.text.trim();
    final isValidFormat = RegExp(r'\S+@\S+\.\S+').hasMatch(email);
    
    setState(() {
      _isEmailValidFormat = isValidFormat;
      if (!isValidFormat) {
        _isEmailAvailable = null;
        _isCheckingEmail = false;
      }
    });

    if (isValidFormat && !_isLogin && _isEmailAvailable == null && !_isCheckingEmail) {
      setState(() => _isCheckingEmail = true);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final available = await authProvider.isEmailAvailable(email);
      
      if (mounted) {
        setState(() {
          _isEmailAvailable = available;
          _isCheckingEmail = false;
        });
      }
    }
  }

  void _checkPasswordStrength() {
    String p = _passwordController.text;
    double strength = 0;
    if (p.length >= 6) strength += 0.3;
    if (p.contains(RegExp(r'[A-Z]'))) strength += 0.3;
    if (p.contains(RegExp(r'[0-9]'))) strength += 0.4;
    setState(() => _passwordStrength = strength);
  }

  @override
  void dispose() {
    _animController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _triggerHaptic({bool heavy = false}) {
    if (heavy) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.lightImpact();
    }
  }

  void _showWelcomeOverlay(String userName) {
    OverlayState? overlayState = Overlay.of(context);
    late OverlayEntry overlayEntry;
    overlayEntry = OverlayEntry(builder: (context) => _WelcomeOverlayWidget(userName: userName));
    overlayState.insert(overlayEntry);
    Future.delayed(const Duration(seconds: 2), () => overlayEntry.remove());
  }

  Future<void> _handleAuth() async {
    if (!_formKey.currentState!.validate()) {
      HapticFeedback.vibrate();
      return;
    }

    if (!_isLogin && _isEmailAvailable == false) {
      _showErrorSnackBar("هذا البريد مسجل بالفعل، يرجى تسجيل الدخول");
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    try {
      bool success;
      if (_isLogin) {
        success = await authProvider.login(_emailController.text.trim(), _passwordController.text.trim());
      } else {
        success = await authProvider.register(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          fullName: _nameController.text.trim(),
        );
      }

      if (success && mounted) {
        _triggerHaptic(heavy: true);
        final name = authProvider.profile?['full_name'] ?? _nameController.text;
        _showWelcomeOverlay(name.isEmpty ? "عزيزي المستخدم" : name);
        await Future.delayed(const Duration(milliseconds: 2200));
        if (mounted) _navigateBasedOnRole(authProvider.role);
      }
    } catch (e) {
      _showErrorSnackBar(_isLogin ? "البريد أو كلمة المرور غير صحيحة" : "فشل إنشاء الحساب");
    }
  }

  void _navigateBasedOnRole(String role) {
    String route = AppRoutes.studentHome;
    if (role == 'teacher') route = AppRoutes.teacherHome;
    else if (role == 'admin') route = AppRoutes.adminHome;
    Navigator.pushReplacementNamed(context, route);
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(24), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
    );
  }

  void _toggleAuthMode() {
    _triggerHaptic();
    setState(() {
      _isLogin = !_isLogin;
      _isEmailValidFormat = false;
      _isEmailAvailable = null;
      _emailController.clear();
      _passwordController.clear();
      _nameController.clear();
    });
    _animController.reset();
    _animController.forward();
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = Provider.of<AuthProvider>(context).isLoading;
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(children: [
        _buildBackground(),
        Center(child: SingleChildScrollView(padding: const EdgeInsets.symmetric(horizontal: 24),
          child: ScaleTransition(scale: _scaleAnimation,
            child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 480),
              child: Column(children: [
                _buildHeader(),
                const SizedBox(height: 40),
                _buildAuthCard(isLoading),
                const SizedBox(height: 32),
                _buildFooterToggle(),
              ]))))),
      ]));
  }

  Widget _buildBackground() {
    return Positioned.fill(child: Container(decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Colors.blue.shade50.withOpacity(0.8), Colors.white, Colors.white]))));
  }

  Widget _buildHeader() {
    return Column(children: [
        Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.blue.shade600, shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 30, offset: const Offset(0, 10))]),
          child: const Icon(Icons.school_rounded, color: Colors.white, size: 40)),
        const SizedBox(height: 24),
        Text(_isLogin ? "أهلاً بك مجدداً" : "انضم لأسرتنا", style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
        const SizedBox(height: 8),
        Text(_isLogin ? "سجل دخولك لمواصلة رحلتك" : "أنشئ حساباً للوصول لمصادرك التعليمية",
          style: TextStyle(color: Colors.grey.shade600, fontSize: 16), textAlign: TextAlign.center),
    ]);
  }

  Widget _buildAuthCard(bool isLoading) {
    return Container(padding: const EdgeInsets.all(30), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(35),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 40, offset: const Offset(0, 20))]),
      child: Form(key: _formKey,
        child: Column(children: [
            _buildBlackboardButton(),
            const SizedBox(height: 24),
            _buildDivider(),
            const SizedBox(height: 24),
            if (!_isLogin) ...[
              CustomTextField(controller: _nameController, hintText: "الاسم الكامل", prefixIcon: IconlyLight.user2,
                validator: (v) => (v == null || v.isEmpty) ? "يرجى كتابة اسمك" : null),
              const SizedBox(height: 16),
            ],
            
            _buildEmailField(),
            
            const SizedBox(height: 16),
            CustomTextField(controller: _passwordController, hintText: "كلمة المرور", prefixIcon: IconlyLight.lock, isPassword: _obscureText,
              autofillHints: const [AutofillHints.password],
              suffixIcon: IconButton(icon: Icon(_obscureText ? IconlyLight.hide : IconlyLight.show, size: 20),
                onPressed: () => setState(() => _obscureText = !_obscureText)),
              validator: (v) => (v == null || v.length < 6) ? "كلمة المرور قصيرة" : null),
            
            const SizedBox(height: 12),
            if (_isLogin) _buildLoginOptions() else _buildPasswordStrengthBar(),
            const SizedBox(height: 32),
            _buildMainButton(isLoading),
          ])));
  }

  Widget _buildEmailField() {
    Widget? suffix;
    if (_isCheckingEmail) {
      suffix = const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)));
    } else if (_isEmailAvailable == true) {
      suffix = const Icon(Icons.check_circle_rounded, color: Colors.green, size: 20);
    } else if (_isEmailAvailable == false) {
      suffix = const Icon(Icons.error_rounded, color: Colors.redAccent, size: 20);
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CustomTextField(controller: _emailController, hintText: "البريد الإلكتروني", prefixIcon: IconlyLight.message, keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          suffixIcon: suffix,
          validator: (v) {
            if (v == null || !v.contains('@')) return "بريد إلكتروني غير صالح";
            if (!_isLogin && _isEmailAvailable == false) return "هذا البريد مستخدم بالفعل";
            return null;
          }),
    ]);
  }

  Widget _buildBlackboardButton() {
    return InkWell(onTap: () { _triggerHaptic(); _showErrorSnackBar("تكامل Blackboard متاح لطلاب الجامعات المشتركة فقط"); },
      borderRadius: BorderRadius.circular(20),
      child: Container(height: 60, decoration: BoxDecoration(borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(colors: [Color(0xFF232526), Color(0xFF414345)]),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 5))]),
        child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.cast_for_education, color: Colors.white, size: 24),
            SizedBox(width: 12),
            Text("دخول عبر Blackboard", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ])));
  }

  Widget _buildDivider() {
    return Row(children: [
        Expanded(child: Divider(color: Colors.grey.shade100)),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text("أو يدوياً", style: TextStyle(color: Colors.grey.shade300, fontSize: 12))),
        Expanded(child: Divider(color: Colors.grey.shade100)),
      ]);
  }

  Widget _buildLoginOptions() {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Row(children: [
          Checkbox(value: _rememberMe, onChanged: (v) => setState(() => _rememberMe = v!),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)), activeColor: Colors.blue),
          const Text("تذكرني", style: TextStyle(fontSize: 13, color: Colors.grey)),
        ]),
        TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotPasswordScreen())),
          child: const Text("نسيت كلمة المرور؟", style: TextStyle(fontSize: 13, color: Colors.blue, fontWeight: FontWeight.bold))),
      ]);
  }

  Widget _buildPasswordStrengthBar() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ClipRRect(borderRadius: BorderRadius.circular(10), child: LinearProgressIndicator(
            value: _passwordStrength, backgroundColor: Colors.grey.shade100,
            color: _passwordStrength < 0.4 ? Colors.red : (_passwordStrength < 0.7 ? Colors.orange : Colors.green),
            minHeight: 6)),
        const SizedBox(height: 6),
        Text(_passwordStrength < 0.4 ? "كلمة مرور ضعيفة" : (_passwordStrength < 0.7 ? "كلمة مرور جيدة" : "كلمة مرور قوية جداً ✅"),
          style: TextStyle(fontSize: 11, color: Colors.grey.shade500))
    ]);
  }

  Widget _buildMainButton(bool isLoading) {
    return Container(width: double.infinity, height: 60, decoration: BoxDecoration(borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))]),
      child: ElevatedButton(onPressed: isLoading ? null : _handleAuth,
        style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade600, foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), elevation: 0),
        child: isLoading ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Text(_isLogin ? "تسجيل دخول" : "إنشاء حسابي", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
    );
  }

  Widget _buildFooterToggle() {
    return Column(children: [
        Text(_isLogin ? "ليس لديك حساب؟" : "لديك حساب بالفعل؟", style: TextStyle(color: Colors.grey.shade600)),
        const SizedBox(height: 4),
        InkWell(onTap: _toggleAuthMode, borderRadius: BorderRadius.circular(15),
          child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(_isLogin ? "سجل الآن مجاناً" : "سجل دخولك من هنا",
              style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 16)))),
    ]);
  }
}

class _WelcomeOverlayWidget extends StatefulWidget {
  final String userName;
  const _WelcomeOverlayWidget({required this.userName});
  @override
  State<_WelcomeOverlayWidget> createState() => _WelcomeOverlayWidgetState();
}

class _WelcomeOverlayWidgetState extends State<_WelcomeOverlayWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _scaleAnim = Tween<double>(begin: 0.8, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(_controller);
    _controller.forward();
  }
  @override
  void dispose() { _controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return Material(color: Colors.black54,
      child: FadeTransition(opacity: _fadeAnim,
        child: ScaleTransition(scale: _scaleAnim,
          child: Center(child: Container(padding: const EdgeInsets.all(40), margin: const EdgeInsets.all(40),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(35)),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.celebration_rounded, color: Colors.orangeAccent, size: 60),
                  const SizedBox(height: 24),
                  Text("أهلاً بك، ${widget.userName}", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  const Text("جاري تحضير فصلك الدراسي...", style: TextStyle(color: Colors.grey, fontSize: 16), textAlign: TextAlign.center),
                  const SizedBox(height: 32),
                  const CircularProgressIndicator(color: Colors.blue, strokeWidth: 3),
                ]))))));
  }
}
