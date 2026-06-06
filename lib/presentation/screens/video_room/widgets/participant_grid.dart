import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:provider/provider.dart';
import '../../../../core/utils/responsive.dart';
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

            final bool isDesktop = Responsive.isDesktop(context);
            
            // تحديد المشارك الرئيسي (المدرس أو مشارك الشاشة)
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
              child: isDesktop 
                ? _buildProfessionalDesktopLayout(mainParticipant, otherParticipants) 
                : _buildMobileLayout(mainParticipant, otherParticipants),
            );
          },
        );
      },
    );
  }

  // توزيع الديسكتوب الاحترافي (المدرس كبير جداً + الطلاب في شريط جانبي)
  Widget _buildProfessionalDesktopLayout(Participant main, List<Participant> others) {
    return Row(
      children: [
        // المدرس (المسرح الرئيسي)
        Expanded(
          flex: 5,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 80, 16, 100), // مساحة للهيدر والكنترول بار
            child: _ParticipantTile(
              key: ValueKey("main_${main.identity}"),
              participant: main,
              isMainStage: true,
            ),
          ),
        ),
        
        // شريط المشاركين الجانبي (أنيق وصغير)
        if (others.isNotEmpty)
          Container(
            width: 200,
            padding: const EdgeInsets.only(top: 80, bottom: 20, right: 16),
            child: ListView.builder(
              itemCount: others.length,
              itemBuilder: (context, index) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: AspectRatio(
                  aspectRatio: 1, // مربعات للطلاب لتبدو منظمة
                  child: _ParticipantTile(
                    key: ValueKey("side_${others[index].identity}"),
                    participant: others[index],
                    isMainStage: false,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMobileLayout(Participant main, List<Participant> others) {
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 70, 8, 8),
            child: _ParticipantTile(participant: main, isMainStage: true),
          ),
        ),
        if (others.isNotEmpty)
          Container(
            height: 110,
            padding: const EdgeInsets.only(bottom: 8),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: others.length,
              itemBuilder: (context, index) => Container(
                width: 110,
                margin: const EdgeInsets.only(right: 8),
                child: _ParticipantTile(participant: others[index], isMainStage: false),
              ),
            ),
          ),
      ],
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
        if (displayName.isEmpty) displayName = participant.identity.replaceAll("teacher_", "").split('_').first;
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
            color: const Color(0xFF1E1F23),
            border: Border.all(
              color: participant.isSpeaking ? Colors.blueAccent : Colors.white.withOpacity(0.05),
              width: participant.isSpeaking ? 3 : 1,
            ),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              // عرض الفيديو (تم استخدام BoxFit.cover لملء الشاشة بشكل احترافي)
              Positioned.fill(
                child: hasVideo
                    ? VideoTrackRenderer(
                        activeVideoTrack!, 
                        fit: isScreen ? VideoViewFit.contain : VideoViewFit.cover,
                      )
                    : _buildAvatar(displayName, isMainStage),
              ),
              
              // خلفية معتمة خفيفة في الأسفل لتوضيح الاسم
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter, end: Alignment.topCenter,
                      colors: [Colors.black.withOpacity(0.7), Colors.transparent],
                    ),
                  ),
                ),
              ),

              // الاسم وحالة الصوت
              Positioned(
                bottom: 8, left: 10, right: 10,
                child: Row(
                  children: [
                    if (!participant.isMicrophoneEnabled())
                      const Icon(Icons.mic_off, color: Colors.redAccent, size: 14),
                    if (!participant.isMicrophoneEnabled()) const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        isMe ? "$displayName (أنت)" : displayName,
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500, fontFamily: 'Cairo'),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              // الشارات العلوية
              Positioned(
                top: 10, right: 10,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isHandRaised) 
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
                        child: const Icon(Icons.front_hand, color: Colors.white, size: 12),
                      ),
                    if (isHandRaised) const SizedBox(width: 6),
                    if (isTeacher)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: Colors.blueAccent, borderRadius: BorderRadius.circular(6)),
                        child: const Text("المعلم", style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                      ),
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
      color: const Color(0xFF2C2D35),
      child: Center(
        child: CircleAvatar(
          radius: isMain ? 45 : 25,
          backgroundColor: Colors.blueAccent.withOpacity(0.1),
          child: Text(
            initial,
            style: TextStyle(color: Colors.blueAccent, fontSize: isMain ? 32 : 18, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}
