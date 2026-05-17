import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:provider/provider.dart';
import '../video_room_controller.dart';

class ParticipantGrid extends StatelessWidget {
  const ParticipantGrid({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<VideoRoomController>();
    final room = controller.room;

    if (room == null) return const Center(child: CircularProgressIndicator());

    final List<Participant> participants = [
      if (room.localParticipant != null) room.localParticipant!,
      ...room.remoteParticipants.values,
    ];

    final bool isMobile = MediaQuery.of(context).size.width < 600;

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isMobile ? 1 : 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: isMobile ? 1.5 : 1.0,
      ),
      itemCount: participants.length,
      itemBuilder: (context, index) {
        final participant = participants[index];
        return _ParticipantTile(participant: participant);
      },
    );
  }
}

class _ParticipantTile extends StatelessWidget {
  final Participant participant;

  const _ParticipantTile({super.key, required this.participant});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<VideoRoomController>();
    final isHandRaised = controller.remoteHandStates[participant.identity] ?? false;

    // استخدام نفس منطق الاسم الذكي لضمان ظهور الاسم الكامل
    String displayName = participant.name ?? participant.identity;
    if (displayName.isEmpty || displayName == "طالب") {
       displayName = participant.identity; 
    }

    return ListenableBuilder(
      listenable: participant,
      builder: (context, child) {
        final videoPublication = participant.videoTrackPublications.isNotEmpty 
            ? participant.videoTrackPublications.first 
            : null;

        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              // عرض الفيديو أو الصورة الرمزية
              videoPublication != null && 
              videoPublication.subscribed && 
              participant.isCameraEnabled() && 
              videoPublication.track != null
                  ? VideoTrackRenderer(videoPublication.track as VideoTrack)
                  : Container(
                      color: Colors.grey[900],
                      child: Center(
                        child: CircleAvatar(
                          radius: 30,
                          backgroundColor: Colors.blueGrey,
                          child: Text(
                            displayName.isNotEmpty
                                ? displayName.substring(0, 1).toUpperCase()
                                : "?",
                            style: const TextStyle(color: Colors.white, fontSize: 24),
                          ),
                        ),
                      ),
                    ),
              
              // ملصق الاسم وحالة الميكروفون
              Positioned(
                bottom: 8,
                left: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!participant.isMicrophoneEnabled())
                        const Padding(
                          padding: EdgeInsets.only(right: 4.0),
                          child: Icon(Icons.mic_off, color: Colors.red, size: 12),
                        ),
                      Flexible(
                        child: Text(
                          displayName,
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // مؤشر رفع اليد
              if (isHandRaised)
                const Positioned(
                  top: 8,
                  right: 8,
                  child: Icon(Icons.front_hand, color: Colors.yellow, size: 24),
                ),
            ],
          ),
        );
      },
    );
  }
}
