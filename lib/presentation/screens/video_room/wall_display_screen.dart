import 'dart:async';
import 'dart:convert';
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
  List<String> _zoneStudentIds = [];
  bool _isLoading = true;
  StreamSubscription? _seatsSubscription;

  // تتبع الحالات القادمة من البث مباشرة (رفع اليد والتمييز)
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

    // 1. تحميل المقاعد وتحديد الطلاب المنتمين لهذه المنطقة
    try {
      final seats = await db.getSeats(widget.sessionId);
      _zoneStudentIds = seats
          .where((s) => s['zone'] == widget.zone && s['student_id'] != null)
          .map((s) => s['student_id'] as String)
          .toList();
    } catch (e) {
      debugPrint("Error loading initial seats: $e");
    }

    // 2. الاتصال بـ LiveKit كـ Subscriber (للعرض فقط)
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

    // 3. الاستماع لتحديثات المقاعد من Supabase (إذا غير طالب مكانه)
    _seatsSubscription = Supabase.instance.client
        .from('seats')
        .stream(primaryKey: ['id'])
        .eq('session_id', widget.sessionId)
        .listen((data) {
          if (mounted) {
            setState(() {
              _zoneStudentIds = data
                  .where(
                    (s) => s['zone'] == widget.zone && s['student_id'] != null,
                  )
                  .map((s) => s['student_id'] as String)
                  .toList();
            });
          }
        });

    if (mounted) {
      setState(() => _isLoading = false);
    }
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
        if (mounted) {
          setState(() => _spotlightUserId = data['value']);
        }
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.blue))
          : _room == null
          ? const Center(
              child: Text(
                "فشل الاتصال بالقاعة",
                style: TextStyle(color: Colors.white, fontFamily: 'Cairo'),
              ),
            )
          : ListenableBuilder(
              listenable: _room!,
              builder: (context, _) {
                // تصفية المشاركين المنتمين لهذه المنطقة فقط
                final participants = _room!.remoteParticipants.values.where((
                  p,
                ) {
                  final cleanId = p.identity.split('_').first;
                  return _zoneStudentIds.any(
                    (id) => p.identity.contains(id) || cleanId == id,
                  );
                }).toList();

                // ترتيب المشاركين: الطالب المميز أولاً، ثم من يرفع يده
                participants.sort((a, b) {
                  if (a.identity == _spotlightUserId) return -1;
                  if (b.identity == _spotlightUserId) return 1;

                  bool handA = _handStates[a.identity] ?? false;
                  bool handB = _handStates[b.identity] ?? false;
                  if (handA && !handB) return -1;
                  if (!handA && handB) return 1;

                  return 0;
                });

                if (participants.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.group_off_rounded,
                          color: Colors.white24,
                          size: 60,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "لا يوجد طلاب في منطقة ${_getZoneArabicName(widget.zone)} حالياً",
                          style: const TextStyle(
                            color: Colors.white,
                            fontFamily: 'Cairo',
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  children: [
                    // شريط علوي يوضح المنطقة وحالة الاتصال
                    Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 20,
                      ),
                      color: Colors.blue.withOpacity(0.1),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.tv_rounded,
                            color: Colors.blue,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            "عرض المنطقة: ${_getZoneArabicName(widget.zone)}",
                            style: const TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Cairo',
                              fontSize: 14,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            "${participants.length} طلاب متصلين في هذه الجهة",
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                              fontFamily: 'Cairo',
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: GridView.builder(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                              childAspectRatio: 16 / 9,
                            ),
                        padding: const EdgeInsets.all(12),
                        itemCount: participants.length,
                        itemBuilder: (context, i) {
                          final p = participants[i];
                          final isSpotlight = p.identity == _spotlightUserId;

                          return ParticipantTile(
                            key: ValueKey(p.identity),
                            participant: p,
                            isMainStage:
                                isSpotlight, // تكبير الصورة إذا كان مميزاً
                            forceHandRaised:
                                _handStates[p
                                    .identity], // تمرير حالة رفع اليد يدوياً
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}
