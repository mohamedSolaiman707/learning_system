import 'dart:ui';
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

    // تجميع كل المشاركين (المحلي والبعيد)
    final List<Participant> allParticipants = [
      if (room.localParticipant != null) room.localParticipant!,
      ...room.remoteParticipants.values,
    ];

    if (allParticipants.isEmpty) return const SizedBox.shrink();

    // --- منطق الـ Swap الذكي للمسرح الرئيسي ---
    Participant? mainParticipant;
    
    // 1. الأولوية الأولى: أي شخص يشارك شاشته
    try {
      mainParticipant = allParticipants.firstWhere((p) => p.isScreenShareEnabled());
    } catch (_) {}

    // 2. الأولوية الثانية: المعلم (نبحث عن كلمة teacher في الهوية)
    if (mainParticipant == null) {
      try {
        mainParticipant = allParticipants.firstWhere(
          (p) => p.identity.toLowerCase().contains('teacher'),
        );
      } catch (_) {}
    }

    // 3. الأولوية الثالثة: Spotlight
    if (mainParticipant == null && controller.spotlightUserId != null) {
      try {
        mainParticipant = allParticipants.firstWhere((p) => p.identity == controller.spotlightUserId);
      } catch (_) {}
    }

    // 4. الاحتياطي: أول شخص في القائمة
    mainParticipant ??= allParticipants.first;

    // بقية المشاركين للشريط السفلي
    final otherParticipants = allParticipants.where((p) => p.identity != mainParticipant?.identity).toList();

    return Container(
      color: const Color(0xFF0F1014),
      child: Column(
        children: [
          // المسرح الرئيسي
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

          // الشريط السفلي للمشاركين الآخرين
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
    final controller = context.watch<VideoRoomController>();
    
    return ListenableBuilder(
      listenable: participant,
      builder: (context, _) {
        final bool isMe = participant is LocalParticipant;
        final bool isTeacher = participant.identity.toLowerCase().contains('teacher');
        final bool isHandRaised = controller.remoteHandStates[participant.identity] ?? false;
        
        // تحسين منطق جلب الاسم
        String displayName = participant.name ?? "";
        if (displayName.isEmpty || displayName.length > 30) {
          displayName = participant.identity.replaceAll("teacher_", "");
        }
        if (displayName.isEmpty || displayName.length > 30) displayName = "مشارك";

        // تحديد التراك النشط
        final screenPart = participant.videoTrackPublications.where((p) => p.isScreenShare).firstOrNull;
        final camPart = participant.videoTrackPublications.where((p) => !p.isScreenShare).firstOrNull;
        final activePub = screenPart ?? camPart;

        final bool hasVideo = activePub != null && 
                             activePub.subscribed && 
                             activePub.track != null &&
                             (activePub.isScreenShare || participant.isCameraEnabled());

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
              // 1. الفيديو أو الأفاتار
              Positioned.fill(
                child: hasVideo
                    ? VideoTrackRenderer(
                        activePub.track as VideoTrack, 
                        fit: activePub.isScreenShare ? VideoViewFit.contain : VideoViewFit.cover,
                      )
                    : _buildAvatar(displayName, isMainStage),
              ),

              // 2. الاسم (Label)
              Positioned(
                bottom: 10,
                left: 10,
                right: 10,
                child: _buildNameLabel(displayName, isMe, participant.isMicrophoneEnabled()),
              ),

              // 3. الشارات (Teacher, Hand, etc)
              Positioned(
                top: 10,
                left: 10,
                right: 10,
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
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFF25262B), Color(0xFF141519)],
        ),
      ),
      child: Center(
        child: CircleAvatar(
          radius: isMain ? 60 : 30,
          backgroundColor: Colors.blueAccent.withOpacity(0.1),
          child: Text(
            name.isNotEmpty ? name.substring(0, 1).toUpperCase() : "?",
            style: TextStyle(
              color: Colors.blueAccent, 
              fontSize: isMain ? 40 : 22,
              fontWeight: FontWeight.bold
            ),
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
