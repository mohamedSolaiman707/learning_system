import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:showcaseview/showcaseview.dart';
import 'video_room_controller.dart';
import 'widgets/participant_grid.dart';
import 'widgets/controls_bar.dart';
import 'widgets/chat_panel.dart';
import 'widgets/qa_panel.dart';
import 'widgets/whiteboard_panel.dart';
import 'widgets/participants_panel.dart';
import 'widgets/poll_panel.dart';

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
    required this.isTeacher,
    this.sessionId,
  });

  @override
  State<VideoRoomScreen> createState() => _VideoRoomScreenState();
}

class _VideoRoomScreenState extends State<VideoRoomScreen> {
  final GlobalKey _micKey = GlobalKey();
  final GlobalKey _camKey = GlobalKey();
  final GlobalKey _chatKey = GlobalKey();
  final GlobalKey _handKey = GlobalKey();
  final GlobalKey _emojiKey = GlobalKey();
  final GlobalKey _screenShareKey = GlobalKey();
  final GlobalKey _qaKey = GlobalKey();
  final GlobalKey _whiteboardKey = GlobalKey();
  final GlobalKey _recordKey = GlobalKey();

  final List<Widget> _reactions = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = context.read<VideoRoomController>();
      controller.init();

      controller.onBreakoutInvite = (room, name, duration) {
        _showBreakoutInvite(room, name, duration, controller);
      };

      controller.onSessionEnded = (msg) {
        _showStaticDialog("تنبيه", msg, onConfirm: () {
          Navigator.pop(context);
          Navigator.pop(context);
        });
      };
      
      controller.onNotification = (title, color) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
            backgroundColor: color,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 100),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
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

  void _showBreakoutInvite(String room, String name, int duration, VideoRoomController controller) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        title: const Text("دعوة لمجموعة عمل", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        content: Text("تم اختيارك للانضمام إلى $name لمدة $duration دقيقة.", style: const TextStyle(fontFamily: 'Cairo')),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () {
              controller.connectToRoom(room);
              Navigator.pop(context);
            },
            child: const Text("انضمام الآن", style: TextStyle(color: Colors.white, fontFamily: 'Cairo')),
          ),
        ],
      ),
    );
  }

  void _showStaticDialog(String title, String content, {VoidCallback? onConfirm}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: const TextStyle(fontFamily: 'Cairo')),
        content: Text(content, style: const TextStyle(fontFamily: 'Cairo')),
        actions: [
          ElevatedButton(
            onPressed: onConfirm,
            child: const Text("حسناً", style: TextStyle(fontFamily: 'Cairo')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bool isMobile = size.width < 600;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Consumer<VideoRoomController>(
        builder: (context, controller, child) {
          if (controller.errorMessage != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 60),
                  const SizedBox(height: 16),
                  Text(controller.errorMessage!, style: const TextStyle(color: Colors.white, fontFamily: 'Cairo')),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => controller.init(),
                    child: const Text("إعادة المحاولة"),
                  ),
                ],
              ),
            );
          }

          if (controller.isLoading) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: Colors.blue, strokeWidth: 3),
                  const SizedBox(height: 24),
                  const Text("جاري دخول القاعة...", style: TextStyle(color: Colors.white, fontSize: 16, fontFamily: 'Cairo')),
                ],
              ),
            );
          }

          return ShowCaseWidget(
            builder: (context) => Stack(
              children: [
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 80),
                    child: const ParticipantGrid(),
                  ),
                ),

                Positioned(top: 0, left: 0, right: 0, child: _buildHeader(context, controller)),

                if (controller.isWhiteboardOpen) const WhiteboardPanel(),
                
                if (controller.spotlightedQuestionId != null && !controller.isQAOpen)
                  _buildSpotlightOverlay(controller, isMobile, size),

                ..._reactions,

                Align(
                  alignment: Alignment.bottomCenter,
                  child: ControlsBar(
                    micKey: _micKey, camKey: _camKey, recordKey: _recordKey,
                    emojiKey: _emojiKey, screenShareKey: _screenShareKey,
                    handKey: _handKey, chatKey: _chatKey, qaKey: _qaKey,
                    whiteboardKey: _whiteboardKey,
                  ),
                ),

                if (controller.isChatOpen) _buildFeaturePanel(const ChatPanel(), isMobile, size),
                if (controller.isQAOpen) _buildFeaturePanel(const QAPanel(), isMobile, size),
                if (controller.isParticipantsOpen) _buildFeaturePanel(const ParticipantsPanel(), isMobile, size),
                if (controller.isPollsOpen) _buildFeaturePanel(const PollPanel(), isMobile, size),

                if (controller.isProcessing)
                  Container(
                    color: Colors.black45,
                    child: const Center(child: CircularProgressIndicator(color: Colors.white)),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSpotlightOverlay(VideoRoomController controller, bool isMobile, Size size) {
    final q = controller.questions.firstWhere((element) => element['id'] == controller.spotlightedQuestionId, orElse: () => {});
    if (q.isEmpty) return const SizedBox();

    return Positioned(
      bottom: 120,
      left: isMobile ? 20 : size.width * 0.25,
      right: isMobile ? 20 : size.width * 0.25,
      child: FadeInUp(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [Colors.orange.shade800, Colors.orange.shade600]),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 20, offset: const Offset(0, 10))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.wb_incandescent, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  const Text("نقاش جاري الآن", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12, fontFamily: 'Cairo')),
                  const Spacer(),
                  Text(q['from'], style: const TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'Cairo')),
                ],
              ),
              const Divider(color: Colors.white24),
              Text(
                q['text'],
                maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600, fontFamily: 'Cairo'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, VideoRoomController controller) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black.withOpacity(0.9), Colors.transparent]),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.white, size: 28),
            onPressed: () => _showExitConfirmation(context, controller),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(controller.title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Cairo'), overflow: TextOverflow.ellipsis),
                Row(
                  children: [
                    if (controller.isRecording) ...[const _PulsingRecordBadge(), const SizedBox(width: 8)],
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
      child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
    );
  }

  void _showExitConfirmation(BuildContext context, VideoRoomController controller) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("مغادرة القاعة", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        content: Text(controller.isTeacher ? "هل تريد إنهاء الحصة للجميع أم المغادرة فقط؟" : "هل أنت متأكد من مغادرة الحصة؟", style: const TextStyle(fontFamily: 'Cairo')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("إلغاء", style: TextStyle(fontFamily: 'Cairo'))),
          if (controller.isTeacher)
            TextButton(
              onPressed: () { controller.endSessionForAll(); Navigator.pop(context); Navigator.pop(context); },
              child: const Text("إنهاء للكل", style: TextStyle(color: Colors.red, fontFamily: 'Cairo')),
            ),
          ElevatedButton(
            onPressed: () { Navigator.pop(context); Navigator.pop(context); },
            child: const Text("مغادرة", style: TextStyle(fontFamily: 'Cairo')),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturePanel(Widget child, bool isMobile, Size size) {
    return Align(
      alignment: isMobile ? Alignment.bottomCenter : Alignment.centerRight,
      child: Container(
        width: isMobile ? size.width * 0.92 : 380, // تعديل العرض ليصبح 92% من الشاشة في الموبايل
        height: isMobile ? size.height * 0.75 : size.height * 0.85,
        margin: isMobile ? const EdgeInsets.only(bottom: 95, left: 16, right: 16) : const EdgeInsets.all(20), // إضافة margin جانبي في الموبايل
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 20, spreadRadius: -5)],
        ),
        child: ClipRRect(borderRadius: BorderRadius.circular(30), child: child),
      ),
    );
  }
}

class FadeInUp extends StatelessWidget {
  final Widget child;
  const FadeInUp({super.key, required this.child});
  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 500),
      builder: (context, val, child) => Opacity(opacity: val, child: Transform.translate(offset: Offset(0, 20 * (1 - val)), child: child)),
      child: child,
    );
  }
}

class _FlyingEmoji extends StatefulWidget {
  final Key key;
  final String emoji;
  final int delay;
  final VoidCallback onComplete;
  const _FlyingEmoji({required this.key, required this.emoji, required this.delay, required this.onComplete}) : super(key: key);
  @override
  State<_FlyingEmoji> createState() => _FlyingEmojiState();
}

class _FlyingEmojiState extends State<_FlyingEmoji> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _yAnim;
  late Animation<double> _opacityAnim;
  late double _startX;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 2500));
    _yAnim = Tween<double>(begin: 0, end: -400).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _opacityAnim = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 20),
    ]).animate(_controller);
    
    Future.delayed(Duration(milliseconds: widget.delay), () {
       if (mounted) _controller.forward().then((_) => widget.onComplete());
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _startX = MediaQuery.of(context).size.width / 2 + (DateTime.now().millisecond % 100 - 50);
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Positioned(
          left: _startX,
          bottom: 100 + _yAnim.value.abs(),
          child: Opacity(opacity: _opacityAnim.value, child: Text(widget.emoji, style: const TextStyle(fontSize: 40))),
        );
      },
    );
  }
}

class _PulsingRecordBadge extends StatefulWidget {
  const _PulsingRecordBadge();
  @override
  State<_PulsingRecordBadge> createState() => _PulsingRecordBadgeState();
}

class _PulsingRecordBadgeState extends State<_PulsingRecordBadge> with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat(reverse: true);
  }
  @override
  void dispose() { _anim.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(4)),
        child: const Row(
          children: [
            Icon(Icons.fiber_manual_record, color: Colors.white, size: 10),
            SizedBox(width: 4),
            Text("REC", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
