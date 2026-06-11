import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/attendance_pdf_service.dart';
import '../../../../core/utils/responsive.dart';

class AttendanceScreen extends StatefulWidget {
  final String sessionId;
  final String subjectName;
  final String? teacherName;

  const AttendanceScreen({
    super.key,
    required this.sessionId,
    required this.subjectName,
    this.teacherName,
  });

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _students = [];

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    setState(() => _isLoading = true);
    try {
      final enrollmentsRes = await supabase
          .from('enrollments')
          .select('student_id, profiles:student_id(full_name)')
          .eq('session_id', widget.sessionId);

      final attendanceRes = await supabase
          .from('attendance')
          .select('student_id, status, joined_at, left_at, total_duration_minutes, profiles:student_id(full_name)')
          .eq('session_id', widget.sessionId);

      final List<dynamic> enrollments = enrollmentsRes as List;
      final List<dynamic> attendanceList = attendanceRes as List;

      final Map<String, Map<String, dynamic>> studentsMap = {};

      for (var e in enrollments) {
        final studentId = e['student_id'];
        final profile = e['profiles'] as Map<String, dynamic>?;
        studentsMap[studentId] = {
          'id': studentId,
          'name': profile?['full_name'] ?? "طالب غير معروف",
          'present': false,
          'joined_at': null,
          'left_at': null,
          'duration': null,
          'isAutoMarked': false,
        };
      }

      for (var a in attendanceList) {
        final studentId = a['student_id'];
        final profile = a['profiles'] as Map<String, dynamic>?;
        
        if (studentsMap.containsKey(studentId)) {
          studentsMap[studentId]!['present'] = a['status'] == 'present';
          studentsMap[studentId]!['joined_at'] = a['joined_at'];
          studentsMap[studentId]!['left_at'] = a['left_at'];
          studentsMap[studentId]!['duration'] = a['total_duration_minutes'];
          studentsMap[studentId]!['isAutoMarked'] = true;
        } else {
          studentsMap[studentId] = {
            'id': studentId,
            'name': profile?['full_name'] ?? "طالب زائر",
            'present': a['status'] == 'present',
            'joined_at': a['joined_at'],
            'left_at': a['left_at'],
            'duration': a['total_duration_minutes'],
            'isAutoMarked': true,
          };
        }
      }

      setState(() {
        _students = studentsMap.values.toList();
        _students.sort((a, b) {
          if (a['present'] != b['present']) return b['present'] ? 1 : -1;
          return a['name'].compareTo(b['name']);
        });
      });
      
    } catch (e) {
      debugPrint("Attendance Load Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _exportToPdf() async {
    if (_students.isEmpty) return;
    
    setState(() => _isLoading = true);
    try {
      final pdfService = AttendancePdfService();
      await pdfService.generateReport(
        subjectName: widget.subjectName,
        teacherName: widget.teacherName ?? "مدرس المادة",
        studentsData: _students,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("خطأ أثناء إنشاء ملف PDF: $e", style: const TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveAttendance() async {
    if (_students.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      final List<Map<String, dynamic>> attendanceData = _students.map((s) => {
        'session_id': widget.sessionId,
        'student_id': s['id'],
        'status': s['present'] ? 'present' : 'absent',
      }).toList();

      await supabase.from('attendance').upsert(attendanceData, onConflict: 'session_id,student_id');
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ كشف الحضور بنجاح ✅', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.green));
      Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ في الحفظ: $e', style: const TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    int presentCount = _students.where((s) => s['present'] == true).length;
    int total = _students.length;
    final bool isDesktop = Responsive.isDesktop(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("كشف الحضور والغياب", style: const TextStyle(color: Color(0xFF102A43), fontWeight: FontWeight.w900, fontSize: 18, fontFamily: 'Cairo')),
            Text(widget.subjectName, style: TextStyle(color: Colors.blueGrey.shade400, fontSize: 12, fontFamily: 'Cairo')),
          ],
        ),
        backgroundColor: Colors.white, elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF102A43)),
        actions: [
          if (!_isLoading && _students.isNotEmpty) ...[
            _buildActionIcon(Icons.picture_as_pdf_rounded, Colors.red, _exportToPdf, "PDF"),
            const SizedBox(width: 10),
            _buildPremiumActionBtn(),
            const SizedBox(width: 20),
          ]
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF102A43), strokeWidth: 2))
              : CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(child: _buildHeader(presentCount, total, isDesktop)),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), shape: BoxShape.circle),
                              child: const Icon(Icons.info_outline_rounded, size: 14, color: Colors.blue),
                            ),
                            const SizedBox(width: 10),
                            const Text("الطلاب الذين سجلوا دخولهم تظهر بياناتهم مفصلة في التقرير", 
                              style: TextStyle(fontSize: 11, color: Colors.blueGrey, fontFamily: 'Cairo', fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                    _students.isEmpty
                        ? SliverFillRemaining(child: _buildEmptyState())
                        : SliverPadding(
                            padding: EdgeInsets.symmetric(horizontal: isDesktop ? 30 : 20, vertical: 20),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) => _buildStudentTile(index, isDesktop),
                                childCount: _students.length,
                              ),
                            ),
                          ),
                    const SliverToBoxAdapter(child: SizedBox(height: 50)),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildActionIcon(IconData icon, Color color, VoidCallback onTap, String tooltip) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: color, size: 22),
        ),
      ),
    );
  }

  Widget _buildPremiumActionBtn() {
    return ElevatedButton.icon(
      onPressed: _saveAttendance,
      icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
      label: const Text("اعتماد الكشف", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900)),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF102A43),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildHeader(int present, int total, bool isDesktop) {
    double percentage = total > 0 ? (present / total) : 0;
    return Container(
      padding: const EdgeInsets.all(30),
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
      child: Row(
        children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text("إحصائيات الحضور", style: TextStyle(color: Colors.white70, fontSize: 14, fontFamily: 'Cairo', fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              Text("$present طالب حاضر", style: TextStyle(color: Colors.white, fontSize: isDesktop ? 28 : 22, fontWeight: FontWeight.w900, fontFamily: 'Cairo')),
              Text("من إجمالي $total طلاب مسجلين", style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13, fontFamily: 'Cairo')),
            ]),
          ),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 70, height: 70,
                child: CircularProgressIndicator(
                  value: percentage,
                  strokeWidth: 8,
                  backgroundColor: Colors.white.withOpacity(0.1),
                  color: const Color(0xFF00C853),
                ),
              ),
              Text("${(percentage * 100).toInt()}%", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStudentTile(int index, bool isDesktop) {
    final s = _students[index];
    final bool isAuto = s['isAutoMarked'] ?? false;
    final bool isPresent = s['present'];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          leading: Container(
            width: 50, height: 50,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isPresent 
                  ? [const Color(0xFF00C853).withOpacity(0.1), const Color(0xFF00C853).withOpacity(0.2)]
                  : [Colors.red.withOpacity(0.1), Colors.red.withOpacity(0.2)],
              ),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(s['name'][0].toUpperCase(), 
                style: TextStyle(color: isPresent ? const Color(0xFF00C853) : Colors.red, fontWeight: FontWeight.w900, fontSize: 20)),
            ),
          ),
          title: Text(s['name'], style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, fontFamily: 'Cairo', color: Color(0xFF102A43))),
          subtitle: Row(
            children: [
              _buildStatusBadge(isPresent, isAuto),
              if (isAuto && s['duration'] != null) ...[
                const SizedBox(width: 8),
                Text("${s['duration']} دقيقة", style: TextStyle(fontSize: 11, color: Colors.blueGrey.shade300, fontFamily: 'Cairo')),
              ]
            ],
          ),
          trailing: Transform.scale(
            scale: 0.8,
            child: Switch(
              value: isPresent,
              activeColor: const Color(0xFF00C853),
              inactiveThumbColor: Colors.red,
              inactiveTrackColor: Colors.red.withOpacity(0.2),
              onChanged: (val) => setState(() => _students[index]['present'] = val),
            ),
          ),
          children: [
            if (isAuto)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildInfoItem(Icons.login_rounded, "الدخول", _formatTime(s['joined_at'])),
                    _buildInfoItem(Icons.logout_rounded, "الخروج", _formatTime(s['left_at'])),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(bool isPresent, bool isAuto) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isPresent ? const Color(0xFF00C853).withOpacity(0.1) : Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isAuto ? "تحضير نظام" : (isPresent ? "حاضر" : "غائب"),
        style: TextStyle(
          color: isPresent ? const Color(0xFF00C853) : Colors.red, 
          fontSize: 10, 
          fontFamily: 'Cairo', 
          fontWeight: FontWeight.w800
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, size: 16, color: Colors.blueGrey.shade200),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 10, color: Colors.blueGrey.shade300, fontFamily: 'Cairo')),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF102A43), fontFamily: 'Cairo')),
      ],
    );
  }

  String _formatTime(String? iso) {
    if (iso == null) return "--:--";
    try {
      final dt = DateTime.parse(iso).toLocal();
      return DateFormat('hh:mm a').format(dt).replaceAll("AM", "ص").replaceAll("PM", "م");
    } catch (_) { return "--:--"; }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(color: Colors.blueGrey.withOpacity(0.05), shape: BoxShape.circle),
            child: Icon(Icons.person_off_rounded, size: 80, color: Colors.blueGrey.shade200),
          ),
          const SizedBox(height: 24),
          const Text("لا يوجد طلاب مسجلين في هذه الحصة", 
            style: TextStyle(color: Colors.blueGrey, fontSize: 16, fontFamily: 'Cairo', fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
