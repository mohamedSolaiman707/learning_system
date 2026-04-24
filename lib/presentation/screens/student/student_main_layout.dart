import 'package:flutter/material.dart';
import 'package:iconly/iconly.dart';
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
    return Scaffold(
      body: _tabs[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(IconlyLight.home),
            selectedIcon: Icon(IconlyBold.home),
            label: 'الرئيسية',
          ),
          NavigationDestination(
            icon: Icon(IconlyLight.calendar),
            selectedIcon: Icon(IconlyBold.calendar),
            label: 'الجدول',
          ),
          NavigationDestination(
            icon: Icon(IconlyLight.profile),
            selectedIcon: Icon(IconlyBold.profile),
            label: 'حسابي',
          ),
        ],
      ),
    );
  }
}
