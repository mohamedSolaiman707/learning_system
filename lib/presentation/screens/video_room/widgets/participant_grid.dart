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

    final List<Participant> allParticipants = [
      if (room.localParticipant != null) room.localParticipant!,
      ...room.remoteParticipants.values,
    ];

    if (allParticipants.isEmpty) return const SizedBox.shrink();

    // --- منطق الـ Swap الذكي للمسرح الرئيسي ---
    Participant? mainParticipant;
    
    // 1. الأولوية الأولى: أي شخص مشغل مشاركة شاشة (Screen Share)
    try {
      mainParticipant = allParticipants.firstWhere((p) => p.isScreenShareEnabled());
    } catch (_) {
      mainParticipant = null;
    }

    // 2. الأولوية الثانية: المعلم (سواء كنت أنا أو الطرف الآخر)
    if (mainParticipant == null) {
      try {
        mainParticipant = allParticipants.firstWhere(
          (p) => p.identity.contains('teacher') || p.identity == 'teacher',
        );
      } catch (_) {
        mainParticipant = null;
      }
    }

    // 3. الأولوية الثالثة: المثبت (Spotlight) إذا وجد
    if (mainParticipant == null && controller.spotlightUserId != null) {
      try {
        mainParticipant = allParticipants.firstWhere((p) => p.identity == controller.spotlightUserId);
      } catch (_) {
        mainParticipant = null;
      }
    }

    // 4. الحالة الاحتياطية: أول شخص في القائمة
    mainParticipant ??= allParticipants.first;

    // القائمة الصغرى (بقية المشاركين)
    final otherParticipants = allParticipants.where((p) => p.identity != mainParticipant?.identity).toList();

    return Container(
      color: const Color(0xFF0F1014),
      child: Column(
        children: [
          // 1. المسرح الرئيسي (المدرس أو شاشة الطالب)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: _ParticipantTile(
                key: ValueKey("main_${mainParticipant.identity}"),
                participant: mainParticipant,
                isMainStage: true,
              ),
            ),
          ),

          // 2. الشريط السفلي للمشاركين الآخرين
          if (otherParticipants.isNotEmpty)
            Container(
              height: 130,
              padding: const EdgeInsets.only(bottom: 8),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: otherParticipants.length,
                itemBuilder: (context, index) {
                  final p = otherParticipants[index];
                  return Container(
                    width: 170,
                    margin: const EdgeInsets.only(right: 10),
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
    final isHandRaised = controller.remoteHandStates[participant.identity] ?? false;
    final bool isMe = participant is LocalParticipant;
    final bool isTeacherParticipant = participant.identity.contains('teacher') || (isMe && controller.isTeacher);
    final bool isPinned = controller.spotlightUserId == participant.identity;

    String displayName = participant.name ?? "";
    if (displayName.isEmpty) displayName = "طالب";

    return ListenableBuilder(
      listenable: participant,
      builder: (context, child) {
        // تحديد التراك الذي سنعرضه (نفضل الشاشة على الكاميرا)
        final screenSharePart = participant.videoTrackPublications.where((p) => p.isScreenShare).firstOrNull;
        final cameraPart = participant.videoTrackPublications.where((p) => !p.isScreenShare).firstOrNull;
        final activePublication = screenSharePart ?? cameraPart;

        final bool hasVideo = activePublication != null && 
                             activePublication.subscribed && 
                             activePublication.track != null &&
                             (activePublication.isScreenShare || participant.isCameraEnabled());

        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(isMainStage ? 24 : 16),
            color: const Color(0xFF1A1B1F),
            border: Border.all(
              color: participant.isSpeaking ? Colors.greenAccent : Colors.white.withOpacity(0.05),
              width: participant.isSpeaking ? 3 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              // --- الفيديو أو الرمز ---
              Positioned.fill(
                child: hasVideo
                    ? VideoTrackRenderer(
                        activePublication.track as VideoTrack, 
                        fit: activePublication.isScreenShare ? VideoViewFit.contain : VideoViewFit.cover,
                      )
                    : Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topRight,
                            end: Alignment.bottomLeft,
                            colors: [Color(0xFF25262B), Color(0xFF141519)],
                          ),
                        ),
                        child: Center(
                          child: CircleAvatar(
                            radius: isMainStage ? 50 : 28,
                            backgroundColor: Colors.blueAccent.withOpacity(0.1),
                            child: Text(
                              displayName.isNotEmpty ? displayName.substring(0, 1).toUpperCase() : "?",
                              style: TextStyle(
                                color: Colors.blueAccent, 
                                fontSize: isMainStage ? 36 : 20,
                                fontWeight: FontWeight.bold
                              ),
                            ),
                          ),
                        ),
                      ),
              ),

              // --- ملصق الاسم ---
              Positioned(
                bottom: 10,
                left: 10,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      color: Colors.black.withOpacity(0.4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!participant.isMicrophoneEnabled())
                            const Padding(
                              padding: EdgeInsets.only(right: 6),
                              child: Icon(Icons.mic_off, color: Colors.redAccent, size: 14),
                            ),
                          Flexible(
                            child: Text(
                              isMe ? "$displayName (أنت)" : displayName,
                              style: TextStyle(
                                color: Colors.white, 
                                fontSize: isMainStage ? 12 : 10,
                                fontWeight: isMainStage ? FontWeight.bold : FontWeight.normal
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // --- أيقونات الحالة ---
              Positioned(
                top: 10,
                left: 10,
                right: 10,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (isTeacherParticipant)
                      _buildBadge("المعلم", Colors.blueAccent, Icons.school),
                    
                    Row(
                      children: [
                        if (isPinned)
                          _buildCircleIcon(Icons.push_pin, Colors.purple),
                        if (isHandRaised)
                          const SizedBox(width: 4),
                        if (isHandRaised)
                          _buildCircleIcon(Icons.front_hand, Colors.orange),
                      ],
                    ),
                  ],
                ),
              ),
              
              if (activePublication?.isScreenShare ?? false)
                Positioned(
                  top: 10,
                  right: 10,
                  child: _buildBadge("شاشة مشاركة", Colors.redAccent, Icons.screen_share),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBadge(String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 8)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 10),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
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
