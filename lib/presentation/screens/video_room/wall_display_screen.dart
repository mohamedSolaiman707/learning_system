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
      ..on<ParticipantConnectedEvent>((event) {
        if (mounted) setState(() {});
      })
      ..on<ParticipantDisconnectedEvent>((event) {
        if (mounted) {
          setState(() => _handStates.remove(event.participant.identity));
        }
      })
      ..on<TrackPublishedEvent>((event) {
        if (mounted) setState(() {});
      })
      ..on<TrackSubscribedEvent>((event) {
        if (mounted) setState(() {});
      })
      ..on<TrackUnsubscribedEvent>((event) {
        if (mounted) setState(() {});
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

  /// يحدد عدد الأعمدة بناءً على عدد المقاعد الكلي لضمان أفضل تقسيم
  int _getCrossAxisCount(int total) {
    if (total <= 1) return 1;
    if (total <= 2) return 2;
    if (total <= 4) return 2;
    if (total <= 6) return 3;
    if (total <= 8) return 4; // 4 أعمدة × 2 صفوف
    if (total <= 9) return 3;
    if (total <= 12) return 4;
    if (total <= 16) return 4;
    return 4;
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
              : LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final h = constraints.maxHeight;
              final cols = _getCrossAxisCount(_seatsPerScreen);
              final rows = (_seatsPerScreen / cols).ceil();
              const gap = 8.0;
              const pad = 8.0;

              return Column(
                children: [
                  _buildHeader(w),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(pad),
                      child: LayoutBuilder(
                        builder: (ctx, innerConstraints) {
                          final availW = innerConstraints.maxWidth;
                          final availH = innerConstraints.maxHeight;
                          // نحسب حجم كل مقعد بدقة لضمان ملء الشاشة كاملاً
                          final tileW = (availW - gap * (cols - 1)) / cols;
                          final tileH = (availH - gap * (rows - 1)) / rows;

                          return Column(
                            mainAxisSize: MainAxisSize.max,
                            children: List.generate(rows, (rowIndex) {
                              return Padding(
                                padding: EdgeInsets.only(bottom: rowIndex < rows - 1 ? gap : 0),
                                child: Row(
                                  mainAxisSize: MainAxisSize.max,
                                  children: List.generate(cols, (colIndex) {
                                    final index = rowIndex * cols + colIndex;
                                    if (index >= _seatsPerScreen) {
                                      // خلية فارغة لملء الصف الأخير
                                      return SizedBox(width: tileW + (colIndex < cols - 1 ? gap : 0), height: tileH);
                                    }
                                    final seat = index < zoneSeats.length ? zoneSeats[index] : null;
                                    final String? studentId = seat?['student_id'];
                                    RemoteParticipant? participant;
                                    if (studentId != null && studentId.isNotEmpty) {
                                      participant = _room!.remoteParticipants.values.where((p) {
                                        final cleanId = p.identity.split('_').first;
                                        return p.identity.contains(studentId) || cleanId == studentId;
                                      }).firstOrNull;
                                    }
                                    return Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        SizedBox(
                                          width: tileW,
                                          height: tileH,
                                          child: AnimatedSwitcher(
                                            duration: const Duration(milliseconds: 800),
                                            switchInCurve: Curves.easeOutBack,
                                            child: _buildSeatTile(seat, participant, w),
                                          ),
                                        ),
                                        if (colIndex < cols - 1) SizedBox(width: gap),
                                      ],
                                    );
                                  }),
                                ),
                              );
                            }),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(double screenWidth) {
    final isSmall = screenWidth < 600;
    final hPad = isSmall ? 12.0 : 30.0;
    final vPad = isSmall ? 8.0 : 15.0;
    final iconSize = isSmall ? 18.0 : 28.0;
    final subtitleSize = isSmall ? 8.0 : 10.0;
    final titleSize = isSmall ? 14.0 : 20.0;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: vPad, horizontal: hPad),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.7),
            border: Border(
              bottom: BorderSide(color: Colors.blue.withOpacity(0.2)),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.monitor_rounded, color: Colors.blue, size: iconSize),
              SizedBox(width: isSmall ? 8 : 20),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "شاشة عرض القاعة الذكية",
                    style: TextStyle(
                      color: Colors.blue.withOpacity(0.7),
                      fontSize: subtitleSize,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Cairo',
                    ),
                  ),
                  Text(
                    _getZoneArabicName(widget.zone),
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: titleSize,
                      fontFamily: 'Cairo',
                    ),
                  ),
                ],
              ),
              const Spacer(),
              _buildLiveBadge(isSmall),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLiveBadge(bool isSmall) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmall ? 6 : 12,
        vertical: isSmall ? 3 : 6,
      ),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const _PulseIcon(),
          SizedBox(width: isSmall ? 4 : 8),
          Text(
            "LIVE",
            style: TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.w900,
              fontSize: isSmall ? 9 : 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeatTile(Map<String, dynamic>? seat, RemoteParticipant? p, double screenWidth) {
    final bool isOccupied =
        seat != null && seat['student_id'] != null && (seat['student_id'] as String).isNotEmpty;
    final bool isOnline = p != null;
    final bool isSpeaking = p?.isSpeaking ?? false;
    final int? seatNum = seat?['seat_number'];

    final isSmall = screenWidth < 600;
    final labelFontSize = isSmall ? 8.0 : 10.0;
    final labelPadH = isSmall ? 6.0 : 10.0;
    final labelPadV = isSmall ? 2.0 : 4.0;
    final labelTop = isSmall ? 6.0 : 12.0;
    final labelLeft = isSmall ? 6.0 : 12.0;
    final borderRadius = isSmall ? 14.0 : 24.0;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
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
            _buildOfflineState(seat!['student_name'] ?? "طالب", isSmall)
          else
            _buildEmptyState(seatNum, isSmall),

          Positioned(
            top: labelTop,
            left: labelLeft,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: labelPadH, vertical: labelPadV),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                seatNum != null ? "مقعد $seatNum" : "--",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: labelFontSize,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Cairo',
                ),
              ),
            ),
          ),
          if (isSpeaking)
            Positioned(top: labelTop, right: labelLeft, child: _SpeakingIndicator()),
        ],
      ),
    );
  }

  Widget _buildEmptyState(int? num, bool isSmall) {
    return Center(
      child: Opacity(
        opacity: 0.1,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_outline_rounded, color: Colors.white, size: isSmall ? 24 : 40),
            Text(
              "شاغر",
              style: TextStyle(color: Colors.white, fontFamily: 'Cairo', fontSize: isSmall ? 9 : 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOfflineState(String name, bool isSmall) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              name,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
              style: TextStyle(color: Colors.white, fontFamily: 'Cairo', fontSize: isSmall ? 10 : 15, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: isSmall ? 2 : 5),
            Text(
              "غير متصل",
              style: TextStyle(color: Colors.white24, fontSize: isSmall ? 8 : 10, fontFamily: 'Cairo'),
            ),
          ],
        ),
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
