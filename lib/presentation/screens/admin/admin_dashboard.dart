import 'package:flutter/material.dart';
import 'package:iconly/iconly.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'widgets/admin_stat_card.dart';
import 'users_management_screen.dart';

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
    setState(() => _isLoading = true);
    try {
      final today = DateTime.now().toIso8601String().split('T')[0];

      // جلب الإحصائيات باستخدام الطريقة الصحيحة في إصدار 2.x
      // نستخدم .count() ونقوم بطلب الـ response بالكامل للحصول على الـ count
      
      final studentRes = await supabase
          .from('profiles')
          .select()
          .eq('role', 'student')
          .count(CountOption.exact);

      final teacherRes = await supabase
          .from('profiles')
          .select()
          .eq('role', 'teacher')
          .count(CountOption.exact);

      final roomRes = await supabase
          .from('rooms')
          .select()
          .eq('is_active', true)
          .count(CountOption.exact);

      final sessionRes = await supabase
          .from('sessions')
          .select()
          .gte('start_time', '${today}T00:00:00')
          .count(CountOption.exact);

      setState(() {
        _totalStudents = studentRes.count;
        _totalTeachers = teacherRes.count;
        _activeRooms = roomRes.count;
        _todaySessions = sessionRes.count;
        _isLoading = false;
      });
    } catch (e) {
      print("Error loading admin stats: $e");
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isMobile = MediaQuery.of(context).size.width < 800;

    return Scaffold(
      appBar: AppBar(
        title: const Text("لوحة التحكم"),
        actions: [
          IconButton(
            onPressed: _loadStats,
            icon: const Icon(IconlyLight.arrow_right_2),
          ),
          IconButton(
            onPressed: () => supabase.auth.signOut().then((_) => Navigator.pushReplacementNamed(context, '/login')),
            icon: const Icon(IconlyLight.logout),
          ),
        ],
      ),
      drawer: isMobile ? _buildDrawer(context) : null,
      body: Row(
        children: [
          if (!isMobile)
            Container(
              width: 250,
              color: Colors.white,
              child: _buildDrawer(context, isDrawer: false),
            ),
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "نظرة عامة",
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 24),
                      Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: [
                          AdminStatCard(
                            title: "إجمالي الطلاب",
                            value: _totalStudents.toString(),
                            icon: IconlyLight.user_1,
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
                            icon: IconlyLight.user,
                            color: Colors.orange,
                          ),
                          AdminStatCard(
                            title: "حصص اليوم",
                            value: _todaySessions.toString(),
                            icon: IconlyLight.calendar,
                            color: Colors.purple,
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      const Text(
                        "إحصائيات الحضور الأسبوعي",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      _buildChart(),
                    ],
                  ),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildChart() {
    return Container(
      height: 300,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: true),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: [
                const FlSpot(0, 3),
                const FlSpot(1, 4),
                const FlSpot(2, 3.5),
                const FlSpot(3, 5),
                const FlSpot(4, 4),
                const FlSpot(5, 6),
              ],
              isCurved: true,
              color: Colors.blue,
              barWidth: 4,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: Colors.blue.withOpacity(0.1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context, {bool isDrawer = true}) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        if (isDrawer)
          const DrawerHeader(
            decoration: BoxDecoration(color: Colors.blue),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.school, color: Colors.white, size: 48),
                SizedBox(height: 10),
                Text("نظام الإدارة", style: TextStyle(color: Colors.white, fontSize: 18)),
              ],
            ),
          ),
        ListTile(
          leading: const Icon(IconlyLight.chart),
          title: const Text("لوحة التحكم"),
          onTap: () {},
          selected: true,
        ),
        ListTile(
          leading: const Icon(IconlyLight.user_1),
          title: const Text("إدارة المستخدمين"),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const UsersManagementScreen()),
            );
          },
        ),
        ListTile(
          leading: const Icon(IconlyLight.setting),
          title: const Text("الإعدادات"),
          onTap: () {},
        ),
        const Divider(),
        ListTile(
          leading: const Icon(IconlyLight.logout, color: Colors.red),
          title: const Text("تسجيل الخروج", style: TextStyle(color: Colors.red)),
          onTap: () {
            supabase.auth.signOut().then((_) => Navigator.pushReplacementNamed(context, '/login'));
          },
        ),
      ],
    );
  }
}
