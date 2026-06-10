import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/database_service.dart';
import '../../../core/services/livekit_service.dart';
import 'widgets/participant_grid.dart';

class WallDisplayScreen extends StatefulWidget {
  final String sessionId;
  final String zone;
  final String roomName;

  const WallDisplayScreen({
    super.key,
    required this.sessionId,
    required this.zone,
    required this.roomName,
  });

  @override
  State<WallDisplayScreen> createState() => _WallDisplayScreenState();
}

class _WallDisplayScreenState extends State<WallDisplayScreen> {
  Room? _room;
  EventsListener<RoomEvent>? _listener;
  List<Map<String, dynamic>> _zoneSeats = [];
  bool _isLoading = true;
  StreamSubscription? _seatsSubscription;

  final Map<String, bool> _handStates = {};
  String? _spotlightUserId;

  final String _livekitUrl =
      'wss://learning-system-academy-axo5qepz.livekit.cloud';

  @override
  void initState() {
    super.initState();
    _initWall();
  }

  Future<void> _initWall() async {
    final db = DatabaseService();

    try {
      final seats = await db.getSeats(widget.sessionId);
      _zoneSeats = seats.where((s) => s['zone'] == widget.zone).toList();
      _zoneSeats.sort(
        (a, b) => (a['seat_number'] as int).compareTo(b['seat_number'] as int),
      );
    } catch (e) {
      debugPrint("Error loading initial seats: $e");
    }

    try {
      final token = await LiveKitService().getRoomToken(
        roomName: widget.roomName,
        userId: "wall_${widget.zone}_${DateTime.now().millisecondsSinceEpoch}",
        userName: "شاشة_${_getZoneArabicName(widget.zone)}",
      );

      if (token != null) {
        _room = Room();
        _listener = _room!.createListener();
        _setupRoomListeners();
        await _room!.connect(_livekitUrl, token);
      }
    } catch (e) {
      debugPrint("Error connecting to LiveKit: $e");
    }

    _seatsSubscription = Supabase.instance.client
        .from('seats')
        .stream(primaryKey: ['id'])
        .eq('session_id', widget.sessionId)
        .listen((data) {
          if (mounted) {
            setState(() {
              _zoneSeats = data.where((s) => s['zone'] == widget.zone).toList();
              _zoneSeats.sort(
                (a, b) => (a['seat_number'] as int).compareTo(
                  b['seat_number'] as int,
                ),
              );
            });
          }
        });

    if (mounted) setState(() => _isLoading = false);
  }

  void _setupRoomListeners() {
    _listener!
      ..on<DataReceivedEvent>((event) {
        try {
          final data = jsonDecode(utf8.decode(event.data));
          _handleIncomingData(data, event.participant);
        } catch (e) {
          debugPrint("Error handling data: $e");
        }
      })
      ..on<ParticipantDisconnectedEvent>((event) {
        if (mounted)
          setState(() => _handStates.remove(event.participant.identity));
      })
      ..on<RoomEvent>((_) {
        if (mounted) setState(() {});
      });
  }

  void _handleIncomingData(Map<String, dynamic> data, RemoteParticipant? p) {
    switch (data['type']) {
      case 'hand_raise':
        if (p != null && mounted)
          setState(() => _handStates[p.identity] = data['value']);
        break;
      case 'spotlight':
        if (mounted) setState(() => _spotlightUserId = data['value']);
        break;
    }
  }

  String _getZoneArabicName(String zone) {
    if (zone == 'right') return 'اليمين';
    if (zone == 'center') return 'الوسط';
    return 'اليسار';
  }

  @override
  void dispose() {
    _seatsSubscription?.cancel();
    _listener?.dispose();
    _room?.disconnect();
    _room?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1014),
      body: Stack(
        children: [
          // Background Gradient for depth
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.2,
                  colors: [Colors.blue.withOpacity(0.05), Colors.transparent],
                ),
              ),
            ),
          ),

          _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.blue),
                )
              : _room == null
              ? const Center(
                  child: Text(
                    "فشل الاتصال بالقاعة",
                    style: TextStyle(color: Colors.white, fontFamily: 'Cairo'),
                  ),
                )
              : Column(
                  children: [
                    _buildHeader(),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            int crossAxisCount = widget.zone == 'center'
                                ? 3
                                : 2;
                            return GridView.builder(
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: crossAxisCount,
                                    crossAxisSpacing: 24,
                                    mainAxisSpacing: 24,
                                    childAspectRatio: 16 / 10,
                                  ),
                              itemCount: _zoneSeats.length,
                              itemBuilder: (context, index) {
                                final seat = _zoneSeats[index];
                                final String? studentId = seat['student_id'];
                                RemoteParticipant? participant;
                                if (studentId != null && studentId.isNotEmpty) {
                                  participant = _room!.remoteParticipants.values
                                      .where((p) {
                                        final cleanId = p.identity
                                            .split('_')
                                            .first;
                                        return p.identity.contains(studentId) ||
                                            cleanId == studentId;
                                      })
                                      .firstOrNull;
                                }

                                return AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 800),
                                  switchInCurve: Curves.easeOutBack,
                                  switchOutCurve: Curves.easeIn,
                                  transitionBuilder: (child, anim) =>
                                      FadeTransition(
                                        opacity: anim,
                                        child: ScaleTransition(
                                          scale: anim,
                                          child: child,
                                        ),
                                      ),
                                  child: _buildSeatTile(seat, participant),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 30),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.7),
            border: Border(
              bottom: BorderSide(color: Colors.blue.withOpacity(0.2)),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.dashboard_customize_rounded,
                color: Colors.blue,
                size: 28,
              ),
              const SizedBox(width: 20),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "نظام العرض الجداري الذكي",
                    style: TextStyle(
                      color: Colors.blue.withOpacity(0.7),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      fontFamily: 'Cairo',
                    ),
                  ),
                  Text(
                    "منطقة ${_getZoneArabicName(widget.zone)}",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 22,
                      fontFamily: 'Cairo',
                    ),
                  ),
                ],
              ),
              const Spacer(),
              _buildLiveBadge(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLiveBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: const Row(
        children: [
          _PulseIcon(),
          SizedBox(width: 10),
          Text(
            "LIVE FEED",
            style: TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.w900,
              fontSize: 12,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeatTile(Map<String, dynamic> seat, RemoteParticipant? p) {
    final bool isOccupied =
        seat['student_id'] != null && (seat['student_id'] as String).isNotEmpty;
    final bool isOnline = p != null;
    final bool isSpeaking = p?.isSpeaking ?? false;
    final int seatNum = seat['seat_number'];

    return Container(
      key: ValueKey("seat_${seatNum}_${seat['student_id']}_$isOnline"),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isSpeaking
              ? Colors.greenAccent
              : (isOnline
                    ? Colors.blue.withOpacity(0.3)
                    : Colors.white.withOpacity(0.05)),
          width: isSpeaking ? 3 : 1,
        ),
        boxShadow: [
          if (isSpeaking)
            BoxShadow(
              color: Colors.greenAccent.withOpacity(0.2),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
        color: isOccupied
            ? const Color(0xFF1E1F23)
            : Colors.white.withOpacity(0.02),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          if (isOnline)
            ParticipantTile(
              participant: p!,
              isMainStage: p.identity == _spotlightUserId,
              forceHandRaised: _handStates[p.identity],
              forceShowScreen: false,
            )
          else if (isOccupied)
            _buildOfflineState(seat['student_name'] ?? "طالب")
          else
            _buildEmptyState(seatNum),

          // Seat Label
          Positioned(
            top: 15,
            left: 15,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Text(
                "مقعد $seatNum",
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Cairo',
                ),
              ),
            ),
          ),

          if (isSpeaking)
            Positioned(top: 15, right: 15, child: _SpeakingIndicator()),
        ],
      ),
    );
  }

  Widget _buildEmptyState(int num) {
    return Center(
      child: Opacity(
        opacity: 0.15,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.airline_seat_recline_normal_rounded,
              color: Colors.white,
              size: 50,
            ),
            const SizedBox(height: 10),
            Text(
              "مقعد شاغر",
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'Cairo',
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOfflineState(String name) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 30,
            height: 30,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: Colors.blue,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'Cairo',
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            "في انتظار الاتصال...",
            style: TextStyle(
              color: Colors.white.withOpacity(0.3),
              fontSize: 11,
              fontFamily: 'Cairo',
            ),
          ),
        ],
      ),
    );
  }
}

// UI Enhancement Components
class _PulseIcon extends StatefulWidget {
  const _PulseIcon();
  @override
  State<_PulseIcon> createState() => _PulseIconState();
}

class _PulseIconState extends State<_PulseIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: const Icon(Icons.fiber_manual_record, color: Colors.red, size: 12),
    );
  }
}

class _SpeakingIndicator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: const BoxDecoration(
        color: Colors.greenAccent,
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.mic_rounded, color: Colors.black, size: 14),
    );
  }
}
