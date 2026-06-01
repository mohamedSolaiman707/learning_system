import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:showcaseview/showcaseview.dart';
import '../../../core/providers/auth_provider.dart';
import 'video_room_controller.dart';
import 'widgets/participant_grid.dart';
import 'widgets/controls_bar.dart';
import 'widgets/whiteboard_panel.dart';
import 'widgets/chat_panel.dart';
import 'widgets/poll_panel.dart';
import 'widgets/quiz_panel.dart';
import 'widgets/qa_panel.dart';
import 'widgets/participants_panel.dart';

class VideoRoomScreen extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => VideoRoomController(
        title: title,
        roomName: roomName,
        userName: userName,
        userId: userId,
        isTeacher: isTeacher,
        sessionId: sessionId,
      )..init(),
      child: ShowCaseWidget(
        onFinish: () => context.read<AuthProvider>().completeVideoTour(),
        builder: (context) => const Scaffold(
          backgroundColor: Colors.black,
          resizeToAvoidBottomInset: true,
          body: SafeArea(
            child: _VideoRoomContent(),
          ),
        ),
      ),
    );
  }
}

class _VideoRoomContent extends StatefulWidget {
  const _VideoRoomContent();

  @override
  State<_VideoRoomContent> createState() => _VideoRoomContentState();
}

class _VideoRoomContentState extends State<_VideoRoomContent> {
  final List<Widget> _reactions = [];
  
  // مفاتيح الجولة داخل اللايف
  final GlobalKey _micKey = GlobalKey();
  final GlobalKey _camKey = GlobalKey();
  final GlobalKey _chatKey = GlobalKey();
  final GlobalKey _handKey = GlobalKey();
  final GlobalKey _exitKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = context.read<VideoRoomController>();
      final auth = context.read<AuthProvider>();

      // تشغيل الجولة إذا كان طالباً ولم يشاهدها من قبل
      if (!auth.isTeacher && !auth.hasSeenVideoTour) {
        ShowCaseWidget.of(context).startShowCase([
          _micKey,
          _camKey,
          _handKey,
          _chatKey,
          _exitKey,
        ]);
      }
      
      controller.onSessionEnded = (msg) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: const Text("تنبيه"),
            content: Text(msg),
            actions: [
              ElevatedButton(
                onPressed: () { Navigator.pop(context); Navigator.pop(context); },
                child: const Text("حسناً"),
              ),
            ],
          ),
        );
      };
      
      controller.onNotification = (title, color) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: color,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 100),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          ),
        );
      };

      controller.onBreakoutInvite = (room, name, duration) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text("دعوة لمجموعة عمل"),
            content: Text("دعاك المدرس للانضمام إلى: $name\nمدة النقاش: $duration دقيقة"),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("تجاهل")),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.read<VideoRoomController>().connectToRoom(room);
                },
                child: const Text("انضمام الآن"),
              ),
            ],
          ),
        );
      };

      controller.onReactionReceived = (emoji) {
        if (!mounted) return;
        setState(() {
          for (int i = 0; i < 3; i++) {
             _reactions.add(_FlyingEmoji(
              key: UniqueKey(),
              emoji: emoji,
              delay: i * 100,
              onComplete: () { if (mounted) setState(() => _reactions.removeAt(0)); }
            ));
          }
        });
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<VideoRoomController>();
    final size = MediaQuery.of(context).size;
    final bool isMobile = size.width < 600;

    if (controller.isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Colors.blue, strokeWidth: 3),
            const SizedBox(height: 24),
            const Text("جاري الاتصال بالقاعة التعليمية...", style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
      );
    }

    if (controller.errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.wifi_off_rounded, size: 80, color: Colors.redAccent),
              const SizedBox(height: 24),
              Text(controller.errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 16)),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () => controller.connectToRoom(controller.roomName),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text("إعادة محاولة الاتصال"),
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 80),
            child: const ParticipantGrid(),
          ),
        ),

        Positioned(top: 0, left: 0, right: 0, child: _buildHeader(context, controller)),

        if (controller.isWhiteboardOpen) const WhiteboardPanel(),
        if (controller.isPollsOpen) _buildCenterPanel(const PollPanel(), isMobile, size),
        if (controller.isQuizOpen) _buildCenterPanel(const QuizPanel(), isMobile, size),

        ..._reactions,

        Align(
          alignment: Alignment.bottomCenter,
          child: ControlsBar(
            micKey: _micKey,
            camKey: _camKey,
            chatKey: _chatKey,
            handKey: _handKey,
          ),
        ),

        if (controller.isChatOpen) _buildFeaturePanel(const ChatPanel(), isMobile, size),
        if (controller.isQAOpen) _buildFeaturePanel(const QAPanel(), isMobile, size),
        if (controller.isParticipantsOpen) _buildFeaturePanel(const ParticipantsPanel(), isMobile, size),

        if (controller.isProcessing)
          Container(
            color: Colors.black45,
            child: const Center(child: CircularProgressIndicator(color: Colors.white)),
          ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, VideoRoomController controller) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Colors.black.withOpacity(0.9), Colors.transparent],
        ),
      ),
      child: Row(
        children: [
          Showcase(
            key: _exitKey,
            title: 'مغادرة الحصة',
            description: 'عند انتهاء الحصة، يمكنك الخروج من هنا.',
            child: IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
              onPressed: () => _showExitConfirmation(context, controller),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(controller.title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                Row(
                  children: [
                    if (controller.isRecording) ...[
                       _buildStatusBadge("REC", Colors.red),
                       const SizedBox(width: 8),
                    ],
                    _buildStatusBadge("${controller.room?.remoteParticipants.length ?? 0} مشارك", Colors.white24),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
      child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  void _showExitConfirmation(BuildContext context, VideoRoomController controller) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("مغادرة القاعة"),
        content: Text(controller.isTeacher ? "هل تريد إنهاء الحصة للجميع أم المغادرة فقط؟" : "هل أنت متأكد من مغادرة الحصة؟"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("إلغاء")),
          if (controller.isTeacher)
            TextButton(
              onPressed: () { controller.endSessionForAll(); Navigator.pop(context); Navigator.pop(context); },
              child: const Text("إنهاء للكل", style: TextStyle(color: Colors.red)),
            ),
          ElevatedButton(
            onPressed: () { Navigator.pop(context); Navigator.pop(context); },
            child: const Text("مغادرة"),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturePanel(Widget child, bool isMobile, Size size) {
    return Align(
      alignment: isMobile ? Alignment.bottomCenter : Alignment.centerRight,
      child: Container(
        width: isMobile ? size.width : 380,
        height: isMobile ? size.height * 0.75 : size.height * 0.85,
        margin: isMobile ? const EdgeInsets.only(bottom: 95) : const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 20, spreadRadius: -5)],
        ),
        child: ClipRRect(borderRadius: BorderRadius.circular(30), child: child),
      ),
    );
  }

  Widget _buildCenterPanel(Widget child, bool isMobile, Size size) {
    return Center(
      child: Container(
        constraints: BoxConstraints(maxWidth: isMobile ? size.width * 0.9 : 500, maxHeight: size.height * 0.8),
        child: Material(elevation: 20, borderRadius: BorderRadius.circular(32), child: child),
      ),
    );
  }
}

class _FlyingEmoji extends StatefulWidget {
  final String emoji;
  final int delay;
  final VoidCallback onComplete;
  const _FlyingEmoji({super.key, required this.emoji, required this.onComplete, this.delay = 0});

  @override
  State<_FlyingEmoji> createState() => _FlyingEmojiState();
}

class _FlyingEmojiState extends State<_FlyingEmoji> with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  late double _randomX;
  late double _randomRotation;

  @override
  void initState() {
    super.initState();
    _randomX = (math.Random().nextDouble() * 150) - 75;
    _randomRotation = (math.Random().nextDouble() * 1.0) - 0.5;

    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 2500));

    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _anim.forward().then((_) => widget.onComplete());
    });
  }

  @override
  void dispose() { _anim.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) {
        final double progress = _anim.value;
        return Positioned(
          bottom: 120 + (progress * 500),
          left: (MediaQuery.of(context).size.width / 2) + _randomX,
          child: Opacity(
            opacity: progress < 0.2 ? progress * 5 : (1 - progress),
            child: Transform.rotate(
              angle: _randomRotation * progress * 5,
              child: Transform.scale(
                scale: 0.5 + (progress * 1.5),
                child: Text(widget.emoji, style: const TextStyle(fontSize: 45)),
              ),
            ),
          ),
        );
      },
    );
  }
}
