import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:provider/provider.dart';
import '../../../core/models/session_model.dart';
import '../../../core/services/database_service.dart';
import '../../../core/utils/responsive.dart';
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

  bool _seatSelected = false;
  int? _selectedSeat;
  List<Map<String, dynamic>> _seats = [];
  bool _seatsLoading = true;

  @override
  void initState() {
    super.initState();
    _calculateTimeLeft();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _calculateTimeLeft());
    
    final db = Provider.of<DatabaseService>(context, listen: false);
    
    db.joinWaitingRoom(widget.session.id, widget.userId);
    _loadSeats();

    _statusSubscription = db.watchSessionStatus(widget.session.id).listen((data) {
      if (data.isEmpty || data.first['status'] == 'ended') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("🔴 تم إنهاء الحصة المباشرة من قبل المعلم، شكراً لكم.", style: TextStyle(fontFamily: 'Cairo')),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
              margin: EdgeInsets.all(20),
            ),
          );

          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) Navigator.pop(context);
          });
        }
        return;
      }

      final String status = data.first['status'];

      if (status == 'active') {
        _navigateToRoom();
      }
    });
  }

  Future<void> _loadSeats() async {
    final db = Provider.of<DatabaseService>(context, listen: false);
    // Ensuring seats are initialized for the session
    await db.initializeSeats(widget.session.id);
    final seats = await db.getSeats(widget.session.id);
    if (mounted) {
      setState(() {
        _seats = seats;
        _seatsLoading = false;
      });
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

  void _navigateToRoom() {
    if (!mounted) return;
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
    final db = Provider.of<DatabaseService>(context, listen: false);
    db.leaveWaitingRoom(widget.session.id, widget.userId);
    super.dispose();
  }

  Widget _buildSeatPicker() {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1014),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F1014), Color(0xFF1A1C1E)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 40),
              const Text("اختر مقعدك في القاعة",
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Text("اختر المقعد المناسب لمكانك الفعلي في القاعة لسهولة تواصل المعلم معك",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 14, fontFamily: 'Cairo')),
              ),
              const SizedBox(height: 40),
              if (_seatsLoading)
                const Expanded(child: Center(child: CircularProgressIndicator()))
              else
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildZoneColumn("يمين القاعة 📷", "right"),
                        const SizedBox(width: 12),
                        _buildZoneColumn("وسط القاعة", "center"),
                        const SizedBox(width: 12),
                        _buildZoneColumn("يسار القاعة 📷", "left"),
                      ],
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _selectedSeat == null ? null : () async {
                      final db = Provider.of<DatabaseService>(context, listen: false);
                      await db.assignSeat(
                        sessionId: widget.session.id,
                        seatNumber: _selectedSeat!,
                        studentId: widget.userId,
                        studentName: widget.userName,
                      );
                      setState(() => _seatSelected = true);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      disabledBackgroundColor: Colors.white.withOpacity(0.05),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                    child: const Text("تأكيد المقعد والمتابعة",
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildZoneColumn(String label, String zoneKey) {
    final zoneSeats = _seats.where((s) => s['zone'] == zoneKey).toList();
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
          ),
          const SizedBox(height: 16),
          ...zoneSeats.map((seat) {
            final int seatNum = seat['seat_number'];
            final bool isOccupied = seat['student_id'] != null;
            final bool isSelected = _selectedSeat == seatNum;
            final String studentName = seat['student_name'] ?? "";

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onTap: isOccupied ? null : () => setState(() => _selectedSeat = seatNum),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.blue : (isOccupied ? Colors.white.withOpacity(0.05) : Colors.transparent),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? Colors.blue : (isOccupied ? Colors.transparent : Colors.white24),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    isOccupied ? studentName : seatNum.toString(),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isOccupied ? Colors.white24 : Colors.white,
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontFamily: 'Cairo',
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_seatSelected) return _buildSeatPicker();

    final bool isDesktop = Responsive.isDesktop(context);
    final timeStr = _timeLeft.inHours > 0 
      ? "${_timeLeft.inHours}:${(_timeLeft.inMinutes % 60).toString().padLeft(2, '0')}:${(_timeLeft.inSeconds % 60).toString().padLeft(2, '0')}"
      : "${_timeLeft.inMinutes}:${(_timeLeft.inSeconds % 60).toString().padLeft(2, '0')}";

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
                    child: const Icon(Icons.access_time_rounded, color: Colors.blue, size: 80),
                  ),
                  const SizedBox(height: 48),
                  Text(
                    "غرفة الانتظار الرقمية",
                    style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 16, fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.session.subjectName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, fontFamily: 'Cairo'),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(30)),
                    child: Text(
                      "المعلم: ${widget.session.teacherName}",
                      style: const TextStyle(color: Colors.blue, fontSize: 15, fontFamily: 'Cairo', fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 60),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(40),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                    ),
                    child: Column(
                      children: [
                        Text(
                          "ستبدأ الحصة التعليمية خلال",
                          style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14, fontFamily: 'Cairo'),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          timeStr,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 64,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 60),
                  const CircularProgressIndicator(strokeWidth: 3, color: Colors.blue),
                  const SizedBox(height: 32),
                  Text(
                    "يرجى البقاء في هذه الصفحة، سيتم توجيهك تلقائياً فور بدء المعلم للحصة",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 14, fontFamily: 'Cairo', height: 1.6),
                  ),
                  const SizedBox(height: 48),
                  TextButton.icon(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.arrow_back_rounded, color: Colors.grey, size: 20),
                    label: const Text("العودة إلى لوحة التحكم", style: TextStyle(color: Colors.grey, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
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
