import 'dart:async';
import 'package:flutter/material.dart';
import 'package:iconly/iconly.dart';
import 'package:intl/intl.dart' as intl;
import 'package:provider/provider.dart';
import '../../../core/models/session_model.dart';
import '../../../core/services/database_service.dart';
import 'video_room_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _calculateTimeLeft();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _calculateTimeLeft());
    
    final db = Provider.of<DatabaseService>(context, listen: false);
    
    // تسجيل الدخول لغرفة الانتظار في قاعدة البيانات
    db.joinWaitingRoom(widget.session.id, widget.userId);

    // مراقبة حالة الجلسة للتحويل التلقائي عند بدء المعلم
    _statusSubscription = db.watchSessionStatus(widget.session.id).listen((data) {
      if (data['status'] == 'active') {
        _navigateToRoom();
      }
    });
  }

  void _calculateTimeLeft() {
    final now = DateTime.now();
    if (widget.session.startTime.isAfter(now)) {
      setState(() {
        _timeLeft = widget.session.startTime.difference(now);
      });
    } else {
      setState(() {
        _timeLeft = Duration.zero;
      });
    }
  }

  void _navigateToRoom() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => VideoRoomScreen(
          title: widget.session.subjectName,
          roomName: "room_${widget.session.id}",
          userName: widget.userName,
          userId: widget.userId,
          isTeacher: false,
          sessionId: widget.session.id,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _timer.cancel();
    _statusSubscription?.cancel();
    final db = Provider.of<DatabaseService>(context, listen: false);
    db.leaveWaitingRoom(widget.session.id, widget.userId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final timeStr = _timeLeft.inHours > 0 
      ? "${_timeLeft.inHours}:${(_timeLeft.inMinutes % 60).toString().padLeft(2, '0')}:${(_timeLeft.inSeconds % 60).toString().padLeft(2, '0')}"
      : "${_timeLeft.inMinutes}:${(_timeLeft.inSeconds % 60).toString().padLeft(2, '0')}";

    return Scaffold(
      backgroundColor: const Color(0xFF0F1014),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(IconlyLight.time_circle, color: Colors.blue, size: 64),
            ),
            const SizedBox(height: 32),
            Text(
              "غرفة الانتظار",
              style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              widget.session.subjectName,
              style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              "المدرس: ${widget.session.teacherName}",
              style: const TextStyle(color: Colors.blue, fontSize: 16),
            ),
            const SizedBox(height: 48),
            const Text(
              "تبدأ الحصة خلال",
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 12),
            Text(
              timeStr,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 48,
                fontWeight: FontWeight.bold,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              intl.DateFormat('hh:mm a').format(widget.session.startTime),
              style: const TextStyle(color: Colors.grey, fontSize: 16),
            ),
            const SizedBox(height: 64),
            const CircularProgressIndicator(strokeWidth: 2, color: Colors.blue),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                "يرجى الانتظار، سيقوم المعلم بفتح القاعة قريباً...",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13),
              ),
            ),
            const SizedBox(height: 40),
            TextButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back, color: Colors.grey),
              label: const Text("العودة للرئيسية", style: TextStyle(color: Colors.grey)),
            ),
          ],
        ),
      ),
    );
  }
}
