import 'package:flutter/material.dart';
import 'package:iconly/iconly.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../core/services/database_service.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/services/attendance_pdf_service.dart';
import '../attendance/attendance_screen.dart';

class TeacherReportsScreen extends StatefulWidget {
  const TeacherReportsScreen({super.key});

  @override
  State<TeacherReportsScreen> createState() => _TeacherReportsScreenState();
}

class _TeacherReportsScreenState extends State<TeacherReportsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _reports = [];
  int _totalAttendanceCount = 0;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() => _isLoading = true);
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final db = Provider.of<DatabaseService>(context, listen: false);
      
      final teacherSessions = await db.getTeacherSessionsAll(auth.user!.id);
      
      List<Map<String, dynamic>> reportsWithStats = [];
      int totalAttendance = 0;

      for (var session in teacherSessions) {
        final sessionId = session['id'];
        
        // جلب البيانات بشكل متوازي لسرعة الأداء
        final results = await Future.wait([
          db.getSessionEnrollments(sessionId),
          db.getAttendanceReportData(sessionId),
          db.getSessionQuizResults(sessionId),
        ]);

        final enrollments = results[0] as List;
        final attendance = results[1] as List;
        final quizzes = results[2] as List;

        final presentCount = attendance.where((a) => a['status'] == 'present').length;
        totalAttendance += presentCount;

        // حساب متوسط درجات الاختبارات
        double avgQuizScore = 0;
        if (quizzes.isNotEmpty) {
          final correctAnswers = quizzes.where((q) => q['is_correct'] == true).length;
          avgQuizScore = (correctAnswers / quizzes.length) * 100;
        }

        reportsWithStats.add({
          'session': session,
          'presentCount': presentCount,
          'absentCount': enrollments.length - presentCount,
          'totalEnrolled': enrollments.length,
          'avgQuizScore': avgQuizScore,
          'attendanceData': attendance,
          'enrollments': enrollments,
        });
      }

      setState(() {
        _reports = reportsWithStats;
        _totalAttendanceCount = totalAttendance;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error loading reports: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _downloadPdf(Map<String, dynamic> report) async {
    final session = report['session'];
    final enrollments = report['enrollments'] as List;
    final attendanceData = report['attendanceData'] as List;
    
    // بناء قائمة الطلاب الشاملة (حاضر وغائب) للتقرير
    final List<Map<String, dynamic>> fullStudentsReport = [];
    
    for (var enrollment in enrollments) {
      final studentId = enrollment['student_id'];
      final profile = enrollment['profiles'] as Map<String, dynamic>?;
      
      final attRecord = attendanceData.firstWhere(
        (a) => a['student_id'] == studentId, 
        orElse: () => null
      );

      fullStudentsReport.add({
        'name': profile?['full_name'] ?? "طالب غير معروف",
        'present': attRecord != null && attRecord['status'] == 'present',
        'joined_at': attRecord?['joined_at'],
        'left_at': attRecord?['left_at'],
        'duration': attRecord?['total_duration_minutes'],
      });
    }

    // إضافة الطلاب الذين حضروا ولم يكونوا مسجلين (زوار)
    for (var att in attendanceData) {
      if (!enrollments.any((e) => e['student_id'] == att['student_id'])) {
        final profile = att['profiles'] as Map<String, dynamic>?;
        fullStudentsReport.add({
          'name': "${profile?['full_name'] ?? 'زائر'} (غير مسجل)",
          'present': true,
          'joined_at': att['joined_at'],
          'left_at': att['left_at'],
          'duration': att['total_duration_minutes'],
        });
      }
    }

    final pdfService = AttendancePdfService();
    await pdfService.generateReport(
      subjectName: session['subject_name'],
      teacherName: Provider.of<AuthProvider>(context, listen: false).profile?['full_name'] ?? "المدرس",
      studentsData: fullStudentsReport,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: const Text("مركز التقارير والإحصاء", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                _buildSummaryHeader(),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: _reports.isEmpty 
                    ? SliverToBoxAdapter(child: _buildEmptyState())
                    : SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => _buildReportCard(_reports[index]),
                          childCount: _reports.length,
                        ),
                      ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
    );
  }

  Widget _buildSummaryHeader() {
    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.all(24),
        margin: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF2E3192), Color(0xFF1BFFFF)]),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))],
        ),
        child: Column(
          children: [
            const Text("الملخص العام للأداء", style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem("إجمالي الحصص", _reports.length.toString(), Icons.video_collection_rounded),
                _buildStatItem("إجمالي الحضور", _totalAttendanceCount.toString(), Icons.people_alt_rounded),
                _buildStatItem("كفاءة الاختبارات", "${_calculateOverallQuizAvg()}%", Icons.quiz_rounded),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _calculateOverallQuizAvg() {
    if (_reports.isEmpty) return "0";
    double sum = 0;
    int count = 0;
    for (var r in _reports) {
      if (r['avgQuizScore'] > 0) {
        sum += r['avgQuizScore'];
        count++;
      }
    }
    return count == 0 ? "0" : (sum / count).toStringAsFixed(0);
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
      ],
    );
  }

  Widget _buildReportCard(Map<String, dynamic> report) {
    final session = report['session'];
    final startTime = DateTime.parse(session['start_time']);
    final double quizScore = report['avgQuizScore'];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            leading: CircleAvatar(
              backgroundColor: Colors.blue.shade50,
              child: const Icon(IconlyBold.document, color: Colors.blue, size: 20),
            ),
            title: Text(session['subject_name'], style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(DateFormat('EEEE, d MMMM').format(startTime), style: const TextStyle(fontSize: 12)),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: session['status'] == 'ended' ? Colors.grey.shade100 : Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                session['status'] == 'ended' ? "منتهية" : "نشطة",
                style: TextStyle(color: session['status'] == 'ended' ? Colors.grey : Colors.green, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              children: [
                Row(
                  children: [
                    _buildMetric("الحضور", "${report['presentCount']}/${report['totalEnrolled']}", Colors.blue),
                    _buildMetric("الغياب", "${report['absentCount']}", Colors.red),
                    _buildMetric("درجة الكويز", "${quizScore.toInt()}%", Colors.orange),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _downloadPdf(report),
                        icon: const Icon(Icons.picture_as_pdf, size: 18),
                        label: const Text("تقرير الحضور PDF"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent.shade400,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    InkWell(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => AttendanceScreen(sessionId: session['id'], subjectName: session['subject_name']))),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.open_in_new, color: Colors.blue, size: 20),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetric(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 60),
          Icon(IconlyLight.chart, size: 80, color: Colors.grey.shade200),
          const SizedBox(height: 20),
          const Text("لا توجد بيانات كافية للتقارير", style: TextStyle(color: Colors.grey, fontSize: 16, fontWeight: FontWeight.bold)),
          const Text("ابدأ حصصك ليتم تجميع البيانات هنا", style: TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }
}
