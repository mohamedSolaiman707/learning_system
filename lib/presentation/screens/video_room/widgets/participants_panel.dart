import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import '../video_room_controller.dart';

class ParticipantsPanel extends StatelessWidget {
  final VideoRoomController controller;

  const ParticipantsPanel({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    // Explicitly typing the list as List<Participant> to avoid incorrect type inference
    final List<Participant> participants = [
      if (controller.room?.localParticipant != null)
        controller.room!.localParticipant!,
      ...controller.room?.remoteParticipants.values ?? [],
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.horizontal(left: Radius.circular(30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "المشاركين",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Cairo',
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => controller.toggleParticipants(),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            "${participants.length} مشارك في القاعة",
            style: const TextStyle(
              color: Colors.grey,
              fontFamily: 'Cairo',
            ),
          ),
          const SizedBox(height: 20),
          if (controller.isTeacher) ...[
            _TeacherControls(controller: controller),
            const Divider(height: 30),
          ],
          Expanded(
            child: ListView.separated(
              itemCount: participants.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                return _ParticipantTile(
                  participant: participants[index],
                  controller: controller,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TeacherControls extends StatelessWidget {
  final VideoRoomController controller;
  const _TeacherControls({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _PermissionToggle(
              icon: controller.isAllMuted ? Icons.mic_off : Icons.mic,
              label: "كتم الجميع",
              isLocked: controller.isAllMuted,
              onTap: () => controller.muteAllParticipants(!controller.isAllMuted),
            ),
            _PermissionToggle(
              icon: controller.isCamLocked ? Icons.videocam_off : Icons.videocam,
              label: "كاميرا الجميع",
              isLocked: controller.isCamLocked,
              onTap: () => controller.disableAllCameras(!controller.isCamLocked),
            ),
            _PermissionToggle(
              icon: controller.isChatLocked ? Icons.chat_bubble_outline : Icons.chat,
              label: "قفل الشات",
              isLocked: controller.isChatLocked,
              onTap: () => controller.toggleChatLock(),
            ),
            _PermissionToggle(
              icon: controller.isWhiteboardLocked ? Icons.draw_outlined : Icons.draw,
              label: "قفل السبورة",
              isLocked: controller.isWhiteboardLocked,
              onTap: () => controller.toggleWhiteboardLock(),
            ),
          ],
        ),
        const SizedBox(height: 15),
        Row(
          children: [
            Expanded(
              child: _ActionButton(
                label: "غرف التقسيم",
                icon: Icons.groups_outlined,
                color: const Color(0xFF102A43),
                onTap: () => _showBreakoutDialog(context),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ActionButton(
                label: "تنزيل الغياب",
                icon: Icons.picture_as_pdf_outlined,
                color: Colors.red.shade700,
                onTap: () {}, // This would trigger PDF generation
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showBreakoutDialog(BuildContext context) {
    int groupCount = 2;
    double duration = 10;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDS) => Container(
          padding: const EdgeInsets.all(30),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(35)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "إعدادات غرف التقسيم",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF102A43),
                  fontFamily: 'Cairo',
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                "عدد المجموعات",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Cairo',
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: () =>
                        groupCount > 2 ? setDS(() => groupCount--) : null,
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 30),
                    child: Text(
                      "$groupCount",
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () =>
                        groupCount < 8 ? setDS(() => groupCount++) : null,
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "المدة (دقيقة)",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Cairo',
                    ),
                  ),
                  Text(
                    "${duration.toInt()} د",
                    style: const TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Cairo',
                    ),
                  ),
                ],
              ),
              Slider(
                value: duration,
                min: 5,
                max: 30,
                divisions: 5,
                activeColor: const Color(0xFF102A43),
                onChanged: (v) => setDS(() => duration = v),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF102A43),
                  minimumSize: const Size(double.infinity, 60),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                onPressed: () {
                  controller.startBreakoutRooms(groupCount, duration.toInt());
                  Navigator.pop(context);
                },
                child: const Text(
                  "بدء التقسيم الآن",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Cairo',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ParticipantTile extends StatelessWidget {
  final Participant participant;
  final VideoRoomController controller;
  const _ParticipantTile({required this.participant, required this.controller});
  @override
  Widget build(BuildContext context) {
    final bool isMe = participant is LocalParticipant;
    final bool handRaised =
        controller.remoteHandStates[participant.identity] ?? false;
    final bool isSpotlight = controller.spotlightUserId == participant.identity;

    // Fixed: In LiveKit 2.x, name is non-nullable.
    final String displayName = participant.name.isNotEmpty ? participant.name : participant.identity;
    final String initial = displayName.isNotEmpty ? displayName[0] : "?";

    return ListTile(
      leading: Stack(
        children: [
          CircleAvatar(
            backgroundColor: isMe
                ? const Color(0xFF102A43)
                : Colors.grey.shade200,
            child: Text(
              initial,
              style: TextStyle(color: isMe ? Colors.white : Colors.black),
            ),
          ),
          if (isSpotlight)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Colors.amber,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.star, size: 10, color: Colors.white),
              ),
            ),
        ],
      ),
      title: Text(
        displayName,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontFamily: 'Cairo',
          fontSize: 14,
        ),
      ),
      subtitle: isMe
          ? const Text(
              "أنت",
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey,
                fontFamily: 'Cairo',
              ),
            )
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (handRaised)
            const Icon(Icons.front_hand, color: Colors.orange, size: 18),
          const SizedBox(width: 8),
          Icon(
            participant.isMicrophoneEnabled() ? Icons.mic : Icons.mic_off,
            color: participant.isMicrophoneEnabled()
                ? Colors.green
                : Colors.red,
            size: 18,
          ),

          if (controller.isTeacher && !isMe)
            PopupMenuButton<String>(
              onSelected: (val) {
                if (val == 'mute') {
                  controller.muteParticipant(
                    participant.identity,
                    participant.isMicrophoneEnabled(),
                  );
                }
                if (val == 'camera') {
                  controller.disableParticipantCamera(
                    participant.identity,
                    participant.isCameraEnabled(),
                  );
                }
                if (val == 'spotlight') {
                  controller.setSpotlight(
                    isSpotlight ? null : participant.identity,
                  );
                }
                if (val == 'kick') _showKickConfirm(context);
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'mute',
                  child: Row(
                    children: [
                      Icon(
                        participant.isMicrophoneEnabled()
                            ? Icons.mic_off
                            : Icons.mic,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        participant.isMicrophoneEnabled()
                            ? "كتم الصوت"
                            : "تفعيل الصوت",
                        style: const TextStyle(fontFamily: 'Cairo'),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'camera',
                  child: Row(
                    children: [
                      Icon(
                        participant.isCameraEnabled()
                            ? Icons.videocam_off
                            : Icons.videocam,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        participant.isCameraEnabled()
                            ? "إيقاف الكاميرا"
                            : "تفعيل الكاميرا",
                        style: const TextStyle(fontFamily: 'Cairo'),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'spotlight',
                  child: Row(
                    children: [
                      Icon(
                        isSpotlight ? Icons.star_border : Icons.star,
                        size: 18,
                        color: Colors.amber,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isSpotlight ? "إلغاء التمييز" : "تمييز المشارك",
                        style: const TextStyle(fontFamily: 'Cairo'),
                      ),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'kick',
                  child: Row(
                    children: [
                      const Icon(Icons.gavel, size: 18, color: Colors.red),
                      const SizedBox(width: 8),
                      Text(
                        "طرد من القاعة",
                        style: TextStyle(
                          color: Colors.red,
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  void _showKickConfirm(BuildContext context) {
    final String displayName = participant.name.isNotEmpty ? participant.name : participant.identity;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("تأكيد الطرد", style: TextStyle(fontFamily: 'Cairo')),
        content: Text(
          "هل أنت متأكد من طرد $displayName؟",
          style: const TextStyle(fontFamily: 'Cairo'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("إلغاء", style: TextStyle(fontFamily: 'Cairo')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              controller.kickParticipant(participant.identity);
              Navigator.pop(ctx);
            },
            child: const Text(
              "طرد",
              style: TextStyle(color: Colors.white, fontFamily: 'Cairo'),
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionToggle extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isLocked;
  final VoidCallback onTap;
  const _PermissionToggle({
    required this.icon,
    required this.label,
    required this.isLocked,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        IconButton(
          icon: Icon(icon, color: isLocked ? Colors.red : Colors.green),
          onPressed: onTap,
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            fontFamily: 'Cairo',
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool isFullWidth;
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.isFullWidth = false,
  });
  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      icon: Icon(icon, size: 18),
      label: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontFamily: 'Cairo',
        ),
      ),
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}
