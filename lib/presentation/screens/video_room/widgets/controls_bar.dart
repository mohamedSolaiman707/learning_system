import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:showcaseview/showcaseview.dart';
import '../video_room_controller.dart';

class ControlsBar extends StatelessWidget {
  final GlobalKey? micKey;
  final GlobalKey? camKey;
  final GlobalKey? chatKey;
  final GlobalKey? handKey;
  final GlobalKey? emojiKey;
  final GlobalKey? screenShareKey;
  final GlobalKey? qaKey;
  final GlobalKey? whiteboardKey;
  final GlobalKey? recordKey;

  const ControlsBar({
    super.key,
    this.micKey,
    this.camKey,
    this.chatKey,
    this.handKey,
    this.emojiKey,
    this.screenShareKey,
    this.qaKey,
    this.whiteboardKey,
    this.recordKey,
  });

  @override
  Widget build(BuildContext context) {
    final data = context.select<VideoRoomController, ({
      bool isMicEnabled,
      bool isCamEnabled,
      bool isRecording,
      bool isRecordingPaused,
      bool isRecordingLoading,
      bool isHandRaised,
      bool isScreenSharing,
      bool isScreenShareLocked,
      bool isChatOpen,
      bool isQAOpen,
      bool isWhiteboardOpen,
      bool isParticipantsOpen,
      bool isVideoWallMode,
      bool isTeacher,
      int unreadMessages,
      int unreadQuestionsCount,
    })>((c) => (
      isMicEnabled: c.isMicEnabled,
      isCamEnabled: c.isCamEnabled,
      isRecording: c.isRecording,
      isRecordingPaused: c.isRecordingPaused,
      isRecordingLoading: c.isRecordingLoading,
      isHandRaised: c.isHandRaised,
      isScreenSharing: c.isScreenSharing,
      isScreenShareLocked: c.isScreenShareLocked,
      isChatOpen: c.isChatOpen,
      isQAOpen: c.isQAOpen,
      isWhiteboardOpen: c.isWhiteboardOpen,
      isParticipantsOpen: c.isParticipantsOpen,
      isVideoWallMode: c.isVideoWallMode,
      isTeacher: c.isTeacher,
      unreadMessages: c.unreadMessages,
      unreadQuestionsCount: c.unreadQuestionsCount,
    ));

    final controller = context.read<VideoRoomController>();
    final bool isMobile = MediaQuery.of(context).size.width < 600;

    return Container(
      margin: EdgeInsets.only(bottom: isMobile ? 20 : 30, left: 20, right: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.12),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 30,
                      spreadRadius: -5,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  bottom: false,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // مجموعة التحكم في الوسائط (Media Group)
                        _buildGroupWrapper([
                          _buildShowcase(
                            key: micKey,
                            title: 'الميكروفون',
                            description:
                                'اضغط لكتم أو تفعيل صوتك أثناء المحاضرة.',
                            child: _PremiumControlButton(
                              icon: data.isMicEnabled
                                  ? Icons.mic_rounded
                                  : Icons.mic_off_rounded,
                              isActive: data.isMicEnabled,
                              activeColor: Colors.blueAccent,
                              onPressed: controller.toggleMic,
                              tooltip: "الميكروفون",
                            ),
                          ),
                          _buildShowcase(
                            key: camKey,
                            title: 'الكاميرا',
                            description:
                                'يمكنك فتح الكاميرا لمشاركة صورتك مع المعلم وزملائك.',
                            child: _PremiumControlButton(
                              icon: data.isCamEnabled
                                  ? Icons.videocam_rounded
                                  : Icons.videocam_off_rounded,
                              isActive: data.isCamEnabled,
                              activeColor: Colors.blueAccent,
                              onPressed: controller.toggleCam,
                              tooltip: "الكاميرا",
                            ),
                          ),
                          if (data.isTeacher)
                            _buildShowcase(
                              key: recordKey,
                              title: 'تسجيل المحاضرة',
                              description:
                                  'ابدأ تسجيل الحصة ليتمكن الطلاب من مشاهدتها لاحقاً عبر السحابة.',
                              child: _PremiumControlButton(
                                icon: data.isRecording
                                    ? Icons.stop_circle_rounded
                                    : Icons.fiber_manual_record_rounded,
                                isActive: data.isRecording,
                                isLoading: data.isRecordingLoading,
                                activeColor: Colors.redAccent,
                                onPressed: controller.toggleRecording,
                                tooltip: data.isRecording
                                    ? "إيقاف التسجيل"
                                    : "بدء التسجيل",
                                pulse:
                                    data.isRecording &&
                                    !data.isRecordingPaused,
                              ),
                            ),
                        ]),

                        _buildDivider(),

                        // مجموعة التفاعل (Interaction Group)
                        _buildGroupWrapper([
                          _buildShowcase(
                            key: emojiKey,
                            title: 'التفاعلات',
                            description:
                                'عبر عن مشاعرك وتفاعل مع الشرح باستخدام الإيموجي.',
                            child: _ReactionButton(controller: controller),
                          ),
                          _buildShowcase(
                            key: handKey,
                            title: 'رفع اليد',
                            description:
                                'استخدمها لتنبيه المعلم أن لديك سؤالاً أو استفساراً.',
                            child: _PremiumControlButton(
                              icon: Icons.front_hand_rounded,
                              isActive: data.isHandRaised,
                              activeColor: Colors.amber,
                              onPressed: controller.toggleHand,
                              tooltip: "رفع اليد",
                            ),
                          ),
                          if (data.isTeacher ||
                              !data.isScreenShareLocked)
                            _buildShowcase(
                              key: screenShareKey,
                              title: 'مشاركة الشاشة',
                              description:
                                  'تسمح لك هذه الميزة بعرض شاشة جهازك للجميع.',
                              child: _PremiumControlButton(
                                icon: data.isScreenSharing
                                    ? Icons.stop_screen_share_rounded
                                    : Icons.screen_share_rounded,
                                isActive: data.isScreenSharing,
                                activeColor: Colors.greenAccent,
                                onPressed: controller.toggleScreenShare,
                                tooltip: "مشاركة الشاشة",
                              ),
                            ),
                        ]),

                        _buildDivider(),

                        // مجموعة الأدوات (Tools Group)
                        _buildGroupWrapper([
                          _buildShowcase(
                            key: chatKey,
                            title: 'الدردشة العامة',
                            description:
                                'تواصل نصياً مع جميع الحاضرين في القاعة.',
                            child: _PremiumControlButton(
                              icon: Icons.chat_bubble_rounded,
                              isActive: data.isChatOpen,
                              activeColor: Colors.blue,
                              onPressed: controller.toggleChat,
                              tooltip: "الدردشة",
                              badgeCount: data.unreadMessages,
                            ),
                          ),
                          _buildShowcase(
                            key: qaKey,
                            title: 'الأسئلة والأجوبة',
                            description:
                                'اطرح أسئلة تعليمية محددة ليجيب عليها المعلم.',
                            child: _PremiumControlButton(
                              icon: Icons.help_outline_rounded,
                              isActive: data.isQAOpen,
                              activeColor: Colors.orange,
                              onPressed: controller.toggleQA,
                              tooltip: "الأسئلة",
                              badgeCount: data.unreadQuestionsCount,
                            ),
                          ),
                          _buildShowcase(
                            key: whiteboardKey,
                            title: 'السبورة التفاعلية',
                            description:
                                'افتح السبورة لمتابعة الرسومات والشروحات التوضيحية.',
                            child: _PremiumControlButton(
                              icon: Icons.edit_note_rounded,
                              isActive: data.isWhiteboardOpen,
                              activeColor: Colors.tealAccent,
                              onPressed: controller.toggleWhiteboard,
                              tooltip: "السبورة",
                            ),
                          ),
                          // زر توزيع المقاعد الجديد (Video Wall) للمدرس
                          if (data.isTeacher)
                            _PremiumControlButton(
                              icon: Icons.grid_view_rounded,
                              isActive: data.isVideoWallMode,
                              activeColor: Colors.blueAccent,
                              onPressed: controller.toggleVideoWallMode,
                              tooltip: "توزيع المقاعد",
                            ),
                        ]),

                        if (data.isTeacher) ...[
                          _buildDivider(),
                          _PremiumControlButton(
                            icon: Icons.people_alt_rounded,
                            isActive: data.isParticipantsOpen,
                            activeColor: Colors.purpleAccent,
                            onPressed: controller.toggleParticipants,
                            tooltip: "المشاركين",
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupWrapper(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(children: children),
    );
  }

  Widget _buildShowcase({
    required GlobalKey? key,
    required String title,
    required String description,
    required Widget child,
  }) {
    if (key == null) return child;
    return Showcase(
      key: key,
      title: title,
      description: description,
      titleTextStyle: const TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 18,
        color: Color(0xFF102A43),
        fontFamily: 'Cairo',
      ),
      descTextStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 14),
      tooltipBackgroundColor: Colors.white,
      targetShapeBorder: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: child,
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 24,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withOpacity(0.0),
            Colors.white.withOpacity(0.15),
            Colors.white.withOpacity(0.0),
          ],
        ),
      ),
    );
  }
}

class _PremiumControlButton extends StatefulWidget {
  final IconData icon;
  final bool isActive;
  final bool isLoading;
  final bool pulse;
  final Color activeColor;
  final VoidCallback onPressed;
  final String tooltip;
  final int badgeCount;

  const _PremiumControlButton({
    required this.icon,
    required this.isActive,
    this.isLoading = false,
    this.pulse = false,
    required this.activeColor,
    required this.onPressed,
    required this.tooltip,
    this.badgeCount = 0,
  });

  @override
  State<_PremiumControlButton> createState() => _PremiumControlButtonState();
}

class _PremiumControlButtonState extends State<_PremiumControlButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Tooltip(
        message: widget.tooltip,
        preferBelow: false,
        child: GestureDetector(
          onTapDown: (_) => _controller.forward(),
          onTapUp: (_) => _controller.reverse(),
          onTapCancel: () => _controller.reverse(),
          onTap: () {
            HapticFeedback.lightImpact();
            widget.onPressed();
          },
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                // Glowing background for active state
                if (widget.isActive && !widget.isLoading) _buildGlowEffect(),

                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: widget.isActive
                        ? widget.activeColor.withOpacity(0.15)
                        : Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: widget.isActive
                          ? widget.activeColor.withOpacity(0.5)
                          : Colors.white.withOpacity(0.05),
                      width: 1.5,
                    ),
                  ),
                  child: Opacity(
                    opacity: widget.isLoading ? 0.3 : 1.0,
                    child: Icon(
                      widget.icon,
                      color: widget.isActive
                          ? widget.activeColor
                          : Colors.white.withOpacity(0.8),
                      size: 24,
                    ),
                  ),
                ),

                if (widget.isLoading)
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        widget.activeColor,
                      ),
                    ),
                  ),

                if (widget.badgeCount > 0)
                  Positioned(top: -2, right: -2, child: _buildBadge()),

                if (widget.pulse) _buildPulseEffect(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlowEffect() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: widget.activeColor.withOpacity(0.2),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
      ),
    );
  }

  Widget _buildBadge() {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: const BoxDecoration(
        color: Colors.redAccent,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
      ),
      child: Text(
        widget.badgeCount > 9 ? "9+" : widget.badgeCount.toString(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 8,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildPulseEffect() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.red.withOpacity(0.5), width: 1),
      ),
    );
  }
}

class _ReactionButton extends StatelessWidget {
  final VideoRoomController controller;
  const _ReactionButton({required this.controller});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      offset: const Offset(-80, -75),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      color: const Color(0xFF1E1F24),
      elevation: 6,
      shadowColor: Colors.black.withOpacity(0.3),
      padding: EdgeInsets.zero,
      icon: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: const Icon(
          Icons.add_reaction_rounded,
          color: Colors.white70,
          size: 24,
        ),
      ),
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          enabled: false,
          padding: EdgeInsets.zero,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 5,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: ['👏', '👍', '❤️', '😂', '🎉'].map((emoji) {
                return InkWell(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    controller.sendReaction(emoji);
                    Navigator.pop(context);
                  },
                  borderRadius: BorderRadius.circular(15),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: Text(
                      emoji,
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}
