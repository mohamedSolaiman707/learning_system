import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../core/services/database_service.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/services/attendance_pdf_service.dart';
import '../attendance/attendance_screen.dart';
import '../../../../core/utils/responsive.dart';

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
        
        final results = await Future.wait([
          db.getSessionEnrollments(sessionId),
          db.getAttendanceReportData(sessionId),
          db.getSessionQuizResults(sessionId),
        ]);

        final enrollments = results[0] as List;
        final attendance = results[1] as List;
        final quizzes = results[2] as List;

        final presentCount = attendance.where((a) => a['status'] != 'kicked').length;
        totalAttendance += presentCount;

        double avgQuizScore = 0;
        if (quizzes.isNotEmpty) {
          final correctAnswers = quizzes.where((q) => q['is_correct'] == true).length;
          avgQuizScore = (correctAnswers / quizzes.length) * 100;
        }

        reportsWithStats.add({
          'session': session,
          'presentCount': presentCount,
          'absentCount': (enrollments.length - presentCount) < 0 ? 0 : (enrollments.length - presentCount),
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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _downloadPdf(Map<String, dynamic> report) async {
    final session = report['session'];
    final enrollments = report['enrollments'] as List;
    final attendanceData = report['attendanceData'] as List;
    
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
        'present': attRecord != null && attRecord['status'] != 'kicked',
        'joined_at': attRecord?['joined_at'] ?? 'لم يحضر',
        'left_at': attRecord?['left_at'] ?? '---',
        'duration': attRecord?['total_duration_minutes'] ?? 0,
      });
    }

    for (var att in attendanceData) {
      if (!enrollments.any((e) => e['student_id'] == att['student_id'])) {
        final profile = att['profiles'] as Map<String, dynamic>?;
        fullStudentsReport.add({
          'name': "${profile?['full_name'] ?? 'مشارك'} (خارج القائمة)",
          'present': true,
          'joined_at': att['joined_at'] ?? '---',
          'left_at': att['left_at'] ?? '---',
          'duration': att['total_duration_minutes'] ?? 0,
        });
      }
    }

    final pdfService = AttendancePdfService();
    await pdfService.generateReport(
      subjectName: session['subject_name'] ?? session['title'] ?? 'حصة تعليمية',
      teacherName: Provider.of<AuthProvider>(context, listen: false).profile?['full_name'] ?? "المعلم",
      studentsData: fullStudentsReport,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("مركز التقارير الذكي", 
                style: TextStyle(color: Color(0xFF102A43), fontWeight: FontWeight.w900, fontSize: 18, fontFamily: 'Cairo')),
            Text("تحليل أداء الحصص والطلاب", 
                style: TextStyle(color: Colors.blueGrey.shade400, fontSize: 12, fontFamily: 'Cairo')),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF102A43)),
        actions: [
          IconButton(
            onPressed: _loadReports, 
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: const Color(0xFF102A43).withOpacity(0.05), shape: BoxShape.circle),
              child: const Icon(Icons.refresh_rounded, color: Color(0xFF102A43), size: 20)
            )
          ),
          const SizedBox(width: 20),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF102A43), strokeWidth: 2))
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(child: _buildSummaryHeader(isDesktop)),
                    SliverPadding(
                      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 30 : 20),
                      sliver: _reports.isEmpty 
                        ? SliverFillRemaining(child: _buildEmptyState())
                        : SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) => _buildReportCard(_reports[index], isDesktop),
                              childCount: _reports.length,
                            ),
                          ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 100)),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSummaryHeader(bool isDesktop) {
    return Container(
      padding: const EdgeInsets.all(35),
      margin: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF102A43), Color(0xFF243B53), Color(0xFF334E68)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(color: const Color(0xFF102A43).withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("الملخص العام للأداء", 
              style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
          const SizedBox(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem("إجمالي الحصص", _reports.length.toString(), Icons.video_collection_rounded, Colors.blueAccent),
              _buildStatItem("إجمالي الحضور", _totalAttendanceCount.toString(), Icons.people_alt_rounded, Colors.greenAccent),
              _buildStatItem("كفاءة الاختبارات", "${_calculateOverallQuizAvg()}%", Icons.quiz_rounded, Colors.orangeAccent),
            ],
          ),
        ],
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

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(15)),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 15),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, height: 1)),
        const SizedBox(height: 5),
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11, fontFamily: 'Cairo', fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildReportCard(Map<String, dynamic> report, bool isDesktop) {
    final session = report['session'];
    final startTime = DateTime.parse(session['start_time']);
    final double quizScore = report['avgQuizScore'];
    final bool isEnded = session['status'] == 'archived' || session['status'] == 'ended';

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: const Color(0xFFF0F4F8), borderRadius: BorderRadius.circular(15)),
                  child: const Icon(Icons.description_rounded, color: Color(0xFF102A43), size: 26),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(session['subject_name'] ?? session['title'] ?? 'بدون عنوان', 
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, fontFamily: 'Cairo', color: Color(0xFF102A43))),
                      Text(DateFormat('EEEE, d MMMM yyyy', 'ar_EG').format(startTime), 
                          style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade300, fontFamily: 'Cairo')),
                    ],
                  ),
                ),
                _buildStatusBadge(isEnded),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF0F4F8)),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildMetric("الحضور", "${report['presentCount']}", Colors.blue, Icons.person_add_rounded),
                    _buildMetric("الغياب", "${report['absentCount']}", Colors.redAccent, Icons.person_remove_rounded),
                    _buildMetric("درجة الكويز", "${quizScore.toInt()}%", Colors.orange, Icons.insights_rounded),
                  ],
                ),
                const SizedBox(height: 25),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _downloadPdf(report),
                        icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                        label: const Text("تصدير تقرير PDF", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF0F4F8),
                          foregroundColor: const Color(0xFF102A43),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                      ),
                    ),
                    const SizedBox(width: 15),
                    InkWell(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => AttendanceScreen(sessionId: session['id'], subjectName: session['subject_name'] ?? 'حصة تعليمية'))),
                      child: Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(color: const Color(0xFF102A43), borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
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

  Widget _buildStatusBadge(bool isEnded) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isEnded ? Colors.grey.shade100 : Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        isEnded ? "مكتملة" : "نشطة الآن",
        style: TextStyle(
          color: isEnded ? Colors.grey : Colors.green, 
          fontSize: 10, 
          fontWeight: FontWeight.w800,
          fontFamily: 'Cairo'
        ),
      ),
    );
  }

  Widget _buildMetric(String label, String value, Color color, IconData icon) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color.withOpacity(0.5)),
            const SizedBox(width: 6),
            Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 18)),
          ],
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: Colors.blueGrey.shade300, fontSize: 11, fontFamily: 'Cairo', fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(color: Colors.blueGrey.withOpacity(0.05), shape: BoxShape.circle),
            child: Icon(Icons.analytics_outlined, size: 60, color: Colors.blueGrey.shade200),
          ),
          const SizedBox(height: 20),
          const Text("لا توجد تقارير متاحة حالياً", 
            style: TextStyle(color: Colors.blueGrey, fontSize: 15, fontFamily: 'Cairo', fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
