import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:showcaseview/showcaseview.dart';
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
      // عند الضغط على زر التخطي أو إنهاء الجولة
      onFinish: () => context.read<AuthProvider>().completeTour(),
      onStart: (index, key) => debugPrint('Started showcase on $index'),
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

  final List<Widget> _tabs = [
    const StudentHomeTab(),
    const StudentScheduleTab(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // بدء الجولة تلقائياً للمستخدم الجديد
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      if (!auth.hasSeenTour) {
        ShowCaseWidget.of(context).startShowCase([
          _sidebarKey,
          _homeKey,
          _scheduleKey,
          _profileKey,
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
            _buildProfessionalShowcase(
              key: _sidebarKey,
              title: 'القائمة الجانبية',
              description: 'استخدم هذه القائمة للتنقل السريع بين أقسام المنصة.',
              child: _buildCustomSidebar(isDesktop),
            ),
          Expanded(
            child: Container(
              margin: isMobile ? EdgeInsets.zero : const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: isMobile ? BorderRadius.zero : BorderRadius.circular(32),
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

  // ويجت مخصصة لعرض الشرح بشكل احترافي
  Widget _buildProfessionalShowcase({
    required GlobalKey key,
    required String title,
    required String description,
    required Widget child,
  }) {
    return Showcase(
      key: key,
      title: title,
      description: description,
      titleTextStyle: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Color(0xFF102A43),
        fontFamily: 'Cairo',
      ),
      descTextStyle: const TextStyle(
        fontSize: 14,
        color: Colors.black87,
        fontFamily: 'Cairo',
      ),
      targetShapeBorder: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      tooltipBackgroundColor: Colors.white,
      child: child,
    );
  }

  Widget _buildCustomSidebar(bool isExpanded) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: isExpanded ? 280 : 100,
      color: const Color(0xFFF0F4F8),
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Icon(Icons.school_rounded, color: Color(0xFF102A43), size: 40),
          ),
          _sidebarItem(0, Icons.grid_view_rounded, "الرئيسية", isExpanded),
          _sidebarItem(1, Icons.calendar_month_rounded, "الجدول", isExpanded),
          _sidebarItem(2, Icons.person_rounded, "حسابي", isExpanded),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _sidebarItem(int index, IconData icon, String label, bool isExpanded) {
    bool isSelected = _selectedIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        onTap: () => setState(() => _selectedIndex = index),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 16, horizontal: isExpanded ? 20 : 0),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF102A43) : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: isExpanded ? MainAxisAlignment.start : MainAxisAlignment.center,
            children: [
              Icon(icon, color: isSelected ? Colors.white : const Color(0xFF486581)),
              if (isExpanded) ...[
                const SizedBox(width: 16),
                Text(label, style: TextStyle(color: isSelected ? Colors.white : const Color(0xFF486581))),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return NavigationBar(
      selectedIndex: _selectedIndex,
      onDestinationSelected: (index) => setState(() => _selectedIndex = index),
      destinations: [
        NavigationDestination(
          icon: _buildProfessionalShowcase(
            key: _homeKey,
            title: 'لوحة التحكم',
            description: 'هنا تجد ملخص حصصك اليومية وأهم التنبيهات.',
            child: const Icon(Icons.grid_view_outlined),
          ),
          label: 'الرئيسية',
        ),
        NavigationDestination(
          icon: _buildProfessionalShowcase(
            key: _scheduleKey,
            title: 'الجدول الدراسي',
            description: 'تابع مواعيد محاضراتك القادمة وروابط الدخول المباشرة.',
            child: const Icon(Icons.calendar_month_outlined),
          ),
          label: 'الجدول',
        ),
        NavigationDestination(
          icon: _buildProfessionalShowcase(
            key: _profileKey,
            title: 'الملف الشخصي',
            description: 'من هنا يمكنك تعديل بياناتك ومتابعة مستواك الدراسي.',
            child: const Icon(Icons.person_outline_rounded),
          ),
          label: 'حسابي',
        ),
      ],
    );
  }
}
