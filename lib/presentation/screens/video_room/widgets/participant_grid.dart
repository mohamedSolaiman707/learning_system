import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:provider/provider.dart';
import '../video_room_controller.dart';

class ParticipantGrid extends StatelessWidget {
  const ParticipantGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return Selector<VideoRoomController, Room?>(
      selector: (_, c) => c.room,
      builder: (context, room, _) {
        if (room == null) return const Center(child: CircularProgressIndicator(color: Colors.blue));

        return ListenableBuilder(
          listenable: room,
          builder: (context, _) {
            final List<Participant> allParticipants = [
              if (room.localParticipant != null) room.localParticipant!,
              ...room.remoteParticipants.values,
            ];

            if (allParticipants.isEmpty) {
              return const Center(
                child: Text("في انتظار دخول المشاركين...", style: TextStyle(color: Colors.white70, fontFamily: 'Cairo')),
              );
            }

            Participant? mainParticipant;
            try {
              mainParticipant = allParticipants.firstWhere((p) => p.isScreenShareEnabled());
            } catch (_) {
              try {
                mainParticipant = allParticipants.firstWhere(
                  (p) => p.identity.toLowerCase().contains('teacher'),
                );
              } catch (_) {
                mainParticipant = allParticipants.isNotEmpty ? allParticipants.first : null;
              }
            }

            if (mainParticipant == null) return const SizedBox.shrink();

            final otherParticipants = allParticipants.where((p) => p.identity != mainParticipant?.identity).toList();

            return Container(
              color: const Color(0xFF0F1014),
              child: Column(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: _ParticipantTile(
                        key: ValueKey("main_${mainParticipant.identity}"),
                        participant: mainParticipant,
                        isMainStage: true,
                      ),
                    ),
                  ),
                  if (otherParticipants.isNotEmpty)
                    Container(
                      height: 140,
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: otherParticipants.length,
                        itemBuilder: (context, index) {
                          final p = otherParticipants[index];
                          return Container(
                            width: 180,
                            margin: const EdgeInsets.only(right: 12),
                            child: _ParticipantTile(
                              key: ValueKey("mini_${p.identity}"),
                              participant: p,
                              isMainStage: false,
                            ),
                          );
                        },
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

class _ParticipantTile extends StatelessWidget {
  final Participant participant;
  final bool isMainStage;

  const _ParticipantTile({
    super.key,
    required this.participant,
    required this.isMainStage,
  });

  @override
  Widget build(BuildContext context) {
    final bool isHandRaised = context.select<VideoRoomController, bool>(
      (c) => c.remoteHandStates[participant.identity] ?? false
    );

    return ListenableBuilder(
      listenable: participant,
      builder: (context, _) {
        final bool isMe = participant is LocalParticipant;
        final bool isTeacher = participant.identity.toLowerCase().contains('teacher');
        
        String displayName = participant.name ?? "";
        if (displayName.isEmpty) {
          displayName = participant.identity.replaceAll("teacher_", "").split('_').first;
        }
        if (displayName.isEmpty) displayName = "مشارك";

        VideoTrack? activeVideoTrack;
        bool isScreen = false;

        final screenPub = participant.videoTrackPublications.where((p) => p.isScreenShare).firstOrNull;
        if (screenPub != null && screenPub.subscribed && screenPub.track != null) {
          activeVideoTrack = screenPub.track as VideoTrack?;
          isScreen = true;
        } else {
          final camPub = participant.videoTrackPublications.where((p) => !p.isScreenShare).firstOrNull;
          if (camPub != null && camPub.subscribed && camPub.track != null) {
            activeVideoTrack = camPub.track as VideoTrack?;
          }
        }

        final bool hasVideo = activeVideoTrack != null && (isScreen || participant.isCameraEnabled());

        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(isMainStage ? 24 : 16),
            color: const Color(0xFF1A1B1F),
            border: Border.all(
              color: participant.isSpeaking ? Colors.greenAccent : Colors.white10,
              width: participant.isSpeaking ? 3 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Positioned.fill(
                child: hasVideo
                    ? VideoTrackRenderer(
                        activeVideoTrack!, 
                        // تم التعديل هنا: نستخدم contain للمسرح الرئيسي لضمان ظهور كامل الصورة
                        fit: (isScreen || isMainStage) ? VideoViewFit.contain : VideoViewFit.cover,
                      )
                    : _buildAvatar(displayName, isMainStage),
              ),
              Positioned(
                bottom: 10, left: 10, right: 10,
                child: _buildNameLabel(displayName, isMe, participant.isMicrophoneEnabled()),
              ),
              Positioned(
                top: 10, left: 10, right: 10,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (isTeacher) _buildBadge("المعلم", Colors.blueAccent, Icons.school),
                    if (isHandRaised) _buildCircleIcon(Icons.front_hand, Colors.orange),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAvatar(String name, bool isMain) {
    String initial = name.isNotEmpty ? name.substring(0, 1).toUpperCase() : "?";
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight, end: Alignment.bottomLeft,
          colors: [Color(0xFF25262B), Color(0xFF141519)],
        ),
      ),
      child: Center(
        child: CircleAvatar(
          radius: isMain ? 60 : 30,
          backgroundColor: Colors.blueAccent.withOpacity(0.1),
          child: Text(
            initial,
            style: TextStyle(color: Colors.blueAccent, fontSize: isMain ? 40 : 22, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget _buildNameLabel(String name, bool isMe, bool isMicOn) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          color: Colors.black45,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isMicOn) const Icon(Icons.mic_off, color: Colors.redAccent, size: 12),
              if (!isMicOn) const SizedBox(width: 4),
              Flexible(
                child: Text(
                  isMe ? "$name (أنت)" : name,
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 10),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildCircleIcon(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Icon(icon, color: Colors.white, size: 14),
    );
  }
}
