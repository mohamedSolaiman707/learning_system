import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconly/iconly.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/livekit_service.dart';
import '../../../core/services/database_service.dart';
import '../../../core/models/question_model.dart';
import '../../../core/models/quiz_model.dart';
import 'package:provider/provider.dart';

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
  final String userId;
  final bool isTeacher;
  final String? sessionId;

  const VideoRoomScreen({
    super.key,
    required this.title,
    required this.roomName,
    required this.userName,
    required this.userId,
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
  bool _isQAOpen = false;
  bool _isParticipantsOpen = false;
  bool _isPollsOpen = false;
  bool _isBreakoutOpen = false;
  bool _isWhiteboardOpen = false;
  bool _isScreenSharing = false;
  bool _isChatLocked = false;
  bool _isMicLocked = false;
  bool _isRecording = false;
  String? _classCode;

  // Real-time Expiry State
  StreamSubscription? _statusSubscription;
  Timer? _expiryTimer;

  QuizModel? _activeQuiz;
  int _quizTimeLeft = 0;
  Timer? _quizTimer;
  int? _selectedQuizOption;
  bool _quizSubmitted = false;

  final List<Stroke> _whiteboardStrokes = [];
  final List<Stroke> _redoStack = [];
  List<Offset> _currentStrokePoints = [];
  Color _selectedColor = Colors.black;
  final double _strokeWidth = 3.0;
  bool _isEraserMode = false;

  Map<String, dynamic>? _activePoll;
  Map<String, int> _pollResults = {};
  String? _myVote;

  final _messageController = TextEditingController();
  final _questionController = TextEditingController();
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _messages = [];
  Timer? _chatTimer;

  final Map<String, bool> _remoteHandStates = {};
  final List<Widget> _reactionParticles = [];

  bool _isBreakoutActive = false;

  @override
  void initState() {
    super.initState();
    _currentActiveRoom = widget.roomName;
    _initializeRoom();

    _chatTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_isChatOpen) _fetchMessages();
    });
  }

  // ميثود جديدة لتهيئة الغرفة مع فحص الصلاحية
  Future<void> _initializeRoom() async {
    if (widget.sessionId != null) {
      final isValid = await _checkAndMonitorSession();
      if (!isValid) return;
    }
    _connectToRoom(_currentActiveRoom!);
  }

  // فحص حالة الجلسة وتفعيل المراقبة اللحظية
  Future<bool> _checkAndMonitorSession() async {
    try {
      final res = await supabase
          .from('sessions')
          .select('class_code, is_recording_enabled, end_time, status')
          .eq('id', widget.sessionId!)
          .single();

      final DateTime endTime = DateTime.parse(res['end_time']);
      final String status = res['status'];

      // 1. تحقق قبل الدخول
      if (status == 'ended' || DateTime.now().isAfter(endTime)) {
        _handleSessionEnded(message: "عذراً، هذه الجلسة انتهت بالفعل.");
        return false;
      }

      if (mounted) {
        setState(() => _classCode = res['class_code']);

        // 2. تفعيل المراقبة اللحظية للحالة (Real-time status)
        _statusSubscription = DatabaseService()
            .watchSessionStatus(widget.sessionId!)
            .listen((data) {
              if (data['status'] == 'ended' && mounted) {
                _handleSessionEnded(message: "قام المدرس بإنهاء الجلسة الآن.");
              }
            });

        // 3. تفعيل مؤقت انتهاء الوقت (Time Expiry)
        final remaining = endTime.difference(DateTime.now());
        _expiryTimer = Timer(remaining, () {
          if (mounted)
            _handleSessionEnded(message: "انتهى الوقت المخصص لهذه الحصة.");
        });

        if (widget.isTeacher && res['is_recording_enabled'] == true)
          _startRecordingSession();
      }
      return true;
    } catch (e) {
      debugPrint("Session init error: $e");
      return true; // في حال الخطأ نتركه يحاول الدخول
    }
  }

  void _handleSessionEnded({String? message}) {
    if (!mounted) return;
    _room?.disconnect();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text("الجلسة انتهت"),
          ],
        ),
        content: Text(message ?? "انتهى وقت الحصة أو تم إغلاق القاعة."),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(); // غلق الديالوج
              Navigator.of(context).pop(); // مغادرة القاعة
            },
            child: const Text("العودة للرئيسية"),
          ),
        ],
      ),
    );
  }

  // ميثود للخروج الآمن للمدرس
  void _onExitPressed() async {
    if (widget.isTeacher) {
      final endAll = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text("مغادرة القاعة"),
          content: const Text(
            "هل تود إنهاء الحصة لجميع الطلاب أم المغادرة فقط؟",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("مغادرة فقط"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                "إنهاء للكل",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      );

      if (endAll == true) {
        // تحديث حالة الجلسة لـ ended لإخراج الجميع
        await DatabaseService().toggleRoomStatus(widget.sessionId!, false);
      }
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _fetchSessionDetails() async {
    // تم دمج المنطق في _checkAndMonitorSession
  }

  Future<void> _startRecordingSession() async {
    final success = await LiveKitService().startRecording(
      widget.roomName,
      widget.sessionId!,
    );
    if (success && mounted) {
      setState(() => _isRecording = true);
      _sendData({'type': 'recording_status', 'value': true});
    }
  }

  Future<void> _stopRecordingSession() async {
    if (widget.isTeacher && _isRecording) {
      await LiveKitService().stopRecording(widget.roomName, widget.sessionId!);
      if (mounted) setState(() => _isRecording = false);
      _sendData({'type': 'recording_status', 'value': false});
    }
  }

  Future<void> _connectToRoom(String roomName) async {
    setState(() => _isLoading = true);
    try {
      final token = await LiveKitService().getRoomToken(
        roomName: roomName,
        userId: widget.userId,
        userName: widget.userName,
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
        final String type = data['type'];

        setState(() {
          switch (type) {
            case 'poll_create':
              _activePoll = data['poll'];
              _pollResults = {
                for (var item in data['poll']['options']) item: 0,
              };
              _myVote = null;
              _isPollsOpen = true;
              _closeOtherPanels();
              break;
            case 'poll_vote':
              final option = data['option'];
              _pollResults[option] = (_pollResults[option] ?? 0) + 1;
              break;
            case 'poll_end':
              _activePoll = null;
              if (!widget.isTeacher) _isPollsOpen = false;
              break;
            case 'new_question':
              _showTopSnackBar(
                "سؤال جديد من ${data['from']} ❓",
                Colors.blueGrey.shade900,
              );
              break;
            case 'question_answered':
              _showTopSnackBar("تم الرد على سؤالك ✅", Colors.green);
              break;
            case 'quiz_create':
              _handleIncomingQuiz(data['quiz']);
              break;
            case 'hand_raise':
              final p = event.participant;
              if (p != null) _remoteHandStates[p.identity] = data['value'];
              break;
            case 'reaction':
              _showReactionEffect(data['value']);
              break;
            case 'whiteboard_draw':
              _handleRemoteDraw(data);
              break;
            case 'whiteboard_clear':
              _whiteboardStrokes.clear();
              _redoStack.clear();
              break;
            case 'whiteboard_undo':
              _executeUndo(remote: true);
              break;
            case 'whiteboard_redo':
              _executeRedo(remote: true);
              break;
            case 'control_mic':
              if (!widget.isTeacher &&
                  (data['target'] == widget.userId || data['target'] == null)) {
                bool lock = data['lock'] ?? false;
                bool val = data['value'] ?? false;
                _room?.localParticipant?.setMicrophoneEnabled(val);
                _isMicEnabled = val;
                _isMicLocked = lock;
                _showAuthoritySnackBar(lock, val);
              }
              break;
            case 'control_chat':
              _isChatLocked = data['value'];
              break;
            case 'recording_status':
              _isRecording = data['value'];
              break;
            case 'breakout_invite':
              if (data['target'] == widget.userId)
                _showBreakoutInvitation(data['room'], data['groupName']);
              break;
            case 'breakout_end':
              _connectToRoom(widget.roomName);
              _showTopSnackBar(
                "انتهى وقت المجموعات، جاري العودة للقاعة الرئيسية...",
                Colors.orange,
              );
              break;
          }
        });
      });

      await room.connect('wss://learning-system-07wdu0v6.livekit.cloud', token);

      if (!widget.isTeacher && widget.sessionId != null) {
        DatabaseService().logStudentEntry(widget.sessionId!, widget.userId);
      }

      if (widget.isTeacher || roomName != widget.roomName) {
        await room.localParticipant?.setCameraEnabled(true);
        await room.localParticipant?.setMicrophoneEnabled(true);
        if (mounted) {
          setState(() {
            _isMicEnabled = true;
            _isCamEnabled = true;
          });
        }
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

  void _closeOtherPanels() {
    _isChatOpen = false;
    _isQAOpen = false;
    _isParticipantsOpen = false;
    _isWhiteboardOpen = false;
    _isPollsOpen = false;
    _isBreakoutOpen = false;
  }

  void _showTopSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _handleIncomingQuiz(Map<String, dynamic> quizData) {
    setState(() {
      _activeQuiz = QuizModel.fromMap(quizData);
      _quizTimeLeft = _activeQuiz!.timeLimitSeconds;
      _selectedQuizOption = null;
      _quizSubmitted = false;
    });
    _quizTimer?.cancel();
    _quizTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_quizTimeLeft > 0) {
          _quizTimeLeft--;
        } else {
          _quizTimer?.cancel();
          if (!_quizSubmitted && !widget.isTeacher) _submitQuizAnswer();
        }
      });
    });
  }

  Future<void> _submitQuizAnswer() async {
    if (_quizSubmitted || _activeQuiz == null) return;
    setState(() => _quizSubmitted = true);
    final db = Provider.of<DatabaseService>(context, listen: false);
    final isCorrect = _selectedQuizOption == _activeQuiz!.correctOptionIndex;
    await db.submitQuizAnswer({
      'quiz_id': _activeQuiz!.id,
      'student_id': widget.userId,
      'student_name': widget.userName,
      'selected_option_index': _selectedQuizOption,
      'is_correct': isCorrect,
    });
    if (mounted)
      _showTopSnackBar(
        isCorrect ? "إجابة صحيحة! 🎉" : "إجابة خاطئة، حظاً أوفر",
        isCorrect ? Colors.green : Colors.redAccent,
      );
  }

  void _showCreateQuizDialog() {
    final questionController = TextEditingController();
    final optionControllers = List.generate(4, (_) => TextEditingController());
    int correctIndex = 0;
    int duration = 60;
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1C1F26),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            "إنشاء اختبار سريع",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: questionController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: "السؤال",
                    labelStyle: TextStyle(color: Colors.grey),
                  ),
                ),
                const SizedBox(height: 20),
                ...List.generate(
                  4,
                  (i) => Row(
                    children: [
                      Radio<int>(
                        value: i,
                        activeColor: Colors.blue,
                        groupValue: correctIndex,
                        onChanged: isSubmitting
                            ? null
                            : (val) =>
                                  setDialogState(() => correctIndex = val!),
                      ),
                      Expanded(
                        child: TextField(
                          controller: optionControllers[i],
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: "الاختيار ${i + 1}",
                            hintStyle: const TextStyle(
                              color: Colors.grey,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    const Text(
                      "المدة (ثواني): ",
                      style: TextStyle(color: Colors.white70),
                    ),
                    DropdownButton<int>(
                      dropdownColor: const Color(0xFF1C1F26),
                      value: duration,
                      style: const TextStyle(color: Colors.white),
                      items: [30, 60, 90, 120, 180]
                          .map(
                            (s) =>
                                DropdownMenuItem(value: s, child: Text("$s")),
                          )
                          .toList(),
                      onChanged: isSubmitting
                          ? null
                          : (val) => setDialogState(() => duration = val!),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(context),
              child: const Text("إلغاء", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (questionController.text.trim().isEmpty) {
                        _showTopSnackBar("برجاء كتابة السؤال", Colors.orange);
                        return;
                      }
                      final options = optionControllers
                          .map((c) => c.text.trim())
                          .toList();
                      if (options.any((opt) => opt.isEmpty)) {
                        _showTopSnackBar(
                          "برجاء ملء جميع الاختيارات",
                          Colors.orange,
                        );
                        return;
                      }
                      setDialogState(() => isSubmitting = true);
                      try {
                        final db = Provider.of<DatabaseService>(
                          context,
                          listen: false,
                        );
                        final quizData = await db.createQuiz({
                          'session_id': widget.sessionId,
                          'question': questionController.text.trim(),
                          'options': options,
                          'correct_option_index': correctIndex,
                          'time_limit_seconds': duration,
                        });
                        _sendData({'type': 'quiz_create', 'quiz': quizData});
                        _handleIncomingQuiz(quizData);
                        if (context.mounted) Navigator.pop(context);
                      } catch (e) {
                        setDialogState(() => isSubmitting = false);
                        if (context.mounted)
                          _showTopSnackBar("خطأ: $e", Colors.redAccent);
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text("بدء الاختبار"),
            ),
          ],
        ),
      ),
    );
  }

  void _showAuthoritySnackBar(bool lock, bool val) {
    String msg = lock
        ? "المدرس قام بقفل الميكروفونات"
        : (val ? "سمح لك المدرس بالتحدث الآن" : "المدرس قام بكتم صوتك");
    _showTopSnackBar(msg, lock ? Colors.redAccent : Colors.blue);
  }

  void _sendData(Map<String, dynamic> data) async {
    if (_room == null) return;
    final bytes = utf8.encode(jsonEncode(data));
    await _room!.localParticipant?.publishData(bytes);
  }

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
      'lock': isOn,
    });
  }

  Future<void> _markAllAsPresent() async {
    if (widget.sessionId == null || _room == null) {
      _showTopSnackBar("لا توجد جلسة نشطة للتحضير", Colors.orange);
      return;
    }
    final List<Participant> studentParticipants = _room!
        .remoteParticipants
        .values
        .toList();
    if (studentParticipants.isEmpty) {
      _showTopSnackBar("لا يوجد طلاب حالياً في القاعة", Colors.orange);
      return;
    }
    setState(() => _isLoading = true);
    try {
      final List<Map<String, dynamic>> attendanceData = studentParticipants
          .map(
            (p) => {
              'session_id': widget.sessionId,
              'student_id': p.identity,
              'status': 'present',
              'joined_at': DateTime.now().toIso8601String(),
            },
          )
          .toList();
      await supabase
          .from('attendance')
          .upsert(attendanceData, onConflict: 'session_id, student_id');
      if (mounted)
        _showTopSnackBar(
          "تم تحضير ${attendanceData.length} طالب بنجاح ✅",
          Colors.green,
        );
    } catch (e) {
      if (mounted) _showTopSnackBar("خطأ في التحضير: $e", Colors.redAccent);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
    setState(() {
      _isBreakoutActive = true;
      _isBreakoutOpen = false;
    });
    _showTopSnackBar("تم إرسال دعوات المجموعات للطلاب", Colors.blue);
  }

  void _endBreakout() {
    _sendData({'type': 'breakout_end'});
    _connectToRoom(widget.roomName);
    setState(() => _isBreakoutActive = false);
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
        setState(() => _messages = List<Map<String, dynamic>>.from(response));
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
    final String liveLink =
        "${Uri.base.origin}/#/live?sessionId=${widget.sessionId}";
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text("دعوة الطلاب", textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "شارك كود الحصة مع الطلاب:",
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
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
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _classCode!));
                    _showTopSnackBar("تم نسخ الكود", Colors.blue);
                  },
                  icon: const Icon(Icons.copy),
                  label: const Text("نسخ الكود"),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: liveLink));
                    _showTopSnackBar("تم نسخ الرابط", Colors.blue);
                  },
                  icon: const Icon(Icons.link),
                  label: const Text("نسخ الرابط"),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    if (!widget.isTeacher && widget.sessionId != null)
      DatabaseService().logStudentExit(widget.sessionId!, widget.userId);
    _statusSubscription?.cancel();
    _expiryTimer?.cancel();
    _stopRecordingSession();
    _quizTimer?.cancel();
    _listener?.dispose();
    _room?.disconnect();
    _chatTimer?.cancel();
    _messageController.dispose();
    _questionController.dispose();
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
                if (_isQAOpen) _buildQAPanel(),
                if (_activeQuiz != null) _buildQuizOverlay(),
                _buildTopBar(inSubRoom),
                _buildBottomControls(),
              ],
            ),
    );
  }

  Widget _buildQuizOverlay() {
    final bool isFinished = _quizTimeLeft == 0 || _quizSubmitted;
    return Positioned.fill(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          color: Colors.black54,
          alignment: Alignment.center,
          child: Container(
            width: 400,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1F26),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "اختبار سريع 📝",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _quizTimeLeft < 10 ? Colors.red : Colors.blue,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        "$_quizTimeLeft s",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  _activeQuiz!.question,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
                const SizedBox(height: 24),
                if (widget.isTeacher)
                  _buildTeacherQuizStats()
                else
                  ...List.generate(
                    _activeQuiz!.options.length,
                    (i) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: InkWell(
                        onTap: isFinished
                            ? null
                            : () => setState(() => _selectedQuizOption = i),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _selectedQuizOption == i
                                ? Colors.blue.withOpacity(0.2)
                                : Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _selectedQuizOption == i
                                  ? Colors.blue
                                  : Colors.white10,
                            ),
                          ),
                          child: Row(
                            children: [
                              Text(
                                "${String.fromCharCode(65 + i)}.",
                                style: const TextStyle(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _activeQuiz!.options[i],
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                if (!widget.isTeacher && !isFinished)
                  ElevatedButton(
                    onPressed: _selectedQuizOption == null
                        ? null
                        : _submitQuizAnswer,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: const Text("تسليم الإجابة"),
                  ),
                if (isFinished || widget.isTeacher)
                  TextButton(
                    onPressed: () => setState(() => _activeQuiz = null),
                    child: const Text(
                      "إغلاق",
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTeacherQuizStats() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: Provider.of<DatabaseService>(
        context,
        listen: false,
      ).watchQuizResults(_activeQuiz!.id),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const CircularProgressIndicator();
        final results = snapshot.data!
            .map((r) => QuizResultModel.fromMap(r))
            .toList();
        final correctCount = results.where((r) => r.isCorrect).length;
        return Column(
          children: [
            Text(
              "إجابات الطلاب: ${results.length}",
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: results.isEmpty ? 0 : correctCount / results.length,
              backgroundColor: Colors.white10,
              color: Colors.green,
            ),
            Text(
              "نسبة النجاح: ${results.isEmpty ? 0 : (correctCount / results.length * 100).toInt()}%",
              style: const TextStyle(color: Colors.green, fontSize: 12),
            ),
          ],
        );
      },
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
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              GestureDetector(
                onPanStart: (details) => setState(
                  () => _currentStrokePoints = [details.localPosition],
                ),
                onPanUpdate: (details) => setState(
                  () => _currentStrokePoints.add(details.localPosition),
                ),
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
          IconButton(
            icon: Icon(
              Icons.cleaning_services,
              color: _isEraserMode ? Colors.blue : Colors.white,
              size: 20,
            ),
            onPressed: () => setState(() => _isEraserMode = !_isEraserMode),
          ),
          IconButton(
            icon: const Icon(Icons.undo, color: Colors.white, size: 20),
            onPressed: _whiteboardStrokes.isEmpty ? null : _executeUndo,
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
                if (widget.isTeacher) ...[
                  IconButton(
                    icon: const Icon(Icons.share, color: Colors.white70),
                    onPressed: _shareInvite,
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.quiz_outlined,
                      color: Colors.white70,
                    ),
                    onPressed: _showCreateQuizDialog,
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.groups_outlined,
                      color: _isBreakoutOpen ? Colors.blue : Colors.white70,
                    ),
                    onPressed: () => setState(() {
                      _closeOtherPanels();
                      _isBreakoutOpen = true;
                    }),
                  ),
                ],
                IconButton(
                  icon: Icon(
                    Icons.question_answer_outlined,
                    color: _isQAOpen ? Colors.blue : Colors.white70,
                  ),
                  onPressed: () => setState(() {
                    _closeOtherPanels();
                    _isQAOpen = true;
                  }),
                ),
                IconButton(
                  icon: Icon(
                    Icons.edit_note,
                    color: _isWhiteboardOpen ? Colors.blue : Colors.white70,
                  ),
                  onPressed: () => setState(() {
                    _closeOtherPanels();
                    _isWhiteboardOpen = true;
                  }),
                ),
                IconButton(
                  icon: Icon(
                    IconlyLight.graph,
                    color: _isPollsOpen ? Colors.blue : Colors.white70,
                  ),
                  onPressed: () => setState(() {
                    _closeOtherPanels();
                    _isPollsOpen = true;
                  }),
                ),
                IconButton(
                  icon: Icon(
                    IconlyLight.user_1,
                    color: _isParticipantsOpen ? Colors.blue : Colors.white70,
                  ),
                  onPressed: () => setState(() {
                    _closeOtherPanels();
                    _isParticipantsOpen = true;
                  }),
                ),
                IconButton(
                  icon: Icon(
                    IconlyLight.chat,
                    color: _isChatOpen ? Colors.blue : Colors.white70,
                  ),
                  onPressed: () => setState(() {
                    _closeOtherPanels();
                    _isChatOpen = true;
                  }),
                ),
                IconButton(
                  icon: const Icon(Icons.logout_rounded, color: Colors.white70),
                  onPressed: _onExitPressed,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQAPanel() {
    return Positioned(
      top: 110,
      right: 20,
      bottom: 120,
      child: Container(
        width: 350,
        decoration: BoxDecoration(
          color: const Color(0xFF1C1F26).withOpacity(0.95),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                "الأسئلة والأجوبة",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: Provider.of<DatabaseService>(
                  context,
                  listen: false,
                ).watchQuestions(widget.sessionId!),
                builder: (context, snapshot) {
                  if (!snapshot.hasData)
                    return const Center(child: CircularProgressIndicator());
                  final questions = snapshot.data!
                      .map((q) => QuestionModel.fromMap(q))
                      .toList();
                  return ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: questions.length,
                    itemBuilder: (context, i) =>
                        _buildQuestionItem(questions[i]),
                  );
                },
              ),
            ),
            if (!widget.isTeacher)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _questionController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: "اسأل سؤالاً...",
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(IconlyBold.send, color: Colors.blue),
                      onPressed: () async {
                        if (_questionController.text.trim().isEmpty) return;
                        await Provider.of<DatabaseService>(
                          context,
                          listen: false,
                        ).submitQuestion({
                          'session_id': widget.sessionId,
                          'student_id': widget.userId,
                          'student_name': widget.userName,
                          'content': _questionController.text.trim(),
                        });
                        _sendData({
                          'type': 'new_question',
                          'from': widget.userName,
                        });
                        _questionController.clear();
                      },
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionItem(QuestionModel q) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: q.isPinned
            ? Colors.blue.withOpacity(0.1)
            : Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            q.studentName,
            style: const TextStyle(
              color: Colors.blue,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
          Text(
            q.content,
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
          if (q.isAnswered)
            Text(
              "الإجابة: ${q.answer}",
              style: const TextStyle(color: Colors.green, fontSize: 12),
            ),
          if (widget.isTeacher && !q.isAnswered)
            TextButton(
              onPressed: () => _showAnswerDialog(q),
              child: const Text("رد", style: TextStyle(fontSize: 12)),
            ),
        ],
      ),
    );
  }

  void _showAnswerDialog(QuestionModel q) {
    final ansController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("الرد على السؤال"),
        content: TextField(controller: ansController),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("إلغاء"),
          ),
          ElevatedButton(
            onPressed: () async {
              await Provider.of<DatabaseService>(
                context,
                listen: false,
              ).answerQuestion(q.id, ansController.text);
              _sendData({'type': 'question_answered'});
              Navigator.pop(context);
            },
            child: const Text("إرسال"),
          ),
        ],
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
        ),
        child: _activePoll == null && widget.isTeacher
            ? _buildPollCreator()
            : _buildActivePoll(),
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
            decoration: const InputDecoration(hintText: "السؤال..."),
          ),
          ElevatedButton(
            onPressed: () => _createPoll(qController.text, ["نعم", "لا"]),
            child: const Text("بدء"),
          ),
        ],
      ),
    );
  }

  Widget _buildActivePoll() {
    if (_activePoll == null) return const Center(child: Text("لا يوجد تصويت"));
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(
            _activePoll!['question'],
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          ...(_activePoll!['options'] as List).map(
            (opt) => ListTile(
              title: Text(opt, style: const TextStyle(color: Colors.white70)),
              onTap: () => _submitVote(opt),
              trailing: Text("${_pollResults[opt] ?? 0}"),
            ),
          ),
          if (widget.isTeacher)
            TextButton(
              onPressed: _endPoll,
              child: const Text("إنهاء", style: TextStyle(color: Colors.red)),
            ),
        ],
      ),
    );
  }

  Widget _buildParticipantsPanel() {
    final List<Participant> participants = [
      if (_room?.localParticipant != null) _room!.localParticipant!,
      ..._room?.remoteParticipants.values ?? [],
    ];
    return Positioned(
      top: 110,
      right: 20,
      bottom: 120,
      child: Container(
        width: 320,
        decoration: BoxDecoration(
          color: const Color(0xFF1C1F26).withOpacity(0.95),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                "المشاركين",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (widget.isTeacher)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildTeacherActionBtn(
                        "كتم الجميع",
                        Icons.mic_off,
                        Colors.redAccent,
                        () => _toggleMicLock(true),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildTeacherActionBtn(
                        "تحضير",
                        Icons.check_circle,
                        Colors.blue,
                        _markAllAsPresent,
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: ListView.builder(
                itemCount: participants.length,
                itemBuilder: (context, i) => ListTile(
                  leading: CircleAvatar(
                    child: Text(
                      participants[i].name.isNotEmpty
                          ? participants[i].name[0]
                          : "?",
                    ),
                  ),
                  title: Text(
                    participants[i].name,
                    style: const TextStyle(color: Colors.white),
                  ),
                  trailing: widget.isTeacher
                      ? IconButton(
                          icon: Icon(
                            participants[i].isMicrophoneEnabled()
                                ? Icons.mic
                                : Icons.mic_off,
                            color: participants[i].isMicrophoneEnabled()
                                ? Colors.green
                                : Colors.red,
                          ),
                          onPressed: () => _toggleStudentMic(participants[i]),
                        )
                      : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeacherActionBtn(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 10)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.2),
        foregroundColor: color,
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
        ),
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                itemCount: _messages.length,
                itemBuilder: (context, i) => ListTile(
                  title: Text(
                    _messages[i]['user_name'],
                    style: const TextStyle(color: Colors.blue, fontSize: 10),
                  ),
                  subtitle: Text(
                    _messages[i]['content'],
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(IconlyBold.send),
                    onPressed: _sendMessage,
                  ),
                ],
              ),
            ),
          ],
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
          color: const Color(0xFF1C1F26),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          children: [
            const Text("المجموعات", style: TextStyle(color: Colors.white)),
            if (!_isBreakoutActive)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [2, 3, 4]
                    .map(
                      (n) => ElevatedButton(
                        onPressed: () => _startBreakout(n),
                        child: Text("$n"),
                      ),
                    )
                    .toList(),
              )
            else
              ElevatedButton(
                onPressed: _endBreakout,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text("إنهاء"),
              ),
          ],
        ),
      ),
    );
  }

  void _showReactionEffect(String emoji) {
    if (!mounted) return;
    final key = UniqueKey();
    setState(
      () => _reactionParticles.add(
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
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildCircleBtn(
              _isMicEnabled ? IconlyBold.voice : IconlyBold.voice_2,
              _isMicEnabled ? Colors.white12 : Colors.red,
              () async {
                if (_isMicLocked && !widget.isTeacher) {
                  _showTopSnackBar("المايك مقفل", Colors.red);
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
              () async {
                await _room?.localParticipant?.setCameraEnabled(!_isCamEnabled);
                setState(() => _isCamEnabled = !_isCamEnabled);
              },
            ),
            const SizedBox(width: 16),
            _buildCircleBtn(
              Icons.back_hand,
              _isHandRaised ? Colors.orange : Colors.white12,
              () {
                setState(() => _isHandRaised = !_isHandRaised);
                _sendData({'type': 'hand_raise', 'value': _isHandRaised});
              },
            ),
            const SizedBox(width: 16),
            _buildCircleBtn(
              Icons.screen_share,
              _isScreenSharing ? Colors.green : Colors.white12,
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
              _onExitPressed,
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
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        padding: EdgeInsets.all(isLarge ? 14 : 12),
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: isLarge ? 24 : 20),
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
        Participant? teacher = isTeacher
            ? room.localParticipant
            : room.remoteParticipants.values.firstOrNull;
        List<Participant> students = participants
            .where((p) => p.identity != teacher?.identity)
            .toList();

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
            const SizedBox(height: 100),
            Expanded(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 15),
                child: screenSharePub != null
                    ? _buildScreenShare(screenSharePub)
                    : (teacher != null
                          ? _buildTile(teacher, isHero: true)
                          : const Center(
                              child: Text(
                                "في انتظار المعلم...",
                                style: TextStyle(color: Colors.white24),
                              ),
                            )),
              ),
            ),
            if (students.isNotEmpty)
              SizedBox(
                height: 150,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  itemCount: students.length,
                  itemBuilder: (context, i) => Container(
                    width: 200,
                    margin: const EdgeInsets.only(left: 10),
                    child: _buildTile(students[i]),
                  ),
                ),
              ),
            const SizedBox(height: 110),
          ],
        );
      },
    );
  }

  Widget _buildScreenShare(TrackPublication pub) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.green, width: 2),
        color: Colors.black,
      ),
      clipBehavior: Clip.antiAlias,
      child: VideoTrackRenderer(
        pub.track as VideoTrack,
        fit: VideoViewFit.contain,
      ),
    );
  }

  Widget _buildTile(Participant p, {bool isHero = false}) {
    final cameraPub = p.videoTrackPublications
        .where((pub) => pub.source == TrackSource.camera)
        .firstOrNull;
    final bool isHandUp = p.identity == room.localParticipant?.identity
        ? localHand
        : (remoteHands[p.identity] ?? false);
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1C1F26),
        borderRadius: BorderRadius.circular(isHero ? 24 : 12),
        border: Border.all(
          color: p.isSpeaking
              ? Colors.blue
              : (isHandUp ? Colors.orange : Colors.white10),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (cameraPub?.track != null && p.isCameraEnabled())
            VideoTrackRenderer(
              cameraPub!.track as VideoTrack,
              fit: VideoViewFit.cover,
            )
          else
            Center(
              child: CircleAvatar(
                radius: isHero ? 40 : 20,
                child: Text(p.name.isNotEmpty ? p.name[0] : "?"),
              ),
            ),
          if (isHero)
            Positioned(
              top: 15,
              right: 15,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  "المعلم",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          if (isHandUp)
            Positioned(
              top: 10,
              left: 10,
              child: const Icon(
                Icons.back_hand,
                color: Colors.orange,
                size: 20,
              ),
            ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(8),
              color: Colors.black45,
              child: Text(
                p.name,
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
            ),
          ),
        ],
      ),
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
      for (int i = 0; i < stroke.points.length - 1; i++)
        canvas.drawLine(stroke.points[i], stroke.points[i + 1], paint);
    }
    Paint currentPaint = Paint()
      ..color = isEraser ? Colors.white : currentColor
      ..strokeCap = StrokeCap.round
      ..strokeWidth = isEraser ? 25.0 : currentWidth;
    for (int i = 0; i < currentPoints.length - 1; i++)
      canvas.drawLine(currentPoints[i], currentPoints[i + 1], currentPaint);
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
  void dispose() {
    _controller.dispose();
    super.dispose();
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
}
