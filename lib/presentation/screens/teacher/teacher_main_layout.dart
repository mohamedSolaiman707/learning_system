import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/providers/auth_provider.dart';
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

  final List<({IconData icon, IconData selectedIcon, String label})> _navItems = [
    (icon: Icons.grid_view_outlined, selectedIcon: Icons.grid_view_rounded, label: 'الرئيسية'),
    (icon: Icons.calendar_today_outlined, selectedIcon: Icons.calendar_today_rounded, label: 'جدولي'),
    (icon: Icons.person_outline_rounded, selectedIcon: Icons.person_rounded, label: 'حسابي'),
  ];

  Future<void> _launchSupport() async {
    final Uri whatsappUri = Uri.parse("https://wa.me/201014250577");
    try {
      if (await canLaunchUrl(whatsappUri)) {
        await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    bool isMobile = Responsive.isMobile(context);
    bool isDesktop = Responsive.isDesktop(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8), 
      body: Row(
        children: [
          if (!isMobile) _buildDesktopSidebar(isDesktop),
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
                child: IndexedStack(
                  index: _selectedIndex,
                  children: _tabs,
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: isMobile
          ? NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (index) => setState(() => _selectedIndex = index),
              destinations: _navItems.map((d) => NavigationDestination(
                icon: Icon(d.icon),
                selectedIcon: Icon(d.selectedIcon),
                label: d.label,
              )).toList(),
            )
          : null,
    );
  }

  Widget _buildDesktopSidebar(bool isExpanded) {
    final auth = Provider.of<AuthProvider>(context);
    final name = auth.profile?['full_name'] ?? "المعلم";

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: isExpanded ? 280 : 100,
      color: const Color(0xFFF0F4F8),
      padding: const EdgeInsets.symmetric(vertical: 30),
      child: Column(
        children: [
          _buildLogo(isExpanded),
          const SizedBox(height: 30),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: List.generate(_navItems.length, (index) => _buildNavTile(index, isExpanded)),
            ),
          ),
          const Spacer(),
          _buildBottomSidebarSection(isExpanded, name),
        ],
      ),
    );
  }

  Widget _buildLogo(bool isExpanded) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isExpanded ? 24 : 0),
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
            const Text(
              "EduConnect",
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: Color(0xFF102A43),
              ),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildNavTile(int index, bool isExpanded) {
    final bool isSelected = _selectedIndex == index;
    final item = _navItems[index];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _selectedIndex = index),
          splashColor: Colors.transparent,
          hoverColor: Colors.transparent,
          highlightColor: Colors.transparent,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.symmetric(
              horizontal: isExpanded ? 20 : 0,
              vertical: 16,
            ),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF102A43) : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              boxShadow: isSelected ? [
                BoxShadow(
                  color: const Color(0xFF102A43).withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ] : [],
            ),
            child: Row(
              mainAxisAlignment: isExpanded ? MainAxisAlignment.start : MainAxisAlignment.center,
              children: [
                Icon(
                  isSelected ? item.selectedIcon : item.icon,
                  color: isSelected ? Colors.white : const Color(0xFF486581),
                  size: 24,
                ),
                if (isExpanded) ...[
                  const SizedBox(width: 16),
                  Text(
                    item.label,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 15,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      color: isSelected ? Colors.white : const Color(0xFF486581),
                    ),
                  ),
                ]
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomSidebarSection(bool isExpanded, String name) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _launchSupport,
              hoverColor: Colors.black.withOpacity(0.02),
              splashColor: Colors.black.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                child: Row(
                  mainAxisAlignment: isExpanded ? MainAxisAlignment.start : MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.support_agent_rounded, color: Color(0xFF486581), size: 24),
                    if (isExpanded) ...[
                      const SizedBox(width: 16),
                      const Text("الدعم الفني", style: TextStyle(color: Color(0xFF486581), fontWeight: FontWeight.w600, fontFamily: 'Cairo')),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}
