import 'package:flutter/material.dart';
import '../../../core/utils/responsive.dart';
import 'tabs/student_home_tab.dart';
import 'tabs/student_schedule_tab.dart';
import '../profile/profile_screen.dart';

class StudentMainLayout extends StatefulWidget {
  const StudentMainLayout({super.key});

  @override
  State<StudentMainLayout> createState() => _StudentMainLayoutState();
}

class _StudentMainLayoutState extends State<StudentMainLayout> {
  int _selectedIndex = 0;

  final List<Widget> _tabs = [
    const StudentHomeTab(),
    const StudentScheduleTab(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    bool isMobile = Responsive.isMobile(context);
    bool isDesktop = Responsive.isDesktop(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      body: Row(
        children: [
          if (!isMobile) _buildCustomSidebar(isDesktop),
          Expanded(
            child: Container(
              margin: isMobile ? EdgeInsets.zero : const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: isMobile 
                    ? BorderRadius.zero 
                    : BorderRadius.circular(32),
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
                borderRadius: isMobile 
                    ? BorderRadius.zero 
                    : BorderRadius.circular(32),
                child: _tabs[_selectedIndex],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: isMobile 
          ? _buildBottomBar()
          : null,
    );
  }

  Widget _buildCustomSidebar(bool isExpanded) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: isExpanded ? 280 : 100,
      color: const Color(0xFFF0F4F8),
      child: Column(
        children: [
          // Logo Section
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

          // Menu Items
          _sidebarItem(0, Icons.grid_view_rounded, Icons.grid_view_outlined, "لوحة التحكم", isExpanded),
          _sidebarItem(1, Icons.calendar_month_rounded, Icons.calendar_month_outlined, "الجدول الدراسي", isExpanded),
          _sidebarItem(2, Icons.person_rounded, Icons.person_outline_rounded, "الملف الشخصي", isExpanded),
          
          const Spacer(),
          
          // Support Section
          _sidebarItem(99, Icons.support_agent_rounded, Icons.support_agent_outlined, "الدعم الفني", isExpanded),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _sidebarItem(int index, IconData selectedIcon, IconData unselectedIcon, String label, bool isExpanded) {
    // التحقق من أن الـ index موجود في قائمة التابات
    bool isSelected = _selectedIndex == index;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        onTap: () {
          if (index == 99) {
             ScaffoldMessenger.of(context).showSnackBar(
               const SnackBar(content: Text("جاري تحويلك للدعم الفني...")),
             );
          } else {
            setState(() => _selectedIndex = index);
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(
            vertical: 16, 
            horizontal: isExpanded ? 20 : 0
          ),
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
              Icon(
                isSelected ? selectedIcon : unselectedIcon,
                color: isSelected ? Colors.white : const Color(0xFF486581),
                size: 24,
              ),
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
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined, color: Color(0xFF486581)),
            selectedIcon: Icon(Icons.grid_view_rounded, color: Color(0xFF102A43)),
            label: 'الرئيسية',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined, color: Color(0xFF486581)),
            selectedIcon: Icon(Icons.calendar_month_rounded, color: Color(0xFF102A43)),
            label: 'الجدول',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded, color: Color(0xFF486581)),
            selectedIcon: Icon(Icons.person_rounded, color: Color(0xFF102A43)),
            label: 'حسابي',
          ),
        ],
      ),
    );
  }
}
