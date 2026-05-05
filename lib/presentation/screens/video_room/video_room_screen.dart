import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconly/iconly.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/livekit_service.dart';
import '../teacher/attendance/attendance_screen.dart';

// موديل الرسم الاحترافي
class Stroke {
  final List<Offset> points;
  final Color color;
  final double width;
  Stroke({required this.points, required this.color, required this.width});
}

class VideoRoomScreen extends StatefulWidget {
  final String title;
  final String roomName;
  final String userName;
  final bool isTeacher;
  final String? sessionId;

  const VideoRoomScreen({
    super.key,
    required this.title,
    required this.roomName,
    required this.userName,
    this.isTeacher = false,
    this.sessionId,
  });

  @override
  State<VideoRoomScreen> createState() => _VideoRoomScreenState();
}

class _VideoRoomScreenState extends State<VideoRoomScreen>
    with TickerProviderStateMixin {
  Room? _room;
  EventsListener<RoomEvent>? _listener;
  bool _isLoading = true;
  String? _errorMessage;
  String? _currentActiveRoom;
  bool _isMicEnabled = false;
  bool _isCamEnabled = false;
  bool _isHandRaised = false;
  bool _isChatOpen = false;
  bool _isParticipantsOpen = false;
  bool _isPollsOpen = false;
  bool _isBreakoutOpen = false;
  bool _isWhiteboardOpen = false;
  bool _isScreenSharing = false;
  bool _isChatLocked = false;
  bool _isMicLocked = false;
  String? _classCode;

  // Whiteboard State
  final List<Stroke> _whiteboardStrokes = [];
  final List<Stroke> _redoStack = [];
  List<Offset> _currentStrokePoints = [];
  Color _selectedColor = Colors.black;
  double _strokeWidth = 3.0;
  bool _isEraserMode = false;

  // Poll State
  Map<String, dynamic>? _activePoll;
  Map<String, int> _pollResults = {};
  String? _myVote;

  final _messageController = TextEditingController();
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _messages = [];
  Timer? _chatTimer;

  final Map<String, bool> _remoteHandStates = {};
  final List<Widget> _reactionParticles = [];

  @override
  void initState() {
    super.initState();
    _currentActiveRoom = widget.roomName;
    _connectToRoom(_currentActiveRoom!);
    _chatTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_isChatOpen) _fetchMessages();
    });
    if (widget.isTeacher && widget.sessionId != null) {
      _fetchClassCode();
    }
  }

  Future<void> _fetchClassCode() async {
    try {
      final res = await supabase
          .from('sessions')
          .select('class_code')
          .eq('id', widget.sessionId!)
          .single();
      if (mounted) setState(() => _classCode = res['class_code']);
    } catch (e) {
      debugPrint("Error fetching class code: $e");
    }
  }

  Future<void> _connectToRoom(String roomName) async {
    setState(() => _isLoading = true);
    try {
      final token = await LiveKitService().getRoomToken(
        roomName,
        widget.userName,
      );
      if (token == null) throw "فشل الحصول على تصريح الدخول (Token)";

      if (_room != null) {
        await _listener?.dispose();
        await _room!.disconnect();
      }

      final room = Room();
      _room = room;
      _listener = room.createListener();

      _listener!.on<DataReceivedEvent>((event) {
        final decoded = utf8.decode(event.data);
        final data = jsonDecode(decoded);

        if (data['type'] == 'poll_create') {
          setState(() {
            _activePoll = data['poll'];
            _pollResults = {for (var item in data['poll']['options']) item: 0};
            _myVote = null;
            _isPollsOpen = true;
            _isChatOpen = false;
            _isParticipantsOpen = false;
            _isWhiteboardOpen = false;
          });
        } else if (data['type'] == 'poll_vote') {
          setState(() {
            final option = data['option'];
            _pollResults[option] = (_pollResults[option] ?? 0) + 1;
          });
        } else if (data['type'] == 'poll_end') {
          setState(() {
            _activePoll = null;
            if (!widget.isTeacher) _isPollsOpen = false;
          });
        } else if (data['type'] == 'breakout_invite' &&
            data['target'] == widget.userName) {
          _showBreakoutInvitation(data['room'], data['groupName']);
        } else if (data['type'] == 'hand_raise') {
          final p = event.participant;
          if (p != null)
            setState(() => _remoteHandStates[p.identity] = data['value']);
        } else if (data['type'] == 'reaction') {
          _showReactionEffect(data['value']);
        } else if (data['type'] == 'whiteboard_draw') {
          _handleRemoteDraw(data);
        } else if (data['type'] == 'whiteboard_clear') {
          setState(() {
            _whiteboardStrokes.clear();
            _redoStack.clear();
          });
        } else if (data['type'] == 'whiteboard_undo') {
          _executeUndo(remote: true);
        } else if (data['type'] == 'whiteboard_redo') {
          _executeRedo(remote: true);
        } else if (data['type'] == 'control_mic' &&
            (data['target'] == widget.userName || data['target'] == null)) {
          if (!widget.isTeacher) {
            bool lock = data['lock'] ?? false;
            bool val = data['value'] ?? false;
            _room?.localParticipant?.setMicrophoneEnabled(val);
            setState(() {
              _isMicEnabled = val;
              _isMicLocked = lock;
            });
            _showAuthoritySnackBar(lock, val);
          }
        } else if (data['type'] == 'control_chat') {
          setState(() => _isChatLocked = data['value']);
        }
      });

      await room.connect('wss://learning-system-07wdu0v6.livekit.cloud', token);

      if (widget.isTeacher || roomName != widget.roomName) {
        await room.localParticipant?.setCameraEnabled(true);
        await room.localParticipant?.setMicrophoneEnabled(true);
        if (mounted)
          setState(() {
            _isMicEnabled = true;
            _isCamEnabled = true;
          });
      }

      setState(() {
        _isLoading = false;
        _currentActiveRoom = roomName;
      });
    } catch (e) {
      setState(() {
        _errorMessage = "خطأ في الاتصال: $e";
        _isLoading = false;
      });
    }
  }

  void _showAuthoritySnackBar(bool lock, bool val) {
    String msg = lock
        ? "المدرس قام بقفل الميكروفونات"
        : (val ? "سمح لك المدرس بالتحدث الآن" : "المدرس قام بكتم صوتك");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(lock ? Icons.lock : Icons.info, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(msg),
          ],
        ),
        backgroundColor: lock ? Colors.redAccent : Colors.blue,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _sendData(Map<String, dynamic> data) async {
    if (_room == null) return;
    final bytes = utf8.encode(jsonEncode(data));
    await _room!.localParticipant?.publishData(bytes);
  }

  // --- Whiteboard Logic ---
  void _handleRemoteDraw(Map<String, dynamic> data) {
    if (data['points'] != null) {
      List<Offset> pts = (data['points'] as List)
          .map((p) => Offset(p['x'].toDouble(), p['y'].toDouble()))
          .toList();
      setState(() {
        _whiteboardStrokes.add(
          Stroke(
            points: pts,
            color: Color(data['color']),
            width: data['width'].toDouble(),
          ),
        );
        _redoStack.clear();
      });
    }
  }

  void _executeUndo({bool remote = false}) {
    if (_whiteboardStrokes.isNotEmpty) {
      setState(() {
        _redoStack.add(_whiteboardStrokes.removeLast());
      });
      if (!remote) _sendData({'type': 'whiteboard_undo'});
    }
  }

  void _executeRedo({bool remote = false}) {
    if (_redoStack.isNotEmpty) {
      setState(() {
        _whiteboardStrokes.add(_redoStack.removeLast());
      });
      if (!remote) _sendData({'type': 'whiteboard_redo'});
    }
  }

  // --- Master Control Logic ---
  void _toggleMicLock(bool lock) {
    _sendData({'type': 'control_mic', 'value': false, 'lock': lock});
    setState(() => _isMicLocked = lock);
  }

  void _toggleStudentMic(Participant p) {
    bool isOn = p.isMicrophoneEnabled();
    _sendData({
      'type': 'control_mic',
      'target': p.identity,
      'value': !isOn,
      'lock': isOn, // لو بنقفله يبقا بنعمله Lock
    });
  }

  void _createPoll(String question, List<String> options) {
    if (question.isEmpty) return;
    final pollData = {
      'question': question,
      'options': options,
      'creator': widget.userName,
    };
    _sendData({'type': 'poll_create', 'poll': pollData});
    setState(() {
      _activePoll = pollData;
      _pollResults = {for (var item in options) item: 0};
    });
  }

  void _submitVote(String option) {
    if (_myVote != null) return;
    _sendData({'type': 'poll_vote', 'option': option});
    setState(() {
      _myVote = option;
      _pollResults[option] = (_pollResults[option] ?? 0) + 1;
    });
  }

  void _endPoll() {
    _sendData({'type': 'poll_end'});
    setState(() => _activePoll = null);
  }

  void _showBreakoutInvitation(String roomName, String groupName) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("مجموعات العمل الفرعية"),
        content: Text(
          "المدرس يدعوك للانضمام إلى $groupName. هل تود الانتقال الآن؟",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("لاحقاً"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _connectToRoom(roomName);
            },
            child: const Text("انضمام الآن"),
          ),
        ],
      ),
    );
  }

  void _startBreakout(int groupCount) {
    final participants = _room!.remoteParticipants.values.toList();
    if (participants.isEmpty) return;
    participants.shuffle();
    for (int i = 0; i < participants.length; i++) {
      final groupId = (i % groupCount) + 1;
      _sendData({
        'type': 'breakout_invite',
        'target': participants[i].identity,
        'room': "${widget.roomName}_grp_$groupId",
        'groupName': "المجموعة $groupId",
      });
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("تم إرسال دعوات المجموعات للطلاب")),
    );
  }

  void _showReactionEffect(String emoji) {
    if (!mounted) return;
    final key = UniqueKey();
    setState(() {
      _reactionParticles.add(
        _FloatingEmoji(
          key: key,
          emoji: emoji,
          onFinished: () {
            if (mounted)
              setState(
                () => _reactionParticles.removeWhere((w) => w.key == key),
              );
          },
        ),
      );
    });
  }

  Future<void> _fetchMessages() async {
    try {
      final response = await supabase
          .from('messages')
          .select()
          .eq('room_name', widget.roomName)
          .order('created_at', ascending: true)
          .limit(50);
      if (mounted)
        setState(() {
          _messages = List<Map<String, dynamic>>.from(response);
        });
    } catch (e) {
      debugPrint("Chat error: $e");
    }
  }

  void _sendMessage() async {
    if (_isChatLocked && !widget.isTeacher) return;
    if (_messageController.text.isEmpty) return;
    final content = _messageController.text;
    _messageController.clear();
    try {
      await supabase.from('messages').insert({
        'room_name': widget.roomName,
        'user_name': widget.userName,
        'content': content,
      });
      _fetchMessages();
    } catch (e) {
      debugPrint("Insert error: $e");
    }
  }

  void _shareInvite() {
    if (_classCode == null) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("دعوة الطلاب"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("شارك كود الحصة مع الطلاب لينضموا إليك:"),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Text(
                _classCode!,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                  color: Colors.blue,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("إغلاق"),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _classCode!));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("تم نسخ الكود بنجاح")),
              );
              Navigator.pop(context);
            },
            icon: const Icon(Icons.copy),
            label: const Text("نسخ الكود"),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _listener?.dispose();
    _room?.disconnect();
    _chatTimer?.cancel();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool inSubRoom = _currentActiveRoom != widget.roomName;
    return Scaffold(
      backgroundColor: const Color(0xFF0F1014),
      body: _isLoading
          ? _buildLoadingState()
          : Stack(
              children: [
                if (_room != null)
                  ParticipantLayout(
                    room: _room!,
                    remoteHands: _remoteHandStates,
                    localHand: _isHandRaised,
                    isTeacher: widget.isTeacher,
                    isWhiteboardOpen: _isWhiteboardOpen,
                    onControlMic: (id, val) => _sendData({
                      'type': 'control_mic',
                      'target': id,
                      'value': val,
                      'lock': false,
                    }),
                  ),
                if (_isWhiteboardOpen) _buildWhiteboardLayer(),
                ..._reactionParticles,
                if (_isChatOpen) _buildChatPanel(),
                if (_isParticipantsOpen) _buildParticipantsPanel(),
                if (_isPollsOpen) _buildPollsPanel(),
                if (_isBreakoutOpen) _buildBreakoutPanel(),
                _buildTopBar(inSubRoom),
                _buildBottomControls(),
              ],
            ),
    );
  }

  Widget _buildWhiteboardLayer() {
    return Positioned.fill(
      top: 100,
      bottom: 120,
      child: Container(
        margin: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 20)],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              GestureDetector(
                onPanStart: (details) {
                  setState(() {
                    _currentStrokePoints = [details.localPosition];
                  });
                },
                onPanUpdate: (details) {
                  setState(() {
                    _currentStrokePoints.add(details.localPosition);
                  });
                },
                onPanEnd: (details) {
                  final stroke = Stroke(
                    points: List.from(_currentStrokePoints),
                    color: _isEraserMode ? Colors.white : _selectedColor,
                    width: _isEraserMode ? 25.0 : _strokeWidth,
                  );
                  _sendData({
                    'type': 'whiteboard_draw',
                    'points': stroke.points
                        .map((p) => {'x': p.dx, 'y': p.dy})
                        .toList(),
                    'color': stroke.color.value,
                    'width': stroke.width,
                  });
                  setState(() {
                    _whiteboardStrokes.add(stroke);
                    _redoStack.clear();
                    _currentStrokePoints = [];
                  });
                },
                child: CustomPaint(
                  painter: WhiteboardPainter(
                    strokes: _whiteboardStrokes,
                    currentPoints: _currentStrokePoints,
                    currentColor: _selectedColor,
                    currentWidth: _strokeWidth,
                    isEraser: _isEraserMode,
                  ),
                  size: Size.infinite,
                ),
              ),
              Positioned(top: 20, left: 20, child: _buildWhiteboardToolbar()),
              Positioned(
                top: 20,
                right: 20,
                child: FloatingActionButton.small(
                  heroTag: "close_wb",
                  onPressed: () => setState(() => _isWhiteboardOpen = false),
                  backgroundColor: Colors.black54,
                  child: const Icon(Icons.close),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWhiteboardToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(25),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _colorPicker(Colors.black),
          _colorPicker(Colors.red),
          _colorPicker(Colors.blue),
          _colorPicker(Colors.green),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(
              Icons.cleaning_services,
              color: _isEraserMode ? Colors.blue : Colors.white,
              size: 20,
            ),
            onPressed: () => setState(() => _isEraserMode = !_isEraserMode),
            tooltip: "الممحاة",
          ),
          const VerticalDivider(color: Colors.white24),
          IconButton(
            icon: const Icon(Icons.undo, color: Colors.white, size: 20),
            onPressed: _whiteboardStrokes.isEmpty ? null : _executeUndo,
            tooltip: "تراجع",
          ),
          IconButton(
            icon: const Icon(Icons.redo, color: Colors.white, size: 20),
            onPressed: _redoStack.isEmpty ? null : _executeRedo,
            tooltip: "إعادة",
          ),
          IconButton(
            icon: const Icon(
              Icons.delete_forever,
              color: Colors.redAccent,
              size: 20,
            ),
            onPressed: () {
              setState(() {
                _whiteboardStrokes.clear();
                _redoStack.clear();
              });
              _sendData({'type': 'whiteboard_clear'});
            },
            tooltip: "مسح الكل",
          ),
        ],
      ),
    );
  }

  Widget _colorPicker(Color color) {
    bool isSelected = _selectedColor == color && !_isEraserMode;
    return GestureDetector(
      onTap: () => setState(() {
        _selectedColor = color;
        _isEraserMode = false;
      }),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.white : Colors.transparent,
            width: 2,
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Colors.blue),
          const SizedBox(height: 20),
          Text(
            _errorMessage ?? "جاري الاتصال بالقاعة...",
            style: const TextStyle(color: Colors.white),
          ),
          if (_errorMessage != null)
            TextButton(
              onPressed: () => _connectToRoom(widget.roomName),
              child: const Text("إعادة المحاولة"),
            ),
        ],
      ),
    );
  }

  Widget _buildTopBar(bool inSubRoom) {
    return Positioned(
      top: 40,
      left: 20,
      right: 20,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.circle,
                  color: inSubRoom ? Colors.orange : Colors.red,
                  size: 8,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    inSubRoom
                        ? "غرفة فرعية: $_currentActiveRoom"
                        : widget.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                if (inSubRoom)
                  IconButton(
                    icon: const Icon(Icons.exit_to_app, color: Colors.orange),
                    onPressed: () => _connectToRoom(widget.roomName),
                    tooltip: "العودة للقاعة الرئيسية",
                  ),
                if (widget.isTeacher && _classCode != null)
                  IconButton(
                    icon: const Icon(Icons.share, color: Colors.white70),
                    tooltip: "دعوة طلاب",
                    onPressed: _shareInvite,
                  ),
                IconButton(
                  icon: Icon(
                    Icons.edit_note,
                    color: _isWhiteboardOpen ? Colors.blue : Colors.white70,
                  ),
                  tooltip: "السبورة الذكية",
                  onPressed: () => setState(() {
                    _isWhiteboardOpen = !_isWhiteboardOpen;
                    _isChatOpen = false;
                    _isParticipantsOpen = false;
                    _isPollsOpen = false;
                  }),
                ),
                IconButton(
                  icon: Icon(
                    IconlyLight.graph,
                    color: _isPollsOpen ? Colors.blue : Colors.white70,
                  ),
                  tooltip: "التصويت المباشر",
                  onPressed: () => setState(() {
                    _isPollsOpen = !_isPollsOpen;
                    _isChatOpen = false;
                    _isParticipantsOpen = false;
                    _isBreakoutOpen = false;
                    _isWhiteboardOpen = false;
                  }),
                ),
                if (widget.isTeacher)
                  IconButton(
                    icon: Icon(
                      Icons.groups_outlined,
                      color: _isBreakoutOpen ? Colors.blue : Colors.white70,
                    ),
                    tooltip: "تقسيم المجموعات",
                    onPressed: () => setState(() {
                      _isBreakoutOpen = !_isBreakoutOpen;
                      _isChatOpen = false;
                      _isParticipantsOpen = false;
                      _isPollsOpen = false;
                    }),
                  ),
                IconButton(
                  icon: Icon(
                    IconlyLight.user_1,
                    color: _isParticipantsOpen ? Colors.blue : Colors.white70,
                  ),
                  tooltip: "المشاركين",
                  onPressed: () => setState(() {
                    _isParticipantsOpen = !_isParticipantsOpen;
                    _isChatOpen = false;
                    _isPollsOpen = false;
                    _isBreakoutOpen = false;
                  }),
                ),
                IconButton(
                  icon: Icon(
                    IconlyLight.chat,
                    color: _isChatOpen ? Colors.blue : Colors.white70,
                  ),
                  tooltip: "الدردشة",
                  onPressed: () => setState(() {
                    _isChatOpen = !_isChatOpen;
                    _isParticipantsOpen = false;
                    _isPollsOpen = false;
                    _isBreakoutOpen = false;
                  }),
                ),
                IconButton(
                  icon: const Icon(Icons.logout_rounded, color: Colors.white70),
                  tooltip: "مغادرة القاعة",
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBreakoutPanel() {
    return Positioned(
      top: 110,
      right: 20,
      child: Container(
        width: 250,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1F26).withOpacity(0.95),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "تقسيم المجموعات",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [2, 3, 4]
                  .map(
                    (n) => ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueGrey,
                      ),
                      onPressed: () {
                        _startBreakout(n);
                        setState(() => _isBreakoutOpen = false);
                      },
                      child: Text("$n"),
                    ),
                  )
                  .toList(),
            ),
            const Text(
              "اختر عدد المجموعات",
              style: TextStyle(color: Colors.grey, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPollsPanel() {
    return Positioned(
      top: 110,
      right: 20,
      bottom: 120,
      child: Container(
        width: 300,
        decoration: BoxDecoration(
          color: const Color(0xFF1C1F26).withOpacity(0.95),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                "التصويت المباشر",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (_activePoll == null && widget.isTeacher) _buildPollCreator(),
            if (_activePoll != null)
              Expanded(child: SingleChildScrollView(child: _buildActivePoll())),
            if (_activePoll == null && !widget.isTeacher)
              const Expanded(
                child: Center(
                  child: Text(
                    "لا يوجد تصويت حالياً",
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPollCreator() {
    final qController = TextEditingController();
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            controller: qController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: "السؤال...",
              hintStyle: TextStyle(color: Colors.grey),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () =>
                _createPoll(qController.text, ["نعم", "لا", "غير متأكد"]),
            child: const Text("بدء التصويت"),
          ),
        ],
      ),
    );
  }

  Widget _buildActivePoll() {
    int total = _pollResults.values.fold(0, (sum, val) => sum + val);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _activePoll!['question'],
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ...(_activePoll!['options'] as List).map((opt) {
            double percent = total == 0 ? 0 : (_pollResults[opt] ?? 0) / total;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: () => _submitVote(opt),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          opt,
                          style: TextStyle(
                            color: _myVote == opt
                                ? Colors.blue
                                : Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          "${(percent * 100).toInt()}%",
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: percent,
                      backgroundColor: Colors.white10,
                      color: _myVote == opt
                          ? Colors.blue
                          : Colors.blue.withOpacity(0.3),
                    ),
                  ],
                ),
              ),
            );
          }),
          if (widget.isTeacher) ...[
            const SizedBox(height: 16),
            TextButton(
              onPressed: _endPoll,
              child: const Text(
                "إنهاء التصويت",
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildParticipantsPanel() {
    if (_room == null) return const SizedBox.shrink();
    final List<Participant> participants = [
      if (_room!.localParticipant != null) _room!.localParticipant!,
      ..._room!.remoteParticipants.values,
    ];
    return Positioned(
      top: 110,
      right: 20,
      bottom: 120,
      child: Container(
        width: 280,
        decoration: BoxDecoration(
          color: const Color(0xFF1C1F26).withOpacity(0.95),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          children: [
            if (widget.isTeacher)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => _toggleMicLock(true),
                          icon: const Icon(Icons.lock, size: 14),
                          label: const Text(
                            "قفل المايكات",
                            style: TextStyle(fontSize: 11),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () => _toggleMicLock(false),
                          icon: const Icon(Icons.lock_open, size: 14),
                          label: const Text(
                            "فتح القفل",
                            style: TextStyle(fontSize: 11),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                        ),
                      ],
                    ),
                    const Divider(color: Colors.white10),
                  ],
                ),
              ),
            Expanded(
              child: ListView.builder(
                itemCount: participants.length,
                itemBuilder: (context, i) {
                  final p = participants[i];
                  final bool isLocal =
                      p.identity == _room?.localParticipant?.identity;
                  return ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Colors.white10,
                      radius: 15,
                      child: Icon(
                        Icons.person,
                        size: 15,
                        color: Colors.white70,
                      ),
                    ),
                    title: Text(
                      p.identity,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                    trailing: widget.isTeacher && !isLocal
                        ? IconButton(
                            icon: Icon(
                              p.isMicrophoneEnabled()
                                  ? Icons.mic
                                  : Icons.mic_off,
                              color: p.isMicrophoneEnabled()
                                  ? Colors.green
                                  : Colors.red,
                              size: 18,
                            ),
                            onPressed: () => _toggleStudentMic(p),
                          )
                        : Icon(
                            p.isMicrophoneEnabled() ? Icons.mic : Icons.mic_off,
                            color: p.isMicrophoneEnabled()
                                ? Colors.green
                                : Colors.grey,
                            size: 16,
                          ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatPanel() {
    return Positioned(
      top: 110,
      right: 20,
      bottom: 120,
      child: Container(
        width: 300,
        decoration: BoxDecoration(
          color: const Color(0xFF1C1F26).withOpacity(0.95),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "الدردشة العامة",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  if (widget.isTeacher)
                    Tooltip(
                      message: _isChatLocked ? "فتح الدردشة" : "قفل الدردشة",
                      child: Switch(
                        value: _isChatLocked,
                        onChanged: (val) {
                          _sendData({'type': 'control_chat', 'value': val});
                          setState(() => _isChatLocked = val);
                        },
                        activeColor: Colors.red,
                      ),
                    ),
                ],
              ),
            ),
            const Divider(color: Colors.white10, height: 1),
            Expanded(
              child: ListView.builder(
                itemCount: _messages.length,
                itemBuilder: (context, i) => _buildMessageBubble(_messages[i]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      enabled: !_isChatLocked || widget.isTeacher,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: _isChatLocked ? "الدردشة مغلقة" : "دردشة...",
                        hintStyle: const TextStyle(color: Colors.grey),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _sendMessage,
                    icon: const Icon(IconlyBold.send, color: Colors.blue),
                    tooltip: "إرسال",
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg) {
    bool isMe = msg['user_name'] == widget.userName;
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: isMe
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Text(
            msg['user_name'] ?? "",
            style: const TextStyle(color: Colors.grey, fontSize: 10),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isMe ? Colors.blue : Colors.white10,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              msg['content'] ?? "",
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    return Positioned(
      bottom: 40,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1F26).withOpacity(0.8),
          borderRadius: BorderRadius.circular(40),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildCircleBtn(
              _isMicLocked && !widget.isTeacher
                  ? Icons.mic_off
                  : (_isMicEnabled ? IconlyBold.voice : IconlyBold.voice_2),
              _isMicLocked && !widget.isTeacher
                  ? Colors.grey
                  : (_isMicEnabled ? Colors.white12 : Colors.red),
              tooltip: _isMicLocked && !widget.isTeacher
                  ? "المايك مقفل من المدرس"
                  : (_isMicEnabled ? "كتم المايك" : "فتح المايك"),
              () async {
                if (_isMicLocked && !widget.isTeacher) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("الميكروفون مغلق بواسطة المدرس"),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  return;
                }
                await _room?.localParticipant?.setMicrophoneEnabled(
                  !_isMicEnabled,
                );
                setState(() => _isMicEnabled = !_isMicEnabled);
              },
            ),
            const SizedBox(width: 16),
            _buildCircleBtn(
              _isCamEnabled ? IconlyBold.video : IconlyBold.hide,
              _isCamEnabled ? Colors.white12 : Colors.red,
              tooltip: _isCamEnabled ? "إغلاق الكاميرا" : "فتح الكاميرا",
              () async {
                await _room?.localParticipant?.setCameraEnabled(!_isCamEnabled);
                setState(() => _isCamEnabled = !_isCamEnabled);
              },
            ),
            const SizedBox(width: 16),
            _buildCircleBtn(
              Icons.back_hand,
              _isHandRaised ? Colors.orange : Colors.white12,
              tooltip: _isHandRaised ? "خفض اليد" : "رفع اليد",
              () {
                final newState = !_isHandRaised;
                setState(() => _isHandRaised = newState);
                _sendData({'type': 'hand_raise', 'value': newState});
              },
            ),
            const SizedBox(width: 16),
            _buildCircleBtn(
              Icons.screen_share,
              _isScreenSharing ? Colors.green : Colors.white12,
              tooltip: _isScreenSharing ? "إيقاف المشاركة" : "مشاركة الشاشة",
              () async {
                final newState = !_isScreenSharing;
                await _room?.localParticipant?.setScreenShareEnabled(newState);
                setState(() => _isScreenSharing = newState);
              },
            ),
            const SizedBox(width: 24),
            _buildCircleBtn(
              IconlyBold.call_missed,
              Colors.red,
              tooltip: "إنهاء المكالمة",
              () => Navigator.pop(context),
              isLarge: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCircleBtn(
    IconData icon,
    Color color,
    VoidCallback onTap, {
    bool isLarge = false,
    String? tooltip,
  }) {
    return Tooltip(
      message: tooltip ?? "",
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: Container(
          padding: EdgeInsets.all(isLarge ? 14 : 12),
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Icon(icon, color: Colors.white, size: isLarge ? 24 : 20),
        ),
      ),
    );
  }
}

class ParticipantLayout extends StatelessWidget {
  final Room room;
  final Map<String, bool> remoteHands;
  final bool localHand;
  final bool isTeacher;
  final bool isWhiteboardOpen;
  final Function(String, bool) onControlMic;

  const ParticipantLayout({
    super.key,
    required this.room,
    required this.remoteHands,
    required this.localHand,
    required this.isTeacher,
    required this.isWhiteboardOpen,
    required this.onControlMic,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: room,
      builder: (context, _) {
        final List<Participant> participants = [
          if (room.localParticipant != null) room.localParticipant!,
          ...room.remoteParticipants.values,
        ];

        TrackPublication? screenSharePub;
        for (var p in participants) {
          final pub = p.videoTrackPublications
              .where((pub) => pub.source == TrackSource.screenShareVideo)
              .firstOrNull;
          if (pub?.track != null) {
            screenSharePub = pub;
            break;
          }
        }

        return Column(
          children: [
            const SizedBox(height: 120),
            if (screenSharePub != null)
              Expanded(
                flex: 4,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.green, width: 2),
                      color: Colors.black,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: VideoTrackRenderer(
                      screenSharePub.track as VideoTrack,
                      fit: VideoViewFit.contain,
                    ),
                  ),
                ),
              ),
            Expanded(
              flex: 2,
              child: GridView.builder(
                padding: const EdgeInsets.all(20),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: (screenSharePub != null || isWhiteboardOpen)
                      ? 4
                      : 2,
                  childAspectRatio: 1.0,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                ),
                itemCount: participants.length,
                itemBuilder: (context, i) {
                  final p = participants[i];
                  final bool isLocal =
                      room.localParticipant != null &&
                      p.identity == room.localParticipant!.identity;
                  final bool isHandUp = isLocal
                      ? localHand
                      : (remoteHands[p.identity] ?? false);
                  final cameraPub = p.videoTrackPublications
                      .where((pub) => pub.source == TrackSource.camera)
                      .firstOrNull;
                  VideoTrack? cameraTrack = cameraPub?.track as VideoTrack?;

                  return Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: p.isSpeaking
                            ? Colors.blue
                            : (isHandUp ? Colors.orange : Colors.white10),
                        width: 2,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      children: [
                        if (cameraTrack != null)
                          VideoTrackRenderer(
                            cameraTrack,
                            fit: VideoViewFit.cover,
                          )
                        else
                          Container(
                            color: Colors.black,
                            child: const Center(
                              child: Icon(
                                IconlyBold.profile,
                                color: Colors.white24,
                                size: 30,
                              ),
                            ),
                          ),
                        if (isHandUp)
                          const Positioned(
                            top: 8,
                            right: 8,
                            child: Icon(
                              Icons.back_hand,
                              color: Colors.orange,
                              size: 16,
                            ),
                          ),
                        if (isTeacher && !isLocal)
                          Positioned(
                            top: 5,
                            left: 5,
                            child: Tooltip(
                              message: p.isMicrophoneEnabled()
                                  ? "كتم مايك الطالب"
                                  : "فتح مايك الطالب (السماح بالتحدث)",
                              child: GestureDetector(
                                onTap: () => onControlMic(
                                  p.identity,
                                  !p.isMicrophoneEnabled(),
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color:
                                        (p.isMicrophoneEnabled()
                                                ? Colors.green
                                                : Colors.red)
                                            .withOpacity(0.8),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    p.isMicrophoneEnabled()
                                        ? Icons.mic
                                        : Icons.mic_off,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            color: Colors.black45,
                            child: Text(
                              isLocal ? "أنت" : p.identity,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 100),
          ],
        );
      },
    );
  }
}

class WhiteboardPainter extends CustomPainter {
  final List<Stroke> strokes;
  final List<Offset> currentPoints;
  final Color currentColor;
  final double currentWidth;
  final bool isEraser;

  WhiteboardPainter({
    required this.strokes,
    required this.currentPoints,
    required this.currentColor,
    required this.currentWidth,
    required this.isEraser,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (var stroke in strokes) {
      Paint paint = Paint()
        ..color = stroke.color
        ..strokeCap = StrokeCap.round
        ..strokeWidth = stroke.width;
      for (int i = 0; i < stroke.points.length - 1; i++) {
        canvas.drawLine(stroke.points[i], stroke.points[i + 1], paint);
      }
    }

    Paint currentPaint = Paint()
      ..color = isEraser ? Colors.white : currentColor
      ..strokeCap = StrokeCap.round
      ..strokeWidth = isEraser ? 25.0 : currentWidth;
    for (int i = 0; i < currentPoints.length - 1; i++) {
      canvas.drawLine(currentPoints[i], currentPoints[i + 1], currentPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _FloatingEmoji extends StatefulWidget {
  final String emoji;
  final VoidCallback onFinished;
  const _FloatingEmoji({
    super.key,
    required this.emoji,
    required this.onFinished,
  });
  @override
  State<_FloatingEmoji> createState() => _FloatingEmojiState();
}

class _FloatingEmojiState extends State<_FloatingEmoji>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    _controller.forward().then((_) => widget.onFinished());
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Positioned(
          bottom: 100 + (_controller.value * 500),
          left: 100 + (_controller.value * 50),
          child: Opacity(
            opacity: 1 - _controller.value,
            child: Text(widget.emoji, style: const TextStyle(fontSize: 40)),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
