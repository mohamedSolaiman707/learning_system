import 'dart:async';
import 'package:flutter/material.dart';
import 'package:iconly/iconly.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart' as intl;
import 'package:shimmer/shimmer.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/services/database_service.dart';
import '../../../../core/services/assignments_service.dart';
import '../../../../core/models/session_model.dart';
import '../widgets/next_class_card.dart';
import '../widgets/upcoming_class_item.dart';
import '../../video_room/video_room_screen.dart';
import '../assignments/student_assignments_screen.dart';
import '../resources/student_resources_screen.dart';

class StudentHomeTab extends StatefulWidget {
  const StudentHomeTab({super.key});

  @override
  State<StudentHomeTab> createState() => _StudentHomeTabState();
}

class _StudentHomeTabState extends State<StudentHomeTab> {
  bool _isLoading = true;
  List<SessionModel> _sessions = [];
  SessionModel? _nextSession;
  int _pendingAssignmentsCount = 0;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadStudentData(initial: true);
    
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      _loadStudentData(initial: false);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadStudentData({bool initial = true}) async {
    if (!mounted) return;
    if (initial) setState(() => _isLoading = true);
    
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final db = Provider.of<DatabaseService>(context, listen: false);
      final assignService = AssignmentsService();
      
      if (auth.user != null) {
        final response = await db.getStudentSchedule(auth.user!.id);
        
        if (mounted) {
          setState(() {
            _sessions = response.map((e) => SessionModel.fromMap(e['sessions'])).toList();
            _sessions.sort((a, b) => a.startTime.compareTo(b.startTime));

            final now = DateTime.now();
            try {
              _nextSession = _sessions.firstWhere((s) => s.endTime.isAfter(now));
            } catch (_) {
              _nextSession = null;
            }
            
            if (initial) _isLoading = false;
          });

          // حساب الواجبات المعلقة فقط (التي لم يسلمها الطالب)
          int pendingCount = 0;
          for (var session in _sessions) {
             final assignments = await assignService.getAssignments(session.id);
             for (var assignment in assignments) {
               final submission = await assignService.getStudentSubmission(assignment.id, auth.user!.id);
               if (submission == null) {
                 pendingCount++;
               }
             }
          }
          if (mounted) setState(() => _pendingAssignmentsCount = pendingCount);
        }
      }
    } catch (e) {
      if (mounted && initial) setState(() => _isLoading = false);
    }
  }

  void _showJoinCodeDialog() {
    final codeController = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("انضمام لحصة جديدة", textAlign: TextAlign.center),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("أدخل كود الحصة المكون من 6 أرقام/حروف للانضمام", 
                style: TextStyle(fontSize: 13, color: Colors.grey), textAlign: TextAlign.center),
              const SizedBox(height: 20),
              TextField(
                controller: codeController,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, letterSpacing: 4),
                decoration: InputDecoration(
                  hintText: "ABC123",
                  hintStyle: TextStyle(color: Colors.grey.shade300, letterSpacing: 4),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                textCapitalization: TextCapitalization.characters,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("إلغاء")),
            ElevatedButton(
              onPressed: isSubmitting ? null : () async {
                if (codeController.text.isEmpty) return;
                
                setDialogState(() => isSubmitting = true);
                try {
                  final auth = Provider.of<AuthProvider>(context, listen: false);
                  final db = Provider.of<DatabaseService>(context, listen: false);
                  
                  await db.enrollStudentByCode(auth.user!.id, codeController.text);
                  
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("تم الانضمام للحصة بنجاح"), backgroundColor: Colors.green)
                    );
                    _loadStudentData(initial: true);
                  }
                } catch (e) {
                  setDialogState(() => isSubmitting = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString().replaceAll("Exception: ", "")), backgroundColor: Colors.red)
                  );
                }
              },
              child: isSubmitting 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text("انضمام"),
            ),
          ],
        ),
      ),
    );
  }

  void _showSessionOptions(SessionModel session) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(session.subjectName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            _buildOptionTile(IconlyLight.document, "الواجبات المدرسية", Colors.blue, () async {
              Navigator.pop(context);
              await Navigator.push(context, MaterialPageRoute(builder: (context) => StudentAssignmentsScreen(sessionId: session.id, subjectName: session.subjectName)));
              _loadStudentData(initial: false); // تحديث العداد عند العودة
            }),
            const Divider(),
            _buildOptionTile(IconlyLight.folder, "المصادر والكتب", Colors.orange, () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (context) => StudentResourcesScreen(sessionId: session.id, subjectName: session.subjectName)));
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile(IconData icon, String title, Color color, VoidCallback onTap) {
    return ListTile(
      leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final userName = authProvider.profile?['full_name'] ?? "الطالب";

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      body: _isLoading 
          ? _buildLoadingSkeleton()
          : RefreshIndicator(
              onRefresh: () => _loadStudentData(initial: true),
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
                          if (_nextSession != null) 
                            GestureDetector(
                              onTap: () => _showSessionOptions(_nextSession!),
                              child: _buildNextClassSection(userName),
                            )
                          else
                            _buildNoClassesCard(),
                          const SizedBox(height: 40),
                          _buildStatsAndProgress(),
                          const SizedBox(height: 40),
                          if (_sessions.isNotEmpty) ...[
                            _buildUpcomingClassesHeader(),
                            const SizedBox(height: 15),
                            _buildUpcomingGrid(),
                          ],
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
      expandedHeight: 120, floating: true, pinned: true,
      backgroundColor: Colors.white, elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsetsDirectional.only(start: 16, bottom: 16),
        title: Text("الرئيسية", style: TextStyle(color: Colors.black.withOpacity(0.8), fontWeight: FontWeight.bold, fontSize: 20)),
      ),
      actions: [
        IconButton(onPressed: _showJoinCodeDialog, icon: const Icon(IconlyLight.plus), tooltip: "انضمام بكود"),
        IconButton(onPressed: () {}, icon: const Badge(child: Icon(IconlyLight.notification))),
        const SizedBox(width: 8),
        Padding(
          padding: const EdgeInsets.only(left: 16),
          child: CircleAvatar(
            backgroundColor: Colors.blue.withOpacity(0.1),
            child: Text(name.isNotEmpty ? name[0].toUpperCase() : "U", style: const TextStyle(color: Colors.blue)),
          ),
        ),
      ],
    );
  }

  Widget _buildWelcomeSection(String name) {
    int todayCount = _sessions.where((s) {
      final now = DateTime.now();
      return s.startTime.day == now.day && s.startTime.month == now.month;
    }).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("أهلاً بك، $name 👋", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        Text(
          todayCount > 0 ? "لديك $todayCount حصص اليوم." : "لا توجد حصص مجدولة لليوم.",
          style: const TextStyle(fontSize: 16, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildNextClassSection(String userName) {
    return NextClassCard(
      subject: _nextSession!.subjectName,
      teacher: _nextSession!.teacherName,
      startTime: intl.DateFormat('hh:mm a').format(_nextSession!.startTime),
      isLive: _nextSession!.isLive,
      onJoin: () {
        Navigator.push(context, MaterialPageRoute(
          builder: (context) => VideoRoomScreen(
            title: "بث مباشر: ${_nextSession!.subjectName}",
            roomName: "room_${_nextSession!.id}",
            userName: userName,
          ),
        ));
      },
    );
  }

  Widget _buildNoClassesCard() {
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.withOpacity(0.1))),
      child: Column(
        children: [
          Icon(IconlyLight.calendar, size: 50, color: Colors.grey.shade300),
          const SizedBox(height: 15),
          const Text("لا توجد حصص قادمة حالياً", style: TextStyle(color: Colors.grey, fontSize: 16)),
          TextButton(onPressed: _showJoinCodeDialog, child: const Text("انضم لحصة الآن")),
        ],
      ),
    );
  }

  Widget _buildStatsAndProgress() {
    return Row(
      children: [
        Expanded(child: _buildStatItem("الحصص", "${_sessions.length}", Icons.collections_bookmark, Colors.green)),
        const SizedBox(width: 16),
        Expanded(child: _buildStatItem("الواجبات", "$_pendingAssignmentsCount", Icons.assignment, Colors.orange)),
      ],
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)]),
      child: Row(
        children: [
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 20)),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ]),
        ],
      ),
    );
  }

  Widget _buildUpcomingClassesHeader() {
    return const Text("حصصك القادمة", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold));
  }

  Widget _buildUpcomingGrid() {
    final upcoming = _sessions.where((s) => s.id != _nextSession?.id).toList();
    if (upcoming.isEmpty) return const SizedBox.shrink();

    return GridView.builder(
      shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: Responsive.isMobile(context) ? 1 : 2,
        crossAxisSpacing: 16, mainAxisSpacing: 16, mainAxisExtent: 100,
      ),
      itemCount: upcoming.length,
      itemBuilder: (context, index) {
        final session = upcoming[index];
        final diff = session.endTime.difference(session.startTime).inMinutes;
        return InkWell(
          onTap: () => _showSessionOptions(session),
          child: UpcomingClassItem(
            subject: session.subjectName,
            teacher: session.teacherName,
            time: intl.DateFormat('hh:mm a').format(session.startTime),
            duration: "$diff دقيقة",
          ),
        );
      },
    );
  }

  Widget _buildLoadingSkeleton() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300, highlightColor: Colors.grey.shade100,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(height: 150, width: double.infinity, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24))),
            const SizedBox(height: 20),
            Row(children: [Expanded(child: Container(height: 80, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)))), const SizedBox(width: 10), Expanded(child: Container(height: 80, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16))))]),
            const SizedBox(height: 30),
            ...List.generate(3, (i) => Container(height: 70, margin: const EdgeInsets.only(bottom: 12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)))),
          ],
        ),
      ),
    );
  }
}
