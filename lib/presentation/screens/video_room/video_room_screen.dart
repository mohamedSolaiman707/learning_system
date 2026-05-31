import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
      child: const Scaffold(
        backgroundColor: Colors.black,
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: _VideoRoomContent(),
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = context.read<VideoRoomController>();
      
      controller.onSessionEnded = (msg) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text("تنبيه"),
            content: Text(msg),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                child: const Text("حسناً"),
              ),
            ],
          ),
        );
      };
      
      controller.onNotification = (title, color) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(title), backgroundColor: color, behavior: SnackBarBehavior.floating),
        );
      };

      controller.onBreakoutInvite = (room, name) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("دعوة لمجموعة عمل"),
            content: Text("دعاك المدرس للانضمام إلى: $name"),
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
        setState(() {
          _reactions.add(_FlyingEmoji(
            key: UniqueKey(),
            emoji: emoji, 
            onComplete: () { if (mounted) setState(() => _reactions.removeAt(0)); }
          ));
        });
      };
    });
  }

  void _showExitConfirmation(BuildContext context, VideoRoomController controller) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("مغادرة القاعة"),
        content: Text(controller.isTeacher
            ? "هل تريد إنهاء الحصة للجميع أم المغادرة فقط؟"
            : "هل أنت متأكد من المغادرة؟"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("إلغاء")),
          if (controller.isTeacher)
            TextButton(
              onPressed: () {
                controller.endSessionForAll();
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text("إنهاء للكل", style: TextStyle(color: Colors.red)),
            ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text("مغادرة"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<VideoRoomController>();
    final size = MediaQuery.of(context).size;
    final bool isMobile = size.width < 600;

    if (controller.isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.blue),
            SizedBox(height: 20),
            Text("جاري الاتصال بالقاعة...", style: TextStyle(color: Colors.white)),
          ],
        ),
      );
    }

    if (controller.errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 60, color: Colors.redAccent),
              const SizedBox(height: 16),
              Text(
                controller.errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => controller.connectToRoom(controller.roomName),
                icon: const Icon(Icons.refresh),
                label: const Text("إعادة محاولة الاتصال"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("خروج", style: TextStyle(color: Colors.white70)),
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
        Positioned(
          top: 0, left: 0, right: 0,
          child: _buildHeader(context, controller),
        ),
        if (controller.isWhiteboardOpen) const WhiteboardPanel(),
        if (controller.isPollsOpen) 
          _buildCenterPanel(const PollPanel(), isMobile, size),
        if (controller.isQuizOpen)
          _buildCenterPanel(const QuizPanel(), isMobile, size),
        ..._reactions,
        const Align(
          alignment: Alignment.bottomCenter,
          child: ControlsBar(),
        ),
        if (controller.isChatOpen)
          _buildFeaturePanel(const ChatPanel(), isMobile, size),
        if (controller.isQAOpen)
          _buildFeaturePanel(const QAPanel(), isMobile, size),
        if (controller.isParticipantsOpen)
          _buildFeaturePanel(const ParticipantsPanel(), isMobile, size),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, VideoRoomController controller) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black.withOpacity(0.8), Colors.transparent],
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
            onPressed: () => _showExitConfirmation(context, controller),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  controller.title,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
                if (controller.isRecording)
                  const Row(
                    children: [
                      Icon(Icons.circle, color: Colors.red, size: 8),
                      SizedBox(width: 4),
                      Text("جاري التسجيل", style: TextStyle(color: Colors.white70, fontSize: 10)),
                    ],
                  ),
              ],
            ),
          ),
          if (controller.isBreakoutRoom && !controller.isTeacher)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: ElevatedButton.icon(
                onPressed: controller.returnToMainRoom,
                icon: const Icon(Icons.home, size: 16, color: Colors.white),
                label: const Text("العودة للقاعة الرئيسية", style: TextStyle(fontSize: 12, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFeaturePanel(Widget child, bool isMobile, Size size) {
    return Align(
      alignment: isMobile ? Alignment.bottomCenter : Alignment.centerRight,
      child: Container(
        width: isMobile ? size.width : 360,
        height: isMobile ? size.height * 0.7 : size.height,
        margin: isMobile 
            ? const EdgeInsets.only(bottom: 95) 
            : const EdgeInsets.only(right: 16, top: 16, bottom: 100),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: isMobile 
            ? const BorderRadius.vertical(top: Radius.circular(24)) 
            : BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 15, spreadRadius: 5)
          ],
        ),
        child: child,
      ),
    );
  }

  Widget _buildCenterPanel(Widget child, bool isMobile, Size size) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isMobile ? size.width * 0.9 : 450,
            maxHeight: size.height * 0.8,
          ),
          child: Material(
            elevation: 10,
            borderRadius: BorderRadius.circular(24),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _FlyingEmoji extends StatefulWidget {
  final String emoji;
  final VoidCallback onComplete;
  const _FlyingEmoji({super.key, required this.emoji, required this.onComplete});

  @override
  State<_FlyingEmoji> createState() => _FlyingEmojiState();
}

class _FlyingEmojiState extends State<_FlyingEmoji> with SingleTickerProviderStateMixin {
  late AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..forward().then((_) => widget.onComplete());
  }

  @override
  void dispose() { _anim.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) {
        return Positioned(
          bottom: 100 + (_anim.value * 400),
          left: 50 + (_anim.value * 20),
          child: Opacity(
            opacity: 1 - _anim.value,
            child: Text(widget.emoji, style: const TextStyle(fontSize: 40)),
          ),
        );
      },
    );
  }
}
