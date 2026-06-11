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
            content: Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Cairo')),
            backgroundColor: color,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 100),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15)),
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
              onComplete: () {
                if (mounted) setState(() => _reactions.removeAt(0));
              },
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
          ElevatedButton(onPressed: onConfirm, child: const Text("حسناً", style: TextStyle(fontFamily: 'Cairo'))),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("إعدادات وتحكم القاعة", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.isTeacher) ...[
                  const Text("صلاحيات الطلاب (قفل جماعي)", style: TextStyle(fontFamily: 'Cairo', fontSize: 13, color: Colors.blue, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  _buildToggle(
                    "قفل الميكروفونات", 
                    controller.isAllMuted, 
                    (val) {
                      controller.muteAllParticipants(val);
                      setDialogState(() {});
                    },
                    icon: Icons.mic_off,
                  ),
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
                  const Divider(),
                ],
                ListTile(
                  leading: const Icon(Icons.refresh, color: Colors.blue),
                  title: const Text("إعادة اتصال البث", style: TextStyle(fontFamily: 'Cairo', fontSize: 14)),
                  onTap: () {
                    controller.connectToRoom(widget.roomName);
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.info_outline, color: Colors.blue),
                  title: const Text("معلومات الغرفة", style: TextStyle(fontFamily: 'Cairo', fontSize: 14)),
                  subtitle: Text(widget.roomName, style: const TextStyle(fontSize: 12)),
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToggle(String title, bool value, Function(bool) onChanged, {IconData? icon}) {
    return SwitchListTile(
      secondary: icon != null ? Icon(icon, size: 20, color: value ? Colors.red : Colors.grey) : null,
      title: Text(title, style: const TextStyle(fontFamily: 'Cairo', fontSize: 13)),
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

    final errorMessage = context.select<VideoRoomController, String?>((c) => c.errorMessage);
    if (errorMessage != null) return _buildErrorState(controller, isDesktop);

    final isLoading = context.select<VideoRoomController, bool>((c) => c.isLoading);
    if (isLoading) return _buildLoadingState();

    return Scaffold(
      backgroundColor: const Color(0xFF0F1014),
      body: Stack(
        children: [
          Row(
            children: [
              // 1. Sidebar: Channels & Whiteboard
              Selector<VideoRoomController, (String, bool)>(
                selector: (_, c) => (c.selectedChannel, c.isWhiteboardOpen),
                builder: (context, data, child) => _buildChannelSidebar(controller),
              ),

              Expanded(
                child: Column(
                  children: [
                    // 2. Top Header: Tools & Menu
                    Selector<VideoRoomController, ({
                      bool isHandRaised,
                      bool isMicEnabled,
                      bool isCamEnabled,
                      int participantCount,
                      String title,
                      bool isChatOpen,
                      bool isQAOpen,
                      bool isScreenSharing,
                      bool isScreenShareLocked,
                    })>(
                      selector: (_, c) => (
                        isHandRaised: c.isHandRaised,
                        isMicEnabled: c.isMicEnabled,
                        isCamEnabled: c.isCamEnabled,
                        participantCount: (c.room?.remoteParticipants.length ?? 0) + 1,
                        title: c.title,
                        isChatOpen: c.isChatOpen,
                        isQAOpen: c.isQAOpen,
                        isScreenSharing: c.isScreenSharing,
                        isScreenShareLocked: c.isScreenShareLocked,
                      ),
                      builder: (context, data, _) => _buildTopHeader(context, controller),
                    ),

                    Expanded(
                      child: Row(
                        children: [
                          // 3. Center Stage (Main Video or Whiteboard)
                          Expanded(
                            child: Stack(
                              children: [
                                // Always render main stage
                                Positioned.fill(
                                  child: Selector<VideoRoomController, (String, bool)>(
                                    selector: (_, c) => (c.selectedChannel, c.isPiPExpanded),
                                    builder: (context, _, __) => _buildMainStage(controller),
                                  ),
                                ),
                                // Whiteboard overlay correctly wrapped in Positioned.fill
                                Positioned.fill(
                                  child: Selector<VideoRoomController, bool>(
                                    selector: (_, c) => c.isWhiteboardOpen,
                                    builder: (_, isOpen, __) => isOpen
                                        ? const WhiteboardPanel()
                                        : const SizedBox(),
                                  ),
                                ),
                                ..._reactions,
                              ],
                            ),
                          ),

                          // 4. Right Sidebar: Chat / Q&A (Desktop Only)
                          Selector<VideoRoomController, ({
                            bool isChatOpen,
                            bool isQAOpen,
                          })>(
                            selector: (_, c) => (
                              isChatOpen: c.isChatOpen,
                              isQAOpen: c.isQAOpen,
                            ),
                            builder: (context, data, _) {
                              final isOpen = (data.isChatOpen || data.isQAOpen) && isDesktop;
                              if (!isOpen) return const SizedBox();
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                width: 350,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF16171B),
                                  border: Border(
                                      left: BorderSide(color: Colors.white10, width: 0.5)
                                  ),
                                ),
                                child: data.isChatOpen
                                    ? const ChatPanel()
                                    : const QAPanel(),
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    // 5. Bottom: Students Cams
                    ListenableBuilder(
                      listenable: controller.room ?? ChangeNotifier(),
                      builder: (context, _) => _buildBottomParticipantBar(controller),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!isDesktop) ...[
            Selector<VideoRoomController, bool>(
              selector: (_, c) => c.isChatOpen,
              builder: (_, isOpen, __) => isOpen
                  ? _buildMobilePanel(const ChatPanel())
                  : const SizedBox(),
            ),
            Selector<VideoRoomController, bool>(
              selector: (_, c) => c.isQAOpen,
              builder: (_, isOpen, __) => isOpen
                  ? _buildMobilePanel(const QAPanel())
                  : const SizedBox(),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildMobilePanel(Widget child) {
    final size = MediaQuery.of(context).size;
    return Positioned(
      bottom: 0, left: 0, right: 0,
      child: Container(
        height: size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(
              top: Radius.circular(20)),
          boxShadow: [BoxShadow(
              color: Colors.black54, blurRadius: 20)],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(
              top: Radius.circular(20)),
          child: child,
        ),
      ),
    );
  }

  Widget _buildTeacherLayout() {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1014),
      body: ShowCaseWidget(
        builder: (context) => Stack(
          children: [
            const Positioned.fill(
                child: ParticipantGrid()
            ),
            Positioned(
              top: 0, left: 0, right: 0,
              child: _buildTopHeader(
                  context,
                  context.read<VideoRoomController>()
              ),
            ),
            Positioned.fill(
              child: Selector<VideoRoomController, bool>(
                selector: (_, c) => c.isWhiteboardOpen,
                builder: (_, isOpen, __) => isOpen
                    ? const WhiteboardPanel()
                    : const SizedBox(),
              ),
            ),
            ..._reactions,
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(
                    bottom: 20),
                child: ControlsBar(),
              ),
            ),
            if (Responsive.isDesktop(context))
              Selector<VideoRoomController, ({
              bool isChatOpen,
              bool isQAOpen,
              bool isParticipantsOpen,
              bool isPollsOpen,
              })>(
                selector: (_, c) => (
                isChatOpen: c.isChatOpen,
                isQAOpen: c.isQAOpen,
                isParticipantsOpen: c.isParticipantsOpen,
                isPollsOpen: c.isPollsOpen,
                ),
                builder: (context, data, _) {
                  final isOpen = data.isChatOpen ||
                      data.isQAOpen ||
                      data.isParticipantsOpen ||
                      data.isPollsOpen;
                  return Align(
                    alignment: Alignment.centerRight,
                    child: AnimatedContainer(
                      duration: const Duration(
                          milliseconds: 300),
                      width: isOpen ? 380 : 0,
                      child: isOpen
                          ? _buildTeacherSidebar(data)
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
    Widget content = const SizedBox();
    final c = context.read<VideoRoomController>();
    if (c.isChatOpen) content = const ChatPanel();
    else if (c.isQAOpen) content = const QAPanel();
    else if (c.isParticipantsOpen)
      content = const ParticipantsPanel();
    else if (c.isPollsOpen) content = const PollPanel();
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
            left: BorderSide(
                color: Colors.white10, width: 0.5)),
      ),
      child: ClipRRect(child: content),
    );
  }

  Widget _buildChannelSidebar(VideoRoomController controller) {
    final channels = [
      {'id': 'room-cam-right', 'label': 'Cam 1', 'desc': 'كاميرا اليمين'},
      {'id': 'room-cam-left', 'label': 'Cam 2', 'desc': 'كاميرا الشمال'},
      {'id': 'whiteboard', 'label': 'Whiteboard', 'desc': 'السبورة'},
      {'id': 'room-cam-screen', 'label': 'Screen', 'desc': 'الشاشة الرئيسية'},
    ];

    return Container(
      width: 120,
      color: const Color(0xFF16171B),
      child: Column(
        children: [
          const SizedBox(height: 20),
          const Text("Channels", style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.builder(
              itemCount: channels.length,
              itemBuilder: (context, index) {
                final ch = channels[index];
                final bool isWhiteboard = ch['id'] == 'whiteboard';
                final isSelected = isWhiteboard 
                    ? controller.isWhiteboardOpen 
                    : (controller.selectedChannel == ch['id'] && !controller.isWhiteboardOpen);

                return InkWell(
                  onTap: () {
                    if (isWhiteboard) {
                      controller.toggleWhiteboard();
                    } else {
                      controller.selectChannel(ch['id']!);
                      if (controller.isWhiteboardOpen) controller.toggleWhiteboard();
                    }
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.blue.withOpacity(0.1) : Colors.transparent,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: isSelected ? Colors.blue : Colors.white10),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          isWhiteboard ? Icons.edit_note_rounded : Icons.video_camera_back_rounded, 
                          color: isSelected ? Colors.blue : Colors.white54, 
                          size: 24
                        ),
                        const SizedBox(height: 8),
                        Text(ch['label']!, textAlign: TextAlign.center, style: TextStyle(color: isSelected ? Colors.blue : Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopHeader(BuildContext context, VideoRoomController controller) {
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
              Text(controller.title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
              Text("Live Session", style: TextStyle(color: Colors.white38, fontSize: 11, fontFamily: 'Cairo')),
            ],
          ),
          const Spacer(),
          // Tools Section
          Row(
            children: [
              _HeaderToolButton(
                icon: controller.isHandRaised ? Icons.front_hand : Icons.front_hand_outlined,
                color: controller.isHandRaised ? Colors.amber : Colors.white54,
                onPressed: controller.toggleHand,
                label: "رفع اليد",
              ),
              const SizedBox(width: 15),
              _HeaderToolButton(
                icon: controller.isMicEnabled ? Icons.mic : Icons.mic_off,
                color: controller.isMicEnabled ? Colors.blue : Colors.redAccent,
                onPressed: controller.toggleMic,
              ),
              const SizedBox(width: 15),
              _HeaderToolButton(
                icon: controller.isCamEnabled ? Icons.videocam : Icons.videocam_off,
                color: controller.isCamEnabled ? Colors.blue : Colors.redAccent,
                onPressed: controller.toggleCam,
              ),
              const SizedBox(width: 15),
              _HeaderToolButton(
                icon: Icons.chat_bubble_rounded,
                color: controller.isChatOpen ? Colors.blue : Colors.white54,
                onPressed: controller.toggleChat,
                label: "الشات",
              ),
              const SizedBox(width: 15),
              _HeaderToolButton(
                icon: Icons.help_outline_rounded,
                color: controller.isQAOpen ? Colors.orange : Colors.white54,
                onPressed: controller.toggleQA,
                label: "الأسئلة",
              ),
              // Fixed: Always show Screen Share for student, but style it based on lock state
              const SizedBox(width: 15),
              _HeaderToolButton(
                icon: controller.isScreenSharing ? Icons.stop_screen_share_rounded : Icons.screen_share_rounded,
                color: controller.isScreenSharing 
                    ? Colors.greenAccent 
                    : (controller.isScreenShareLocked && !widget.isTeacher ? Colors.white24 : Colors.white54),
                onPressed: controller.isScreenShareLocked && !widget.isTeacher 
                    ? () => controller.onNotification?.call("مشاركة الشاشة مقفلة من قبل المعلم 🔒", Colors.orange)
                    : controller.toggleScreenShare,
                label: "مشاركة الشاشة",
              ),
              const SizedBox(width: 25),
              // User Count
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(20)),
                child: Row(
                  children: [
                    const Icon(Icons.people_alt_rounded, color: Colors.blue, size: 16),
                    const SizedBox(width: 8),
                    Text("${(controller.room?.remoteParticipants.length ?? 0) + 1}", style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          const Spacer(),
          // Menu Section
          IconButton(onPressed: _showSettingsDialog, icon: const Icon(Icons.settings, color: Colors.white54)),
          IconButton(
            onPressed: () => _showExitConfirmation(context, controller),
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
          ),
        ],
      ),
    );
  }

  Widget _buildMainStage(VideoRoomController controller) {
    final allParticipants = <Participant>[
      if (controller.room?.localParticipant != null) controller.room!.localParticipant!,
      ...controller.room?.remoteParticipants.values ?? [],
    ];

    // Always show teacher in main stage
    Participant? teacher;
    try {
      teacher = allParticipants.firstWhere(
            (p) => p.identity.toLowerCase().contains('teacher'),
      );
    } catch (_) {
      teacher = allParticipants.isNotEmpty ? allParticipants.first : null;
    }

    // Get selected channel camera (for PiP)
    final channelCam = controller.selectedChannel != 'whiteboard'
        ? allParticipants.where((p) => p.identity.contains(controller.selectedChannel)).firstOrNull
        : null;

    if (allParticipants.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.blue, strokeWidth: 2),
      );
    }

    return Stack(
      children: [
        // Main stage — always teacher
        Positioned.fill(
          child: teacher != null
              ? ParticipantTile(
            key: ValueKey("main_teacher_${teacher.identity}"),
            participant: teacher,
            isMainStage: true,
          )
              : const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: Colors.blue, strokeWidth: 2),
                const SizedBox(height: 16),
                Text("في انتظار المدرس...", style: TextStyle(color: Colors.white54, fontFamily: 'Cairo', fontSize: 16)),
              ],
            ),
          ),
        ),

        // PiP — selected channel camera (bottom right)
        if (channelCam != null)
          Positioned(
            bottom: 16,
            right: 16,
            child: GestureDetector(
              onTap: () => controller.togglePiP(),
              child: Selector<VideoRoomController, bool>(
                selector: (_, c) => c.isPiPExpanded,
                builder: (context, isExpanded, _) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: isExpanded ? 320 : 180,
                    height: isExpanded ? 180 : 100,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue, width: 2),
                      boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 10)],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Stack(
                        children: [
                          ParticipantTile(
                            key: ValueKey("pip_${channelCam.identity}"),
                            participant: channelCam,
                            isMainStage: false,
                          ),
                          // Channel label
                          Positioned(
                            top: 6, left: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                              child: Text(
                                controller.getCameraLabel(controller.selectedChannel),
                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                              ),
                            ),
                          ),
                          // Expand/Collapse icon
                          Positioned(
                            top: 6, right: 6,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                              child: Icon(isExpanded ? Icons.close_fullscreen : Icons.open_in_full, color: Colors.white, size: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildRightSidebar(VideoRoomController controller) {
    return Container(
      width: 350,
      decoration: const BoxDecoration(
        color: Color(0xFF16171B),
        border: Border(left: BorderSide(color: Colors.white10, width: 0.5)),
      ),
      child: const ChatPanel(),
    );
  }

  Widget _buildBottomParticipantBar(VideoRoomController controller) {
    final allParticipants = <Participant>[
      if (controller.room?.localParticipant != null) controller.room!.localParticipant!,
      ...controller.room?.remoteParticipants.values ?? [],
    ];

    // Filter out the classroom cameras to only show students
    final students = allParticipants.where((p) => !p.identity.contains('room-cam-') && !p.identity.contains('teacher_')).toList();
    final localPart = controller.room?.localParticipant;

    return Container(
      height: 140,
      padding: const EdgeInsets.symmetric(vertical: 10),
      color: const Color(0xFF0F1014),
      child: Row(
        children: [
          const SizedBox(width: 20),
          const Text("Students", style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
          const SizedBox(width: 20),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: students.length,
              itemBuilder: (context, index) {
                return Container(
                  width: 180,
                  margin: const EdgeInsets.only(right: 12),
                  child: ParticipantTile(participant: students[index], isMainStage: false),
                );
              },
            ),
          ),
          // "My Cam" fixed at the end
          if (localPart != null)
            Container(
              width: 200,
              padding: const EdgeInsets.only(left: 20, right: 20),
              decoration: const BoxDecoration(
                border: Border(left: BorderSide(color: Colors.white10)),
              ),
              child: Column(
                children: [
                  const Text("My Cam", style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Expanded(child: ParticipantTile(participant: localPart, isMainStage: false)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildErrorState(VideoRoomController controller, bool isDesktop) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1014),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 80),
            const SizedBox(height: 24),
            Text(controller.errorMessage!, style: const TextStyle(color: Colors.white, fontSize: 18, fontFamily: 'Cairo')),
            const SizedBox(height: 32),
            ElevatedButton(onPressed: () => controller.init(), child: const Text("إعادة المحاولة", style: TextStyle(fontFamily: 'Cairo'))),
          ],
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
            const Text("جاري دخول القاعة التعليمية...", style: TextStyle(color: Colors.white, fontSize: 16, fontFamily: 'Cairo')),
          ],
        ),
      ),
    );
  }

  void _showExitConfirmation(BuildContext context, VideoRoomController controller) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("مغادرة القاعة", style: TextStyle(fontFamily: 'Cairo')),
        content: Text(
          widget.isTeacher
              ? "هل تريد إنهاء الحصة للجميع أم المغادرة فقط؟"
              : "هل أنت متأكد من مغادرة الحصة الدراسية؟",
          style: const TextStyle(fontFamily: 'Cairo'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("إلغاء",
                style: TextStyle(fontFamily: 'Cairo')),
          ),
          if (widget.isTeacher)
            TextButton(
              onPressed: () {
                controller.endSessionForAll();
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text("إنهاء للجميع",
                  style: TextStyle(
                      color: Colors.red,
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.bold)),
            ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF102A43)),
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text("مغادرة الآن",
                style: TextStyle(
                    color: Colors.white, fontFamily: 'Cairo')),
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
  const _HeaderToolButton({required this.icon, required this.color, required this.onPressed, this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: onPressed,
          icon: Icon(icon, color: color),
          style: IconButton.styleFrom(backgroundColor: color.withOpacity(0.05), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        ),
        if (label != null) Text(label!, style: TextStyle(color: color, fontSize: 8, fontFamily: 'Cairo')),
      ],
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
          child: Opacity(opacity: _opacityAnim.value, child: Text(widget.emoji, style: const TextStyle(fontSize: 40))),
        );
      },
    );
  }
}
