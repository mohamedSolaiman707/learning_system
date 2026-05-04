import 'package:flutter/material.dart';
import 'package:iconly/iconly.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/services/database_service.dart';
import '../../../../core/models/session_model.dart';
import '../widgets/next_class_card.dart';
import '../widgets/upcoming_class_item.dart';
import '../../video_room/video_room_screen.dart';

class StudentHomeTab extends StatefulWidget {
  const StudentHomeTab({super.key});

  @override
  State<StudentHomeTab> createState() => _StudentHomeTabState();
}

class _StudentHomeTabState extends State<StudentHomeTab> {
  bool _isLoading = true;
  List<SessionModel> _sessions = [];

  @override
  void initState() {
    super.initState();
    _loadStudentData();
  }

  Future<void> _loadStudentData() async {
    setState(() => _isLoading = true);
    try {
      // هنا يمكن تطوير DatabaseService ليشمل جلب حصص الطالب المسجل فيها
      // حالياً سنحاكي جلب البيانات لتوضيح التصميم الاحترافي
      await Future.delayed(const Duration(seconds: 1));
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final profile = authProvider.profile;
    final userName = profile?['full_name'] ?? "الطالب";

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      body: _isLoading 
          ? _buildLoadingSkeleton()
          : RefreshIndicator(
              onRefresh: _loadStudentData,
              child: CustomScrollView(
                slivers: [
                  _buildSliverAppBar(userName),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(Responsive.isMobile(context) ? 16 : 30),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildWelcomeSection(userName),
                          const SizedBox(height: 30),
                          _buildNextClassSection(userName),
                          const SizedBox(height: 40),
                          _buildStatsAndProgress(),
                          const SizedBox(height: 40),
                          _buildUpcomingClassesHeader(),
                          const SizedBox(height: 15),
                          _buildUpcomingGrid(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSliverAppBar(String name) {
    return SliverAppBar(
      expandedHeight: 120,
      floating: true,
      pinned: true,
      backgroundColor: Colors.white,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsetsDirectional.only(start: 16, bottom: 16),
        title: Text(
          "الرئيسية",
          style: TextStyle(
            color: Colors.black.withOpacity(0.8),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      actions: [
        IconButton(
          onPressed: () {},
          icon: const Badge(child: Icon(IconlyLight.notification)),
        ),
        const SizedBox(width: 8),
        Padding(
          padding: const EdgeInsets.only(left: 16),
          child: CircleAvatar(
            backgroundColor: Colors.blue.withOpacity(0.1),
            child: Text(name[0].toUpperCase(), style: const TextStyle(color: Colors.blue)),
          ),
        ),
      ],
    );
  }

  Widget _buildWelcomeSection(String name) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "مرحباً بك مجدداً، $name 👋",
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const Text(
          "لديك حصتان اليوم، استعد جيداً!",
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildNextClassSection(String userName) {
    // محاكاة لحصة قادمة
    return NextClassCard(
      subject: "رياضيات - التفاضل والتكامل",
      teacher: "أ. محمد علي",
      startTime: "10:30 ص",
      isLive: true,
      onJoin: () {
        Navigator.push(context, MaterialPageRoute(
          builder: (context) => VideoRoomScreen(
            title: "بث مباشر: رياضيات",
            roomName: "math_101",
            userName: userName,
          ),
        ));
      },
    );
  }

  Widget _buildStatsAndProgress() {
    return Responsive(
      mobile: Column(
        children: [
          _buildStatItem("الحصص المكتملة", "12", Icons.check_circle, Colors.green),
          const SizedBox(height: 12),
          _buildStatItem("الساعات الدراسية", "24.5", Icons.timer, Colors.orange),
        ],
      ),
      desktop: Row(
        children: [
          Expanded(child: _buildStatItem("الحصص المكتملة", "12", Icons.check_circle, Colors.green)),
          const SizedBox(width: 20),
          Expanded(child: _buildStatItem("الساعات الدراسية", "24.5", Icons.timer, Colors.orange)),
          const SizedBox(width: 20),
          Expanded(child: _buildStatItem("المهام المنجزة", "85%", Icons.assignment_turned_in, Colors.blue)),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 15),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingClassesHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text("حصصك القادمة", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        TextButton(onPressed: () {}, child: const Text("عرض الكل")),
      ],
    );
  }

  Widget _buildUpcomingGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = Responsive.isDesktop(context) ? 3 : (Responsive.isTablet(context) ? 2 : 1);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            mainAxisExtent: 100,
          ),
          itemCount: 4,
          itemBuilder: (context, index) => const UpcomingClassItem(
            subject: "اللغة العربية",
            teacher: "د. سارة محمود",
            time: "04:00 م",
            duration: "60 دقيقة",
          ),
        );
      },
    );
  }

  Widget _buildLoadingSkeleton() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(height: 150, width: double.infinity, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24))),
            const SizedBox(height: 20),
            Row(children: List.generate(2, (i) => Expanded(child: Container(height: 100, margin: const EdgeInsets.all(5), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)))))),
            const SizedBox(height: 30),
            Container(height: 20, width: 150, color: Colors.white),
            const SizedBox(height: 20),
            ...List.generate(3, (i) => Container(height: 80, margin: const EdgeInsets.only(bottom: 12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)))),
          ],
        ),
      ),
    );
  }
}
