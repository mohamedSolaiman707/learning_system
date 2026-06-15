import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter/services.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../../core/services/livekit_service.dart';
import '../../../core/services/database_service.dart';
import '../../../core/services/attendance_pdf_service.dart';
import 'utils/classroom_participant_utils.dart';
import 'package:http/http.dart' as http;

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
  bool _isRecordingLoading = false;
  String? _errorMessage;
  String? _currentRoomName;
  bool _isBreakoutActive = false;
  final Map<int, List<String>> _breakoutGroups = {};
  int _breakoutTimeLeft = 0;
  Timer? _breakoutTimer;

  bool _isMicEnabled = false;
  bool _isCamEnabled = false;
  bool _isHandRaised = false;
  bool _isMicLocked = false;
  bool _isCamLocked = false;

  bool _isRecording = false;
  bool _isRecordingPaused = false;

  bool _isScreenSharing = false;
  bool _isChatLocked = false;
  bool _isWhiteboardLocked = false;
  bool _isScreenShareLocked = false;
  String? _spotlightUserId;
  String? _authorizedStudentId;
  String? _spotlightedQuestionId;
  bool _isAllMuted = false;

  bool _isChatOpen = false;
  bool _isWhiteboardOpen = false;
  bool _isPollsOpen = false;
  bool _isQAOpen = false;
  bool _isParticipantsOpen = false;

  bool _isVideoWallMode = false;
  int _wallPage = 0;
  int get wallPage => _wallPage;
  static const int wallPageSize = 8;

  Map<String, String> _studentAnswers = {};
  Map<String, String> get studentAnswers => _studentAnswers;

  String? getAnswerForParticipant(String identity) {
    for (final entry in _studentAnswers.entries) {
      if (identity.contains(entry.key) ||
          entry.key.contains(identity.split('_').first)) {
        return entry.value;
      }
    }
    return null;
  }

  Map<String, dynamic>? _activeQuestion;
  Map<String, dynamic>? get activeQuestion => _activeQuestion;
  String? get activeQuestionCorrectAnswer =>
      _activeQuestion?['correctAnswer'] as String?;

  String? _myCurrentAnswer;
  String? get myCurrentAnswer => _myCurrentAnswer;

  String? _myCurrentPollVote;
  String? get myCurrentPollVote => _myCurrentPollVote;

  List<Stroke> _whiteboardStrokes = [];
  final List<Stroke> _redoStack = [];
  Color _selectedColor = Colors.black;
  double _strokeWidth = 3.0;

  Map<String, dynamic>? _activePoll;
  Map<String, int> _pollResults = {};
  List<Map<String, dynamic>> _messages = [];
  List<Map<String, dynamic>> _questions = [];
  int _unreadQuestionsCount = 0;
  int _unreadMessages = 0;

  bool _seatPickerShown = false;
  bool get seatPickerShown => _seatPickerShown;
  List<Map<String, dynamic>> _seats = [];
  List<Map<String, dynamic>> get seats => _seats;

  /// Stable key for Selector memoization — only changes when seat assignments change.
  String get seatsLayoutKey =>
      _seats.map((s) => '${s['id']}:${s['student_id']}').join('|');

  int _screenCount = 3;
  int _seatsPerScreen = 8;
  int get screenCount => _screenCount;
  int get seatsPerScreen => _seatsPerScreen;

  List<String> get screenZones {
    return List.generate(_screenCount, (i) => 'screen_${i + 1}');
  }

  List<Map<String, dynamic>> seatsForZone(String zone) {
    return _seats.where((s) => s['zone'] == zone).toList()..sort(
          (a, b) => (a['seat_number'] as int).compareTo(b['seat_number'] as int),
    );
  }

  final Map<String, bool> _remoteHandStates = {};
  final List<Map<String, dynamic>> _handRaiseQueue = [];

  bool _isConnected = true;
  StreamSubscription? _connectivitySubscription;
  DateTime? _lastMutedSpeechWarning;

  final supabase = Supabase.instance.client;
  StreamSubscription? _statusSubscription;
  StreamSubscription? _seatsSubscription;
  Timer? _expiryTimer;
  Timer? _notifyDebounce;
  bool _isDisposed = false;
  bool _isReconnecting = false;
  int _reconnectAttempts = 0;
  static const _maxReconnectAttempts = 5;

  String _selectedChannel = "room-cam-right";
  String get selectedChannel => _selectedChannel;

  bool _isPiPExpanded = false;
  bool get isPiPExpanded => _isPiPExpanded;

  void togglePiP() {
    _isPiPExpanded = !_isPiPExpanded;
    notifyListeners();
  }

  static const List<String> roomCameraOrder = [
    'room-cam-right',
    'room-cam-left',
    'room-cam-screen',
  ];

  void cycleRoomCamera() {
    int currentIndex = roomCameraOrder.indexOf(_selectedChannel);
    if (currentIndex == -1) {
      _selectedChannel = roomCameraOrder.first;
    } else {
      _selectedChannel =
      roomCameraOrder[(currentIndex + 1) % roomCameraOrder.length];
    }
    // تم إزالة إغلاق السبورة من هنا للسماح بالتبديل
    _triggerHaptic();
    notifyListeners();
  }

  bool get isReconnecting => _isReconnecting;

  void _notify({bool immediate = false}) {
    if (_isDisposed) return;
    if (immediate) {
      _notifyDebounce?.cancel();
      notifyListeners();
      return;
    }
    _notifyDebounce?.cancel();
    _notifyDebounce = Timer(const Duration(milliseconds: 48), () {
      if (!_isDisposed) notifyListeners();
    });
  }

  bool _seatsEqual(List<Map<String, dynamic>> a, List<Map<String, dynamic>> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i]['id'] != b[i]['id'] ||
          a[i]['student_id'] != b[i]['student_id'] ||
          a[i]['student_name'] != b[i]['student_name'] ||
          a[i]['seat_number'] != b[i]['seat_number']) {
        return false;
      }
    }
    return true;
  }

  void _applySeatsFromServer(List<Map<String, dynamic>> data) {
    final normalized = List<Map<String, dynamic>>.from(data);
    if (_seatsEqual(_seats, normalized)) return;
    _seats = normalized;
    if (!isTeacher) {
      final mySeat = _seats.firstWhere(
            (s) => s['student_id'] == userId,
        orElse: () => {},
      );
      _seatPickerShown = mySeat.isNotEmpty;
    }
    _notify();
  }

  List<Map<String, dynamic>> _cloneSeats() =>
      _seats.map((s) => Map<String, dynamic>.from(s)).toList();

  void checkAndFallbackChannel() {
    if (_room == null || isTeacher) return;

    final allParticipants = ClassroomParticipantUtils.allFromRoom(_room);
    final channelCam = ClassroomParticipantUtils.findChannelParticipant(
      allParticipants,
      _selectedChannel,
    );

    if (ClassroomParticipantUtils.isRoomCamActive(channelCam)) return;

    for (final cam in roomCameraOrder) {
      if (cam == _selectedChannel) continue;
      final candidate = ClassroomParticipantUtils.findChannelParticipant(
        allParticipants,
        cam,
      );
      if (ClassroomParticipantUtils.isRoomCamActive(candidate)) {
        _selectedChannel = cam;
        onNotification?.call(
          'تم التحويل تلقائياً لـ ${getCameraLabel(cam)} 📷',
          Colors.orange,
        );
        _notify(immediate: true);
        return;
      }
    }
    // No active room cam — UI falls back to teacher via ClassroomParticipantUtils.
    _notify(immediate: true);
  }

  String getCameraLabel(String channel) {
    switch (channel) {
      case 'room-cam-right':
        return 'كاميرا القاعة 1';
      case 'room-cam-left':
        return 'كاميرا القاعة 2';
      case 'room-cam-screen':
        return 'كاميرا القاعة 3';
      default:
        return 'كاميرا القاعة';
    }
  }

  double get engagementScore {
    if (_room == null || _room!.remoteParticipants.isEmpty) return 0.0;
    int totalParticipants = _room!.remoteParticipants.length;
    int activeParticipants =
        _handRaiseQueue.length +
            (_activePoll != null
                ? _pollResults.values.fold<int>(0, (a, b) => a + b)
                : 0) +
            _questions.where((q) => q['created_at'] != null).length;

    double score = (activeParticipants / totalParticipants) * 100;
    return score.clamp(0.0, 100.0);
  }

  void selectChannel(String trackName) {
    if (_selectedChannel == trackName) {
      cycleRoomCamera();
    } else {
      _selectedChannel = trackName;
      // تم إزالة إغلاق السبورة من هنا
      notifyListeners();
    }
  }

  Room? get room => _room;
  bool get isLoading => _isLoading;
  bool get isProcessing => _isProcessing;
  bool get isRecordingLoading => _isRecordingLoading;
  String? get errorMessage => _errorMessage;
  bool get isMicEnabled => _isMicEnabled;
  bool get isCamEnabled => _isCamEnabled;
  bool get isHandRaised => _isHandRaised;
  bool get isRecording => _isRecording;
  bool get isRecordingPaused => _isRecordingPaused;
  bool get isScreenSharing => _isScreenSharing;
  bool get isChatOpen => _isChatOpen;
  bool get isWhiteboardOpen => _isWhiteboardOpen;
  bool get isPollsOpen => _isPollsOpen;
  bool get isQAOpen => _isQAOpen;
  bool get isParticipantsOpen => _isParticipantsOpen;
  bool get isVideoWallMode => _isVideoWallMode;
  List<Stroke> get whiteboardStrokes => _whiteboardStrokes;
  Map<String, dynamic>? get activePoll => _activePoll;
  Map<String, int> get pollResults => _pollResults;
  List<Map<String, dynamic>> get messages => _messages;
  List<Map<String, dynamic>> get questions => _questions;
  int get unreadQuestionsCount => _unreadQuestionsCount;
  int get unreadMessages => _unreadMessages;
  String? get spotlightedQuestionId => _spotlightedQuestionId;
  Map<String, bool> get remoteHandStates => _remoteHandStates;
  List<Map<String, dynamic>> get handRaiseQueue => _handRaiseQueue;
  bool get isChatLocked => _isChatLocked;
  bool get isWhiteboardLocked => _isWhiteboardLocked;
  bool get isScreenShareLocked => _isScreenShareLocked;
  String? get spotlightUserId => _spotlightUserId;
  String? get authorizedStudentId => _authorizedStudentId;
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

  void _triggerHaptic({bool heavy = false}) {
    if (heavy) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.lightImpact();
    }
  }

  void launchQuestion(Map<String, dynamic> question) {
    _activeQuestion = question;
    _studentAnswers = {};
    _myCurrentAnswer = null;
    sendData({'type': 'new_active_question', 'question': question});
    if (sessionId != null) {
      DatabaseService().saveLiveQuestion(
        sessionId: sessionId!,
        question: question,
      );
    }
    notifyListeners();
  }

  void closeQuestion() {
    _activeQuestion = null;
    _myCurrentAnswer = null;
    sendData({'type': 'close_active_question'});
    if (sessionId != null) {
      DatabaseService().closeLiveQuestion(sessionId!);
    }
    notifyListeners();
  }

  void submitAnswer(String answer) {
    _myCurrentAnswer = answer;
    final identity = _room?.localParticipant?.identity ?? userId;
    sendData({
      'type': 'student_answer',
      'from': userName,
      'identity': identity,
      'answer': answer,
    });
    notifyListeners();
  }

  void revealCorrectAnswer(String answer) {
    sendData({'type': 'reveal_answer', 'correct': answer});
    if (_activeQuestion != null) {
      _activeQuestion!['correctAnswer'] = answer;
    }
    notifyListeners();
  }

  void toggleVideoWallMode() {
    _isVideoWallMode = !_isVideoWallMode;
    resetWallPage();
    notifyListeners();
  }

  void nextWallPage(int totalCount) {
    final maxPage = ((totalCount - 1) / wallPageSize).floor();
    if (_wallPage < maxPage) {
      _wallPage++;
      notifyListeners();
    }
  }

  void prevWallPage() {
    if (_wallPage > 0) {
      _wallPage--;
      notifyListeners();
    }
  }

  void resetWallPage() {
    _wallPage = 0;
  }

  void toggleChat() {
    _triggerHaptic();
    _isChatOpen = !_isChatOpen;
    if (_isChatOpen) _unreadMessages = 0;
    _isWhiteboardOpen = false;
    _isQAOpen = false;
    _isParticipantsOpen = false;
    _isPollsOpen = false;
    notifyListeners();
  }

  void toggleWhiteboard() {
    _triggerHaptic();
    _isWhiteboardOpen = !_isWhiteboardOpen;
    _isChatOpen = false;
    _isQAOpen = false;
    _isParticipantsOpen = false;
    _isPollsOpen = false;
    _notify(immediate: true);
  }

  void toggleQA() {
    _triggerHaptic();
    _isQAOpen = !_isQAOpen;
    if (_isQAOpen) _unreadQuestionsCount = 0;
    _isChatOpen = false;
    _isWhiteboardOpen = false;
    _isParticipantsOpen = false;
    _isPollsOpen = false;
    notifyListeners();
  }

  void toggleParticipants() {
    _triggerHaptic();
    _isParticipantsOpen = !_isParticipantsOpen;
    if (_isParticipantsOpen) loadAndExpandSeats();
    _isChatOpen = false;
    _isWhiteboardOpen = false;
    _isQAOpen = false;
    _isPollsOpen = false;
    notifyListeners();
  }

  void togglePolls() {
    _triggerHaptic();
    _isPollsOpen = !_isPollsOpen;
    _isChatOpen = false;
    _isWhiteboardOpen = false;
    _isQAOpen = false;
    _isParticipantsOpen = false;
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
        event,
        ) {
      final hasInternet = event.any(
            (result) => result != ConnectivityResult.none,
      );
      if (_isConnected && !hasInternet) {
        _isConnected = false;
        onNotification?.call("فقدت الاتصال بالإنترنت ⚠️", Colors.red);
      } else if (!_isConnected && hasInternet) {
        _isConnected = true;
        onNotification?.call("تم استعادة الاتصال ✅", Colors.green);
        if (_room == null ||
            _room!.connectionState == ConnectionState.disconnected) {
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

    // بدئ الاستماع للمقاعد فوراً قبل أي انتظار طويل
    if (sessionId != null) {
      _seatsSubscription = supabase
          .from('seats')
          .stream(primaryKey: ['id'])
          .eq('session_id', sessionId!)
          .listen(
            (data) => _applySeatsFromServer(data),
        onError: (e) => debugPrint('Seats stream error: $e'),
      );
    }

    if (sessionId != null && sessionId!.isNotEmpty) {
      try {
        final isValid = await _checkAndMonitorSession();
        if (!isValid) {
          _isLoading = false;
          notifyListeners();
          return;
        }
      } catch (e) {
        debugPrint("Session monitor error: $e");
      }
    }

    try {
      await _loadChatHistory();
      await _loadActiveLiveQuestion();
      if (isTeacher && sessionId != null) {
        await DatabaseService().initializeSeats(sessionId!);
      }
      await loadAndExpandSeats();
    } catch (e) {
      debugPrint("Load data error: $e");
    }

    await connectToRoom(roomName);
    await loadAndExpandSeats();
  }

  Future<void> _loadActiveLiveQuestion() async {
    if (sessionId == null || isTeacher) return;
    try {
      final q = await DatabaseService().getActiveLiveQuestion(sessionId!);
      if (q != null) {
        _activeQuestion = q;
        _studentAnswers = {};
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Load active question error: $e");
    }
  }

  Future<void> loadAndExpandSeats() async {
    if (sessionId == null) return;
    try {
      // Load config first
      final config = await DatabaseService()
          .getSessionScreenConfig(sessionId!);
      _screenCount = config['screen_count'];
      _seatsPerScreen = config['seats_per_screen'];

      // Check if seats exist first
      final existing = await DatabaseService()
          .getSeats(sessionId!);

      if (existing.isEmpty) {
        // Only initialize if no seats exist
        await DatabaseService().initializeSeats(
          sessionId!,
          screenCount: _screenCount,
          seatsPerScreen: _seatsPerScreen,
        );
      } else if (existing.length <
          _screenCount * _seatsPerScreen) {
        // Expand if needed
        await DatabaseService().initializeSeats(
          sessionId!,
          screenCount: _screenCount,
          seatsPerScreen: _seatsPerScreen,
        );
      }

      // Load final seats
      final data = await DatabaseService()
          .getSeats(sessionId!);
      _applySeatsFromServer(data);

    } catch (e) {
      debugPrint("loadAndExpandSeats error: $e");
      // Try to load whatever exists
      try {
        final data = await DatabaseService()
            .getSeats(sessionId!);
        if (data.isNotEmpty) {
          _applySeatsFromServer(data);
        }
      } catch (_) {}
    }
  }

  Future<void> updateScreenConfig({
    required int screenCount,
    required int seatsPerScreen,
  }) async {
    if (!isTeacher || sessionId == null) return;
    _screenCount = screenCount;
    _seatsPerScreen = seatsPerScreen;
    await DatabaseService().updateSessionScreenConfig(
      sessionId!,
      screenCount: screenCount,
      seatsPerScreen: seatsPerScreen,
    );
    // Re-initialize seats with new config
    await loadAndExpandSeats();
    notifyListeners();
  }

  Future<bool> claimSeat(int seatNumber) async {
    if (sessionId == null) return false;

    final optimistic = _cloneSeats();
    final seatIdx = optimistic.indexWhere(
          (s) => s['seat_number'] == seatNumber,
    );
    if (seatIdx == -1) return false;

    for (final s in optimistic) {
      if (s['student_id'] == userId) {
        s['student_id'] = null;
        s['student_name'] = null;
      }
    }
    optimistic[seatIdx]['student_id'] = userId;
    optimistic[seatIdx]['student_name'] = userName;
    _seats = optimistic;
    _seatPickerShown = true;
    _notify(immediate: true);

    try {
      final result = await DatabaseService().claimSeat(
        sessionId: sessionId!,
        seatNumber: seatNumber,
        studentId: userId,
        studentName: userName,
      );
      if (result['success'] == true) return true;
      await loadAndExpandSeats();
      return false;
    } catch (e) {
      debugPrint('claimSeat error: $e');
      await loadAndExpandSeats();
      return false;
    }
  }

  Future<void> moveSeat(int fromSeat, int toSeat) async {
    if (sessionId == null || !isTeacher) return;

    final optimistic = _cloneSeats();
    final fromIdx = optimistic.indexWhere((s) => s['seat_number'] == fromSeat);
    final toIdx = optimistic.indexWhere((s) => s['seat_number'] == toSeat);
    if (fromIdx == -1 || toIdx == -1) return;

    final fromData = Map<String, dynamic>.from(optimistic[fromIdx]);
    final toData = Map<String, dynamic>.from(optimistic[toIdx]);
    optimistic[fromIdx]['student_id'] = toData['student_id'];
    optimistic[fromIdx]['student_name'] = toData['student_name'];
    optimistic[toIdx]['student_id'] = fromData['student_id'];
    optimistic[toIdx]['student_name'] = fromData['student_name'];
    _seats = optimistic;
    _isProcessing = true;
    _notify(immediate: true);

    try {
      await DatabaseService().moveStudentSeat(
        sessionId: sessionId!,
        fromSeat: fromSeat,
        toSeat: toSeat,
      );
      onNotification?.call("تم تغيير ترتيب المقاعد بنجاح", Colors.green);
    } catch (e) {
      debugPrint('moveSeat error: $e');
      onNotification?.call("فشل في تغيير ترتيب المقاعد", Colors.red);
      await loadAndExpandSeats();
    } finally {
      _isProcessing = false;
      _notify(immediate: true);
    }
  }

  Future<void> clearSeat(int seatNumber) async {
    if (sessionId == null) return;
    try {
      await DatabaseService().assignSeat(
        sessionId: sessionId!,
        seatNumber: seatNumber,
        studentId: null,
        studentName: null,
      );
      await loadAndExpandSeats();
    } catch (e) {
      debugPrint("Error clearing seat: $e");
    }
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
      final res = await supabase
          .from('sessions')
          .select()
          .eq('id', sessionId!)
          .single();
      final DateTime endTime = DateTime.parse(res['end_time']);
      _isRecording = res['is_recording'] ?? false;
      _isRecordingPaused = res['is_recording_paused'] ?? false;

      if (_isRecording && !isTeacher) {
        Future.delayed(const Duration(seconds: 3), () {
          onNotification?.call(
            "🔴 تنبيه: هذه الحصة يتم تسجيلها حالياً",
            Colors.redAccent,
          );
        });
      }

      if (res['status'] == 'ended' ||
          res['status'] == 'archived' ||
          DateTime.now().isAfter(endTime)) {
        onSessionEnded?.call("هذه الجلسة انتهت بالفعل.");
        return false;
      }
      _statusSubscription = DatabaseService()
          .watchSessionStatus(sessionId!)
          .listen((data) {
        if (data.isNotEmpty) {
          final sessionData = data.first;
          bool dbRecording = sessionData['is_recording'] ?? false;
          bool dbPaused = sessionData['is_recording_paused'] ?? false;
          if (dbRecording != _isRecording ||
              dbPaused != _isRecordingPaused) {
            _isRecording = dbRecording;
            _isRecordingPaused = dbPaused;
            if (_isRecording) {
              onNotification?.call(
                _isRecordingPaused
                    ? "⏸️ تم إيقاف التسجيل مؤقتاً"
                    : "🔴 يتم الآن تسجيل الحصة",
                _isRecordingPaused ? Colors.orange : Colors.red,
              );
            } else {
              onNotification?.call(
                "⏹️ تم إيقاف التسجيل نهائياً",
                Colors.blueGrey,
              );
            }
            notifyListeners();
          }
          if (sessionData['status'] == 'ended' ||
              sessionData['status'] == 'archived') {
            onNotification?.call(
              "🔴 تم إنهاء البث المباشر.",
              Colors.redAccent,
            );
            Future.delayed(
              const Duration(seconds: 3),
                  () => onSessionEnded?.call("انتهت الحصة الدراسية."),
            );
          }
        }
      });
      _expiryTimer = Timer(
        endTime.difference(DateTime.now()),
            () => onSessionEnded?.call("انتهى وقت الحصة."),
      );
      return true;
    } catch (e) {
      debugPrint("Check monitor session error: $e");
      return true;
    }
  }

  Future<void> connectToRoom(String targetRoomName) async {
    if (!_isConnected) return;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      if (!isTeacher && sessionId != null) {
        final isKicked = await DatabaseService().isStudentKicked(
          sessionId!,
          userId,
        );
        if (isKicked) {
          _errorMessage = "عذراً، تم استبعادك من دخول هذه القاعة.";
          _isLoading = false;
          notifyListeners();
          onSessionEnded?.call("تم استبعادك من قبل المعلم.");
          return;
        }
      }
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
        roomOptions: RoomOptions(
          adaptiveStream: true,
          dynacast: true,
          defaultVideoPublishOptions: isTeacher
              ? const VideoPublishOptions(
            videoEncoding: VideoEncoding(
              maxBitrate: 4000000,
              maxFramerate: 30,
            ),
            simulcast: true,
          )
              : const VideoPublishOptions(simulcast: true),
        ),
      );

      _listener = _room!.createListener();
      _setupEventListeners();

      await _room!.connect(
        'wss://learning-system-academy-axo5qepz.livekit.cloud',
        token,
      );

      _currentRoomName = targetRoomName;
      _isLoading = false;
      notifyListeners();

      if (!isTeacher && sessionId != null) {
        DatabaseService()
            .logStudentEntry(sessionId!, userId, userName)
            .catchError((e) {
          debugPrint("Log student entry error (Background): $e");
        });
      }
    } catch (e) {
      debugPrint("Connect to room error: $e");
      _errorMessage = "فشل الاتصال بالقاعة. يرجى المحاولة لاحقاً.";
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
        try {
          final data = jsonDecode(utf8.decode(event.data));
          _handleIncomingData(data, event.participant);
        } catch (e) {
          debugPrint("Error handling incoming data: $e");
        }
      })
      ..on<RoomDisconnectedEvent>((event) {
        if (event.reason != null) {
          _handleRoomDisconnected(event.reason!);
        }
      })
      ..on<RoomAttemptReconnectEvent>((_) {
        _isReconnecting = true;
        onNotification?.call('جاري إعادة الاتصال...', Colors.orange);
        _notify(immediate: true);
      })
      ..on<RoomReconnectedEvent>((_) {
        _isReconnecting = false;
        _reconnectAttempts = 0;
        onNotification?.call('تم استعادة الاتصال ✅', Colors.green);
        _notify(immediate: true);
      })
      ..on<ParticipantConnectedEvent>((event) {
        loadAndExpandSeats();
        checkAndFallbackChannel();
        _notify(immediate: true);
      })
      ..on<ParticipantDisconnectedEvent>((event) {
        checkAndFallbackChannel();
        _handRaiseQueue.removeWhere(
              (item) => item['identity'] == event.participant.identity,
        );
        _notify(immediate: true);
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
        _notify();
      })
      ..on<TrackSubscribedEvent>((_) {
        checkAndFallbackChannel();
        _notify(immediate: true);
      })
      ..on<TrackUnsubscribedEvent>((_) {
        checkAndFallbackChannel();
        _notify(immediate: true);
      })
      ..on<TrackMutedEvent>((_) {
        checkAndFallbackChannel();
        _notify(immediate: true);
      })
      ..on<TrackUnmutedEvent>((_) {
        checkAndFallbackChannel();
        _notify(immediate: true);
      });
  }

  Future<void> _handleRoomDisconnected(DisconnectReason reason) async {
    if (_isDisposed) return;
    if (reason == DisconnectReason.clientInitiated) return;

    _isReconnecting = true;
    onNotification?.call('انقطع الاتصال — جاري إعادة المحاولة...', Colors.red);
    _notify(immediate: true);
    await _attemptReconnect();
  }

  Future<void> _attemptReconnect() async {
    if (_isDisposed || !_isConnected) return;
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      _isReconnecting = false;
      _errorMessage = 'فشل إعادة الاتصال. يرجى المحاولة يدوياً.';
      _notify(immediate: true);
      return;
    }

    _reconnectAttempts++;
    await Future.delayed(Duration(seconds: min(_reconnectAttempts * 2, 10)));
    if (_isDisposed) return;

    try {
      await connectToRoom(_currentRoomName ?? roomName);
      _reconnectAttempts = 0;
      _isReconnecting = false;
    } catch (e) {
      debugPrint('Reconnect attempt $_reconnectAttempts failed: $e');
      await _attemptReconnect();
    }
  }

  bool _isMe(String? targetId) {
    if (targetId == null) return false;
    final myId = _room?.localParticipant?.identity ?? userId;
    return targetId.split('_').first == myId.split('_').first;
  }

  void _handleIncomingData(Map<String, dynamic> data, RemoteParticipant? p) {
    switch (data['type']) {
      case 'chat_message':
        _messages = [data, ..._messages];
        if (!_isChatOpen) _unreadMessages++;
        break;
      case 'edit_chat_message':
        final index = _messages.indexWhere(
              (m) => m['id'].toString() == data['id'].toString(),
        );
        if (index != -1) {
          final updatedMsg = Map<String, dynamic>.from(_messages[index]);
          updatedMsg['content'] = data['content'];
          updatedMsg['is_edited'] = true;
          _messages[index] = updatedMsg;
          _messages = List.from(_messages);
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
          onSessionEnded?.call("تم استبعادك من القاعة من قبل المعلم.");
        }
        break;
      case 'new_question':
        final newQ = {
          ...data,
          'id': data['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
          'upvotes': 0,
          'is_answered': false,
          'senderId': data['senderId'] ?? '',
        };
        _questions = [newQ, ..._questions];
        if (!_isQAOpen) {
          _unreadQuestionsCount++;
          if (isTeacher) {
            onNotification?.call("سؤال جديد من ${data['from']} ❓", Colors.blue);
          }
        }
        _sortQuestions();
        break;
      case 'upvote_question':
        final qIndex = _questions.indexWhere(
              (q) => q['id'] == data['question_id'],
        );
        if (qIndex != -1) {
          final updatedQ = Map<String, dynamic>.from(_questions[qIndex]);
          updatedQ['upvotes'] = (updatedQ['upvotes'] ?? 0) + 1;
          _questions[qIndex] = updatedQ;
          _sortQuestions();
        }
        break;
      case 'mark_answered':
        final qIndex = _questions.indexWhere(
              (q) => q['id'] == data['question_id'],
        );
        if (qIndex != -1) {
          final updatedQ = Map<String, dynamic>.from(_questions[qIndex]);
          updatedQ['is_answered'] = true;
          _questions[qIndex] = updatedQ;
          if (_spotlightedQuestionId == data['question_id']) {
            _spotlightedQuestionId = null;
          }
          _questions = List.from(_questions);
        }
        break;
      case 'spotlight_question':
        _spotlightedQuestionId = data['question_id'];
        if (_spotlightedQuestionId != null) {
          final q = _questions.firstWhere(
                (element) => element['id'] == _spotlightedQuestionId,
            orElse: () => {},
          );
          if (q.isNotEmpty) {
            onNotification?.call(
              "تركيز الآن على سؤال ${q['from']}",
              Colors.orange,
            );
          }
        }
        _sortQuestions();
        break;
      case 'hand_raise':
        if (p != null) {
          _remoteHandStates[p.identity] = data['value'];
          if (data['value'] == true) {
            if (!_handRaiseQueue.any((i) => i['identity'] == p.identity)) {
              _handRaiseQueue.add({
                'identity': p.identity,
                'name': p.name,
                'time': DateTime.now(),
              });
            }
            if (isTeacher) {
              onNotification?.call("قوم ${p.name} برفع يده ✋", Colors.orange);
            }
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
        onNotification?.call("🔴 تم إنهاء البث.", Colors.redAccent);
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
          _whiteboardStrokes = List.from(_whiteboardStrokes);
        }
        break;
      case 'whiteboard_redo':
        if (_redoStack.isNotEmpty) {
          _whiteboardStrokes.add(_redoStack.removeLast());
          _whiteboardStrokes = List.from(_whiteboardStrokes);
        }
        break;
      case 'whiteboard_clear':
        _whiteboardStrokes = [];
        _redoStack.clear();
        break;
      case 'control_chat':
        _isChatLocked = data['value'];
        break;
      case 'control_whiteboard':
        _isWhiteboardLocked = data['value'];
        break;
      case 'pen_authority_changed':
        _authorizedStudentId = data['authorized_id'];
        break;
      case 'control_screenshare':
        _isScreenShareLocked = data['value'];
        break;
      case 'spotlight':
        _spotlightUserId = data['value'];
        break;
      case 'new_poll':
        _activePoll = data['poll'];
        _pollResults = {};
        _myCurrentPollVote = null;
        if (!isTeacher) {
          onNotification?.call("استطلاع جديد متاح 📊", Colors.blue);
        }
        break;
      case 'poll_vote':
        if (isTeacher) {
          _pollResults[data['option']] =
              (_pollResults[data['option']] ?? 0) + 1;
          _pollResults = Map.from(_pollResults);
        }
        break;
      case 'poll_end':
        _activePoll = null;
        _pollResults = {};
        _myCurrentPollVote = null;
        break;
      case 'new_active_question':
        _activeQuestion = data['question'];
        _studentAnswers = {};
        _myCurrentAnswer = null;
        if (!isTeacher) {
          onNotification?.call("سؤال جديد من المدرس ❓", Colors.blue);
        }
        break;
      case 'close_active_question':
        _activeQuestion = null;
        _myCurrentAnswer = null;
        break;
      case 'student_answer':
        if (isTeacher) {
          _studentAnswers[data['from']] = data['answer'];
          _studentAnswers = Map.from(_studentAnswers);
        }
        break;
      case 'reveal_answer':
        if (_activeQuestion != null) {
          _activeQuestion!['correctAnswer'] = data['correct'];
          _activeQuestion = Map.from(_activeQuestion!);
        }
        break;
    }
    notifyListeners();
  }

  void _sortQuestions() {
    final sorted = List<Map<String, dynamic>>.from(_questions);
    sorted.sort((a, b) {
      if (a['id'] == _spotlightedQuestionId) return -1;
      if (b['id'] == _spotlightedQuestionId) return 1;
      bool handA = _remoteHandStates[a['senderId']] ?? false;
      bool handB = _remoteHandStates[b['senderId']] ?? false;
      if (handA && !handB) return -1;
      if (!handA && handB) return 1;
      int upvotesA = a['upvotes'] ?? 0;
      int upvotesB = b['upvotes'] ?? 0;
      return upvotesB.compareTo(upvotesA);
    });
    _questions = sorted;
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
      if (sessionId != null) {
        await LiveKitService().logBreakoutSession(
          parentSessionId: sessionId!,
          groups: groupingData,
          durationMinutes: duration,
        );
      }
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

  void grantPenToStudent(String? studentId) {
    if (!isTeacher) return;
    _authorizedStudentId = studentId;
    sendData({'type': 'pen_authority_changed', 'authorized_id': studentId});

    if (studentId != null) {
      onNotification?.call("تم منح صلاحية الكتابة للطالب", Colors.green);
    } else {
      onNotification?.call("تم سحب صلاحيات الكتابة الخاصة", Colors.orange);
    }
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
    if (sessionId != null) {
      try {
        await DatabaseService().markStudentAsKicked(
          sessionId!,
          tId.split('_').first,
        );
      } catch (_) {}
    }
    notifyListeners();
  }

  void createPoll(String question, List<String> options) {
    _activePoll = {'question': question, 'options': options};
    _pollResults = {for (var opt in options) opt: 0};
    sendData({'type': 'new_poll', 'poll': _activePoll});
    notifyListeners();
  }

  void endPoll() {
    _activePoll = null;
    _pollResults = {};
    sendData({'type': 'poll_end'});
    notifyListeners();
  }

  void votePoll(String option) {
    if (_activePoll == null) return;
    _myCurrentPollVote = option;
    sendData({'type': 'poll_vote', 'option': option});
    notifyListeners();
  }

  void _handleMicControl(Map<String, dynamic> data) {
    if (!isTeacher && (data['target'] == null || _isMe(data['target']))) {
      _isMicEnabled = data['value'];
      _room?.localParticipant?.setMicrophoneEnabled(_isMicEnabled);
      _isMicLocked = data['lock'] ?? false;
      notifyListeners();
    }
  }

  void _handleCamControl(Map<String, dynamic> data) {
    if (!isTeacher && (data['target'] == null || _isMe(data['target']))) {
      _isCamEnabled = data['value'];
      _room?.localParticipant?.setCameraEnabled(_isCamEnabled);
      _isCamLocked = data['lock'] ?? false;
      notifyListeners();
    }
  }

  void _handleDraw(Map<String, dynamic> data) {
    final List points = data['points'];
    final newStroke = Stroke(
      points: points
          .map((e) => Offset(e['x'].toDouble(), e['y'].toDouble()))
          .toList(),
      color: Color(data['color']),
      width: data['width'].toDouble(),
    );
    _whiteboardStrokes = [..._whiteboardStrokes, newStroke];
    _redoStack.clear();
  }

  void addStroke(List<Offset> pts) {
    if (!isTeacher) {
      if (_isWhiteboardLocked) return;
      if (_authorizedStudentId != null) {
        final myId = _room?.localParticipant?.identity ?? userId;
        if (myId.split('_').first != _authorizedStudentId!.split('_').first) {
          return;
        }
      }
    }

    final s = Stroke(
      points: List.from(pts),
      color: _selectedColor,
      width: _strokeWidth,
    );
    _whiteboardStrokes = [..._whiteboardStrokes, s];
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
      final removed = _whiteboardStrokes.removeLast();
      _redoStack.add(removed);
      _whiteboardStrokes = List.from(_whiteboardStrokes);
      sendData({'type': 'whiteboard_undo'});
      notifyListeners();
    }
  }

  void redoWhiteboard() {
    if (_redoStack.isNotEmpty) {
      final added = _redoStack.removeLast();
      _whiteboardStrokes = [..._whiteboardStrokes, added];
      sendData({'type': 'whiteboard_redo'});
      notifyListeners();
    }
  }

  void hideWhiteboard() => _isWhiteboardOpen = false;
  void clearWhiteboard() {
    _whiteboardStrokes = [];
    _redoStack.clear();
    sendData({'type': 'whiteboard_clear'});
    notifyListeners();
  }

  void sendMessage(String text, {Map<String, dynamic>? replyTo}) async {
    if (text.trim().isEmpty || (_isChatLocked && !isTeacher)) return;

    final tempId = DateTime.now().millisecondsSinceEpoch.toString();
    final msg = {
      'id': tempId,
      'user_name': userName,
      'content': text.trim(),
      'created_at': DateTime.now().toIso8601String(),
      if (replyTo != null) 'reply_to': replyTo,
    };

    _messages = [msg, ..._messages];
    sendData({'type': 'chat_message', ...msg});
    notifyListeners();

    try {
      final response = await supabase
          .from('messages')
          .insert({
        'room_name': roomName,
        'user_name': userName,
        'content': text.trim(),
        'reply_to': replyTo,
      })
          .select()
          .single();

      final index = _messages.indexWhere((m) => m['id'] == tempId);
      if (index != -1) {
        final updatedMsg = Map<String, dynamic>.from(_messages[index]);
        updatedMsg['id'] = response['id'];
        _messages[index] = updatedMsg;
        _messages = List.from(_messages);
        notifyListeners();
      }
    } catch (_) {}
  }

  void editMessage(String messageId, String newContent) async {
    final index = _messages.indexWhere(
          (m) => m['id'].toString() == messageId.toString(),
    );
    if (index == -1) return;

    if (_messages[index]['user_name'] != userName) return;

    final updatedMsg = Map<String, dynamic>.from(_messages[index]);
    updatedMsg['content'] = newContent.trim();
    updatedMsg['is_edited'] = true;
    _messages[index] = updatedMsg;
    _messages = List.from(_messages);

    sendData({
      'type': 'edit_chat_message',
      'id': messageId,
      'content': newContent.trim(),
    });

    notifyListeners();

    try {
      await supabase
          .from('messages')
          .update({'content': newContent.trim(), 'is_edited': true})
          .eq('id', messageId);
    } catch (e) {
      debugPrint("Error editing message: $e");
    }
  }

  void sendQuestion(String text) {
    if (text.trim().isEmpty) return;
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final qData = {
      'type': 'new_question',
      'id': id,
      'from': userName,
      'senderId': _room?.localParticipant?.identity ?? userId,
      'text': text.trim(),
    };
    final localQ = {...qData, 'upvotes': 0, 'is_answered': false};
    _questions = [localQ, ..._questions];
    _sortQuestions();
    sendData(qData);
    notifyListeners();
  }

  void upvoteQuestion(String questionId) {
    final qIndex = _questions.indexWhere((q) => q['id'] == questionId);
    if (qIndex != -1) {
      final updatedQ = Map<String, dynamic>.from(_questions[qIndex]);
      updatedQ['upvotes'] = (updatedQ['upvotes'] ?? 0) + 1;
      _questions[qIndex] = updatedQ;
      _sortQuestions();
      sendData({'type': 'upvote_question', 'question_id': questionId});
      notifyListeners();
    }
  }

  void markQuestionAsAnswered(String questionId) {
    if (!isTeacher) return;
    final qIndex = _questions.indexWhere((q) => q['id'] == questionId);
    if (qIndex != -1) {
      final updatedQ = Map<String, dynamic>.from(_questions[qIndex]);
      updatedQ['is_answered'] = true;
      _questions[qIndex] = updatedQ;
      if (_spotlightedQuestionId == questionId) _spotlightedQuestionId = null;
      _questions = List.from(_questions);
      sendData({'type': 'mark_answered', 'question_id': questionId});
      notifyListeners();
    }
  }

  void toggleQuestionSpotlight(String questionId) {
    if (!isTeacher) return;
    _spotlightedQuestionId = (_spotlightedQuestionId == questionId)
        ? null
        : questionId;
    _sortQuestions();
    sendData({
      'type': 'spotlight_question',
      'question_id': _spotlightedQuestionId,
    });
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
    if (sessionId == null || _isRecording) return;
    _isRecordingLoading = true;
    notifyListeners();
    onNotification?.call("جاري تحضير السيرفر للتسجيل... ⏳", Colors.blueGrey);

    try {
      final response = await http
          .post(
        Uri.parse(
          '${LiveKitService.supabaseUrl}/functions/v1/livekit-recording',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${LiveKitService.supabaseAnonKey}',
        },
        body: jsonEncode({
          'action': 'start',
          'roomName': roomName,
          'sessionId': sessionId,
          'title': title,
        }),
      )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        try {
          await DatabaseService().saveSession({
            'is_recording': true,
            'is_recording_paused': false,
          }, id: sessionId!);
        } catch (_) {}
        _isRecording = true;
        _isRecordingPaused = false;
        _triggerHaptic(heavy: true);
        onNotification?.call("🔴 بدأ التسجيل بنجاح", Colors.red);
      } else {
        final errorData = jsonDecode(response.body);
        onNotification?.call(
          "خطأ من السيرفر: ${errorData['error'] ?? 'فشل البدء'}",
          Colors.red,
        );
      }
    } catch (e) {
      onNotification?.call(
        "فشل الاتصال بالسيرفر: تأكد من مفاتيح LIVEKIT في Supabase",
        Colors.red,
      );
      debugPrint("Recording start error: $e");
    } finally {
      _isRecordingLoading = false;
      notifyListeners();
    }
  }

  Future<void> stopRecording() async {
    if (sessionId == null || !_isRecording) return;
    _isRecordingLoading = true;
    notifyListeners();

    try {
      final success = await LiveKitService().stopRecording(
        roomName,
        sessionId!,
      );
      if (success) {
        try {
          await DatabaseService().saveSession({
            'is_recording': false,
            'is_recording_paused': false,
          }, id: sessionId!);
        } catch (_) {}
        _isRecording = true;
        _isRecordingPaused = false;
        _triggerHaptic();
        onNotification?.call("✅ تم إيقاف التسجيل وجاري المعالجة", Colors.blue);
      } else {
        onNotification?.call("فشل إيقاف التسجيل", Colors.red);
      }
    } catch (e) {
      onNotification?.call("خطأ أثناء الإيقاف: $e", Colors.red);
    } finally {
      _isRecordingLoading = false;
      notifyListeners();
    }
  }

  Future<void> pauseRecording() async {
    if (sessionId == null || !_isRecording || _isRecordingPaused) return;
    try {
      final success = await LiveKitService().pauseRecording(
        roomName,
        sessionId!,
      );
      if (success) {
        try {
          await DatabaseService().saveSession({
            'is_recording_paused': true,
          }, id: sessionId!);
        } catch (_) {}
        _isRecordingPaused = true;
        notifyListeners();
      }
    } catch (e) {
      onNotification?.call("فشل إيقاف التسجيل مؤقتاً", Colors.red);
    }
  }

  Future<void> resumeRecording() async {
    if (sessionId == null || !_isRecording || !_isRecordingPaused) return;
    try {
      final success = await LiveKitService().resumeRecording(
        roomName,
        sessionId!,
      );
      if (success) {
        try {
          await DatabaseService().saveSession({
            'is_recording_paused': false,
          }, id: sessionId!);
        } catch (_) {}
        _isRecordingPaused = false;
        notifyListeners();
      }
    } catch (e) {
      onNotification?.call("فشل استئناف التسجيل", Colors.red);
    }
  }

  Future<void> toggleRecording() async {
    if (!isTeacher || _isRecordingLoading) return;
    _triggerHaptic();
    if (_isRecording) {
      if (_isRecordingPaused) {
        await resumeRecording();
      } else {
        await stopRecording();
      }
    } else {
      await startRecording();
    }
  }

  Future<void> downloadAttendanceReport() async {
    if (sessionId == null || _isProcessing) return;
    _isProcessing = true;
    notifyListeners();
    try {
      final attendanceData = await DatabaseService().getSessionAttendance(
        sessionId!,
      );
      await AttendancePdfService().generateReport(
        subjectName: title,
        teacherName: userName,
        studentsData: attendanceData,
      );
      onNotification?.call("تم استخراج تقرير الحضور ✅", Colors.green);
    } catch (e) {
      onNotification?.call("فشل استخراج التقرير", Colors.red);
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  Future<void> endSessionForAll() async {
    if (!isTeacher || sessionId == null) return;
    _isProcessing = true;
    notifyListeners();
    try {
      if (_isRecording) await stopRecording();
      sendData({'type': 'session_ended'});
      await DatabaseService().finalizeSessionAttendance(sessionId!);
      await DatabaseService().toggleRoomStatus(sessionId!, false);
      await DatabaseService().updateSessionStatus(sessionId!, 'archived');
      await Future.delayed(const Duration(milliseconds: 1500));
      final attendanceData = await DatabaseService().getSessionAttendance(
        sessionId!,
      );
      await AttendancePdfService().generateReport(
        subjectName: title,
        teacherName: userName,
        studentsData: attendanceData,
      );
      _room?.disconnect();
      onSessionEnded?.call("تم إنهاء الحصة وأرشفة التقرير بنجاح ✅");
    } catch (e) {
      debugPrint("Error ending session: $e");
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _notifyDebounce?.cancel();
    if (isTeacher && _isRecording) {
      LiveKitService().stopRecording(roomName, sessionId ?? "");
    }
    if (sessionId != null) {
      try {
        DatabaseService().logStudentExit(sessionId!, userId);
      } catch (_) {}
    }
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    _statusSubscription?.cancel();
    _statusSubscription = null;
    _seatsSubscription?.cancel();
    _seatsSubscription = null;
    _expiryTimer?.cancel();
    _breakoutTimer?.cancel();
    _listener?.dispose();
    _listener = null;
    _room?.disconnect();
    _room = null;
    super.dispose();
  }
}
