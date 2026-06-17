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
  final String zone; // e.g., 'screen_1', 'screen_2'
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
  List<Map<String, dynamic>> _allSeats = [];
  bool _isLoading = true;
  StreamSubscription? _seatsSubscription;
  int _seatsPerScreen = 8;

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
      // تحميل إعدادات الجلسة لمعرفة عدد المقاعد لكل شاشة
      final config = await db.getSessionScreenConfig(widget.sessionId);
      if (mounted) {
        setState(() {
          _seatsPerScreen = config['seats_per_screen'] ?? 8;
        });
      }

      final seats = await db.getSeats(widget.sessionId);
      if (mounted) {
        setState(() {
          _allSeats = seats;
        });
      }
    } catch (e) {
      debugPrint("Error loading initial config/seats: $e");
    }

    try {
      final token = await LiveKitService().getRoomToken(
        roomName: widget.roomName,
        userId: "wall_${widget.zone}_${DateTime.now().millisecondsSinceEpoch}",
        userName: _getZoneArabicName(widget.zone),
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
          _allSeats = data;
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
        if (mounted) {
          setState(() => _handStates.remove(event.participant.identity));
        }
      })
      ..on<RoomEvent>((_) {
        if (mounted) setState(() {});
      });
  }

  void _handleIncomingData(Map<String, dynamic> data, RemoteParticipant? p) {
    switch (data['type']) {
      case 'hand_raise':
        if (p != null && mounted) {
          setState(() => _handStates[p.identity] = data['value']);
        }
        break;
      case 'spotlight':
        if (mounted) setState(() => _spotlightUserId = data['value']);
        break;
    }
  }

  String _getZoneArabicName(String zone) {
    if (zone.startsWith('screen_')) {
      final num = zone.split('_').last;
      return 'شاشة $num';
    }
    if (zone == 'right') return 'شاشة 1';
    if (zone == 'center') return 'شاشة 2';
    return 'شاشة 3';
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
    // تصفية المقاعد الخاصة بهذه المنطقة فقط
    final zoneSeats = _allSeats.where((s) => s['zone'] == widget.zone).toList()
      ..sort((a, b) =>
          (a['seat_number'] as int).compareTo(b['seat_number'] as int));

    return Scaffold(
      backgroundColor: const Color(0xFF0F1014),
      body: Stack(
        children: [
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
                  padding: const EdgeInsets.all(12.0),
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                    SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: _seatsPerScreen <= 8 ? 2 : 4,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.5,
                    ),
                    itemCount: _seatsPerScreen,
                    itemBuilder: (context, index) {
                      final seat = index < zoneSeats.length
                          ? zoneSeats[index]
                          : null;

                      final String? studentId = seat?['student_id'];
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
                        child: _buildSeatTile(seat, participant),
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
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 30),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.7),
            border: Border(
              bottom: BorderSide(color: Colors.blue.withOpacity(0.2)),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.monitor_rounded, color: Colors.blue, size: 28),
              const SizedBox(width: 20),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "شاشة عرض القاعة الذكية",
                    style: TextStyle(
                      color: Colors.blue.withOpacity(0.7),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Cairo',
                    ),
                  ),
                  Text(
                    _getZoneArabicName(widget.zone),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: const Row(
        children: [
          _PulseIcon(),
          SizedBox(width: 8),
          Text(
            "LIVE",
            style: TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeatTile(Map<String, dynamic>? seat, RemoteParticipant? p) {
    final bool isOccupied =
        seat != null && seat['student_id'] != null && (seat['student_id'] as String).isNotEmpty;
    final bool isOnline = p != null;
    final bool isSpeaking = p?.isSpeaking ?? false;
    final int? seatNum = seat?['seat_number'];

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isSpeaking
              ? Colors.greenAccent
              : (isOnline
              ? Colors.blue.withOpacity(0.3)
              : Colors.white.withOpacity(0.05)),
          width: isSpeaking ? 3 : 1,
        ),
        color: isOccupied ? const Color(0xFF1E1F23) : Colors.white.withOpacity(0.02),
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
            _buildOfflineState(seat!['student_name'] ?? "طالب")
          else
            _buildEmptyState(seatNum),

          Positioned(
            top: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                seatNum != null ? "مقعد $seatNum" : "--",
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Cairo',
                ),
              ),
            ),
          ),
          if (isSpeaking)
            Positioned(top: 12, right: 12, child: _SpeakingIndicator()),
        ],
      ),
    );
  }

  Widget _buildEmptyState(int? num) {
    return Center(
      child: Opacity(
        opacity: 0.1,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.person_outline_rounded, color: Colors.white, size: 40),
            Text(
              "شاغر",
              style: const TextStyle(color: Colors.white, fontFamily: 'Cairo', fontSize: 12),
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
          Text(
            name,
            style: const TextStyle(color: Colors.white, fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 5),
          Text(
            "غير متصل",
            style: TextStyle(color: Colors.white24, fontSize: 10, fontFamily: 'Cairo'),
          ),
        ],
      ),
    );
  }
}

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
      child: const Icon(Icons.fiber_manual_record, color: Colors.red, size: 10),
    );
  }
}

class _SpeakingIndicator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: const BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle),
      child: const Icon(Icons.mic_rounded, color: Colors.black, size: 12),
    );
  }
}
