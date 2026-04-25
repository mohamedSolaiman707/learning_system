import 'package:flutter/material.dart';
import 'package:iconly/iconly.dart';
import 'tabs/teacher_home_tab.dart';
import 'tabs/teacher_schedule_tab.dart'; // استدعاء ملف جدول المدرس الجديد
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
    const TeacherScheduleTab(), // تم التغيير هنا لاستخدام كلاس المدرس
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _tabs,
      ),
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
            label: 'جدولي',
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
