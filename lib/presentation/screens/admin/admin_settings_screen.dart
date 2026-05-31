import 'package:flutter/material.dart';
import 'package:flutter_iconly/flutter_iconly.dart';
import 'package:provider/provider.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/localization/app_localizations.dart';
import '../profile/profile_screen.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  bool _maintenanceMode = false;
  bool _allowGuestRegistration = true;

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(context.translate('settings')),
        elevation: 0,
      ),
      body: Responsive(
        mobile: _buildListLayout(themeProvider),
        desktop: _buildGridLayout(themeProvider),
      ),
    );
  }

  Widget _buildListLayout(ThemeProvider themeProvider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCategoryHeader(context.translate('theme_mode')),
          _buildThemeSettings(themeProvider),
          const SizedBox(height: 30),
          _buildCategoryHeader(context.translate('language')),
          _buildLanguageSettings(),
          const SizedBox(height: 30),
          _buildCategoryHeader("إعدادات المنصة"),
          _buildPlatformSettings(),
          const SizedBox(height: 30),
          _buildCategoryHeader("النظام"),
          _buildSystemSettings(),
        ],
      ),
    );
  }

  Widget _buildGridLayout(ThemeProvider themeProvider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("إعدادات النظام المتقدمة", 
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
          const SizedBox(height: 40),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  children: [
                    _buildCategoryHeader(context.translate('theme_mode')),
                    _buildThemeSettings(themeProvider),
                    const SizedBox(height: 30),
                    _buildCategoryHeader(context.translate('language')),
                    _buildLanguageSettings(),
                  ],
                ),
              ),
              const SizedBox(width: 30),
              Expanded(
                child: Column(
                  children: [
                    _buildCategoryHeader("إعدادات المنصة"),
                    _buildPlatformSettings(),
                  ],
                ),
              ),
              const SizedBox(width: 30),
              Expanded(
                child: Column(
                  children: [
                    _buildCategoryHeader("النظام"),
                    _buildSystemSettings(),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildThemeSettings(ThemeProvider themeProvider) {
    return _buildCard([
      _buildSwitchItem(
        themeProvider.isDarkMode ? Icons.dark_mode : Icons.light_mode,
        context.translate('dark_mode'),
        "تغيير مظهر التطبيق بالكامل",
        themeProvider.isDarkMode,
        (val) => themeProvider.toggleTheme(val),
      ),
    ]);
  }

  Widget _buildLanguageSettings() {
    return _buildCard([
      ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.language, color: Colors.orange),
        ),
        title: const Text("لغة التطبيق", style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: const Text("العربية (مصر)"),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14),
        onTap: () {
          // يمكن هنا إضافة شيت لاختيار اللغة
        },
      ),
    ]);
  }

  Widget _buildPlatformSettings() {
    return _buildCard([
      _buildSwitchItem(
        IconlyLight.work,
        "وضع الصيانة",
        "منع دخول الحصص مؤقتاً",
        _maintenanceMode,
        (val) => setState(() => _maintenanceMode = val),
      ),
      const Divider(indent: 60),
      _buildSwitchItem(
        IconlyLight.addUser,
        "تسجيل الطلاب",
        "السماح بإنشاء حسابات جديدة",
        _allowGuestRegistration,
        (val) => setState(() => _allowGuestRegistration = val),
      ),
    ]);
  }

  Widget _buildSystemSettings() {
    return _buildCard([
      _buildSimpleItem(IconlyLight.infoSquare, "عن المنصة", "v1.5.0 Professional", null),
      const Divider(indent: 60),
      _buildSimpleItem(IconlyLight.dangerCircle, "مسح السجلات", "تنظيف البيانات القديمة", () {}, color: Colors.red),
    ]);
  }

  Widget _buildCategoryHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, right: 10),
      child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSwitchItem(IconData icon, String title, String sub, bool value, Function(bool) onChanged) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: Colors.blue, size: 22),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      subtitle: Text(sub, style: const TextStyle(fontSize: 12)),
      trailing: Switch.adaptive(value: value, onChanged: onChanged),
    );
  }

  Widget _buildSimpleItem(IconData icon, String title, String sub, VoidCallback? onTap, {Color? color}) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: (color ?? Colors.blue).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: color ?? Colors.blue, size: 22),
      ),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: color)),
      subtitle: Text(sub, style: const TextStyle(fontSize: 12)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
    );
  }
}
