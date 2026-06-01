import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter/services.dart'; 
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
  bool _isProcessing = false; 
  String? _errorMessage;
  String? _currentRoomName;
  bool _isBreakoutActive = false;
  
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
  
  // نظام تتبع رفع اليد المطور
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
  bool get isRoomLocked => _isRoomLocked;

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

  void _triggerHaptic({bool heavy = false}) {
    if (heavy) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.lightImpact();
    }
  }

  void toggleChat() { _triggerHaptic(); _isChatOpen = !_isChatOpen; _isWhiteboardOpen = false; _isQAOpen = false; _isParticipantsOpen = false; notifyListeners(); }
  void toggleWhiteboard() { _triggerHaptic(); _isWhiteboardOpen = !_isWhiteboardOpen; _isChatOpen = false; _isQAOpen = false; _isParticipantsOpen = false; notifyListeners(); }
  void toggleQA() { _triggerHaptic(); _isQAOpen = !_isQAOpen; _isChatOpen = false; _isWhiteboardOpen = false; _isParticipantsOpen = false; notifyListeners(); }
  void toggleParticipants() { _triggerHaptic(); _isParticipantsOpen = !_isParticipantsOpen; _isChatOpen = false; _isWhiteboardOpen = false; _isQAOpen = false; notifyListeners(); }
  
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
        onNotification?.call("تم استعادة الاتصال ✅", Colors.green);
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
      debugPrint("Error loading chat history: $e");
    }
  }

  Future<bool> _checkAndMonitorSession() async {
    try {
      final res = await supabase.from('sessions').select().eq('id', sessionId!).single();
      final DateTime endTime = DateTime.parse(res['end_time']);
      if (res['status'] == 'ended' || res['status'] == 'archived' || DateTime.now().isAfter(endTime)) {
        onSessionEnded?.call("هذه الجلسة انتهت بالفعل.");
        return false;
      }
      _statusSubscription = DatabaseService().watchSessionStatus(sessionId!).listen((data) {
        if (data.isNotEmpty && (data.first['status'] == 'ended' || data.first['status'] == 'archived')) {
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
      onNotification?.call("لا يمكن الاتصال بدون إنترنت", Colors.orange);
      return;
    }

    _isLoading = true; 
    _errorMessage = null;
    notifyListeners();

    try {
      final suffix = DateTime.now().millisecondsSinceEpoch.toString().substring(10);
      final effectiveUserId = isTeacher ? "teacher_$userId" : "${userId}_$suffix";
      
      final token = await LiveKitService().getRoomToken(
        roomName: targetRoomName, 
        userId: effectiveUserId, 
        userName: userName
      );
      
      if (token == null) throw Exception("فشل الحصول على رمز الدخول من السيرفر");

      if (_room != null) { 
        await _listener?.dispose(); 
        await _room!.disconnect(); 
        await Future.delayed(const Duration(milliseconds: 800));
      }

      _room = Room(
        roomOptions: const RoomOptions(
          adaptiveStream: true,
          dynacast: true,
          defaultVideoPublishOptions: VideoPublishOptions(simulcast: true),
        ),
      );

      _listener = _room!.createListener();
      _setupEventListeners();

      int retryCount = 0;
      bool connected = false;
      
      while (retryCount < 3 && !connected) {
        try {
          await _room!.connect(
            'wss://learning-system-07wdu0v6.livekit.cloud', 
            token,
            connectOptions: const ConnectOptions(autoSubscribe: true),
          );
          connected = true;
        } catch (e) {
          retryCount++;
          if (retryCount >= 3) rethrow;
          await Future.delayed(Duration(seconds: retryCount * 2));
        }
      }
      
      _currentRoomName = targetRoomName;
      _isLoading = false; 
      _errorMessage = null;

      // تسجيل دخول الطالب في نظام الحضور
      if (!isTeacher && sessionId != null) {
        DatabaseService().logStudentEntry(sessionId!, userId);
      }

      notifyListeners();
    } catch (e) { 
      debugPrint("Connection Error: $e");
      _errorMessage = "فشل الاتصال بالقاعة. تأكد من جودة الإنترنت لديك."; 
      _isLoading = false; 
      notifyListeners(); 
    }
  }

  void returnToMainRoom() => connectToRoom(roomName);

  void _setupEventListeners() {
    _listener!
      ..on<DataReceivedEvent>((event) {
        final data = jsonDecode(utf8.decode(event.data));
        _handleIncomingData(data, event.participant);
      })
      ..on<ParticipantConnectedEvent>((event) {
        // تحديث الواجهة فوراً لزيادة العداد
        notifyListeners();
        Future.delayed(const Duration(milliseconds: 500), () {
          String name = event.participant.name ?? event.participant.identity;
          if (name.length > 30) name = "مشارك جديد";
          onNotification?.call("👋 انضم $name للبث", Colors.green.shade700);
        });
      })
      ..on<ParticipantDisconnectedEvent>((event) {
        String name = event.participant.name ?? event.participant.identity;
        onNotification?.call("🚪 غادر $name القاعة", Colors.blueGrey.shade700);
        
        _handRaiseQueue.removeWhere((item) => item['identity'] == event.participant.identity);
        
        notifyListeners();
      })
      ..on<RoomDisconnectedEvent>((event) {
        if (_isConnected) {
          onNotification?.call("⚠️ انقطع الاتصال بالقاعة، جاري المحاولة مرة أخرى...", Colors.orange);
        }
      })
      ..on<ActiveSpeakersChangedEvent>((event) {
        final local = _room?.localParticipant;
        if (local != null && !_isMicEnabled) {
          final isSpeaking = event.speakers.any((s) => s.identity == local.identity);
          if (isSpeaking) {
            final now = DateTime.now();
            if (_lastMutedSpeechWarning == null || now.difference(_lastMutedSpeechWarning!).inSeconds > 5) {
              _lastMutedSpeechWarning = now;
              onNotification?.call("أنت صامت حالياً، الميكروفون مغلق 🎤", Colors.blueAccent);
              _triggerHaptic(heavy: true);
            }
          }
        }
        notifyListeners();
      })
      ..on<TrackSubscribedEvent>((_) => notifyListeners())
      ..on<TrackUnsubscribedEvent>((_) => notifyListeners())
      ..on<TrackMutedEvent>((_) => notifyListeners())
      ..on<TrackUnmutedEvent>((_) => notifyListeners())
      ..on<LocalTrackPublishedEvent>((_) => notifyListeners())
      ..on<LocalTrackUnpublishedEvent>((_) => notifyListeners())
      ..on<ParticipantMetadataUpdatedEvent>((_) => notifyListeners())
      ..on<ParticipantConnectionQualityUpdatedEvent>((event) {
        if (event.participant == _room?.localParticipant && event.connectionQuality == ConnectionQuality.poor) {
          onNotification?.call("جودة الاتصال لديك منخفضة حالياً 📶", Colors.orange);
        }
        notifyListeners();
      });
  }

  bool _isMe(String? targetId) {
    if (targetId == null) return true;
    final myId = _room?.localParticipant?.identity ?? userId;
    if (targetId.contains('_')) {
        final baseTarget = targetId.split('_').first;
        final baseMe = myId.split('_').first;
        return baseTarget.toLowerCase() == baseMe.toLowerCase();
    }
    return targetId.toLowerCase() == myId.toLowerCase();
  }

  void _handleIncomingData(Map<String, dynamic> data, RemoteParticipant? p) {
    switch (data['type']) {
      case 'chat_message':
        _messages.insert(0, data);
        if (!_isChatOpen) {
          onNotification?.call("رسالة من ${data['user_name']}", Colors.blueAccent);
        }
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
      case 'kick_participant':
        if (_isMe(data['target'])) {
          onNotification?.call("⚠️ لقد تقرر استبعادك من الجلسة الحالية.", Colors.red);
          Future.delayed(const Duration(seconds: 2), () {
            _room?.disconnect();
            onSessionEnded?.call("تم استبعادك من القاعة الدراسية.");
          });
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
          if (data['value'] == true) {
            if (!_handRaiseQueue.any((item) => item['identity'] == p.identity)) {
              _handRaiseQueue.add({
                'identity': p.identity,
                'name': p.name ?? "طالب",
                'time': DateTime.now(),
              });
            }
            if (isTeacher) onNotification?.call("قام ${p.name ?? p.identity} برفع يده ✋", Colors.orange);
          } else {
            _handRaiseQueue.removeWhere((item) => item['identity'] == p.identity);
          }
        }
        break;
      case 'lower_hand':
        if (_isMe(data['target'])) {
          _isHandRaised = false;
          onNotification?.call("قام المدرس بإنزال يدك", Colors.blueGrey);
        }
        _handRaiseQueue.removeWhere((item) => item['identity'] == data['target']);
        _remoteHandStates[data['target'] ?? ''] = false;
        break;
      case 'lower_all_hands':
        _remoteHandStates.clear();
        _handRaiseQueue.clear(); 
        _isHandRaised = false;
        onNotification?.call("تم إنزال أيدي الجميع", Colors.blueGrey);
        break;
      case 'session_ended':
        onNotification?.call("🔴 انتهى البث المباشر، شكراً لكم.", Colors.redAccent);
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
        onNotification?.call(_isChatLocked ? "تم قفل الدردشة من قبل المدرس" : "الدردشة متاحة الآن للجميع", Colors.blueGrey);
        break;
      case 'control_whiteboard':
        _isWhiteboardLocked = data['value'];
        onNotification?.call(_isWhiteboardLocked ? "تم قصر استخدام السبورة" : "السبورة متاحة للجميع الآن", Colors.blueGrey);
        break;
      case 'control_screenshare':
        _isScreenShareLocked = data['value'];
        onNotification?.call(_isScreenShareLocked ? "مشاركة الشاشة مقفلة حالياً" : "تم السماح بمشاركة الشاشة", Colors.blueGrey);
        break;
      case 'spotlight':
        _spotlightUserId = data['value'];
        if (_isMe(_spotlightUserId) && !isTeacher) {
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
      _triggerHaptic();
    } catch (e) { debugPrint("Error submitting quiz: $e"); }
    notifyListeners();
  }

  void _handleMicControl(Map<String, dynamic> data) {
    if (!isTeacher && _isMe(data['target'])) {
      final shouldEnable = data['value'] as bool;
      _isMicEnabled = shouldEnable;
      _isMicLocked = data['lock'] ?? false;
      _room?.localParticipant?.setMicrophoneEnabled(shouldEnable);
      String msg = data['target'] != null 
          ? (shouldEnable ? "تم تفعيل الميكروفون لك" : "تم كتم صوتك من قبل المدرس")
          : (_isMicLocked ? "تم كتم صوت الجميع" : "المدرس سمح للجميع بالتحدث");
      onNotification?.call(msg, _isMicLocked ? Colors.red : Colors.green);
      notifyListeners();
    }
  }

  void _handleCamControl(Map<String, dynamic> data) {
    if (!isTeacher && _isMe(data['target'])) {
      final shouldEnable = data['value'] as bool;
      _isCamEnabled = shouldEnable;
      _isCamLocked = data['lock'] ?? false;
      _room?.localParticipant?.setCameraEnabled(shouldEnable);
      String msg = data['target'] != null 
          ? (shouldEnable ? "المعلم يطلب منك تفعيل الكاميرا" : "تم إغلاق الكاميرا لك من المدرس")
          : (_isCamLocked ? "تم إغلاق كاميرات الجميع" : "المدرس سمح بفتح الكاميرات");
      onNotification?.call(msg, _isCamLocked ? Colors.red : Colors.green);
      notifyListeners();
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
    _triggerHaptic();
    if (_whiteboardStrokes.isNotEmpty) {
      _redoStack.add(_whiteboardStrokes.removeLast());
      sendData({'type': 'whiteboard_undo'});
      notifyListeners();
    } else {
      onNotification?.call("لا يوجد رسومات للتراجع عنها", Colors.blueGrey);
    }
  }

  void redoWhiteboard() {
    _triggerHaptic();
    if (_redoStack.isNotEmpty) {
      _whiteboardStrokes.add(_redoStack.removeLast());
      sendData({'type': 'whiteboard_redo'});
      notifyListeners();
    } else {
      onNotification?.call("لا يوجد عمليات للإعادة", Colors.blueGrey);
    }
  }

  void clearWhiteboard() {
    _triggerHaptic(heavy: true);
    _whiteboardStrokes.clear();
    _redoStack.clear();
    sendData({'type': 'whiteboard_clear'});
    notifyListeners();
  }

  void sendMessage(String text) async {
    final cleanText = text.trim();
    if (cleanText.isEmpty) return;

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
      'content': cleanText,
      'created_at': DateTime.now().toIso8601String(),
    };
    _messages.insert(0, newMessage);
    notifyListeners();
    sendData({'type': 'chat_message', ...newMessage});
    try {
      await supabase.from('messages').insert({
        'room_name': roomName,
        'user_name': userName,
        'content': cleanText,
      });
    } catch (e) { debugPrint("Error sending message to DB: $e"); }
  }

  Future<void> toggleMic() async { 
    if (!_isConnected) { onNotification?.call("تحقق من الإنترنت أولاً", Colors.orange); return; }
    if (!_isMicLocked) { 
      try {
        _isMicEnabled = !_isMicEnabled; 
        await _room?.localParticipant?.setMicrophoneEnabled(_isMicEnabled); 
        _triggerHaptic();
        notifyListeners(); 
      } catch (e) {
        _isMicEnabled = !_isMicEnabled;
        onNotification?.call("تأكد من إعطاء إذن الوصول للميكروفون 🎤", Colors.red);
      }
    } else {
      onNotification?.call("المدرس منع استخدام الميكروفون حالياً", Colors.red);
    }
  }
  
  Future<void> toggleCam() async { 
    if (!_isConnected) { onNotification?.call("تحقق من الإنترنت أولاً", Colors.orange); return; }
    if (!_isCamLocked) {
      try {
        _isCamEnabled = !_isCamEnabled; 
        await _room?.localParticipant?.setCameraEnabled(_isCamEnabled); 
        _triggerHaptic();
        notifyListeners(); 
      } catch (e) {
        _isCamEnabled = !_isCamEnabled;
        onNotification?.call("تأكد من إعطاء إذن الوصول للكاميرا 📷", Colors.red);
      }
    } else {
      onNotification?.call("المدرس منع استخدام الكاميرا حالياً", Colors.red);
    }
  }
  
  void toggleHand() { 
    if (!_isConnected) { onNotification?.call("تحقق من الإنترنت أولاً", Colors.orange); return; }
    _isHandRaised = !_isHandRaised; 
    _triggerHaptic();
    sendData({'type': 'hand_raise', 'value': _isHandRaised}); 
    
    if (_isHandRaised) {
      if (!_handRaiseQueue.any((item) => item['identity'] == userId)) {
        _handRaiseQueue.add({
          'identity': userId,
          'name': userName,
          'time': DateTime.now(),
        });
      }
    } else {
      _handRaiseQueue.removeWhere((item) => item['identity'] == userId);
    }
    notifyListeners(); 
  }
  
  void lowerParticipantHand(String identity) {
    if (!isTeacher || !_isConnected) return;
    _remoteHandStates[identity] = false;
    _handRaiseQueue.removeWhere((item) => item['identity'] == identity);
    sendData({'type': 'lower_hand', 'target': identity});
    notifyListeners();
  }

  void lowerAllHands() {
    if (!isTeacher || !_isConnected) return;
    _remoteHandStates.clear();
    _handRaiseQueue.clear(); 
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

  void startBreakoutRooms(int count) async {
    if (!isTeacher || _room == null || !_isConnected || _isProcessing) return;
    
    final students = _room!.remoteParticipants.values.toList();
    if (students.isEmpty) {
      onNotification?.call("لا يوجد طلاب لتقسيمهم حالياً", Colors.red);
      return;
    }

    _isProcessing = true; notifyListeners();
    _isBreakoutActive = true;
    
    try {
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
      onNotification?.call("تم إرسال دعوات غرف العمل بنجاح ✅", Colors.green);
    } catch (e) {
      onNotification?.call("حدث خطأ أثناء توزيع الطلاب", Colors.red);
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  void endBreakoutRooms() {
    if (!isTeacher || !_isConnected) return;
    _isBreakoutActive = false;
    sendData({'type': 'end_breakout'});
    notifyListeners();
    onNotification?.call("تم إنهاء مجموعات العمل وعودة الجميع للقاعة الرئيسية", Colors.blueGrey);
  }

  void muteParticipant(String targetUserId, bool mute) {
    if (!isTeacher || !_isConnected) return;
    sendData({'type': 'control_mic', 'target': targetUserId, 'value': !mute, 'lock': mute});
  }

  void muteAllParticipants(bool mute) {
    if (!isTeacher || !_isConnected) return;
    _isAllMuted = mute;
    _isMicLocked = mute;
    sendData({'type': 'control_mic', 'target': null, 'value': !mute, 'lock': mute});
    notifyListeners();
  }

  void disableParticipantCamera(String targetUserId, bool disable) {
    if (!isTeacher || !_isConnected) return;
    sendData({'type': 'control_cam', 'target': targetUserId, 'value': !disable, 'lock': disable});
  }

  void disableAllCameras(bool disable) {
    if (!isTeacher || !_isConnected) return;
    _isCamLocked = disable;
    sendData({'type': 'control_cam', 'target': null, 'value': !disable, 'lock': disable});
    notifyListeners();
  }

  void kickParticipant(String targetUserId) async {
    if (!isTeacher || !_isConnected) return;
    
    // 1. إرسال إشارة الطرد عبر LiveKit
    sendData({'type': 'kick_participant', 'target': targetUserId});
    
    // 2. تسجيل الطرد في قاعدة البيانات لمنع إعادة الدخول
    if (sessionId != null) {
      // استخراج الـ base userId من الـ identity (التي قد تحتوي على suffix)
      String baseId = targetUserId;
      if (targetUserId.contains('_')) {
        baseId = targetUserId.split('_').first;
      }
      await DatabaseService().markStudentAsKicked(sessionId!, baseId);
    }
    
    onNotification?.call("تم استبعاد المشارك من القاعة", Colors.blueGrey);
  }

  Future<void> toggleScreenShare() async {
    if (_room == null || !_isConnected || _isProcessing) return;
    
    if (!isTeacher && _isScreenShareLocked) {
      onNotification?.call("مشاركة الشاشة معطلة من قبل المدرس", Colors.orange);
      return;
    }
    
    try {
      _isProcessing = true; notifyListeners();
      _isScreenSharing = !_isScreenSharing;
      await _room!.localParticipant?.setScreenShareEnabled(_isScreenSharing);
      _triggerHaptic();
    } catch (e) {
      _isScreenSharing = false;
      onNotification?.call("فشل بدء مشاركة الشاشة، تأكد من دعم جهازك", Colors.red);
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  void sendReaction(String emoji) { 
    if (!_isConnected) return;
    final now = DateTime.now();
    if (_lastReactionSent != null && now.difference(_lastReactionSent!).inMilliseconds < 500) {
      onNotification?.call("تمهل قليلاً ✋", Colors.blueGrey);
      return;
    }
    
    _lastReactionSent = now;
    sendData({'type': 'reaction', 'value': emoji}); 
    onReactionReceived?.call(emoji); 
    _triggerHaptic();
  }
  
  void sendData(Map<String, dynamic> d) {
    if (_isConnected && _room != null) {
      final data = utf8.encode(jsonEncode(d));
      _room!.localParticipant?.publishData(data, reliable: true);
    }
  }

  Future<void> startRecording() async { 
    if (!_isConnected) return;
    if (await LiveKitService().startRecording(roomName, sessionId!)) { 
      _isRecording = true; 
      onNotification?.call("بدأ تسجيل الحصة الآن ⏺️", Colors.redAccent);
      notifyListeners(); 
    } 
  }

  Future<void> endSessionForAll() async {
    if (isTeacher && sessionId != null && _isConnected && !_isProcessing) {
      try {
        _isProcessing = true; notifyListeners();
        
        sendData({'type': 'session_ended'});
        onNotification?.call("جاري حفظ بيانات الحصة وأرشفة السجلات...", Colors.blueAccent);

        await Future.delayed(const Duration(seconds: 2));

        await DatabaseService().updateSessionStatus(sessionId!, 'archived');
        await DatabaseService().saveSession({
          'end_time': DateTime.now().toUtc().toIso8601String(),
        }, id: sessionId!);

        await DatabaseService().toggleRoomStatus(sessionId!, false);

        _room?.disconnect();
        _isProcessing = false;
        onSessionEnded?.call("تم إنهاء الحصة بنجاح وحفظ كافة التقارير.");
      } catch (e) {
        _isProcessing = false;
        debugPrint("Error archiving session: $e");
        onNotification?.call("حدث خطأ أثناء أرشفة الجلسة", Colors.red);
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
