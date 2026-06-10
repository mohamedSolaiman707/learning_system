import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:animations/animations.dart';

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
    final isDesktop = Responsive.isDesktop(context);
    final isMobile = Responsive.isMobile(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: isMobile ? _buildAppBar() : null,
      drawer: isMobile
          ? Drawer(child: _buildSidebar(context))
          : null,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMobile)
            Container(
              width: isDesktop ? 280 : 100,
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
              child: _buildSidebar(context, isDrawer: false, isExpanded: isDesktop),
            ),
          Expanded(
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
                        padding: EdgeInsets.symmetric(
                          horizontal: isMobile ? 15.0 : 40.0,
                          vertical: 30.0,
                        ),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1400),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (!isMobile)
                                  _buildDesktopHeader(),
                                if (isMobile)
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
      title: const Text("لوحة التحكم", style: TextStyle(color: Colors.black, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
      iconTheme: const IconThemeData(color: Colors.black),
      actions: [
        IconButton(onPressed: _loadStats, icon: const Icon(Icons.refresh)),
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
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
            ),
            const Text(
              "إليك نظرة سريعة على ما يحدث في المنصة اليوم",
              style: TextStyle(fontSize: 16, color: Colors.grey, fontFamily: 'Cairo'),
            ),
          ],
        ),
        ElevatedButton.icon(
          onPressed: _loadStats,
          icon: const Icon(Icons.refresh, size: 20),
          label: const Text("تحديث البيانات", style: TextStyle(fontFamily: 'Cairo')),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            minimumSize: const Size(150, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
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
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
        ),
        Text(
          "آخر إحصائيات النظام",
          style: TextStyle(fontSize: 14, color: Colors.grey, fontFamily: 'Cairo'),
        ),
      ],
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 80, color: Colors.redAccent),
          const SizedBox(height: 16),
          Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontFamily: 'Cairo', fontSize: 18)),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadStats,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(200, 50),
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("إعادة المحاولة", style: TextStyle(fontFamily: 'Cairo')),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        bool isDesktop = Responsive.isDesktop(context);
        bool isTablet = Responsive.isTablet(context);
        
        int crossAxisCount = isDesktop ? 4 : (isTablet ? 2 : 1);
        double childAspectRatio = isDesktop ? 1.8 : 2.2;

        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 20,
          mainAxisSpacing: 20,
          childAspectRatio: childAspectRatio,
          children: [
            AdminStatCard(
              title: "إجمالي الطلاب",
              value: _totalStudents.toString(),
              icon: Icons.person_outline,
              color: Colors.blue,
            ),
            AdminStatCard(
              title: "الغرف النشطة",
              value: _activeRooms.toString(),
              icon: Icons.videocam_outlined,
              color: Colors.green,
            ),
            AdminStatCard(
              title: "إجمالي المعلمين",
              value: _totalTeachers.toString(),
              icon: Icons.person_outline,
              color: Colors.orange,
            ),
            AdminStatCard(
              title: "حصص اليوم",
              value: _todaySessions.toString(),
              icon: Icons.calendar_today_outlined,
              color: Colors.purple,
            ),
          ],
        );
      },
    );
  }

  Widget _buildChartSection() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "تحليلات الحضور",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
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
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "النشاطات الأخيرة",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
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
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
      ),
      subtitle: Text(time, style: const TextStyle(fontSize: 12, fontFamily: 'Cairo')),
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildSidebar(BuildContext context, {bool isDrawer = true, bool isExpanded = true}) {
    return Column(
      children: [
        const SizedBox(height: 50),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.school, size: 30, color: Colors.white),
        ),
        if (isExpanded) ...[
          const SizedBox(height: 15),
          const Text(
            "EduConnect",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
          ),
        ],
        const SizedBox(height: 40),
        _buildSidebarItem(Icons.bar_chart, "لوحة التحكم", true, isExpanded, () {}),
        _buildSidebarItem(
          Icons.person_outline,
          "المستخدمين",
          false,
          isExpanded,
          () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const UsersManagementScreen(),
            ),
          ),
        ),
        _buildSidebarItem(
          Icons.videocam_outlined,
          "الحصص",
          false,
          isExpanded,
          () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const SessionsManagementScreen(),
            ),
          ),
        ),
        _buildSidebarItem(
          Icons.settings_outlined,
          "الإعدادات",
          false,
          isExpanded,
          () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AdminSettingsScreen(),
            ),
          ),
        ),
        const Spacer(),
        _buildSidebarItem(
          Icons.logout,
          "خروج",
          false,
          isExpanded,
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
    bool isExpanded,
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
      title: isExpanded ? Text(
        title,
        style: TextStyle(
          fontFamily: 'Cairo',
          color: isSelected
              ? Colors.blue
              : (isDestructive ? Colors.red : Colors.black),
        ),
      ) : null,
      contentPadding: EdgeInsets.symmetric(horizontal: isExpanded ? 30 : 0),
      visualDensity: isExpanded ? VisualDensity.standard : VisualDensity.compact,
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
