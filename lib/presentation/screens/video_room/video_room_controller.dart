import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter/services.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../../core/services/livekit_service.dart';
import '../../../core/services/database_service.dart';
import '../../../core/services/attendance_pdf_service.dart';
import '../../../core/models/quiz_model.dart';

class Stroke {
  final List<Offset> points;
  final Color color;
  final double width;
  Stroke({required this.points, required this.color, required this.width});
}

class VideoRoomController extends ChangeNotifier {
  final String title;
  final String roomName;
  final String userName;
  final String userId;
  final bool isTeacher;
  final String? sessionId;

  VideoRoomController({
    required this.title,
    required this.roomName,
    required this.userName,
    required this.userId,
    required this.isTeacher,
    this.sessionId,
  });

  Room? _room;
  EventsListener<RoomEvent>? _listener;
  bool _isLoading = true;
  bool _isProcessing = false;
  String? _errorMessage;
  String? _currentRoomName;
  bool _isBreakoutActive = false;
  Map<int, List<String>> _breakoutGroups = {};
  int _breakoutTimeLeft = 0;
  Timer? _breakoutTimer;

  bool _isMicEnabled = false;
  bool _isCamEnabled = false;
  bool _isHandRaised = false;
  bool _isMicLocked = false;
  bool _isCamLocked = false;
  bool _isRecording = false;
  bool _isScreenSharing = false;

  bool _isChatLocked = false;
  bool _isWhiteboardLocked = false;
  bool _isScreenShareLocked = false;
  String? _spotlightUserId;
  bool _isAllMuted = false;
  bool _isRoomLocked = false;

  bool _isChatOpen = false;
  bool _isWhiteboardOpen = false;
  bool _isPollsOpen = false;
  bool _isQuizOpen = false;
  bool _isQAOpen = false;
  bool _isParticipantsOpen = false;

  final List<Stroke> _whiteboardStrokes = [];
  final List<Stroke> _redoStack = [];
  Color _selectedColor = Colors.black;
  double _strokeWidth = 3.0;

  Map<String, dynamic>? _activePoll;
  Map<String, int> _pollResults = {};
  QuizModel? _activeQuiz;
  int _quizTimeLeft = 0;
  Timer? _quizTimer;
  bool _quizSubmitted = false;
  List<Map<String, dynamic>> _messages = [];
  final List<Map<String, dynamic>> _questions = [];

  final Map<String, bool> _remoteHandStates = {};
  final List<Map<String, dynamic>> _handRaiseQueue = [];

  bool _isConnected = true;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  DateTime? _lastMutedSpeechWarning;
  DateTime? _lastReactionSent;

  Room? get room => _room;
  bool get isLoading => _isLoading;
  bool get isProcessing => _isProcessing;
  String? get errorMessage => _errorMessage;
  bool get isMicEnabled => _isMicEnabled;
  bool get isCamEnabled => _isCamEnabled;
  bool get isHandRaised => _isHandRaised;
  bool get isRecording => _isRecording;
  bool get isScreenSharing => _isScreenSharing;
  bool get isChatOpen => _isChatOpen;
  bool get isWhiteboardOpen => _isWhiteboardOpen;
  bool get isPollsOpen => _isPollsOpen;
  bool get isQuizOpen => _isQuizOpen;
  bool get isQAOpen => _isQAOpen;
  bool get isParticipantsOpen => _isParticipantsOpen;
  List<Stroke> get whiteboardStrokes => _whiteboardStrokes;
  Map<String, dynamic>? get activePoll => _activePoll;
  Map<String, int> get pollResults => _pollResults;
  QuizModel? get activeQuiz => _activeQuiz;
  int get quizTimeLeft => _quizTimeLeft;
  bool get quizSubmitted => _quizSubmitted;
  List<Map<String, dynamic>> get messages => _messages;
  List<Map<String, dynamic>> get questions => _questions;
  Map<String, bool> get remoteHandStates => _remoteHandStates;
  List<Map<String, dynamic>> get handRaiseQueue => _handRaiseQueue;
  bool get isChatLocked => _isChatLocked;
  bool get isWhiteboardLocked => _isWhiteboardLocked;
  bool get isScreenShareLocked => _isScreenShareLocked;
  String? get spotlightUserId => _spotlightUserId;
  bool get isAllMuted => _isAllMuted;
  bool get isCamLocked => _isCamLocked;
  Color get selectedColor => _selectedColor;
  bool get isBreakoutActive => _isBreakoutActive;
  bool get isBreakoutRoom =>
      _currentRoomName != null && _currentRoomName != roomName;
  int get breakoutTimeLeft => _breakoutTimeLeft;
  Map<int, List<String>> get breakoutGroups => _breakoutGroups;

  Function(String message)? onSessionEnded;
  Function(String title, Color color)? onNotification;
  Function(String room, String name, int duration)? onBreakoutInvite;
  Function(String emoji)? onReactionReceived;

  final supabase = Supabase.instance.client;
  StreamSubscription? _statusSubscription;
  Timer? _expiryTimer;

  void _triggerHaptic({bool heavy = false}) {
    if (heavy)
      HapticFeedback.mediumImpact();
    else
      HapticFeedback.lightImpact();
  }

  void toggleChat() {
    _triggerHaptic();
    _isChatOpen = !_isChatOpen;
    _isWhiteboardOpen = false;
    _isQAOpen = false;
    _isParticipantsOpen = false;
    notifyListeners();
  }

  void toggleWhiteboard() {
    _triggerHaptic();
    _isWhiteboardOpen = !_isWhiteboardOpen;
    _isChatOpen = false;
    _isQAOpen = false;
    _isParticipantsOpen = false;
    notifyListeners();
  }

  void toggleQA() {
    _triggerHaptic();
    _isQAOpen = !_isQAOpen;
    _isChatOpen = false;
    _isWhiteboardOpen = false;
    _isParticipantsOpen = false;
    notifyListeners();
  }

  void toggleParticipants() {
    _triggerHaptic();
    _isParticipantsOpen = !_isParticipantsOpen;
    _isChatOpen = false;
    _isWhiteboardOpen = false;
    _isQAOpen = false;
    notifyListeners();
  }

  void setWhiteboardColor(Color color) {
    _selectedColor = color;
    notifyListeners();
  }

  void setStrokeWidth(double width) {
    _strokeWidth = width;
    notifyListeners();
  }

  Future<void> init() async {
    _currentRoomName = roomName;
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
        List<ConnectivityResult> results,
        ) {
      final hasInternet = results.any(
            (result) => result != ConnectivityResult.none,
      );
      if (_isConnected && !hasInternet) {
        _isConnected = false;
        onNotification?.call("فقدت الاتصال بالإنترنت ⚠️", Colors.red);
      } else if (!_isConnected && hasInternet) {
        _isConnected = true;
        onNotification?.call("تم استعادة الاتصال ✅", Colors.green);
        if (_room == null ||
            _room!.connectionState == ConnectionState.disconnected)
          connectToRoom(_currentRoomName ?? roomName);
      }
      notifyListeners();
    });

    final results = await Connectivity().checkConnectivity();
    _isConnected = results.any((result) => result != ConnectivityResult.none);
    if (!_isConnected) {
      _isLoading = false;
      _errorMessage = "لا يوجد اتصال بالإنترنت حالياً";
      notifyListeners();
      return;
    }

    if (sessionId != null && sessionId!.isNotEmpty) {
      final isValid = await _checkAndMonitorSession();
      if (!isValid) return;
    }
    await _loadChatHistory();
    await connectToRoom(roomName);
  }

  Future<void> _loadChatHistory() async {
    try {
      final data = await supabase
          .from('messages')
          .select()
          .eq('room_name', roomName)
          .order('created_at', ascending: false);
      _messages = List<Map<String, dynamic>>.from(data);
      notifyListeners();
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  Future<bool> _checkAndMonitorSession() async {
    try {
      final res = await supabase
          .from('sessions')
          .select()
          .eq('id', sessionId!)
          .single();
      final DateTime endTime = DateTime.parse(res['end_time']);
      if (res['status'] == 'ended' ||
          res['status'] == 'archived' ||
          DateTime.now().isAfter(endTime)) {
        onSessionEnded?.call("هذه الجلسة انتهت بالفعل.");
        return false;
      }
      _statusSubscription = DatabaseService()
          .watchSessionStatus(sessionId!)
          .listen((data) {
        if (data.isNotEmpty &&
            (data.first['status'] == 'ended' ||
                data.first['status'] == 'archived')) {
          onNotification?.call(
            "🔴 تم إنهاء البث المباشر.",
            Colors.redAccent,
          );
          Future.delayed(
            const Duration(seconds: 3),
                () => onSessionEnded?.call("انتهت الحصة الدراسية."),
          );
        }
      });
      _expiryTimer = Timer(
        endTime.difference(DateTime.now()),
            () => onSessionEnded?.call("انتهى وقت الحصة."),
      );
      if (isTeacher && res['is_recording_enabled'] == true) startRecording();
      return true;
    } catch (e) {
      return true;
    }
  }

  Future<void> connectToRoom(String targetRoomName) async {
    if (!_isConnected) return;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final suffix = DateTime.now().millisecondsSinceEpoch.toString().substring(
        10,
      );
      final effectiveUserId = isTeacher
          ? "teacher_$userId"
          : "${userId}_$suffix";
      final token = await LiveKitService().getRoomToken(
        roomName: targetRoomName,
        userId: effectiveUserId,
        userName: userName,
      );
      if (token == null) throw Exception("Failed to get token");
      if (_room != null) {
        await _listener?.dispose();
        await _room!.disconnect();
        await Future.delayed(const Duration(milliseconds: 500));
      }
      _room = Room(
        roomOptions: const RoomOptions(adaptiveStream: true, dynacast: true),
      );
      _listener = _room!.createListener();
      _setupEventListeners();
      await _room!.connect(
        'wss://learning-system-07wdu0v6.livekit.cloud',
        token,
      );
      _currentRoomName = targetRoomName;
      if (isBreakoutRoom) {
        _whiteboardStrokes.clear();
        _redoStack.clear();
      }
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = "فشل الاتصال بالقاعة.";
      _isLoading = false;
      notifyListeners();
    }
  }

  void returnToMainRoom() => connectToRoom(roomName);
  void joinBreakoutRoom(int groupNum) =>
      connectToRoom("${roomName}_group_$groupNum");

  void _setupEventListeners() {
    _listener!
      ..on<DataReceivedEvent>((event) {
        final data = jsonDecode(utf8.decode(event.data));
        _handleIncomingData(data, event.participant);
      })
      ..on<ParticipantConnectedEvent>((event) {
        notifyListeners();
        onNotification?.call(
          "👋 انضم ${event.participant.name ?? "مشارك"} للبث",
          Colors.green.shade700,
        );
      })
      ..on<ParticipantDisconnectedEvent>((event) {
        onNotification?.call(
          "🚪 غادر ${event.participant.name ?? "مشارك"} القاعة",
          Colors.blueGrey.shade700,
        );
        _handRaiseQueue.removeWhere(
              (item) => item['identity'] == event.participant.identity,
        );
        notifyListeners();
      })
      ..on<ActiveSpeakersChangedEvent>((event) {
        if (_room?.localParticipant != null && !_isMicEnabled) {
          final isSpeaking = event.speakers.any(
                (s) => s.identity == _room!.localParticipant!.identity,
          );
          if (isSpeaking) {
            final now = DateTime.now();
            if (_lastMutedSpeechWarning == null ||
                now.difference(_lastMutedSpeechWarning!).inSeconds > 5) {
              _lastMutedSpeechWarning = now;
              onNotification?.call(
                "الميكروفون مغلق حالياً 🎤",
                Colors.blueAccent,
              );
              _triggerHaptic(heavy: true);
            }
          }
        }
        notifyListeners();
      })
      ..on<TrackSubscribedEvent>((_) => notifyListeners())
      ..on<TrackUnsubscribedEvent>((_) => notifyListeners())
      ..on<TrackMutedEvent>((_) => notifyListeners())
      ..on<TrackUnmutedEvent>((_) => notifyListeners());
  }

  bool _isMe(String? targetId) {
    if (targetId == null) return false;
    final myId = _room?.localParticipant?.identity ?? userId;
    return targetId.split('_').first == myId.split('_').first;
  }

  void _handleIncomingData(Map<String, dynamic> data, RemoteParticipant? p) {
    switch (data['type']) {
      case 'chat_message':
        _messages.insert(0, data);
        break;
      case 'reaction':
        onReactionReceived?.call(data['value']);
        break;
      case 'control_mic':
        _handleMicControl(data);
        break;
      case 'control_cam':
        _handleCamControl(data);
        break;
      case 'breakout_invite':
        if (_isMe(data['target'])) {
          _breakoutTimeLeft = data['duration'] * 60;
          _startBreakoutCountdown();
          onBreakoutInvite?.call(
            data['room'],
            data['groupName'],
            data['duration'],
          );
        }
        break;
      case 'end_breakout':
        _breakoutTimer?.cancel();
        _breakoutTimeLeft = 0;
        if (isBreakoutRoom) returnToMainRoom();
        break;
      case 'kick_participant':
        if (_isMe(data['target'])) {
          _room?.disconnect();
          onSessionEnded?.call("تم استبعادك من القاعة.");
        }
        break;
      case 'new_question':
        _questions.add(data);
        break;
      case 'poll_create':
        _activePoll = data['poll'];
        _pollResults = {for (var o in data['poll']['options']) o: 0};
        _isPollsOpen = true;
        break;
      case 'poll_vote':
        _pollResults[data['option']] = (_pollResults[data['option']] ?? 0) + 1;
        break;
      case 'quiz_create':
        _handleQuiz(data['quiz']);
        break;
      case 'hand_raise':
        if (p != null) {
          _remoteHandStates[p.identity] = data['value'];
          if (data['value'] == true) {
            if (!_handRaiseQueue.any((i) => i['identity'] == p.identity))
              _handRaiseQueue.add({
                'identity': p.identity,
                'name': p.name ?? "طالب",
                'time': DateTime.now(),
              });
            if (isTeacher)
              onNotification?.call(
                "قام ${p.name ?? "مشارك"} برفع يده ✋",
                Colors.orange,
              );
          } else {
            _handRaiseQueue.removeWhere((i) => i['identity'] == p.identity);
          }
        }
        break;
      case 'lower_hand':
        if (_isMe(data['target'])) _isHandRaised = false;
        _handRaiseQueue.removeWhere((i) => i['identity'] == data['target']);
        break;
      case 'lower_all_hands':
        _remoteHandStates.clear();
        _handRaiseQueue.clear();
        _isHandRaised = false;
        break;
      case 'session_ended':
        onNotification?.call("🔴 انتهى البث.", Colors.redAccent);
        Future.delayed(
          const Duration(seconds: 2),
              () => onSessionEnded?.call("انتهت الحصة."),
        );
        break;
      case 'whiteboard_draw':
        _handleDraw(data);
        break;
      case 'whiteboard_undo':
        if (_whiteboardStrokes.isNotEmpty) {
          _redoStack.add(_whiteboardStrokes.removeLast());
        }
        break;
      case 'whiteboard_redo':
        if (_redoStack.isNotEmpty) {
          _whiteboardStrokes.add(_redoStack.removeLast());
        }
        break;
      case 'whiteboard_clear':
        _whiteboardStrokes.clear();
        break;
      case 'control_chat':
        _isChatLocked = data['value'];
        break;
      case 'control_whiteboard':
        _isWhiteboardLocked = data['value'];
        break;
      case 'control_screenshare':
        _isScreenShareLocked = data['value'];
        break;
      case 'spotlight':
        _spotlightUserId = data['value'];
        break;
    }
    notifyListeners();
  }

  void _startBreakoutCountdown() {
    _breakoutTimer?.cancel();
    _breakoutTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_breakoutTimeLeft > 0) {
        _breakoutTimeLeft--;
        notifyListeners();
      } else {
        t.cancel();
        if (isBreakoutRoom) returnToMainRoom();
      }
    });
  }

  void _handleQuiz(Map<String, dynamic> quizData) {
    _activeQuiz = QuizModel.fromMap(quizData);
    _quizTimeLeft = _activeQuiz!.timeLimitSeconds;
    _isQuizOpen = true;
    _quizTimer?.cancel();
    _quizTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_quizTimeLeft > 0) {
        _quizTimeLeft--;
        notifyListeners();
      } else {
        t.cancel();
        _isQuizOpen = false;
        notifyListeners();
      }
    });
  }

  void submitQuiz(int selectedIndex) async {
    if (_activeQuiz == null) return;
    _quizSubmitted = true;
    try {
      await supabase.from('quiz_results').insert({
        'quiz_id': _activeQuiz!.id,
        'student_id': userId,
        'student_name': userName,
        'selected_option_index': selectedIndex,
        'is_correct': selectedIndex == _activeQuiz!.correctOptionIndex,
      });
    } catch (_) {}
    notifyListeners();
  }

  void startBreakoutRooms(int count, int duration) async {
    if (!isTeacher || _room == null || _isProcessing) return;
    final students = _room!.remoteParticipants.values.toList();
    if (students.isEmpty) return;
    _isProcessing = true;
    _isBreakoutActive = true;
    _breakoutTimeLeft = duration * 60;
    _breakoutGroups.clear();
    notifyListeners();
    try {
      students.shuffle();
      List<Map<String, dynamic>> groupingData = [];
      for (int i = 0; i < students.length; i++) {
        int gNum = (i % count) + 1;
        String gRoom = "${roomName}_group_$gNum";
        _breakoutGroups
            .putIfAbsent(gNum, () => [])
            .add(students[i].name ?? students[i].identity);
        groupingData.add({
          'student_id': students[i].identity,
          'group_room': gRoom,
        });
        sendData(
          {
            'type': 'breakout_invite',
            'target': students[i].identity,
            'room': gRoom,
            'groupName': "مجموعة $gNum",
            'duration': duration,
          },
          targetIdentities: [students[i].identity],
        );
      }
      if (sessionId != null)
        await LiveKitService().logBreakoutSession(
          parentSessionId: sessionId!,
          groups: groupingData,
          durationMinutes: duration,
        );
      _startBreakoutCountdown();
      onNotification?.call("تم بدء المجموعات بنجاح ✅", Colors.green);
    } catch (_) {
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  void endBreakoutRooms() {
    if (!isTeacher) return;
    _isBreakoutActive = false;
    _breakoutTimer?.cancel();
    _breakoutTimeLeft = 0;
    sendData({'type': 'end_breakout'});
    notifyListeners();
  }

  void muteParticipant(String tId, bool mute) => sendData({
    'type': 'control_mic',
    'target': tId,
    'value': !mute,
    'lock': mute,
  });
  void muteAllParticipants(bool mute) {
    _isAllMuted = mute;
    _isMicLocked = mute;
    sendData({
      'type': 'control_mic',
      'target': null,
      'value': !mute,
      'lock': mute,
    });
    notifyListeners();
  }

  void disableParticipantCamera(String tId, bool disable) => sendData({
    'type': 'control_cam',
    'target': tId,
    'value': !disable,
    'lock': disable,
  });
  void disableAllCameras(bool disable) {
    _isCamLocked = disable;
    sendData({
      'type': 'control_cam',
      'target': null,
      'value': !disable,
      'lock': disable,
    });
    notifyListeners();
  }

  void lowerParticipantHand(String id) {
    _handRaiseQueue.removeWhere((i) => i['identity'] == id);
    sendData({'type': 'lower_hand', 'target': id});
    notifyListeners();
  }

  void lowerAllHands() {
    _handRaiseQueue.clear();
    _isHandRaised = false;
    sendData({'type': 'lower_all_hands'});
    notifyListeners();
  }

  void toggleChatLock() {
    _isChatLocked = !_isChatLocked;
    sendData({'type': 'control_chat', 'value': _isChatLocked});
    notifyListeners();
  }

  void toggleWhiteboardLock() {
    _isWhiteboardLocked = !_isWhiteboardLocked;
    sendData({'type': 'control_whiteboard', 'value': _isWhiteboardLocked});
    notifyListeners();
  }

  void toggleScreenShareLock() {
    _isScreenShareLocked = !_isScreenShareLocked;
    sendData({'type': 'control_screenshare', 'value': _isScreenShareLocked});
    notifyListeners();
  }

  void setSpotlight(String? id) {
    _spotlightUserId = id;
    sendData({'type': 'spotlight', 'value': id});
    notifyListeners();
  }

  void kickParticipant(String tId) async {
    if (!isTeacher) return;
    sendData({'type': 'kick_participant', 'target': tId});
    if (sessionId != null)
      await DatabaseService().markStudentAsKicked(
        sessionId!,
        tId.split('_').first,
      );
    notifyListeners();
  }

  void _handleMicControl(Map<String, dynamic> data) {
    if (!isTeacher && _isMe(data['target'])) {
      _isMicEnabled = data['value'];
      _room?.localParticipant?.setMicrophoneEnabled(_isMicEnabled);
      notifyListeners();
    }
  }

  void _handleCamControl(Map<String, dynamic> data) {
    if (!isTeacher && _isMe(data['target'])) {
      _isCamEnabled = data['value'];
      _room?.localParticipant?.setCameraEnabled(_isCamEnabled);
      notifyListeners();
    }
  }

  void _handleDraw(Map<String, dynamic> data) {
    final List points = data['points'];
    _whiteboardStrokes.add(
      Stroke(
        points: points
            .map((e) => Offset(e['x'].toDouble(), e['y'].toDouble()))
            .toList(),
        color: Color(data['color']),
        width: data['width'].toDouble(),
      ),
    );
    _redoStack.clear();
  }

  void addStroke(List<Offset> pts) {
    if (!isTeacher && _isWhiteboardLocked) return;
    final s = Stroke(
      points: List.from(pts),
      color: _selectedColor,
      width: _strokeWidth,
    );
    _whiteboardStrokes.add(s);
    _redoStack.clear();
    sendData({
      'type': 'whiteboard_draw',
      'points': pts.map((e) => {'x': e.dx, 'y': e.dy}).toList(),
      'color': s.color.toARGB32(),
      'width': s.width,
    });
    notifyListeners();
  }

  void undoWhiteboard() {
    if (_whiteboardStrokes.isNotEmpty) {
      _redoStack.add(_whiteboardStrokes.removeLast());
      sendData({'type': 'whiteboard_undo'});
      notifyListeners();
    }
  }

  void redoWhiteboard() {
    if (_redoStack.isNotEmpty) {
      _whiteboardStrokes.add(_redoStack.removeLast());
      sendData({'type': 'whiteboard_redo'});
      notifyListeners();
    }
  }

  void clearWhiteboard() {
    _whiteboardStrokes.clear();
    _redoStack.clear();
    sendData({'type': 'whiteboard_clear'});
    notifyListeners();
  }

  void sendMessage(String text) async {
    if (text.trim().isEmpty || (_isChatLocked && !isTeacher)) return;
    final msg = {
      'user_name': userName,
      'content': text.trim(),
      'created_at': DateTime.now().toIso8601String(),
    };
    _messages.insert(0, msg);
    sendData({'type': 'chat_message', ...msg});
    try {
      await supabase.from('messages').insert({
        'room_name': roomName,
        'user_name': userName,
        'content': text.trim(),
      });
    } catch (_) {}
    notifyListeners();
  }

  Future<void> toggleMic() async {
    if (_isMicLocked && !isTeacher) return;
    _isMicEnabled = !_isMicEnabled;
    await _room?.localParticipant?.setMicrophoneEnabled(_isMicEnabled);
    notifyListeners();
  }

  Future<void> toggleCam() async {
    if (_isCamLocked && !isTeacher) return;
    _isCamEnabled = !_isCamEnabled;
    await _room?.localParticipant?.setCameraEnabled(_isCamEnabled);
    notifyListeners();
  }

  void toggleHand() {
    _isHandRaised = !_isHandRaised;
    sendData({'type': 'hand_raise', 'value': _isHandRaised});
    notifyListeners();
  }

  Future<void> toggleScreenShare() async {
    if (!isTeacher && _isScreenShareLocked) return;
    try {
      _isScreenSharing = !_isScreenSharing;
      await _room!.localParticipant?.setScreenShareEnabled(_isScreenSharing);
      notifyListeners();
    } catch (_) {
      _isScreenSharing = false;
      notifyListeners();
    }
  }

  void sendReaction(String emoji) {
    sendData({'type': 'reaction', 'value': emoji});
    onReactionReceived?.call(emoji);
    _triggerHaptic();
  }

  void sendData(Map<String, dynamic> d, {List<String>? targetIdentities}) {
    if (_room != null) {
      final data = utf8.encode(jsonEncode(d));
      _room!.localParticipant?.publishData(
        data,
        reliable: true,
        destinationIdentities: targetIdentities,
      );
    }
  }

  Future<void> startRecording() async {
    if (sessionId != null &&
        await LiveKitService().startRecording(roomName, sessionId!)) {
      _isRecording = true;
      notifyListeners();
    }
  }

  Future<void> endSessionForAll() async {
    if (!isTeacher || sessionId == null) return;
    _isProcessing = true;
    notifyListeners();
    try {
      // 1. إرسال إشارة لجميع المشاركين بإنهاء الجلسة
      sendData({'type': 'session_ended'});

      // 2. تحديث حالة الجلسة في قاعدة البيانات إلى مؤرشفة
      await DatabaseService().updateSessionStatus(sessionId!, 'archived');

      // 3. جلب بيانات الحضور لتوليد التقرير
      final attendanceData = await DatabaseService().getSessionAttendance(sessionId!);
      
      // 4. توليد تقرير PDF وحفظه/عرضه
      await AttendancePdfService().generateReport(
        subjectName: title,
        teacherName: userName,
        studentsData: attendanceData,
      );

      // 5. فصل الاتصال
      _room?.disconnect();
      onSessionEnded?.call("تم إنهاء الحصة وتوليد تقرير الحضور بنجاح ✅");
    } catch (e) {
      debugPrint("Error ending session: $e");
      onNotification?.call("حدث خطأ أثناء أرشفة الجلسة", Colors.red);
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    if (sessionId != null) DatabaseService().logStudentExit(sessionId!, userId);
    _connectivitySubscription?.cancel();
    _statusSubscription?.cancel();
    _expiryTimer?.cancel();
    _quizTimer?.cancel();
    _breakoutTimer?.cancel();
    _room?.disconnect();
    super.dispose();
  }
}
