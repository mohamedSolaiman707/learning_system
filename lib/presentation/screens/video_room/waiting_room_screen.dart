import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/models/session_model.dart';
import '../../../core/services/database_service.dart';
import 'video_room_screen.dart';
import 'video_room_controller.dart';

class WaitingRoomScreen extends StatefulWidget {
  final SessionModel session;
  final String userName;
  final String userId;

  const WaitingRoomScreen({
    super.key,
    required this.session,
    required this.userName,
    required this.userId,
  });

  @override
  State<WaitingRoomScreen> createState() => _WaitingRoomScreenState();
}

class _WaitingRoomScreenState extends State<WaitingRoomScreen> {
  late Timer _timer;
  Duration _timeLeft = Duration.zero;
  StreamSubscription? _statusSubscription;
  StreamSubscription? _roomSubscription;
  final _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _calculateTimeLeft();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _calculateTimeLeft());
    
    final db = Provider.of<DatabaseService>(context, listen: false);
    db.joinWaitingRoom(widget.session.id, widget.userId);

    // 1. مراقبة حالة الجلسة العامة
    _statusSubscription = db.watchSessionStatus(widget.session.id).listen((data) {
      if (data.isNotEmpty) {
        final String status = data.first['status'];
        if (status == 'active') {
          _navigateToRoom();
        } else if (status == 'ended' || status == 'archived') {
           _handleSessionEnded();
        }
      }
    });

    // 2. الحل الجذري: مراقبة "القاعة" مباشرة (Real-time Room Monitor)
    // إذا فتح المدرس القاعة، ندخل الطالب فوراً بغض النظر عن الـ Status
    _roomSubscription = _supabase
        .from('rooms')
        .stream(primaryKey: ['id'])
        .eq('session_id', widget.session.id)
        .listen((data) {
          if (data.isNotEmpty && data.first['is_active'] == true) {
            _navigateToRoom();
          }
        });
  }

  void _handleSessionEnded() {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("🔴 انتهت الحصة الدراسية، شكراً لكم.", style: TextStyle(fontFamily: 'Cairo')),
          backgroundColor: Colors.redAccent,
        ),
      );
      Navigator.pop(context);
    }
  }

  void _calculateTimeLeft() {
    final now = DateTime.now();
    if (widget.session.startTime.isAfter(now)) {
      if (mounted) {
        setState(() {
          _timeLeft = widget.session.startTime.difference(now);
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _timeLeft = Duration.zero;
        });
      }
    }
  }

  bool _isNavigating = false;
  void _navigateToRoom() {
    if (!mounted || _isNavigating) return;
    _isNavigating = true;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ChangeNotifierProvider(
          create: (_) => VideoRoomController(
            title: widget.session.subjectName,
            roomName: "room_${widget.session.id}",
            userName: widget.userName,
            userId: widget.userId,
            isTeacher: false,
            sessionId: widget.session.id,
          ),
          child: VideoRoomScreen(
            title: widget.session.subjectName,
            roomName: "room_${widget.session.id}",
            userName: widget.userName,
            userId: widget.userId,
            isTeacher: false,
            sessionId: widget.session.id,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _timer.cancel();
    _statusSubscription?.cancel();
    _roomSubscription?.cancel();
    final db = Provider.of<DatabaseService>(context, listen: false);
    db.leaveWaitingRoom(widget.session.id, widget.userId);
    super.dispose();
  }

  // ... (باقي الـ UI يظل كما هو لجمال التصميم)
  
  Widget _buildTimeUnit(String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white38, fontSize: 14, fontFamily: 'Cairo'),
        ),
      ],
    );
  }

  Widget _buildTimeDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(":", style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 32, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20), 
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hours = _timeLeft.inHours;
    final minutes = _timeLeft.inMinutes % 60;
    final seconds = _timeLeft.inSeconds % 60;

    return Scaffold(
      backgroundColor: const Color(0xFF0F1014),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F1014), Color(0xFF1A1C1E)],
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.05),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.blue.withOpacity(0.1), width: 2),
                    ),
                    child: const Icon(Icons.access_time_rounded, color: Colors.blue, size: 65),
                  ),
                  const SizedBox(height: 48),
                  const Text("غرفة الانتظار الرقمية", style: TextStyle(color: Colors.white70, fontSize: 16, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Text(widget.session.subjectName, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, fontFamily: 'Cairo')),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(30)),
                    child: Text("المعلم: ${widget.session.teacherName}", style: const TextStyle(color: Colors.blue, fontSize: 15, fontFamily: 'Cairo', fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(height: 60),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(40),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(32), border: Border.all(color: Colors.white.withOpacity(0.05))),
                    child: Column(
                      children: [
                        const Text("ستبدأ الحصة التعليمية خلال", style: TextStyle(color: Colors.white70, fontSize: 14, fontFamily: 'Cairo')),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (hours > 0) ...[
                              _buildTimeUnit(hours.toString().padLeft(2, '0'), "ساعة"),
                              _buildTimeDivider(),
                            ],
                            _buildTimeUnit(minutes.toString().padLeft(2, '0'), "دقيقة"),
                            _buildTimeDivider(),
                            _buildTimeUnit(seconds.toString().padLeft(2, '0'), "ثانية"),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 60),
                  const _WaitingHourglass(),
                  const SizedBox(height: 32),
                  const Text("يرجى البقاء في هذه الصفحة، سيتم توجيهك تلقائياً فور بدء المعلم للحصة", textAlign: TextAlign.center, style: TextStyle(color: Colors.white38, fontSize: 14, fontFamily: 'Cairo', height: 1.6)),
                  const SizedBox(height: 48),
                  TextButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_rounded, color: Colors.grey, size: 20),
                    label: const Text("العودة إلى لوحة التحكم", style: TextStyle(color: Colors.grey, fontFamily: 'Cairo')),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WaitingHourglass extends StatefulWidget {
  const _WaitingHourglass();
  @override
  State<_WaitingHourglass> createState() => _WaitingHourglassState();
}
class _WaitingHourglassState extends State<_WaitingHourglass> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
  }
  @override
  void dispose() { _controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.3, end: 1.0).animate(_controller),
      child: Column(
        children: [
          const Icon(Icons.hourglass_bottom_rounded, color: Colors.blue, size: 40),
          const SizedBox(height: 12),
          Container(width: 30, height: 3, decoration: BoxDecoration(color: Colors.blue.withOpacity(0.2), borderRadius: BorderRadius.circular(10)))
        ],
      ),
    );
  }
}
