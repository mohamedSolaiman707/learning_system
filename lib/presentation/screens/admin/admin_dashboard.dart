import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:animations/animations.dart';
import 'package:flutter_iconly/flutter_iconly.dart'; // التعديل هنا

import '../../../core/providers/auth_provider.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/services/database_service.dart';
import '../../../core/utils/responsive.dart';
import 'admin_settings_screen.dart';
import 'widgets/admin_stat_card.dart';
import 'users_management_screen.dart';
import 'sessions_management_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  String? _errorMessage;
  int _totalStudents = 0;
  int _totalTeachers = 0;
  int _activeRooms = 0;
  int _todaySessions = 0;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _loadStats();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final dbService = Provider.of<DatabaseService>(context, listen: false);
      final stats = await dbService.getAdminStats();

      if (mounted) {
        setState(() {
          _totalStudents = stats['totalStudents'] ?? 0;
          _totalTeachers = stats['totalTeachers'] ?? 0;
          _activeRooms = stats['activeRooms'] ?? 0;
          _todaySessions = stats['todaySessions'] ?? 0;
          _isLoading = false;
        });
        _animationController.forward(from: 0);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage =
              "حدث خطأ أثناء تحميل البيانات. يرجى المحاولة مرة أخرى.";
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: Responsive.isMobile(context) ? _buildAppBar() : null,
      drawer: Responsive.isMobile(context)
          ? Drawer(child: _buildSidebar(context))
          : null,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!Responsive.isMobile(context))
            Expanded(
              flex: 1,
              child: Container(
                height: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: _buildSidebar(context, isDrawer: false),
              ),
            ),
          Expanded(
            flex: 5,
            child: PageTransitionSwitcher(
              transitionBuilder: (child, primaryAnimation, secondaryAnimation) {
                return FadeThroughTransition(
                  animation: primaryAnimation,
                  secondaryAnimation: secondaryAnimation,
                  child: child,
                );
              },
              child: _isLoading
                  ? _buildLoadingSkeleton()
                  : _errorMessage != null
                  ? _buildErrorView()
                  : RefreshIndicator(
                      onRefresh: _loadStats,
                      child: SingleChildScrollView(
                        padding: EdgeInsets.all(
                          Responsive.isMobile(context) ? 15.0 : 30.0,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!Responsive.isMobile(context))
                              _buildDesktopHeader(),
                            if (Responsive.isMobile(context))
                              _buildMobileHeader(),
                            const SizedBox(height: 30),
                            FadeTransition(
                              opacity: _animationController,
                              child: SlideTransition(
                                position:
                                    Tween<Offset>(
                                      begin: const Offset(0, 0.1),
                                      end: Offset.zero,
                                    ).animate(
                                      CurvedAnimation(
                                        parent: _animationController,
                                        curve: Curves.easeOut,
                                      ),
                                    ),
                                child: _buildStatsGrid(),
                              ),
                            ),
                            const SizedBox(height: 40),
                            Responsive(
                              mobile: Column(
                                children: [
                                  _buildChartSection(),
                                  const SizedBox(height: 30),
                                  _buildRecentActivity(),
                                ],
                              ),
                              desktop: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: _buildChartSection(),
                                  ),
                                  const SizedBox(width: 30),
                                  Expanded(child: _buildRecentActivity()),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      title: const Text("لوحة التحكم"),
      actions: [
        IconButton(onPressed: _loadStats, icon: const Icon(IconlyLight.swap)),
        const SizedBox(width: 15),
      ],
    );
  }

  Widget _buildDesktopHeader() {
    final profile = Provider.of<AuthProvider>(context).profile;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "مرحباً، ${profile?['full_name'] ?? 'المسؤول'}",
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const Text(
              "إليك نظرة سريعة على ما يحدث في المنصة اليوم",
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
        ElevatedButton.icon(
          onPressed: _loadStats,
          icon: const Icon(IconlyLight.swap, size: 20),
          label: const Text("تحديث البيانات"),
          style: ElevatedButton.styleFrom(minimumSize: const Size(150, 50)),
        ),
      ],
    );
  }

  Widget _buildMobileHeader() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "نظرة عامة",
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        Text(
          "آخر إحصائيات النظام",
          style: TextStyle(fontSize: 14, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(IconlyLight.dangerCircle, size: 60, color: Colors.red),
          const SizedBox(height: 16),
          Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadStats,
            style: ElevatedButton.styleFrom(minimumSize: const Size(200, 50)),
            child: const Text("إعادة المحاولة"),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = Responsive.isDesktop(context)
            ? 4
            : (Responsive.isTablet(context) ? 2 : 1);
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 20,
          mainAxisSpacing: 20,
          childAspectRatio: Responsive.isDesktop(context) ? 1.5 : 2.0,
          children: [
            AdminStatCard(
              title: "إجمالي الطلاب",
              value: _totalStudents.toString(),
              icon: IconlyLight.user2,
              color: Colors.blue,
            ),
            AdminStatCard(
              title: "الغرف النشطة",
              value: _activeRooms.toString(),
              icon: IconlyLight.video,
              color: Colors.green,
            ),
            AdminStatCard(
              title: "إجمالي المعلمين",
              value: _totalTeachers.toString(),
              icon: IconlyLight.user2,
              color: Colors.orange,
            ),
            AdminStatCard(
              title: "حصص اليوم",
              value: _todaySessions.toString(),
              icon: IconlyLight.calendar,
              color: Colors.purple,
            ),
          ],
        );
      },
    );
  }

  Widget _buildChartSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "تحليلات الحضور",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 30),
            SizedBox(
              height: 300,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: const FlTitlesData(
                    show: true,
                    rightTitles: AxisTitles(),
                    topTitles: AxisTitles(),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: [
                        const FlSpot(0, 3),
                        const FlSpot(1, 4),
                        const FlSpot(2, 5),
                        const FlSpot(3, 4),
                        const FlSpot(4, 7),
                        const FlSpot(5, 6),
                      ],
                      isCurved: true,
                      color: Colors.blue,
                      barWidth: 4,
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.blue.withOpacity(0.1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivity() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "النشاطات الأخيرة",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            _buildActivityItem(
              "تم تسجيل طالب جديد",
              "منذ 10 دقائق",
              Icons.person_add,
              Colors.blue,
            ),
            _buildActivityItem(
              "بدأت حصة جديدة",
              "منذ 15 دقيقة",
              Icons.video_call,
              Colors.green,
            ),
            _buildActivityItem(
              "تم رفع ملف جديد",
              "منذ ساعة",
              Icons.file_present,
              Colors.orange,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityItem(
    String title,
    String time,
    IconData icon,
    Color color,
  ) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withOpacity(0.1),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
      ),
      subtitle: Text(time, style: const TextStyle(fontSize: 12)),
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildSidebar(BuildContext context, {bool isDrawer = true}) {
    return Column(
      children: [
        const SizedBox(height: 60),
        const Icon(Icons.school, size: 60, color: Colors.blue),
        const SizedBox(height: 10),
        const Text(
          "EduConnect",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 40),
        _buildSidebarItem(IconlyBold.chart, "لوحة التحكم", true, () {}),
        _buildSidebarItem(
          IconlyLight.user2,
          "المستخدمين",
          false,
          () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const UsersManagementScreen(),
            ),
          ),
        ),
        _buildSidebarItem(
          IconlyLight.video,
          "الحصص",
          false,
          () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const SessionsManagementScreen(),
            ),
          ),
        ),
        _buildSidebarItem(
          IconlyLight.setting,
          "الإعدادات",
          false,
          () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AdminSettingsScreen(),
            ),
          ),
        ),
        const Spacer(),
        _buildSidebarItem(
          IconlyLight.logout,
          "خروج",
          false,
          (){
            Provider.of<AuthProvider>(context, listen: false).logout();
            Navigator.pushReplacementNamed(context, AppRoutes.login);
          },
          isDestructive: true,
        ),
        const SizedBox(height: 30),
      ],
    );
  }

  Widget _buildSidebarItem(
    IconData icon,
    String title,
    bool isSelected,
    VoidCallback onTap, {
    bool isDestructive = false,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Icon(
        icon,
        color: isSelected
            ? Colors.blue
            : (isDestructive ? Colors.red : Colors.grey),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected
              ? Colors.blue
              : (isDestructive ? Colors.red : Colors.black),
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 30),
    );
  }

  Widget _buildLoadingSkeleton() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(30),
        child: Column(
          children: [
            Row(
              children: [
                Container(width: 200, height: 30, color: Colors.white),
              ],
            ),
            const SizedBox(height: 30),
            Row(
              children: List.generate(
                4,
                (i) => Expanded(
                  child: Container(
                    height: 120,
                    margin: const EdgeInsets.only(right: 20),
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
