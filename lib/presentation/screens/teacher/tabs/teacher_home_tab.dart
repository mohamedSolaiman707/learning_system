import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconly/iconly.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart' as intl;
import 'package:shimmer/shimmer.dart';
import 'package:file_picker/file_picker.dart';

import '../../../../core/providers/auth_provider.dart';
import '../../../../core/services/database_service.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/models/session_model.dart';
import '../widgets/teacher_stat_card.dart';
import '../attendance/attendance_screen.dart';
import '../assignments/teacher_assignments_screen.dart';
import '../../video_room/video_room_screen.dart';

class TeacherHomeTab extends StatefulWidget {
  const TeacherHomeTab({super.key});

  @override
  State<TeacherHomeTab> createState() => _TeacherHomeTabState();
}

class _TeacherHomeTabState extends State<TeacherHomeTab> {
  bool _isLoading = true;
  List<SessionModel> _sessions = [];
  int _totalStudents = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      // محاكاة جلب البيانات عبر DatabaseService مستقبلاً
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
    final name = profile?['full_name'] ?? "المدرس";

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      body: _isLoading 
          ? _buildLoadingSkeleton()
          : RefreshIndicator(
              onRefresh: _loadData,
              child: CustomScrollView(
                slivers: [
                  _buildSliverAppBar(name),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(Responsive.isMobile(context) ? 16 : 30),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildWelcomeHeader(name),
                          const SizedBox(height: 24),
                          _buildStatsSection(),
                          const SizedBox(height: 32),
                          Responsive(
                            mobile: Column(
                              children: [
                                _buildCurrentSessionSection(name),
                                const SizedBox(height: 32),
                                _buildQuickActions(null), // تمرير الجلسة هنا
                              ],
                            ),
                            desktop: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 3, child: _buildCurrentSessionSection(name)),
                                const SizedBox(width: 30),
                                Expanded(flex: 2, child: _buildQuickActions(null)),
                              ],
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

  Widget _buildSliverAppBar(String name) {
    return SliverAppBar(
      expandedHeight: 100,
      floating: true,
      pinned: true,
      backgroundColor: Colors.white,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        title: Text("لوحة المدرس", style: TextStyle(color: Colors.black.withOpacity(0.8), fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: false,
      ),
      actions: [
        IconButton(onPressed: () {}, icon: const Badge(child: Icon(IconlyLight.notification))),
        const SizedBox(width: 15),
      ],
    );
  }

  Widget _buildWelcomeHeader(String name) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("أهلاً بك، 👋", style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
        Text("أ. $name", style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildStatsSection() {
    return Row(
      children: [
        Expanded(child: TeacherStatCard(title: "طلابك", value: "124", icon: IconlyLight.user_1, color: Colors.blue)),
        const SizedBox(width: 16),
        Expanded(child: TeacherStatCard(title: "حصص اليوم", value: "3", icon: IconlyLight.video, color: Colors.orange)),
        if (Responsive.isDesktop(context)) ...[
          const SizedBox(width: 16),
          Expanded(child: TeacherStatCard(title: "التقييم", value: "4.9", icon: IconlyLight.star, color: Colors.amber)),
        ]
      ],
    );
  }

  Widget _buildCurrentSessionSection(String teacherName) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("الحصة القادمة", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF0061FF), Color(0xFF00C6FF)]),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(16)),
                    child: const Icon(IconlyLight.video, color: Colors.white, size: 30),
                  ),
                  const SizedBox(width: 20),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("اللغة الإنجليزية - Unit 5", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                        Text("اليوم | 05:00 م - 06:30 م", style: TextStyle(color: Colors.white70, fontSize: 14)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(
                          builder: (context) => VideoRoomScreen(title: "بث مباشر", roomName: "english_5", userName: teacherName)
                        ));
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.blue,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text("ابدأ البث المباشر الآن", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions(SessionModel? session) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("إجراءات سريعة", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        _buildActionCard(IconlyLight.user_1, "تحضير الطلاب", Colors.orange, () {}),
        const SizedBox(height: 12),
        _buildActionCard(IconlyLight.document, "إضافة واجب", Colors.green, () {}),
        const SizedBox(height: 12),
        _buildActionCard(IconlyLight.folder, "المكتبة التعليمية", Colors.blue, () {}),
      ],
    );
  }

  Widget _buildActionCard(IconData icon, String title, Color color, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      ),
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
            ...List.generate(3, (i) => Container(height: 70, margin: const EdgeInsets.only(bottom: 12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)))),
          ],
        ),
      ),
    );
  }
}
