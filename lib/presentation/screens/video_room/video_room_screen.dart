import 'package:flutter/material.dart';
import 'package:learning_by_video_call/presentation/screens/video_room/widgets/dynamic_stage.dart';
import 'package:provider/provider.dart';
import 'package:showcaseview/showcaseview.dart';
import 'video_room_controller.dart';
import 'widgets/participant_grid.dart';
import 'widgets/controls_bar.dart';
import 'widgets/chat_panel.dart';
import 'widgets/qa_panel.dart';
import 'widgets/whiteboard_panel.dart';
import 'widgets/participants_panel.dart';
import 'utils/classroom_participant_utils.dart';
import 'widgets/poll_panel.dart';
import 'widgets/source_manager_sidebar.dart';
import 'widgets/seat_picker_dialog.dart';
import '../../../core/utils/responsive.dart';
import 'package:livekit_client/livekit_client.dart';

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
  final List<Widget> _reactions = [];
  bool _isSeatPickerOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = context.read<VideoRoomController>();
      controller.init();

      controller.addListener(_handleSeatPicker);

      controller.onBreakoutInvite = (room, name, duration) {
        _showBreakoutInvite(room, name, duration, controller);
      };

      controller.onSessionEnded = (msg) {
        _showStaticDialog(
          "تنبيه",
          msg,
          onConfirm: () {
            Navigator.pop(context);
            Navigator.pop(context);
          },
        );
      };

      controller.onNotification = (title, color) {
        if (!mounted) return;
        final bool isDesktop = Responsive.isDesktop(context);

        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: Colors.white.withOpacity(0.9),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Cairo',
                      fontSize: 13,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: color.withOpacity(0.95),
            behavior: SnackBarBehavior.floating,
            elevation: 10,
            width: isDesktop ? 400 : null,
            margin: isDesktop
                ? null
                : const EdgeInsets.fromLTRB(20, 0, 20, 100),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      };

      controller.onReactionReceived = (emoji) {
        if (!mounted) return;
        setState(() {
          for (int i = 0; i < 3; i++) {
            _reactions.add(
              _FlyingEmoji(
                key: UniqueKey(),
                emoji: emoji,
                delay: i * 100,
                onComplete: () {
                  if (mounted) setState(() => _reactions.removeAt(0));
                },
              ),
            );
          }
        });
      };
    });
  }

  void _handleSeatPicker() {
    if (!mounted || widget.isTeacher) return;
    final controller = context.read<VideoRoomController>();

    // Open picker if not shown, not already open, and controller finished initial loading
    if (!controller.seatPickerShown && !_isSeatPickerOpen) {
      setState(() => _isSeatPickerOpen = true);
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => ChangeNotifierProvider.value(
          value: controller,
          child: const SeatPickerDialog(),
        ),
      ).then((_) {
        if (mounted) setState(() => _isSeatPickerOpen = false);
      });
    }
  }

  @override
  void dispose() {
    try {
      context.read<VideoRoomController>().removeListener(_handleSeatPicker);
    } catch (_) {}
    super.dispose();
  }

  void _showBreakoutInvite(
    String room,
    String name,
    int duration,
    VideoRoomController controller,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        title: const Text(
          "دعوة لمجموعة عمل",
          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
        ),
        content: Text(
          "تم اختيارك للانضمام إلى $name لمدة $duration دقيقة.",
          style: const TextStyle(fontFamily: 'Cairo'),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              controller.connectToRoom(room);
              Navigator.pop(context);
            },
            child: const Text(
              "انضمام الآن",
              style: TextStyle(color: Colors.white, fontFamily: 'Cairo'),
            ),
          ),
        ],
      ),
    );
  }

  void _showStaticDialog(
    String title,
    String content, {
    VoidCallback? onConfirm,
  }) {
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

  void _showSettingsDialog() {
    final controller = context.read<VideoRoomController>();
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            "إعدادات وتحكم القاعة",
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.isTeacher) ...[
                  const Text(
                    "صلاحيات الطلاب (قفل جماعي)",
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 13,
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildToggle("قفل الميكروفونات", controller.isAllMuted, (
                    val,
                  ) {
                    controller.muteAllParticipants(val);
                    setDialogState(() {});
                  }, icon: Icons.mic_off),
                  _buildToggle(
                    "قفل الكاميرات",
                    controller.isCamLocked,
                    (val) {
                      controller.disableAllCameras(val);
                      setDialogState(() {});
                    },
                    icon: Icons.videocam_off,
                  ),
                  _buildToggle(
                    "قفل الشات",
                    controller.isChatLocked,
                    (val) {
                      controller.toggleChatLock();
                      setDialogState(() {});
                    },
                    icon: Icons.speaker_notes_off_outlined,
                  ),
                  _buildToggle(
                    "قفل السبورة",
                    controller.isWhiteboardLocked,
                    (val) {
                      controller.toggleWhiteboardLock();
                      setDialogState(() {});
                    },
                    icon: Icons.edit_outlined,
                  ),
                  _buildToggle(
                    "قفل مشاركة الشاشة",
                    controller.isScreenShareLocked,
                    (val) {
                      controller.toggleScreenShareLock();
                      setDialogState(() {});
                    },
                    icon: Icons.screen_lock_landscape,
                  ),
                  const Divider(),
                  _buildToggle(
                    "وضع جدار الفيديو (Wall)",
                    controller.isVideoWallMode,
                    (val) {
                      controller.toggleVideoWallMode();
                      setDialogState(() {});
                    },
                    icon: Icons.grid_view_rounded,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToggle(
    String title,
    bool value,
    Function(bool) onChanged, {
    IconData? icon,
  }) {
    return SwitchListTile(
      secondary: icon != null
          ? Icon(icon, size: 20, color: value ? Colors.red : Colors.grey)
          : null,
      title: Text(
        title,
        style: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
      ),
      value: value,
      activeColor: Colors.red,
      onChanged: onChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = Responsive.isDesktop(context);
    final controller = context.read<VideoRoomController>();

    if (widget.isTeacher) return _buildTeacherLayout();

    final errorMessage = context.select<VideoRoomController, String?>(
      (c) => c.errorMessage,
    );
    if (errorMessage != null) return _buildErrorState(controller, isDesktop);

    final isLoading = context.select<VideoRoomController, bool>(
      (c) => c.isLoading,
    );
    if (isLoading) return _buildLoadingState();

    return Scaffold(
      backgroundColor: const Color(0xFF0F1014),
      body: Stack(
        children: [
          Row(
            children: [
              // 1. Source Manager Sidebar (Multi-Source)
              Selector<VideoRoomController, String>(
                selector: (_, c) => c.multiSourceKey,
                builder: (context, _, __) => SourceManagerSidebar(),
              ),

              Expanded(
                child: Column(
                  children: [
                    // 2. Top Header
                    Selector<
                      VideoRoomController,
                      ({
                        bool isHandRaised,
                        bool isMicEnabled,
                        bool isCamEnabled,
                        bool isChatOpen,
                        bool isQAOpen,
                        bool isPollsOpen,
                        bool isScreenSharing,
                        bool isScreenShareLocked,
                      })
                    >(
                      selector: (_, c) => (
                        isHandRaised: c.isHandRaised,
                        isMicEnabled: c.isMicEnabled,
                        isCamEnabled: c.isCamEnabled,
                        isChatOpen: c.isChatOpen,
                        isQAOpen: c.isQAOpen,
                        isPollsOpen: c.isPollsOpen,
                        isScreenSharing: c.isScreenSharing,
                        isScreenShareLocked: c.isScreenShareLocked,
                      ),
                      builder: (context, data, _) => _buildTopHeader(
                        context,
                        controller,
                        isHandRaised: data.isHandRaised,
                        isMicEnabled: data.isMicEnabled,
                        isCamEnabled: data.isCamEnabled,
                        isChatOpen: data.isChatOpen,
                        isQAOpen: data.isQAOpen,
                        isPollsOpen: data.isPollsOpen,
                        isScreenSharing: data.isScreenSharing,
                        isScreenShareLocked: data.isScreenShareLocked,
                      ),
                    ),

                    Expanded(
                      child: Row(
                        children: [
                          // 3. Dynamic Multi-Source Stage
                          Expanded(
                            child: Stack(
                              clipBehavior: Clip.hardEdge,
                              children: [
                                Positioned.fill(
                                  child: DynamicStage(controller: controller),
                                ),
                                ..._reactions,
                              ],
                            ),
                          ),

                          // 4. Right Panel
                          Selector<
                            VideoRoomController,
                            ({bool isChatOpen, bool isQAOpen, bool isPollsOpen})
                          >(
                            selector: (_, c) => (
                              isChatOpen: c.isChatOpen,
                              isQAOpen: c.isQAOpen,
                              isPollsOpen: c.isPollsOpen,
                            ),
                            builder: (context, data, _) {
                              final isOpen =
                                  (data.isChatOpen ||
                                      data.isQAOpen ||
                                      data.isPollsOpen) &&
                                  isDesktop;
                              if (!isOpen) return const SizedBox();
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                width: 380,
                                padding: const EdgeInsets.all(16),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(24),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        blurRadius: 20,
                                        offset: const Offset(0, 10),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(24),
                                    child: data.isChatOpen
                                        ? const ChatPanel()
                                        : (data.isQAOpen
                                              ? const QAPanel()
                                              : const PollPanel()),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    // 5. Bottom Bar
                    _StudentBottomBar(controller: controller),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopHeader(
    BuildContext context,
    VideoRoomController controller, {
    bool? isHandRaised,
    bool? isMicEnabled,
    bool? isCamEnabled,
    bool? isChatOpen,
    bool? isQAOpen,
    bool? isPollsOpen,
    bool? isScreenSharing,
    bool? isScreenShareLocked,
  }) {
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1B1F),
        border: Border(bottom: BorderSide(color: Colors.white10, width: 0.5)),
      ),
      child: Row(
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                controller.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Cairo',
                ),
              ),
              Row(
                children: [
                  const Icon(
                    Icons.people_alt_rounded,
                    color: Colors.blue,
                    size: 12,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    "${(controller.room?.remoteParticipants.length ?? 0) + 1} متصل الآن",
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 10,
                      fontFamily: 'Cairo',
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Spacer(),
          if (!widget.isTeacher)
            Row(
              children: [
                _HeaderToolButton(
                  icon: (isHandRaised ?? controller.isHandRaised)
                      ? Icons.front_hand
                      : Icons.front_hand_outlined,
                  color: (isHandRaised ?? controller.isHandRaised)
                      ? Colors.amber
                      : Colors.white54,
                  onPressed: controller.toggleHand,
                  label: "رفع اليد",
                ),
                const SizedBox(width: 15),
                _HeaderToolButton(
                  icon: (isMicEnabled ?? controller.isMicEnabled)
                      ? Icons.mic
                      : Icons.mic_off,
                  color: (isMicEnabled ?? controller.isMicEnabled)
                      ? Colors.blue
                      : Colors.redAccent,
                  onPressed: controller.toggleMic,
                  label: (isMicEnabled ?? controller.isMicEnabled)
                      ? "الميكروفون"
                      : "صامت",
                ),
                const SizedBox(width: 15),
                _HeaderToolButton(
                  icon: (isCamEnabled ?? controller.isCamEnabled)
                      ? Icons.videocam
                      : Icons.videocam_off,
                  color: (isCamEnabled ?? controller.isCamEnabled)
                      ? Colors.blue
                      : Colors.redAccent,
                  onPressed: controller.toggleCam,
                  label: "الكاميرا",
                ),
                const SizedBox(width: 15),
                _HeaderToolButton(
                  icon: Icons.chat_bubble_rounded,
                  color: (isChatOpen ?? controller.isChatOpen)
                      ? Colors.blue
                      : Colors.white54,
                  onPressed: controller.toggleChat,
                  label: "الشات",
                ),
                const SizedBox(width: 15),
                _HeaderToolButton(
                  icon: Icons.help_outline_rounded,
                  color: (isQAOpen ?? controller.isQAOpen)
                      ? Colors.orange
                      : Colors.white54,
                  onPressed: controller.toggleQA,
                  label: "الأسئلة",
                ),
                const SizedBox(width: 15),
                _HeaderToolButton(
                  icon: Icons.poll_rounded,
                  color: (isPollsOpen ?? controller.isPollsOpen)
                      ? Colors.green
                      : Colors.white54,
                  onPressed: controller.togglePolls,
                  label: "الاستطلاع",
                ),
              ],
            ),
          const Spacer(),
          Row(
            children: [
              if (widget.isTeacher) ...[
                IconButton(
                  onPressed: () {},
                  icon: const Icon(
                    Icons.person_pin_rounded,
                    color: Colors.white54,
                  ),
                  tooltip: "الملف الشخصي",
                ),
                IconButton(
                  onPressed: _showSettingsDialog,
                  icon: const Icon(Icons.settings, color: Colors.white54),
                  tooltip: "الإعدادات",
                ),
              ],
              IconButton(
                onPressed: () => _showExitConfirmation(context, controller),
                icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                tooltip: "خروج",
              ),
            ],
          ),
        ],
      ),
    );
  }

  // _buildChannelSidebar replaced by _SourceManagerSidebar widget below

  Widget _buildTeacherLayout() {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1014),
      body: ShowCaseWidget(
        builder: (context) => Stack(
          children: [
            const Positioned.fill(child: ParticipantGrid()),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _buildTopHeader(
                context,
                context.read<VideoRoomController>(),
              ),
            ),
            Positioned.fill(
              child: Selector<VideoRoomController, bool>(
                selector: (_, c) => c.isWhiteboardOpen,
                builder: (_, isOpen, __) => isOpen
                    ? const Material(
                        color: Colors.white,
                        child: WhiteboardPanel(),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
            ..._reactions,
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: ControlsBar(),
              ),
            ),
            if (Responsive.isDesktop(context))
              Selector<
                VideoRoomController,
                ({
                  bool isChatOpen,
                  bool isQAOpen,
                  bool isParticipantsOpen,
                  bool isPollsOpen,
                })
              >(
                selector: (_, c) => (
                  isChatOpen: c.isChatOpen,
                  isQAOpen: c.isQAOpen,
                  isParticipantsOpen: c.isParticipantsOpen,
                  isPollsOpen: c.isPollsOpen,
                ),
                builder: (context, data, _) {
                  final isOpen =
                      data.isChatOpen ||
                      data.isQAOpen ||
                      data.isParticipantsOpen ||
                      data.isPollsOpen;
                  return Align(
                    alignment: Alignment.centerRight,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: isOpen ? 420 : 0,
                      padding: isOpen
                          ? const EdgeInsets.all(16)
                          : EdgeInsets.zero,
                      child: isOpen
                          ? Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 20,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(24),
                                child: _buildTeacherSidebar(data),
                              ),
                            )
                          : const SizedBox(),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeacherSidebar(dynamic data) {
    final c = context.read<VideoRoomController>();
    if (c.isChatOpen) return const ChatPanel();
    if (c.isQAOpen) return const QAPanel();
    if (c.isParticipantsOpen) return const ParticipantsPanel();
    if (c.isPollsOpen) return const PollPanel();
    return const SizedBox();
  }

  Widget _buildErrorState(VideoRoomController controller, bool isDesktop) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1014),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.wifi_off_rounded,
                  color: Colors.redAccent,
                  size: 60,
                ),
              ),
              const SizedBox(height: 30),
              Text(
                controller.errorMessage ?? "حدث خطأ غير متوقع",
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 40),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 280),
                child: SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF102A43),
                      foregroundColor: Colors.white,
                      elevation: 8,
                      shadowColor: const Color(0xFF102A43).withOpacity(0.4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    onPressed: () => controller.init(),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.refresh_rounded, size: 20),
                        SizedBox(width: 12),
                        Text(
                          "إعادة المحاولة",
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Scaffold(
      backgroundColor: Color(0xFF0F1014),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.blue),
            const SizedBox(height: 24),
            const Text(
              "جاري دخول القاعة التعليمية...",
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontFamily: 'Cairo',
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showExitConfirmation(
    BuildContext context,
    VideoRoomController controller,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          "مغادرة القاعة",
          style: TextStyle(fontFamily: 'Cairo'),
        ),
        content: Text(
          widget.isTeacher
              ? "هل تريد إنهاء الحصة للجميع أم المغادرة فقط؟"
              : "هل أنت متأكد من مغادرة الحصة الدراسية؟",
          style: const TextStyle(fontFamily: 'Cairo'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("إلغاء", style: TextStyle(fontFamily: 'Cairo')),
          ),
          if (widget.isTeacher)
            TextButton(
              onPressed: () {
                controller.endSessionForAll();
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text(
                "إنهاء للجميع",
                style: TextStyle(
                  color: Colors.red,
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF102A43),
            ),
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text(
              "مغادرة الآن",
              style: TextStyle(color: Colors.white, fontFamily: 'Cairo'),
            ),
          ),
        ],
      ),
    );
  }
}

/// ─── Source Manager Sidebar (Deprecated) ───

/// Individual source card in the sidebar with live preview
class _SourceCard extends StatelessWidget {
  final String channelId;
  final String label;
  final IconData icon;
  final bool isActive;
  final bool isPinned;
  final bool isOnline;
  final bool isWhiteboard;
  final Participant? participant;
  final VoidCallback onToggle;
  final VoidCallback onPin;

  const _SourceCard({
    required this.channelId,
    required this.label,
    required this.icon,
    required this.isActive,
    required this.isPinned,
    required this.isOnline,
    required this.isWhiteboard,
    required this.participant,
    required this.onToggle,
    required this.onPin,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = isPinned
        ? Colors.amber
        : (isActive ? Colors.blue : Colors.white.withOpacity(0.06));
    final bgColor = isPinned
        ? Colors.amber.withOpacity(0.06)
        : (isActive
              ? Colors.blue.withOpacity(0.06)
              : Colors.white.withOpacity(0.02));

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: isPinned ? 1.5 : 1),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: (isPinned ? Colors.amber : Colors.blue).withOpacity(
                    0.08,
                  ),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Column(
        children: [
          // Preview area
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
            child: SizedBox(
              height: 90,
              width: double.infinity,
              child: _buildPreview(),
            ),
          ),
          // Controls bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isActive ? Colors.blue : Colors.white30,
                  size: 14,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: isActive ? Colors.white : Colors.white38,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Cairo',
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Eye toggle (add/remove from stage)
                _MiniIconButton(
                  icon: isActive
                      ? Icons.visibility_rounded
                      : Icons.visibility_off_rounded,
                  color: isActive ? Colors.blue : Colors.white24,
                  onTap: onToggle,
                  tooltip: isActive ? 'إزالة من المسرح' : 'إضافة للمسرح',
                ),
                const SizedBox(width: 2),
                // Pin toggle
                _MiniIconButton(
                  icon: Icons.push_pin_rounded,
                  color: isPinned ? Colors.amber : Colors.white24,
                  onTap: onPin,
                  tooltip: isPinned ? 'إلغاء التثبيت' : 'تثبيت كمصدر رئيسي',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    // Whiteboard preview — static icon
    if (isWhiteboard) {
      return Container(
        color: Colors.white.withOpacity(0.95),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.edit_note_rounded,
                color: isActive ? Colors.blue : Colors.grey.shade400,
                size: 28,
              ),
              const SizedBox(height: 4),
              Text(
                'السبورة التفاعلية',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 9,
                  fontFamily: 'Cairo',
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Offline placeholder
    if (!isOnline || participant == null) {
      return Container(
        color: const Color(0xFF1A1B1F),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.videocam_off_rounded,
                color: Colors.white.withOpacity(0.1),
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                'غير متصل',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.15),
                  fontSize: 9,
                  fontFamily: 'Cairo',
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Live preview using ParticipantTile at LOW quality
    return ParticipantTile(
      key: ValueKey('sidebar_preview_${participant!.identity}'),
      participant: participant!,
      isMainStage: false,
      forceShowScreen: false,
    );
  }
}

/// Tiny icon button used in source card controls
class _MiniIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String tooltip;

  const _MiniIconButton({
    required this.icon,
    required this.color,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, color: color, size: 14),
        ),
      ),
    );
  }
}

/// Bottom student strip — rebuilds only when seat layout or room roster changes.
class _StudentBottomBar extends StatelessWidget {
  final VideoRoomController controller;

  const _StudentBottomBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Selector<VideoRoomController, String>(
      selector: (_, c) => c.seatsLayoutKey,
      builder: (context, _, __) {
        return ListenableBuilder(
          listenable: controller.room ?? controller,
          builder: (context, _) {
            final participants = ClassroomParticipantUtils.allFromRoom(
              controller.room,
            );
            final localIdentity = controller.room?.localParticipant?.identity;

            final rawStudents = participants
                .where(
                  (p) => ClassroomParticipantUtils.isStudentParticipant(
                    p,
                    localIdentity: localIdentity,
                  ),
                )
                .toList();

            final orderedStudents = <Participant>[];
            for (final seat in controller.seats) {
              final sId = seat['student_id'];
              if (sId == null) continue;
              final match = rawStudents
                  .where((p) => p.identity.startsWith(sId as String))
                  .firstOrNull;
              if (match != null && !orderedStudents.contains(match)) {
                orderedStudents.add(match);
              }
            }
            for (final p in rawStudents) {
              if (!orderedStudents.contains(p)) orderedStudents.add(p);
            }

            final localPart = controller.room?.localParticipant;

            return Container(
              height: 140,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: const BoxDecoration(
                color: Color(0xFF0F1014),
                border: Border(
                  top: BorderSide(color: Colors.white10, width: 0.5),
                ),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 20),
                  const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.people_outline_rounded,
                        color: Colors.white38,
                        size: 20,
                      ),
                      Text(
                        'Students',
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: orderedStudents.length,
                      itemBuilder: (context, index) {
                        final p = orderedStudents[index];
                        final seat = controller.seats.firstWhere(
                          (s) =>
                              s['student_id'] != null &&
                              p.identity.startsWith(s['student_id'] as String),
                          orElse: () => <String, dynamic>{},
                        );

                        return Container(
                          width: 180,
                          margin: const EdgeInsets.only(right: 12),
                          child: ParticipantTile(
                            participant: p,
                            isMainStage: false,
                            displayName: seat['student_name'] as String?,
                          ),
                        );
                      },
                    ),
                  ),
                  if (localPart != null)
                    Container(
                      width: 200,
                      padding: const EdgeInsets.only(left: 20, right: 20),
                      decoration: const BoxDecoration(
                        border: Border(left: BorderSide(color: Colors.white10)),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'My Cam',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Cairo',
                            ),
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: ParticipantTile(
                              participant: localPart,
                              isMainStage: false,
                              displayName: controller.userName,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _WaitingForTeacher extends StatelessWidget {
  const _WaitingForTeacher();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.blue, strokeWidth: 2),
          SizedBox(height: 16),
          Text(
            'في انتظار المدرس...',
            style: TextStyle(
              color: Colors.white54,
              fontFamily: 'Cairo',
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderToolButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;
  final String? label;
  const _HeaderToolButton({
    required this.icon,
    required this.color,
    required this.onPressed,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: onPressed,
          icon: Icon(icon, color: color),
          style: IconButton.styleFrom(
            backgroundColor: color.withOpacity(0.05),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(8),
            minimumSize: const Size(45, 45),
          ),
        ),
        if (label != null)
          Text(
            label!,
            style: TextStyle(color: color, fontSize: 8, fontFamily: 'Cairo'),
          ),
      ],
    );
  }
}

class _FlyingEmoji extends StatefulWidget {
  final Key key;
  final String emoji;
  final int delay;
  final VoidCallback onComplete;
  const _FlyingEmoji({
    required this.key,
    required this.emoji,
    required this.delay,
    required this.onComplete,
  }) : super(key: key);
  @override
  State<_FlyingEmoji> createState() => _FlyingEmojiState();
}

class _FlyingEmojiState extends State<_FlyingEmoji>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _yAnim;
  late Animation<double> _opacityAnim;
  late double _startX;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );
    _yAnim = Tween<double>(
      begin: 0,
      end: -400,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
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
    _startX =
        MediaQuery.of(context).size.width / 2 +
        (DateTime.now().millisecond % 100 - 50);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Positioned(
          left: _startX,
          bottom: 100 + _yAnim.value.abs(),
          child: Opacity(
            opacity: _opacityAnim.value,
            child: Text(widget.emoji, style: const TextStyle(fontSize: 40)),
          ),
        );
      },
    );
  }
}
