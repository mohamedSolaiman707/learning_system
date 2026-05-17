import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:livekit_client/livekit_client.dart';
import '../video_room_controller.dart';

class ParticipantsPanel extends StatelessWidget {
  const ParticipantsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<VideoRoomController>();
    final room = controller.room;
    final size = MediaQuery.of(context).size;
    final bool isMobile = size.width < 600;

    if (room == null) return const SizedBox.shrink();

    final List<Participant> participants = [
      if (room.localParticipant != null) room.localParticipant!,
      ...room.remoteParticipants.values,
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: isMobile 
          ? const BorderRadius.vertical(top: Radius.circular(25)) 
          : const BorderRadius.only(topLeft: Radius.circular(25)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10)],
      ),
      child: Column(
        children: [
          _buildHeader(controller),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: participants.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final p = participants[index];
                final bool isMe = p is LocalParticipant;
                final bool isMicOn = p.isMicrophoneEnabled();
                final bool handRaised = controller.remoteHandStates[p.identity] ?? false;

                return ListTile(
                  leading: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      CircleAvatar(
                        backgroundColor: isMe ? Colors.blue.shade100 : Colors.grey.shade200,
                        child: Text(
                          (p.name ?? p.identity).isNotEmpty 
                              ? (p.name ?? p.identity).substring(0, 1).toUpperCase()
                              : "?",
                          style: TextStyle(color: isMe ? Colors.blue : Colors.black87),
                        ),
                      ),
                      if (handRaised)
                        const Positioned(
                          right: -4,
                          top: -4,
                          child: Icon(Icons.front_hand, color: Colors.orange, size: 18),
                        ),
                    ],
                  ),
                  title: Text(
                    p.name ?? p.identity,
                    style: TextStyle(
                      fontWeight: isMe ? FontWeight.bold : FontWeight.normal,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    isMe ? (controller.isTeacher ? "أنت (المدرس)" : "أنت (طالب)") : "طالب",
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // أيقونة حالة المايك
                      Icon(
                        isMicOn ? Icons.mic : Icons.mic_off,
                        color: isMicOn ? Colors.green : Colors.red,
                        size: 20,
                      ),
                      
                      // أدوات تحكم المدرس
                      if (controller.isTeacher && !isMe) ...[
                        const SizedBox(width: 4),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, size: 20),
                          onSelected: (value) {
                            if (value == 'mute') {
                              controller.muteParticipant(p.identity, isMicOn);
                            } else if (value == 'kick') {
                              _confirmKick(context, controller, p);
                            }
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: 'mute',
                              child: Row(
                                children: [
                                  Icon(isMicOn ? Icons.mic_off : Icons.mic, size: 18),
                                  const SizedBox(width: 8),
                                  Text(isMicOn ? "كتم الصوت" : "تفعيل الصوت"),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'kick',
                              child: Row(
                                children: [
                                  Icon(Icons.person_remove, size: 18, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text("طرد من الحصة", style: TextStyle(color: Colors.red)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
          
          // أزرار التحكم الجماعي للمدرس
          if (controller.isTeacher)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        for (var p in room.remoteParticipants.values) {
                          controller.muteParticipant(p.identity, true);
                        }
                      },
                      icon: const Icon(Icons.mic_off, size: 18),
                      label: const Text("كتم الجميع", style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _confirmKick(BuildContext context, VideoRoomController controller, Participant p) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("تأكيد الطرد"),
        content: Text("هل أنت متأكد من طرد ${p.name ?? p.identity}؟"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("إلغاء")),
          ElevatedButton(
            onPressed: () {
              controller.kickParticipant(p.identity);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("طرد الآن"),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(VideoRoomController controller) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text("المشاركون", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          IconButton(icon: const Icon(Icons.close), onPressed: controller.toggleParticipants),
        ],
      ),
    );
  }
}
