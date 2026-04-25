import 'package:flutter/material.dart';
import 'package:iconly/iconly.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shimmer/shimmer.dart';
import 'widgets/admin_stat_card.dart';
import 'users_management_screen.dart';
import 'sessions_management_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;
  int _totalStudents = 0;
  int _totalTeachers = 0;
  int _activeRooms = 0;
  int _todaySessions = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final today = DateTime.now().toIso8601String().split('T')[0];

      final studentRes = await supabase.from('profiles').select().eq('role', 'student').count(CountOption.exact);
      final teacherRes = await supabase.from('profiles').select().eq('role', 'teacher').count(CountOption.exact);
      final roomRes = await supabase.from('rooms').select().eq('is_active', true).count(CountOption.exact);
      final sessionRes = await supabase.from('sessions').select().gte('start_time', '${today}T00:00:00').count(CountOption.exact);

      if (mounted) {
        setState(() {
          _totalStudents = studentRes.count;
          _totalTeachers = teacherRes.count;
          _activeRooms = roomRes.count;
          _todaySessions = sessionRes.count;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading admin stats: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isMobile = MediaQuery.of(context).size.width < 900;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: _buildAppBar(isMobile),
      drawer: isMobile ? _buildSidebar(context) : null,
      body: Row(
        children: [
          if (!isMobile)
            Container(
              width: 280,
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20)],
              ),
              child: _buildSidebar(context, isDrawer: false),
            ),
          Expanded(
            child: _isLoading 
                ? _buildLoadingSkeleton()
                : RefreshIndicator(
                    onRefresh: _loadStats,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(30.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeader(),
                          const SizedBox(height: 30),
                          _buildStatsGrid(),
                          const SizedBox(height: 40),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 2, child: _buildChartSection()),
                              if (!isMobile) const SizedBox(width: 30),
                              if (!isMobile) Expanded(child: _buildRecentActivity()),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isMobile) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: isMobile ? null : const SizedBox(),
      title: Text("لوحة التحكم", style: TextStyle(color: Colors.grey.shade800, fontWeight: FontWeight.bold)),
      actions: [
        IconButton(onPressed: _loadStats, icon: const Icon(IconlyLight.swap)),
        const SizedBox(width: 10),
        const CircleAvatar(radius: 18, backgroundColor: Colors.blue, child: Icon(IconlyBold.profile, size: 20, color: Colors.white)),
        const SizedBox(width: 20),
      ],
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("نظرة عامة على النظام", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1A1C1E))),
        Text("مرحباً بك مجدداً، إليك ما يحدث في المنصة اليوم", style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
      ],
    );
  }

  Widget _buildStatsGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = constraints.maxWidth > 1200 ? 4 : (constraints.maxWidth > 700 ? 2 : 1);
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 20,
          mainAxisSpacing: 20,
          childAspectRatio: 1.8,
          children: [
            AdminStatCard(title: "إجمالي الطلاب", value: _totalStudents.toString(), icon: IconlyLight.user_1, color: Colors.blue),
            AdminStatCard(title: "الغرف النشطة", value: _activeRooms.toString(), icon: IconlyLight.video, color: Colors.green),
            AdminStatCard(title: "إجمالي المعلمين", value: _totalTeachers.toString(), icon: IconlyLight.user_1, color: Colors.orange),
            AdminStatCard(title: "حصص اليوم", value: _todaySessions.toString(), icon: IconlyLight.calendar, color: Colors.purple),
          ],
        );
      },
    );
  }

  Widget _buildChartSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("إحصائيات الحضور الأسبوعي", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 30),
          SizedBox(
            height: 300,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: true, drawVerticalLine: false),
                titlesData: const FlTitlesData(show: true, rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)), topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false))),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: [const FlSpot(0, 3), const FlSpot(1, 4), const FlSpot(2, 3.5), const FlSpot(3, 5), const FlSpot(4, 4), const FlSpot(5, 6), const FlSpot(6, 4.5)],
                    isCurved: true,
                    color: Colors.blue,
                    barWidth: 4,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(show: true, color: Colors.blue.withOpacity(0.05)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivity() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("آخر النشاطات", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          _buildActivityItem("تم إنشاء حساب طالب جديد", "منذ 5 دقائق", IconlyLight.user_1, Colors.blue),
          _buildActivityItem("بدأت حصة الرياضيات", "منذ 12 دقيقة", IconlyLight.video, Colors.green),
          _buildActivityItem("تم تحديث جدول الامتحانات", "منذ ساعة", IconlyLight.document, Colors.orange),
        ],
      ),
    );
  }

  Widget _buildActivityItem(String title, String time, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, size: 18, color: color)),
          const SizedBox(width: 15),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)), Text(time, style: TextStyle(color: Colors.grey.shade500, fontSize: 12))])),
        ],
      ),
    );
  }

  Widget _buildSidebar(BuildContext context, {bool isDrawer = true}) {
    return Column(
      children: [
        if (isDrawer) const DrawerHeader(child: Center(child: Icon(Icons.school, size: 50, color: Colors.blue))),
        const SizedBox(height: 20),
        _buildSidebarItem(IconlyBold.chart, "لوحة التحكم", true, () {}),
        _buildSidebarItem(IconlyLight.user_1, "إدارة المستخدمين", false, () => Navigator.push(context, MaterialPageRoute(builder: (context) => const UsersManagementScreen()))),
        _buildSidebarItem(IconlyLight.video, "الجلسات والحصص", false, () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SessionsManagementScreen()))),
        _buildSidebarItem(IconlyLight.setting, "الإعدادات", false, () {}),
        const Spacer(),
        _buildSidebarItem(IconlyLight.logout, "تسجيل الخروج", false, () => supabase.auth.signOut().then((_) => Navigator.pushReplacementNamed(context, '/login')), isDestructive: true),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildSidebarItem(IconData icon, String title, bool isSelected, VoidCallback onTap, {bool isDestructive = false}) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: isSelected ? Colors.blue : (isDestructive ? Colors.red : Colors.grey)),
      title: Text(title, style: TextStyle(color: isSelected ? Colors.blue : (isDestructive ? Colors.red : Colors.black87), fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      selected: isSelected,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
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
            Container(height: 40, width: 300, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 30),
            Row(children: List.generate(4, (index) => Expanded(child: Container(margin: const EdgeInsets.only(right: 20), height: 120, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)))))),
          ],
        ),
      ),
    );
  }
}
