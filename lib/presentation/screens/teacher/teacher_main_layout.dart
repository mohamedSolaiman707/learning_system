import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/utils/responsive.dart';
import 'tabs/teacher_home_tab.dart';
import 'tabs/teacher_schedule_tab.dart'; 
import '../profile/profile_screen.dart';

class TeacherMainLayout extends StatefulWidget {
  const TeacherMainLayout({super.key});

  @override
  State<TeacherMainLayout> createState() => _TeacherMainLayoutState();
}

class _TeacherMainLayoutState extends State<TeacherMainLayout> {
  int _selectedIndex = 0;

  final List<Widget> _tabs = [
    const TeacherHomeTab(),
    const TeacherScheduleTab(),
    const ProfileScreen(),
  ];

  final List<NavigationDestination> _destinations = const [
    NavigationDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home),
      label: 'الرئيسية',
    ),
    NavigationDestination(
      icon: Icon(Icons.calendar_today_outlined),
      selectedIcon: Icon(Icons.calendar_today),
      label: 'جدولي',
    ),
    NavigationDestination(
      icon: Icon(Icons.person_outline),
      selectedIcon: Icon(Icons.person),
      label: 'حسابي',
    ),
  ];

  Future<void> _launchSupport() async {
    final Uri whatsappUri = Uri.parse("https://wa.me/201014250577");
    try {
      if (await canLaunchUrl(whatsappUri)) {
        await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("تعذر فتح واتساب", style: TextStyle(fontFamily: 'Cairo'))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isMobile = Responsive.isMobile(context);
    bool isDesktop = Responsive.isDesktop(context);

    return Scaffold(
      body: Row(
        children: [
          if (!isMobile)
            _buildDesktopSidebar(isDesktop),
          if (!isMobile) const VerticalDivider(thickness: 1, width: 1, color: Colors.black12),
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: _tabs,
            ),
          ),
        ],
      ),
      bottomNavigationBar: isMobile
          ? NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (index) => setState(() => _selectedIndex = index),
              destinations: _destinations,
            )
          : null,
    );
  }

  Widget _buildDesktopSidebar(bool isExpanded) {
    return Container(
      width: isExpanded ? 260 : 80,
      color: Colors.white,
      child: Column(
        children: [
          const SizedBox(height: 40),
          // Logo
          CircleAvatar(
            backgroundColor: const Color(0xFF102A43).withOpacity(0.1),
            child: const Icon(Icons.school_rounded, color: Color(0xFF102A43)),
          ),
          const SizedBox(height: 40),

          // Navigation Items
          Expanded(
            child: NavigationRail(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (index) => setState(() => _selectedIndex = index),
              extended: isExpanded,
              backgroundColor: Colors.transparent,
              minWidth: 80,
              minExtendedWidth: 260,
              labelType: isExpanded ? NavigationRailLabelType.none : NavigationRailLabelType.all,
              destinations: _destinations.map((d) => NavigationRailDestination(
                icon: d.icon,
                selectedIcon: d.selectedIcon,
                label: Text(d.label, style: const TextStyle(fontFamily: 'Cairo')),
              )).toList(),
            ),
          ),

          // Support Item at Bottom
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: isExpanded
                ? ListTile(
                    onTap: _launchSupport,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    leading: const Icon(Icons.support_agent_rounded, color: Color(0xFF486581)),
                    title: const Text("الدعم الفني", style: TextStyle(fontFamily: 'Cairo', fontSize: 14, color: Color(0xFF486581))),
                    hoverColor: Colors.blue.withOpacity(0.05),
                  )
                : IconButton(
                    onPressed: _launchSupport,
                    icon: const Icon(Icons.support_agent_rounded, color: Color(0xFF486581)),
                    tooltip: "الدعم الفني",
                  ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
