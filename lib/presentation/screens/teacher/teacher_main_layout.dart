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
      backgroundColor: const Color(0xFFF8F9FB),
      body: Row(
        children: [
          if (!isMobile) _buildDesktopSidebar(isDesktop),
          Expanded(
            child: Container(
              margin: EdgeInsets.only(
                top: isMobile ? 0 : 15,
                right: isMobile ? 0 : 15,
                bottom: isMobile ? 0 : 15,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: isMobile ? BorderRadius.zero : const BorderRadius.only(
                  topRight: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
                boxShadow: [
                  if (!isMobile)
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 20,
                      offset: const Offset(-5, 0),
                    ),
                ],
              ),
              child: ClipRRect(
                borderRadius: isMobile ? BorderRadius.zero : const BorderRadius.only(
                  topRight: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
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
          ? Container(
              decoration: BoxDecoration(
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
              ),
              child: NavigationBar(
                elevation: 0,
                backgroundColor: Colors.white,
                indicatorColor: const Color(0xFF102A43).withOpacity(0.1),
                selectedIndex: _selectedIndex,
                onDestinationSelected: (index) => setState(() => _selectedIndex = index),
                destinations: _navItems.map((d) => NavigationDestination(
                  icon: Icon(d.icon, color: Colors.blueGrey),
                  selectedIcon: Icon(d.selectedIcon, color: const Color(0xFF102A43)),
                  label: d.label,
                )).toList(),
              ),
            )
          : null,
    );
  }

  Widget _buildDesktopSidebar(bool isExpanded) {
    final auth = Provider.of<AuthProvider>(context);
    final name = auth.profile?['full_name'] ?? "المعلم";

    return Container(
      width: isExpanded ? 280 : 100,
      color: const Color(0xFFF8F9FB),
      padding: const EdgeInsets.symmetric(vertical: 30),
      child: Column(
        children: [
          // Logo Section
          _buildLogo(isExpanded),
          const SizedBox(height: 50),

          // Navigation Section
          Expanded(
            child: Column(
              children: List.generate(_navItems.length, (index) {
                return _buildNavTile(index, isExpanded);
              }),
            ),
          ),

          // Bottom Section (Profile Summary & Support)
          _buildBottomSidebarSection(isExpanded, name),
        ],
      ),
    );
  }

  Widget _buildLogo(bool isExpanded) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isExpanded ? 24 : 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF102A43), Color(0xFF243B53)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF102A43).withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: const Icon(Icons.school_rounded, color: Colors.white, size: 24),
          ),
          if (isExpanded) ...[
            const SizedBox(width: 15),
            const Text(
              "EduConnect",
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: Color(0xFF102A43),
                letterSpacing: 0.5,
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
      padding: EdgeInsets.symmetric(horizontal: isExpanded ? 16 : 12, vertical: 4),
      child: InkWell(
        onTap: () => setState(() => _selectedIndex = index),
        borderRadius: BorderRadius.circular(15),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: EdgeInsets.symmetric(
            horizontal: isExpanded ? 16 : 0,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              if (isSelected)
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
            ],
          ),
          child: Row(
            mainAxisAlignment: isExpanded ? MainAxisAlignment.start : MainAxisAlignment.center,
            children: [
              Icon(
                isSelected ? item.selectedIcon : item.icon,
                color: isSelected ? const Color(0xFF102A43) : Colors.blueGrey.shade400,
                size: 24,
              ),
              if (isExpanded) ...[
                const SizedBox(width: 15),
                Text(
                  item.label,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 15,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? const Color(0xFF102A43) : Colors.blueGrey.shade600,
                  ),
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomSidebarSection(bool isExpanded, String name) {
    return Column(
      children: [
        // Support Button
        Padding(
          padding: EdgeInsets.symmetric(horizontal: isExpanded ? 16 : 12),
          child: ListTile(
            onTap: _launchSupport,
            contentPadding: EdgeInsets.symmetric(horizontal: isExpanded ? 16 : 0),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            leading: Icon(
              Icons.headset_mic_outlined,
              color: Colors.blueGrey.shade400,
              size: 22,
            ),
            title: isExpanded
                ? Text(
                    "الدعم الفني",
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 14,
                      color: Colors.blueGrey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  )
                : null,
            visualDensity: isExpanded ? VisualDensity.standard : VisualDensity.compact,
          ),
        ),
        const SizedBox(height: 10),
        // Divider
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Divider(color: Colors.blueGrey.withOpacity(0.1)),
        ),
        const SizedBox(height: 10),
        // Mini Profile
        if (isExpanded)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF102A43).withOpacity(0.03),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: const Color(0xFF102A43),
                    child: Text(
                      name[0].toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF102A43),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const Text(
                          "معلم معتمد",
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 10,
                            color: Colors.blueGrey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xFF102A43).withOpacity(0.1),
            child: Text(
              name[0].toUpperCase(),
              style: const TextStyle(color: Color(0xFF102A43), fontWeight: FontWeight.bold),
            ),
          ),
      ],
    );
  }
}
