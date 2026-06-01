import 'dart:ui';
import 'package:flutter/material.dart';
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
  });

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<VideoRoomController>();
    final bool isMobile = MediaQuery.of(context).size.width < 600;

    return Container(
      margin: EdgeInsets.only(bottom: isMobile ? 20 : 30, left: 20, right: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(40),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.4),
              borderRadius: BorderRadius.circular(40),
              border: Border.all(color: Colors.white.withOpacity(0.1), width: 1.5),
            ),
            child: SafeArea(
              top: false,
              bottom: false,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildShowcase(
                      key: micKey,
                      title: 'الميكروفون',
                      description: 'من هنا يمكنك كتم أو تفعيل صوتك أثناء الحصة.',
                      child: _AnimatedControlButton(
                        icon: controller.isMicEnabled ? Icons.mic_rounded : Icons.mic_off_rounded,
                        isActive: controller.isMicEnabled,
                        color: Colors.white,
                        activeColor: Colors.blue,
                        onPressed: controller.toggleMic,
                        tooltip: "الميكروفون",
                      ),
                    ),
                    _buildShowcase(
                      key: camKey,
                      title: 'الكاميرا',
                      description: 'اضغط هنا لفتح الكاميرا ومشاركة صورتك مع زملائك.',
                      child: _AnimatedControlButton(
                        icon: controller.isCamEnabled ? Icons.videocam_rounded : Icons.videocam_off_rounded,
                        isActive: controller.isCamEnabled,
                        color: Colors.white,
                        activeColor: Colors.blue,
                        onPressed: controller.toggleCam,
                        tooltip: "الكاميرا",
                      ),
                    ),
                    
                    const SizedBox(width: 8),
                    _buildShowcase(
                      key: emojiKey,
                      title: 'التفاعلات',
                      description: 'عبر عن مشاعرك باستخدام الإيموجي أثناء الشرح.',
                      child: _ReactionButton(controller: controller),
                    ),
                    const SizedBox(width: 8),

                    if (controller.isTeacher || !controller.isScreenShareLocked)
                      _buildShowcase(
                        key: screenShareKey,
                        title: 'مشاركة الشاشة',
                        description: 'يمكنك عرض شاشة جهازك للمشاركين في القاعة.',
                        child: _AnimatedControlButton(
                          icon: controller.isScreenSharing ? Icons.stop_screen_share_rounded : Icons.screen_share_rounded,
                          isActive: controller.isScreenSharing,
                          activeColor: Colors.green,
                          onPressed: controller.toggleScreenShare,
                          tooltip: "مشاركة الشاشة",
                        ),
                      ),

                    _buildShowcase(
                      key: handKey,
                      title: 'رفع اليد',
                      description: 'استخدم هذه الميزة إذا كان لديك سؤال للمعلم.',
                      child: _AnimatedControlButton(
                        icon: Icons.front_hand_rounded,
                        isActive: controller.isHandRaised,
                        activeColor: Colors.amber,
                        onPressed: controller.toggleHand,
                        tooltip: "رفع اليد",
                      ),
                    ),
                    
                    _buildDivider(),

                    _buildShowcase(
                      key: chatKey,
                      title: 'الدردشة',
                      description: 'تواصل مع المعلم وزملائك نصياً من هنا.',
                      child: _AnimatedControlButton(
                        icon: Icons.chat_bubble_rounded,
                        isActive: controller.isChatOpen,
                        activeColor: Colors.blue,
                        onPressed: controller.toggleChat,
                        tooltip: "الدردشة",
                      ),
                    ),
                    _buildShowcase(
                      key: qaKey,
                      title: 'الأسئلة والأجوبة',
                      description: 'اطرح أسئلتك التعليمية ليجيب عليها المعلم.',
                      child: _AnimatedControlButton(
                        icon: Icons.help_outline_rounded,
                        isActive: controller.isQAOpen,
                        activeColor: Colors.orange,
                        onPressed: controller.toggleQA,
                        tooltip: "الأسئلة",
                      ),
                    ),
                    _buildShowcase(
                      key: whiteboardKey,
                      title: 'السبورة التفاعلية',
                      description: 'افتح السبورة لمتابعة الشروحات التوضيحية.',
                      child: _AnimatedControlButton(
                        icon: Icons.edit_note_rounded,
                        isActive: controller.isWhiteboardOpen,
                        activeColor: Colors.green,
                        onPressed: controller.toggleWhiteboard,
                        tooltip: "السبورة",
                      ),
                    ),

                    if (controller.isTeacher) ...[
                      _buildDivider(),
                      _AnimatedControlButton(
                        icon: Icons.people_alt_rounded,
                        isActive: controller.isParticipantsOpen,
                        activeColor: Colors.purple,
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
    );
  }

  Widget _buildShowcase({required GlobalKey? key, required String title, required String description, required Widget child}) {
    if (key == null) return child;
    return Showcase(
      key: key,
      title: title,
      description: description,
      titleTextStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF102A43), fontFamily: 'Cairo'),
      descTextStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 14),
      tooltipBackgroundColor: Colors.white,
      targetShapeBorder: const CircleBorder(), // لأن الأزرار دائرية
      child: child,
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 30,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: Colors.white.withOpacity(0.1),
    );
  }
}

class _AnimatedControlButton extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final Color color;
  final Color activeColor;
  final VoidCallback onPressed;
  final String tooltip;

  const _AnimatedControlButton({
    required this.icon,
    required this.isActive,
    this.color = Colors.white,
    required this.activeColor,
    required this.onPressed,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isActive ? activeColor.withOpacity(0.2) : Colors.white.withOpacity(0.05),
              shape: BoxShape.circle,
              border: Border.all(
                color: isActive ? activeColor : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Icon(icon, color: isActive ? activeColor : color, size: 24),
          ),
        ),
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
      offset: const Offset(0, -70),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      color: Colors.black.withOpacity(0.9),
      padding: EdgeInsets.zero,
      icon: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), shape: BoxShape.circle),
        child: const Icon(Icons.add_reaction_rounded, color: Colors.white, size: 22),
      ),
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          enabled: false,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: ['👏', '👍', '❤️', '😂', '🎉'].map((emoji) {
              return InkWell(
                onTap: () {
                  controller.sendReaction(emoji);
                  Navigator.pop(context);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Text(
                    emoji,
                    style: const TextStyle(fontSize: 26),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
