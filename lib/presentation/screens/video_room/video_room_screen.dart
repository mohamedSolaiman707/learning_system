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
import '../../../core/utils/responsive.dart';

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
    final bool isDesktop = Responsive.isDesktop(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0F1014),
      body: Consumer<VideoRoomController>(
        builder: (context, controller, child) {
          if (controller.errorMessage != null) {
            return _buildErrorState(controller, isDesktop);
          }

          if (controller.isLoading) {
            return _buildLoadingState();
          }

          // تحديد ما إذا كان الشريط الجانبي مفتوحاً
          final bool isSidebarOpen = controller.isChatOpen || controller.isQAOpen || controller.isParticipantsOpen || controller.isPollsOpen;

          return ShowCaseWidget(
            builder: (context) => Stack(
              children: [
                Row(
                  children: [
                    // المنطقة الرئيسية للفيديو
                    Expanded(
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: AnimatedPadding(
                              duration: const Duration(milliseconds: 300),
                              padding: EdgeInsets.only(bottom: isDesktop ? 0 : 80),
                              child: const ParticipantGrid(),
                            ),
                          ),

                          // الهيدر الاحترافي
                          Positioned(top: 0, left: 0, right: 0, child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildHeader(context, controller),
                              if (!widget.isTeacher) _buildChannelSelector(controller, isDesktop),
                            ],
                          )),

                          if (controller.isWhiteboardOpen) const WhiteboardPanel(),
                          
                          if (controller.spotlightedQuestionId != null && !controller.isQAOpen)
                            _buildSpotlightOverlay(controller, !isDesktop, size),

                          ..._reactions,

                          // شريط التحكم العائم
                          Align(
                            alignment: Alignment.bottomCenter,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 20),
                              child: ControlsBar(
                                micKey: _micKey, camKey: _camKey, recordKey: _recordKey,
                                emojiKey: _emojiKey, screenShareKey: _screenShareKey,
                                handKey: _handKey, chatKey: _chatKey, qaKey: _qaKey,
                                whiteboardKey: _whiteboardKey,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // الشريط الجانبي المدمج (للمتصفح والديسكتوب)
                    if (isDesktop)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: isSidebarOpen ? 380 : 0,
                        curve: Curves.easeInOut,
                        child: isSidebarOpen ? _buildSidebar(controller) : const SizedBox(),
                      ),
                  ],
                ),

                // Panels للموبايل فقط
                if (!isDesktop) ...[
                  if (controller.isChatOpen) _buildFeaturePanel(const ChatPanel(), size),
                  if (controller.isQAOpen) _buildFeaturePanel(const QAPanel(), size),
                  if (controller.isParticipantsOpen) _buildFeaturePanel(const ParticipantsPanel(), size),
                  if (controller.isPollsOpen) _buildFeaturePanel(const PollPanel(), size),
                ],

                if (controller.isProcessing)
                  Container(
                    color: Colors.black54,
                    child: const Center(child: CircularProgressIndicator(color: Colors.white)),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildChannelSelector(VideoRoomController controller, bool isDesktop) {
    final channels = [
      {'id': 'room-cam-right', 'label': 'كاميرا اليمين'},
      {'id': 'room-cam-left', 'label': 'كاميرا الشمال'},
      {'id': 'room-cam-screen', 'label': 'الشاشة'},
      {'id': 'whiteboard', 'label': 'السبورة'},
    ];

    Widget buildButtons() {
      return Wrap(
        spacing: 12,
        runSpacing: 10,
        alignment: WrapAlignment.center,
        children: channels.map((ch) {
          final isSelected = controller.selectedChannel == ch['id'];
          return SizedBox(
            width: isDesktop ? 130 : null,
            child: OutlinedButton(
              onPressed: () => controller.selectChannel(ch['id']!),
              style: OutlinedButton.styleFrom(
                backgroundColor: isSelected ? Colors.blue : Colors.transparent,
                side: BorderSide(color: isSelected ? Colors.blue : Colors.white),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              child: Text(
                ch['label']!,
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'Cairo',
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 13,
                ),
              ),
            ),
          );
        }).toList(),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: isDesktop
          ? Center(child: buildButtons())
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: channels.map((ch) {
                  final isSelected = controller.selectedChannel == ch['id'];
                  return Padding(
                    padding: const EdgeInsets.only(left: 10),
                    child: OutlinedButton(
                      onPressed: () => controller.selectChannel(ch['id']!),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: isSelected ? Colors.blue : Colors.transparent,
                        side: BorderSide(color: isSelected ? Colors.blue : Colors.white),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      child: Text(
                        ch['label']!,
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: 'Cairo',
                          fontSize: 12,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
    );
  }

  Widget _buildSidebar(VideoRoomController controller) {
    Widget content = const SizedBox();
    if (controller.isChatOpen) content = const ChatPanel();
    else if (controller.isQAOpen) content = const QAPanel();
    else if (controller.isParticipantsOpen) content = const ParticipantsPanel();
    else if (controller.isPollsOpen) content = const PollPanel();

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(left: BorderSide(color: Colors.white10, width: 0.5)),
        boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 20, offset: Offset(-5, 0))],
      ),
      child: ClipRRect(child: content),
    );
  }

  Widget _buildErrorState(VideoRoomController controller, bool isDesktop) {
    return Center(
      child: Container(
        constraints: BoxConstraints(maxWidth: isDesktop ? 500 : double.infinity),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 80),
            const SizedBox(height: 24),
            Text(
              controller.errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 18, fontFamily: 'Cairo', fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: isDesktop ? 250 : double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                onPressed: () => controller.init(),
                child: const Text("إعادة المحاولة", style: TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Colors.blue, strokeWidth: 3),
          const SizedBox(height: 24),
          const Text("جاري دخول القاعة التعليمية...", style: TextStyle(color: Colors.white, fontSize: 16, fontFamily: 'Cairo')),
        ],
      ),
    );
  }

  Widget _buildSpotlightOverlay(VideoRoomController controller, bool isMobile, Size size) {
    final q = controller.questions.firstWhere((element) => element['id'] == controller.spotlightedQuestionId, orElse: () => {});
    if (q.isEmpty) return const SizedBox();

    return Positioned(
      bottom: isMobile ? 120 : 110,
      left: isMobile ? 20 : size.width * 0.2,
      right: isMobile ? 20 : size.width * 0.2,
      child: FadeInUp(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [Colors.orange.shade800, Colors.orange.shade600]),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 20, offset: const Offset(0, 10))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.wb_incandescent, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  const Text("سؤال مطروح للنقاش", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Cairo')),
                  const Spacer(),
                  Text(q['from'], style: const TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'Cairo')),
                ],
              ),
              const Divider(color: Colors.white24),
              Text(
                q['text'],
                maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600, fontFamily: 'Cairo'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, VideoRoomController controller) {
    final isDesktop = Responsive.isDesktop(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: isDesktop ? 15 : 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black87, Colors.transparent]),
      ),
      child: Row(
        children: [
          _CircleIconButton(
            icon: Icons.logout_rounded, 
            color: Colors.redAccent.withOpacity(0.8),
            onPressed: () => _showExitConfirmation(context, controller),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(controller.title, style: TextStyle(color: Colors.white, fontSize: isDesktop ? 22 : 18, fontWeight: FontWeight.bold, fontFamily: 'Cairo'), overflow: TextOverflow.ellipsis),
                Row(
                  children: [
                    if (controller.isRecording) ...[const _PulsingRecordBadge(), const SizedBox(width: 8)],
                    _buildStatusBadge("${controller.room?.remoteParticipants.length ?? 0} مشارك", Colors.white24),
                  ],
                ),
              ],
            ),
          ),
          if (widget.isTeacher) ...[
            _CircleIconButton(
              icon: controller.isVideoWallMode 
                  ? Icons.view_sidebar_rounded 
                  : Icons.grid_view_rounded,
              color: Colors.white.withOpacity(0.1),
              onPressed: () => controller.toggleVideoWallMode(),
            ),
            const SizedBox(width: 12),
          ],
          if (isDesktop) _buildDesktopClock(),
        ],
      ),
    );
  }

  Widget _buildDesktopClock() {
     return StreamBuilder(
       stream: Stream.periodic(const Duration(seconds: 1)),
       builder: (context, snapshot) {
         final now = DateTime.now();
         return Container(
           padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
           decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
           child: Text(
             "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}",
             style: const TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1),
           ),
         );
       }
     );
  }

  Widget _buildStatusBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
    );
  }

  void _showExitConfirmation(BuildContext context, VideoRoomController controller) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("مغادرة القاعة", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        content: Text(controller.isTeacher ? "هل تريد إنهاء الحصة للجميع أم المغادرة فقط؟" : "هل أنت متأكد من مغادرة الحصة الدراسية؟", style: const TextStyle(fontFamily: 'Cairo')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("إلغاء", style: TextStyle(fontFamily: 'Cairo'))),
          if (controller.isTeacher)
            TextButton(
              onPressed: () { controller.endSessionForAll(); Navigator.pop(context); Navigator.pop(context); },
              child: const Text("إنهاء الحصة للكل", style: TextStyle(color: Colors.red, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
            ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF102A43)),
            onPressed: () { Navigator.pop(context); Navigator.pop(context); },
            child: const Text("مغادرة الآن", style: TextStyle(color: Colors.white, fontFamily: 'Cairo')),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturePanel(Widget child, Size size) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        width: size.width * 0.94,
        height: size.height * 0.75,
        margin: const EdgeInsets.only(bottom: 100, left: 16, right: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [BoxShadow(color: Colors.black87, blurRadius: 30, spreadRadius: -5)],
        ),
        child: ClipRRect(borderRadius: BorderRadius.circular(30), child: child),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final Color color;
  const _CircleIconButton({required this.icon, required this.onPressed, required this.color});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 22),
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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(6)),
        child: const Row(
          children: [
            Icon(Icons.fiber_manual_record, color: Colors.white, size: 12),
            SizedBox(width: 4),
            Text("REC", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
