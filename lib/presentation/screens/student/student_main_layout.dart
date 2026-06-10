import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/utils/responsive.dart';
import 'tabs/student_home_tab.dart';
import 'tabs/student_schedule_tab.dart';
import '../profile/profile_screen.dart';

class StudentMainLayout extends StatelessWidget {
  const StudentMainLayout({super.key});

  @override
  Widget build(BuildContext context) {
    return ShowCaseWidget(
      // حفظ حالة الجولة عند الانتهاء أو التخطي
      onFinish: () => context.read<AuthProvider>().completeTour(),
      builder: (context) => const StudentMainContent(),
    );
  }
}

class StudentMainContent extends StatefulWidget {
  const StudentMainContent({super.key});

  @override
  State<StudentMainContent> createState() => _StudentMainContentState();
}

class _StudentMainContentState extends State<StudentMainContent> {
  int _selectedIndex = 0;

  // مفاتيح الجولة الإرشادية
  final GlobalKey _sidebarKey = GlobalKey();
  final GlobalKey _homeKey = GlobalKey();
  final GlobalKey _scheduleKey = GlobalKey();
  final GlobalKey _profileKey = GlobalKey();
  final GlobalKey _supportKey = GlobalKey();

  final List<Widget> _tabs = [
    const StudentHomeTab(),
    const StudentScheduleTab(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // تشغيل الجولة تلقائياً للمستخدمين الجدد فقط
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      if (!auth.hasSeenTour) {
        ShowCaseWidget.of(context).startShowCase([
          if (!Responsive.isMobile(context)) _sidebarKey,
          _homeKey,
          _scheduleKey,
          _profileKey,
          if (!Responsive.isMobile(context)) _supportKey,
        ]);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    bool isMobile = Responsive.isMobile(context);
    bool isDesktop = Responsive.isDesktop(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      body: Row(
        children: [
          if (!isMobile) 
            Showcase(
              key: _sidebarKey,
              title: 'القائمة الجانبية',
              description: 'من هنا يمكنك الوصول لكافة أقسام المنصة وإدارة حسابك.',
              child: _buildCustomSidebar(isDesktop),
            ),
          Expanded(
            child: Container(
              margin: isMobile ? EdgeInsets.zero : const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: isMobile ? BorderRadius.zero : BorderRadius.circular(32),
                boxShadow: [
                  if (!isMobile)
                    BoxShadow(
                      color: const Color(0xFF102A43).withOpacity(0.05),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    )
                ],
              ),
              child: ClipRRect(
                borderRadius: isMobile ? BorderRadius.zero : BorderRadius.circular(32),
                child: _tabs[_selectedIndex],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: isMobile ? _buildBottomBar() : null,
    );
  }

  Widget _buildCustomSidebar(bool isExpanded) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: isExpanded ? 280 : 100,
      color: const Color(0xFFF0F4F8),
      child: Column(
        children: [
          // Logo Section (المستعاد بالكامل)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
            child: Row(
              mainAxisAlignment: isExpanded ? MainAxisAlignment.start : MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF102A43),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.school_rounded, color: Colors.white, size: 28),
                ),
                if (isExpanded) ...[
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "EduConnect",
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 20,
                            color: Color(0xFF102A43),
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          "بوابة الطالب",
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF627D98),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Menu Items (المستعادة مع دمج الـ Showcase)
          _sidebarItem(0, Icons.grid_view_rounded, Icons.grid_view_outlined, "لوحة التحكم", isExpanded, _homeKey, 'الرئيسية', 'هنا ملخص حصصك اليومية وأهم التنبيهات.'),
          _sidebarItem(1, Icons.calendar_month_rounded, Icons.calendar_month_outlined, "الجدول الدراسي", isExpanded, _scheduleKey, 'جدولك', 'تابع مواعيد محاضراتك القادمة وروابط الدخول.'),
          _sidebarItem(2, Icons.person_rounded, Icons.person_outline_rounded, "الملف الشخصي", isExpanded, _profileKey, 'حسابك', 'يمكنك تعديل بياناتك ومتابعة مستواك الدراسي.'),
          
          const Spacer(),
          
          // Support Section (المستعاد بالكامل)
          _sidebarItem(99, Icons.support_agent_rounded, Icons.support_agent_outlined, "الدعم الفني", isExpanded, _supportKey, 'الدعم الفني', 'نحن هنا لمساعدتك في أي وقت إذا واجهتك مشكلة.'),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _sidebarItem(int index, IconData selectedIcon, IconData unselectedIcon, String label, bool isExpanded, GlobalKey key, String tourTitle, String tourDesc) {
    bool isSelected = _selectedIndex == index;
    
    return Showcase(
      key: key,
      title: tourTitle,
      description: tourDesc,
      titleTextStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF102A43), fontFamily: 'Cairo'),
      descTextStyle: const TextStyle(fontFamily: 'Cairo'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: InkWell(
          onTap: () async {
            if (index == 99) {
               final Uri whatsappUri = Uri.parse("https://wa.me/201014250577");
               if (await canLaunchUrl(whatsappUri)) {
                 await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
               } else {
                 if (context.mounted) {
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تعذر فتح واتساب")));
                 }
               }
            } else {
              setState(() => _selectedIndex = index);
            }
          },
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.symmetric(vertical: 16, horizontal: isExpanded ? 20 : 0),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF102A43) : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                if (isSelected)
                  BoxShadow(
                    color: const Color(0xFF102A43).withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
              ],
            ),
            child: Row(
              mainAxisAlignment: isExpanded ? MainAxisAlignment.start : MainAxisAlignment.center,
              children: [
                Icon(isSelected ? selectedIcon : unselectedIcon, color: isSelected ? Colors.white : const Color(0xFF486581), size: 24),
                if (isExpanded) ...[
                  const SizedBox(width: 16),
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      fontSize: 15,
                      color: isSelected ? Colors.white : const Color(0xFF486581),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: NavigationBar(
        elevation: 0,
        height: 70,
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFF102A43).withOpacity(0.1),
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) => setState(() => _selectedIndex = index),
        destinations: [
          NavigationDestination(
            icon: Showcase(key: _homeKey, title: 'الرئيسية', description: 'ملخص حصصك اليومية', child: const Icon(Icons.grid_view_outlined, color: Color(0xFF486581))),
            selectedIcon: const Icon(Icons.grid_view_rounded, color: Color(0xFF102A43)),
            label: 'الرئيسية',
          ),
          NavigationDestination(
            icon: Showcase(key: _scheduleKey, title: 'الجدول', description: 'تابع مواعيد محاضراتك', child: const Icon(Icons.calendar_month_outlined, color: Color(0xFF486581))),
            selectedIcon: const Icon(Icons.calendar_month_rounded, color: Color(0xFF102A43)),
            label: 'الجدول',
          ),
          NavigationDestination(
            icon: Showcase(key: _profileKey, title: 'حسابي', description: 'إدارة ملفك الشخصي', child: const Icon(Icons.person_outline_rounded, color: Color(0xFF486581))),
            selectedIcon: const Icon(Icons.person_rounded, color: Color(0xFF102A43)),
            label: 'حسابي',
          ),
        ],
      ),
    );
  }
}
