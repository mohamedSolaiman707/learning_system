import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
  final String roomName;
  final String userName;
  final String userId;
  final bool isTeacher;
  final String? sessionId;

  VideoRoomController({
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
    if (sessionId != null) {
      final isValid = await _checkAndMonitorSession();
      if (!isValid) return;
      _initChatRealtime();
    }
    await connectToRoom(roomName);
  }

  void _initChatRealtime() {
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
    _isLoading = true; notifyListeners();
    try {
      final token = await LiveKitService().getRoomToken(roomName: targetRoomName, userId: userId, userName: userName);
      if (_room != null) { await _listener?.dispose(); await _room!.disconnect(); }
      _room = Room();
      _listener = _room!.createListener();
      _setupEventListeners();
      await _room!.connect('wss://learning-system-07wdu0v6.livekit.cloud', token!);
      
      if (!isTeacher && sessionId != null) {
        DatabaseService().logStudentEntry(sessionId!, userId);
      }
      
      _isLoading = false; notifyListeners();
    } catch (e) { _errorMessage = e.toString(); _isLoading = false; notifyListeners(); }
  }

  void _setupEventListeners() {
    _listener!.on<DataReceivedEvent>((event) {
      final data = jsonDecode(utf8.decode(event.data));
      _handleIncomingData(data, event.participant);
    });
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
      case 'hand_raise': if (p != null) _remoteHandStates[p.identity] = data['value']; break;
      case 'reaction': onReactionReceived?.call(data['value']); break;
      case 'whiteboard_draw': _handleDraw(data); break;
      case 'whiteboard_clear': _whiteboardStrokes.clear(); _redoStack.clear(); break;
      case 'whiteboard_undo': 
        if (_whiteboardStrokes.isNotEmpty) _redoStack.add(_whiteboardStrokes.removeLast()); 
        break;
      case 'whiteboard_redo':
        if (_redoStack.isNotEmpty) _whiteboardStrokes.add(_redoStack.removeLast());
        break;
      case 'control_mic': _handleMicControl(data); break;
      case 'kick_participant': 
        if (data['target'] == userId) onSessionEnded?.call("تم استبعادك من الجلسة بواسطة المدرس.");
        break;
      case 'control_chat': _isChatLocked = data['value']; break;
      case 'breakout_invite': if (data['target'] == userId) onBreakoutInvite?.call(data['room'], data['groupName']); break;
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
    if (_isChatLocked && !isTeacher) return;
    try {
      await supabase.from('chat_messages').insert({
        'session_id': sessionId,
        'user_id': userId,
        'user_name': userName,
        'message_text': text,
      });
    } catch (e) { debugPrint("Error sending message: $e"); }
  }

  void toggleMic() { if (!_isMicLocked) { _isMicEnabled = !_isMicEnabled; _room?.localParticipant?.setMicrophoneEnabled(_isMicEnabled); notifyListeners(); } }
  void toggleCam() { _isCamEnabled = !_isCamEnabled; _room?.localParticipant?.setCameraEnabled(_isCamEnabled); notifyListeners(); }
  void toggleHand() { _isHandRaised = !_isHandRaised; sendData({'type': 'hand_raise', 'value': _isHandRaised}); notifyListeners(); }
  
  void muteParticipant(String targetUserId, bool mute) {
    if (!isTeacher) return;
    sendData({
      'type': 'control_mic',
      'target': targetUserId,
      'value': !mute,
      'lock': mute
    });
  }

  void kickParticipant(String targetUserId) {
    if (!isTeacher) return;
    sendData({
      'type': 'kick_participant',
      'target': targetUserId
    });
  }

  Future<void> toggleScreenShare() async {
    if (_room == null) return;
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

  void sendReaction(String emoji) { sendData({'type': 'reaction', 'value': emoji}); onReactionReceived?.call(emoji); }
  void sendData(Map<String, dynamic> d) => _room?.localParticipant?.publishData(utf8.encode(jsonEncode(d)));
  Future<void> startRecording() async { if (await LiveKitService().startRecording(roomName, sessionId!)) { _isRecording = true; notifyListeners(); } }

  Future<void> endSessionForAll() async {
    if (isTeacher && sessionId != null) {
      try {
        await DatabaseService().toggleRoomStatus(sessionId!, false);
        sendData({'type': 'session_ended'});
      } catch (e) { debugPrint("Error ending session: $e"); }
    }
  }

  @override
  void dispose() {
    if (sessionId != null) {
      DatabaseService().logStudentExit(sessionId!, userId);
    }
    _statusSubscription?.cancel(); 
    _chatSubscription?.cancel();
    _expiryTimer?.cancel(); 
    _quizTimer?.cancel();
    _room?.disconnect(); 
    super.dispose();
  }
}
