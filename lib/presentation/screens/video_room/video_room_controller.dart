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

  // Moderation States
  bool _isChatLocked = false;
  bool _isWhiteboardLocked = false;
  bool _isScreenShareLocked = false; 
  String? _spotlightUserId; 

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
  bool get isWhiteboardLocked => _isWhiteboardLocked;
  bool get isScreenShareLocked => _isScreenShareLocked;
  String? get spotlightUserId => _spotlightUserId;

  Color get selectedColor => _selectedColor;
  bool get isBreakoutActive => _isBreakoutActive;
  bool get isBreakoutRoom => _currentRoomName != null && _currentRoomName != roomName;
  bool get isConnected => _isConnected;

  Function(String message)? onSessionEnded;
  Function(String title, Color color)? onNotification;
  Function(String room, String name)? onBreakoutInvite;
  Function(String emoji)? onReactionReceived;

  final supabase = Supabase.instance.client;
  StreamSubscription? _statusSubscription;
  Timer? _expiryTimer;

  void toggleChat() { _isChatOpen = !_isChatOpen; _isWhiteboardOpen = false; _isQAOpen = false; _isParticipantsOpen = false; notifyListeners(); }
  void toggleWhiteboard() { _isWhiteboardOpen = !_isWhiteboardOpen; _isChatOpen = false; _isQAOpen = false; _isParticipantsOpen = false; notifyListeners(); }
  void toggleQA() { _isQAOpen = !_isQAOpen; _isChatOpen = false; _isWhiteboardOpen = false; _isParticipantsOpen = false; notifyListeners(); }
  void toggleParticipants() { _isParticipantsOpen = !_isParticipantsOpen; _isChatOpen = false; _isWhiteboardOpen = false; _isQAOpen = false; notifyListeners(); }
  
  void setWhiteboardColor(Color color) { _selectedColor = color; notifyListeners(); }
  void setStrokeWidth(double width) { _strokeWidth = width; notifyListeners(); }

  Future<void> init() async {
    _currentRoomName = roomName;
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      final hasInternet = results.any((result) => result != ConnectivityResult.none);
      if (_isConnected && !hasInternet) {
        _isConnected = false;
        onNotification?.call("فقدت الاتصال بالإنترنت ⚠️", Colors.red);
      } else if (!_isConnected && hasInternet) {
        _isConnected = true;
        onNotification?.call("تم استعادة الاتصال بالإنترنت ✅", Colors.green);
        if (_room == null || _room!.connectionState == ConnectionState.disconnected) {
          connectToRoom(_currentRoomName ?? roomName);
        }
      }
      notifyListeners();
    });

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
    }
    
    // جلب التاريخ القديم للمحادثة عند البدء
    await _loadChatHistory();
    await connectToRoom(roomName);
  }

  // جلب الرسائل القديمة مرة واحدة (بدون Realtime)
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
      debugPrint("Error loading chat history: $e");
    }
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
        if (data.isNotEmpty && data.first['status'] == 'ended') {
          onNotification?.call("🔴 تم إنهاء البث المباشر من قبل المعلم.", Colors.redAccent);
          Future.delayed(const Duration(seconds: 3), () => onSessionEnded?.call("انتهت الحصة الدراسية."));
        }
      }, onError: (e) => debugPrint("Session listener error: $e"));
      
      _expiryTimer = Timer(endTime.difference(DateTime.now()), () {
        onSessionEnded?.call("انتهى وقت الحصة المجدول.");
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
      ..on<ParticipantConnectedEvent>((event) {
        String name = event.participant.name ?? "طالب جديد";
        onNotification?.call("👋 انضم $name للبث", Colors.green.shade700);
        notifyListeners();
      })
      ..on<ParticipantDisconnectedEvent>((event) {
        String name = event.participant.name ?? "طالب";
        onNotification?.call("🚪 غادر $name للبث", Colors.blueGrey.shade700);
        notifyListeners();
      })
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
      case 'chat_message':
        // استقبال رسالة شات جديدة عبر LiveKit
        _messages.insert(0, data);
        if (!_isChatOpen) {
          onNotification?.call("رسالة من ${data['user_name']}", Colors.blueAccent);
        }
        break;
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
      case 'control_mic':
        _handleMicControl(data);
        break;
      case 'kick_participant':
        if (data['target'] == userId) {
          onNotification?.call("⚠️ عذراً، لقد قرر المعلم استبعادك من الجلسة الحالية.", Colors.red);
          Future.delayed(const Duration(seconds: 4), () {
            _room?.disconnect();
            onSessionEnded?.call("تم استبعادك من القاعة الدراسية.");
          });
        }
        break;
      case 'session_ended':
        onNotification?.call("🔴 تم إنهاء البث المباشر من قبل المعلم، شكراً لكم.", Colors.redAccent);
        Future.delayed(const Duration(seconds: 3), () {
          _room?.disconnect();
          onSessionEnded?.call("انتهت الحصة الدراسية.");
        });
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
        _redoStack.clear();
        break;
      case 'control_chat':
        _isChatLocked = data['value'];
        onNotification?.call(_isChatLocked ? "تم قفل الدردشة من قبل المدرس" : "تم فتح الدردشة", Colors.blueGrey);
        break;
      case 'control_whiteboard':
        _isWhiteboardLocked = data['value'];
        onNotification?.call(_isWhiteboardLocked ? "المدرس قصر استخدام السبورة" : "تم السماح بالرسم للجميع", Colors.blueGrey);
        break;
      case 'control_screenshare':
        _isScreenShareLocked = data['value'];
        onNotification?.call(_isScreenShareLocked ? "مشاركة الشاشة مقفلة حالياً" : "تم السماح بمشاركة الشاشة", Colors.blueGrey);
        break;
      case 'spotlight':
        _spotlightUserId = data['value'];
        if (_spotlightUserId == userId && !isTeacher) {
          onNotification?.call("🌟 تم تسليط الضوء عليك من قبل المعلم", Colors.purple);
        }
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

  void submitQuiz(int selectedIndex) async {
    if (!_isConnected || _activeQuiz == null) return;
    _quizSubmitted = true;
    try {
      await supabase.from('quiz_results').insert({
        'quiz_id': _activeQuiz!.id,
        'student_id': userId,
        'student_name': userName,
        'selected_option_index': selectedIndex,
        'is_correct': selectedIndex == _activeQuiz!.correctOptionIndex,
      });
    } catch (e) { debugPrint("Error submitting quiz: $e"); }
    notifyListeners();
  }

  void _handleMicControl(Map<String, dynamic> data) {
    if (!isTeacher && (data['target'] == userId || data['target'] == null)) {
      _isMicEnabled = data['value'];
      _isMicLocked = data['lock'] ?? false;
      _room?.localParticipant?.setMicrophoneEnabled(_isMicEnabled);
      
      String msg = "";
      if (data['target'] == userId) {
        msg = _isMicEnabled ? "قام المعلم بتفعيل الميكروفون لك" : "قام المعلم بكتم صوتك";
      } else {
        msg = _isMicLocked ? "المدرس كتم صوت الجميع" : "المدرس سمح للجميع بالتحدث";
      }
      onNotification?.call(msg, _isMicLocked ? Colors.red : Colors.green);
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
    if (!isTeacher && _isWhiteboardLocked) {
      onNotification?.call("المدرس منع الرسم حالياً", Colors.orange);
      return;
    }
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
    if (_isChatLocked && !isTeacher) {
      onNotification?.call("الدردشة مقفلة حالياً", Colors.orange);
      return;
    }

    final newMessage = {
      'user_name': userName,
      'content': text,
      'created_at': DateTime.now().toIso8601String(),
    };

    // 1. أضف الرسالة محلياً فوراً (لسرعة العرض عند المستخدم)
    _messages.insert(0, newMessage);
    notifyListeners();

    // 2. أرسلها للآخرين فوراً عبر LiveKit (الحل البديل لـ Realtime)
    sendData({
      'type': 'chat_message',
      ...newMessage
    });
    
    // 3. احفظها في قاعدة البيانات لكي تظهر عند الدخول مرة أخرى (History)
    try {
      await supabase.from('messages').insert({
        'room_name': roomName,
        'user_name': userName,
        'content': text,
      });
    } catch (e) { debugPrint("Error sending message to DB: $e"); }
  }

  void toggleMic() { 
    if (!_isConnected) { onNotification?.call("تحقق من الإنترنت أولاً", Colors.orange); return; }
    if (!_isMicLocked) { 
      _isMicEnabled = !_isMicEnabled; 
      _room?.localParticipant?.setMicrophoneEnabled(_isMicEnabled); 
      notifyListeners(); 
    } else {
      onNotification?.call("المدرس منع استخدام الميكروفون", Colors.red);
    }
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

  void toggleWhiteboardLock() {
    if (!isTeacher || !_isConnected) return;
    _isWhiteboardLocked = !_isWhiteboardLocked;
    sendData({'type': 'control_whiteboard', 'value': _isWhiteboardLocked});
    notifyListeners();
  }

  void toggleScreenShareLock() {
    if (!isTeacher || !_isConnected) return;
    _isScreenShareLocked = !_isScreenShareLocked;
    sendData({'type': 'control_screenshare', 'value': _isScreenShareLocked});
    notifyListeners();
  }

  void setSpotlight(String? identity) {
    if (!isTeacher || !_isConnected) return;
    _spotlightUserId = identity;
    sendData({'type': 'spotlight', 'value': _spotlightUserId});
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

  // --- دوال التحكم المحدثة لضمان الوصول 100% ---
  
  void muteParticipant(String targetUserId, bool mute) {
    if (!isTeacher || !_isConnected) return;
    // نرسل الأمر بنظام Broadcast لضمان الوصول، والطالب سيتعرف عليه عبر target
    sendData({
      'type': 'control_mic',
      'target': targetUserId,
      'value': !mute,
      'lock': mute
    });
  }

  void muteAllParticipants(bool mute) {
    if (!isTeacher || !_isConnected) return;
    sendData({
      'type': 'control_mic',
      'target': null, 
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
    if (!isTeacher && _isScreenShareLocked) {
      onNotification?.call("مشاركة الشاشة معطلة من قبل المدرس", Colors.orange);
      return;
    }
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
      // إرسال البيانات لكل القاعة (Broadcast) لضمان وصولها بنجاح
      _room?.localParticipant?.publishData(
        utf8.encode(jsonEncode(d))
      );
    }
  }

  Future<void> startRecording() async { 
    if (!_isConnected) return;
    if (await LiveKitService().startRecording(roomName, sessionId!)) { _isRecording = true; notifyListeners(); } 
  }

  Future<void> endSessionForAll() async {
    if (isTeacher && sessionId != null && _isConnected) {
      try {
        sendData({'type': 'session_ended'});
        onNotification?.call("جاري إنهاء البث وحذف البيانات من المنصة...", Colors.blueAccent);
        await Future.delayed(const Duration(seconds: 3));
        await DatabaseService().deleteSession(sessionId!);
        _room?.disconnect();
        onSessionEnded?.call("تم إنهاء الحصة الدراسية بنجاح وحذف السجل.");
      } catch (e) { 
        debugPrint("Error ending session: $e");
        onNotification?.call("حدث خطأ أثناء إنهاء الجلسة", Colors.red);
      }
    }
  }

  @override
  void dispose() {
    if (sessionId != null && sessionId!.isNotEmpty) {
      DatabaseService().logStudentExit(sessionId!, userId);
    }
    _connectivitySubscription?.cancel();
    _statusSubscription?.cancel(); 
    _expiryTimer?.cancel(); 
    _quizTimer?.cancel();
    _room?.disconnect(); 
    super.dispose();
  }
}
