import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/localization/app_localizations.dart';

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
    final bool isDesktop = Responsive.isDesktop(context);
    
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: Text(context.translate('settings'), 
          style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: SingleChildScrollView(
            padding: EdgeInsets.all(isDesktop ? 40 : 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isDesktop) ...[
                  const Text("إعدادات النظام", 
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, fontFamily: 'Cairo', color: Color(0xFF102A43))),
                  const SizedBox(height: 8),
                  const Text("تحكم في مظهر ووظائف المنصة التعليمية بالكامل", 
                    style: TextStyle(fontSize: 14, color: Colors.grey, fontFamily: 'Cairo')),
                  const SizedBox(height: 40),
                ],
                
                _buildCategoryHeader("المظهر واللغة"),
                _buildCard([
                  _buildSwitchItem(
                    themeProvider.isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                    context.translate('dark_mode'),
                    "تفعيل الوضع الداكن للتطبيق",
                    themeProvider.isDarkMode,
                    (val) => themeProvider.toggleTheme(val),
                  ),
                  const Divider(height: 1, indent: 70),
                  _buildSimpleItem(
                    Icons.language_rounded, 
                    "لغة المنصة", 
                    "العربية (مصر)", 
                    () {}, 
                    iconColor: Colors.orange
                  ),
                ]),
                
                const SizedBox(height: 32),
                
                _buildCategoryHeader("إعدادات الوصول"),
                _buildCard([
                  _buildSwitchItem(
                    Icons.construction_rounded,
                    "وضع الصيانة",
                    "منع دخول الطلاب للحصص مؤقتاً",
                    _maintenanceMode,
                    (val) => setState(() => _maintenanceMode = val),
                  ),
                  const Divider(height: 1, indent: 70),
                  _buildSwitchItem(
                    Icons.person_add_alt_1_rounded,
                    "تسجيل مستخدمين جدد",
                    "السماح بإنشاء حسابات طلاب جديدة",
                    _allowGuestRegistration,
                    (val) => setState(() => _allowGuestRegistration = val),
                  ),
                ]),
                
                const SizedBox(height: 32),
                
                _buildCategoryHeader("حول النظام"),
                _buildCard([
                  _buildSimpleItem(Icons.info_outline_rounded, "إصدار المنصة", "v2.1.0 Professional", null),
                  const Divider(height: 1, indent: 70),
                  _buildSimpleItem(
                    Icons.delete_sweep_outlined, 
                    "مسح الذاكرة المؤقتة", 
                    "تنظيف سجلات النظام القديمة", 
                    () {}, 
                    color: Colors.redAccent
                  ),
                ]),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, right: 8, left: 8),
      child: Text(title, 
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blueGrey, fontFamily: 'Cairo')),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSwitchItem(IconData icon, String title, String sub, bool value, Function(bool) onChanged) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: const Color(0xFF102A43).withOpacity(0.05), borderRadius: BorderRadius.circular(14)),
        child: Icon(icon, color: const Color(0xFF102A43), size: 24),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Cairo')),
      subtitle: Text(sub, style: const TextStyle(fontSize: 12, color: Colors.grey, fontFamily: 'Cairo')),
      trailing: Switch.adaptive(
        value: value, 
        onChanged: onChanged,
        activeColor: const Color(0xFF102A43),
      ),
    );
  }

  Widget _buildSimpleItem(IconData icon, String title, String sub, VoidCallback? onTap, {Color? color, Color? iconColor}) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: (iconColor ?? color ?? const Color(0xFF102A43)).withOpacity(0.05), borderRadius: BorderRadius.circular(14)),
        child: Icon(icon, color: iconColor ?? color ?? const Color(0xFF102A43), size: 24),
      ),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color, fontFamily: 'Cairo')),
      subtitle: Text(sub, style: const TextStyle(fontSize: 12, color: Colors.grey, fontFamily: 'Cairo')),
      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
    );
  }
}
