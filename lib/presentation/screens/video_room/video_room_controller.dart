import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart' hide ConnectionState;
import 'package:livekit_client/livekit_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../../core/services/livekit_service.dart';
import '../../../core/services/database_service.dart';
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
  String? _errorMessage;
  String? _currentRoomName;
  bool _isBreakoutActive = false;
  
  bool _isMicEnabled = false;
  bool _isCamEnabled = false;
  bool _isHandRaised = false;
  bool _isMicLocked = false;
  bool _isRecording = false;
  bool _isScreenSharing = false;

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
  List<Map<String, dynamic>> _questions = [];
  final Map<String, bool> _remoteHandStates = {};
  bool _isChatLocked = false;

  // Connectivity state
  bool _isConnected = true;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  // Getters
  Room? get room => _room;
  bool get isLoading => _isLoading;
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
  bool get isChatLocked => _isChatLocked;
  Color get selectedColor => _selectedColor;
  bool get isBreakoutActive => _isBreakoutActive;
  bool get isBreakoutRoom => _currentRoomName != null && _currentRoomName != roomName;
  bool get isConnected => _isConnected;

  // Callbacks
  Function(String message)? onSessionEnded;
  Function(String title, Color color)? onNotification;
  Function(String room, String name)? onBreakoutInvite;
  Function(String emoji)? onReactionReceived;

  final supabase = Supabase.instance.client;
  StreamSubscription? _statusSubscription;
  StreamSubscription? _chatSubscription;
  Timer? _expiryTimer;

  void toggleChat() { _isChatOpen = !_isChatOpen; _isWhiteboardOpen = false; _isQAOpen = false; _isParticipantsOpen = false; notifyListeners(); }
  void toggleWhiteboard() { _isWhiteboardOpen = !_isWhiteboardOpen; _isChatOpen = false; _isQAOpen = false; _isParticipantsOpen = false; notifyListeners(); }
  void toggleQA() { _isQAOpen = !_isQAOpen; _isChatOpen = false; _isWhiteboardOpen = false; _isParticipantsOpen = false; notifyListeners(); }
  void toggleParticipants() { _isParticipantsOpen = !_isParticipantsOpen; _isChatOpen = false; _isWhiteboardOpen = false; _isQAOpen = false; notifyListeners(); }
  
  void setWhiteboardColor(Color color) { _selectedColor = color; notifyListeners(); }
  void setStrokeWidth(double width) { _strokeWidth = width; notifyListeners(); }

  Future<void> init() async {
    _currentRoomName = roomName;
    
    // Monitor Connectivity
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      final hasInternet = results.any((result) => result != ConnectivityResult.none);
      if (_isConnected && !hasInternet) {
        _isConnected = false;
        onNotification?.call("فقدت الاتصال بالإنترنت ⚠️", Colors.red);
      } else if (!_isConnected && hasInternet) {
        _isConnected = true;
        onNotification?.call("تم استعادة الاتصال بالإنترنت ✅", Colors.green);
        // Retry connection if needed
        if (_room == null || _room!.connectionState == ConnectionState.disconnected) {
          connectToRoom(_currentRoomName ?? roomName);
        }
      }
      notifyListeners();
    });

    // Check initial connectivity
    final results = await Connectivity().checkConnectivity();
    _isConnected = results.any((result) => result != ConnectivityResult.none);

    if (!_isConnected) {
      _isLoading = false;
      _errorMessage = "لا يوجد اتصال بالإنترنت";
      notifyListeners();
      return;
    }

    if (sessionId != null && sessionId!.isNotEmpty) {
      final isValid = await _checkAndMonitorSession();
      if (!isValid) return;
      _initChatRealtime();
    }
    await connectToRoom(roomName);
  }

  void _initChatRealtime() {
    if (sessionId == null || sessionId!.isEmpty) return;
    _chatSubscription = supabase
        .from('chat_messages')
        .stream(primaryKey: ['id'])
        .eq('session_id', sessionId!)
        .order('created_at')
        .listen((data) {
          _messages = List<Map<String, dynamic>>.from(data);
          notifyListeners();
        });
  }

  Future<bool> _checkAndMonitorSession() async {
    try {
      final res = await supabase.from('sessions').select().eq('id', sessionId!).single();
      final DateTime endTime = DateTime.parse(res['end_time']);
      if (res['status'] == 'ended' || DateTime.now().isAfter(endTime)) {
        onSessionEnded?.call("هذه الجلسة انتهت بالفعل.");
        return false;
      }
      _statusSubscription = DatabaseService().watchSessionStatus(sessionId!).listen((data) {
        if (data['status'] == 'ended') onSessionEnded?.call("تم إنهاء الجلسة.");
      });
      _expiryTimer = Timer(endTime.difference(DateTime.now()), () {
        onSessionEnded?.call("انتهى وقت الحصة.");
      });
      if (isTeacher && res['is_recording_enabled'] == true) startRecording();
      return true;
    } catch (e) { return true; }
  }

  Future<void> connectToRoom(String targetRoomName) async {
    if (!_isConnected) {
      onNotification?.call("يرجى التحقق من اتصالك بالإنترنت", Colors.orange);
      return;
    }

    _isLoading = true; notifyListeners();
    try {
      final token = await LiveKitService().getRoomToken(roomName: targetRoomName, userId: userId, userName: userName);
      if (_room != null) { await _listener?.dispose(); await _room!.disconnect(); }
      _room = Room();
      _listener = _room!.createListener();
      _setupEventListeners();
      await _room!.connect('wss://learning-system-07wdu0v6.livekit.cloud', token!);
      
      _currentRoomName = targetRoomName;
      _isLoading = false; notifyListeners();
    } catch (e) { _errorMessage = e.toString(); _isLoading = false; notifyListeners(); }
  }

  void returnToMainRoom() => connectToRoom(roomName);

  void _setupEventListeners() {
    _listener!
      ..on<DataReceivedEvent>((event) {
        final data = jsonDecode(utf8.decode(event.data));
        _handleIncomingData(data, event.participant);
      })
      ..on<ParticipantConnectedEvent>((_) => notifyListeners())
      ..on<ParticipantDisconnectedEvent>((_) => notifyListeners())
      ..on<ActiveSpeakersChangedEvent>((_) => notifyListeners())
      ..on<TrackSubscribedEvent>((_) => notifyListeners())
      ..on<TrackUnsubscribedEvent>((_) => notifyListeners())
      ..on<TrackMutedEvent>((_) => notifyListeners())
      ..on<TrackUnmutedEvent>((_) => notifyListeners())
      ..on<ParticipantMetadataUpdatedEvent>((_) => notifyListeners())
      ..on<ParticipantConnectionQualityUpdatedEvent>((_) => notifyListeners());
  }

  void _handleIncomingData(Map<String, dynamic> data, RemoteParticipant? p) {
    switch (data['type']) {
      case 'new_question': 
        _questions.add(data); 
        if (!_isQAOpen) onNotification?.call("سؤال جديد من ${data['from']}", Colors.blue);
        break;
      case 'poll_create': _activePoll = data['poll']; _pollResults = {for (var o in data['poll']['options']) o: 0}; _isPollsOpen = true; break;
      case 'poll_vote': _pollResults[data['option']] = (_pollResults[data['option']] ?? 0) + 1; break;
      case 'quiz_create': _handleQuiz(data['quiz']); break;
      case 'hand_raise': 
        if (p != null) {
          _remoteHandStates[p.identity] = data['value'];
          if (isTeacher && data['value'] == true) {
            onNotification?.call("قام ${p.name ?? 'طالب'} برفع يده ✋", Colors.orange);
          }
        }
        break;
      case 'lower_hand':
        if (data['target'] == userId) {
          _isHandRaised = false;
          onNotification?.call("قام المدرس بإنزال يدك", Colors.blueGrey);
        } else {
          _remoteHandStates[data['target']] = false;
        }
        break;
      case 'lower_all_hands':
        _remoteHandStates.clear();
        _isHandRaised = false;
        onNotification?.call("تم إنزال أيدي الجميع", Colors.blueGrey);
        break;
      case 'breakout_invite':
        if (data['target'] == userId) {
          onBreakoutInvite?.call(data['room'], data['groupName']);
        }
        break;
      case 'end_breakout':
        if (!isTeacher) returnToMainRoom();
        break;
    }
    notifyListeners();
  }

  void _handleQuiz(Map<String, dynamic> quizData) {
    _activeQuiz = QuizModel.fromMap(quizData);
    _quizTimeLeft = _activeQuiz!.timeLimitSeconds;
    _isQuizOpen = true;
    _quizTimer?.cancel();
    _quizTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_quizTimeLeft > 0) { _quizTimeLeft--; notifyListeners(); }
      else { t.cancel(); _isQuizOpen = false; notifyListeners(); }
    });
  }

  void submitQuiz(int score) async {
    if (!_isConnected) {
      onNotification?.call("لا يوجد إنترنت لإرسال الإجابة", Colors.red);
      return;
    }
    _quizSubmitted = true;
    try {
      await supabase.from('quiz_results').insert({
        'session_id': sessionId,
        'user_id': userId,
        'score': score,
      });
    } catch (e) { debugPrint("Error submitting quiz: $e"); }
    notifyListeners();
  }

  void _handleMicControl(Map<String, dynamic> data) {
    if (!isTeacher && (data['target'] == userId || data['target'] == null)) {
      _isMicEnabled = data['value'];
      _isMicLocked = data['lock'] ?? false;
      _room?.localParticipant?.setMicrophoneEnabled(_isMicEnabled);
      onNotification?.call(_isMicLocked ? "الميكروفون مقفل" : "الميكروفون مفعل", _isMicLocked ? Colors.red : Colors.green);
    }
  }

  void _handleDraw(Map<String, dynamic> data) {
    final List points = data['points'];
    _whiteboardStrokes.add(Stroke(
      points: points.map((e) => Offset(e['x'].toDouble(), e['y'].toDouble())).toList(),
      color: Color(data['color']),
      width: data['width'].toDouble(),
    ));
    _redoStack.clear();
  }

  void addStroke(List<Offset> points) {
    if (!_isConnected) return;
    final s = Stroke(points: List.from(points), color: _selectedColor, width: _strokeWidth);
    _whiteboardStrokes.add(s);
    _redoStack.clear();
    sendData({
      'type': 'whiteboard_draw', 
      'points': points.map((e) => {'x': e.dx, 'y': e.dy}).toList(), 
      'color': s.color.toARGB32(), 
      'width': s.width
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
    if (!_isConnected) {
      onNotification?.call("لا يوجد إنترنت لإرسال الرسالة", Colors.red);
      return;
    }
    if (_isChatLocked && !isTeacher) return;
    if (sessionId == null || sessionId!.isEmpty) {
      onNotification?.call("لا يمكن إرسال رسائل في غرفة بدون جلسة نشطة", Colors.red);
      return;
    }
    try {
      await supabase.from('chat_messages').insert({
        'session_id': sessionId,
        'user_id': userId,
        'user_name': userName,
        'message_text': text,
      });
    } catch (e) { debugPrint("Error sending message: $e"); }
  }

  void toggleMic() { 
    if (!_isConnected) { onNotification?.call("تحقق من الإنترنت أولاً", Colors.orange); return; }
    if (!_isMicLocked) { _isMicEnabled = !_isMicEnabled; _room?.localParticipant?.setMicrophoneEnabled(_isMicEnabled); notifyListeners(); } 
  }
  
  void toggleCam() { 
    if (!_isConnected) { onNotification?.call("تحقق من الإنترنت أولاً", Colors.orange); return; }
    _isCamEnabled = !_isCamEnabled; _room?.localParticipant?.setCameraEnabled(_isCamEnabled); notifyListeners(); 
  }
  
  void toggleHand() { 
    if (!_isConnected) { onNotification?.call("تحقق من الإنترنت أولاً", Colors.orange); return; }
    _isHandRaised = !_isHandRaised; sendData({'type': 'hand_raise', 'value': _isHandRaised}); notifyListeners(); 
  }
  
  void lowerParticipantHand(String identity) {
    if (!isTeacher || !_isConnected) return;
    _remoteHandStates[identity] = false;
    sendData({'type': 'lower_hand', 'target': identity});
    notifyListeners();
  }

  void lowerAllHands() {
    if (!isTeacher || !_isConnected) return;
    _remoteHandStates.clear();
    _isHandRaised = false;
    sendData({'type': 'lower_all_hands'});
    notifyListeners();
  }

  void toggleChatLock() {
    if (!isTeacher || !_isConnected) return;
    _isChatLocked = !_isChatLocked;
    sendData({'type': 'control_chat', 'value': _isChatLocked});
    notifyListeners();
  }

  void startBreakoutRooms(int count) {
    if (!isTeacher || _room == null || !_isConnected) return;
    final students = _room!.remoteParticipants.values.toList();
    if (students.isEmpty) {
      onNotification?.call("لا يوجد طلاب لتقسيمهم", Colors.red);
      return;
    }

    _isBreakoutActive = true;
    for (int i = 0; i < students.length; i++) {
      int groupNum = (i % count) + 1;
      String groupRoom = "${roomName}_group_$groupNum";
      sendData({
        'type': 'breakout_invite',
        'target': students[i].identity,
        'room': groupRoom,
        'groupName': "مجموعة العمل $groupNum"
      });
    }
    notifyListeners();
    onNotification?.call("تم إرسال دعوات غرف العمل", Colors.green);
  }

  void endBreakoutRooms() {
    if (!isTeacher || !_isConnected) return;
    _isBreakoutActive = false;
    sendData({'type': 'end_breakout'});
    notifyListeners();
    onNotification?.call("تم إنهاء مجموعات العمل وعودة الجميع", Colors.blueGrey);
  }

  void muteParticipant(String targetUserId, bool mute) {
    if (!isTeacher || !_isConnected) return;
    sendData({
      'type': 'control_mic',
      'target': targetUserId,
      'value': !mute,
      'lock': mute
    });
  }

  void kickParticipant(String targetUserId) {
    if (!isTeacher || !_isConnected) return;
    sendData({
      'type': 'kick_participant',
      'target': targetUserId
    });
  }

  Future<void> toggleScreenShare() async {
    if (_room == null || !_isConnected) return;
    try {
      _isScreenSharing = !_isScreenSharing;
      await _room!.localParticipant?.setScreenShareEnabled(_isScreenSharing);
      notifyListeners();
    } catch (e) {
      _isScreenSharing = false;
      onNotification?.call("فشل بدء مشاركة الشاشة", Colors.red);
      notifyListeners();
    }
  }

  void sendReaction(String emoji) { 
    if (!_isConnected) return;
    sendData({'type': 'reaction', 'value': emoji}); onReactionReceived?.call(emoji); 
  }
  
  void sendData(Map<String, dynamic> d) {
    if (_isConnected) {
      _room?.localParticipant?.publishData(utf8.encode(jsonEncode(d)));
    }
  }

  Future<void> startRecording() async { 
    if (!_isConnected) return;
    if (await LiveKitService().startRecording(roomName, sessionId!)) { _isRecording = true; notifyListeners(); } 
  }

  Future<void> endSessionForAll() async {
    if (isTeacher && sessionId != null && _isConnected) {
      try {
        await DatabaseService().toggleRoomStatus(sessionId!, false);
        sendData({'type': 'session_ended'});
      } catch (e) { debugPrint("Error ending session: $e"); }
    }
  }

  @override
  void dispose() {
    if (sessionId != null && sessionId!.isNotEmpty) {
      DatabaseService().logStudentExit(sessionId!, userId);
    }
    _connectivitySubscription?.cancel();
    _statusSubscription?.cancel(); 
    _chatSubscription?.cancel();
    _expiryTimer?.cancel(); 
    _quizTimer?.cancel();
    _room?.disconnect(); 
    super.dispose();
  }
}
