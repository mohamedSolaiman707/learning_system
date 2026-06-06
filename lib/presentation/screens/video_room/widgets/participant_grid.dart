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
            
            // البحث عن مشارك يشارك شاشته
            Participant? screenSharer;
            try {
              screenSharer = allParticipants.firstWhere((p) => p.isScreenShareEnabled());
            } catch (_) {}

            if (screenSharer != null) {
              return _buildSpeakerLayout(context, screenSharer, allParticipants.where((p) => p != screenSharer).toList(), isDesktop);
            }

            return _buildGridLayout(context, allParticipants, isDesktop);
          },
        );
      },
    );
  }

  Widget _buildGridLayout(BuildContext context, List<Participant> participants, bool isDesktop) {
    int crossAxisCount = participants.length <= 1 ? 1 : (participants.length <= 4 ? 2 : 3);
    if (!isDesktop) crossAxisCount = participants.length <= 1 ? 1 : 2;

    return Container(
      color: const Color(0xFF0F1014),
      padding: const EdgeInsets.all(12),
      child: GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: isDesktop ? 1.7 : 0.85,
        ),
        itemCount: participants.length,
        itemBuilder: (context, index) => _ParticipantTile(
          key: ValueKey("grid_${participants[index].identity}"),
          participant: participants[index],
          isMainStage: participants.length == 1,
        ),
      ),
    );
  }

  Widget _buildSpeakerLayout(BuildContext context, Participant main, List<Participant> others, bool isDesktop) {
    if (!isDesktop) {
      return Column(
        children: [
          Expanded(child: Padding(padding: const EdgeInsets.all(8), child: _ParticipantTile(participant: main, isMainStage: true))),
          if (others.isNotEmpty)
            SizedBox(
              height: 140,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: others.length,
                itemBuilder: (context, index) => Container(width: 160, margin: const EdgeInsets.only(right: 8), child: _ParticipantTile(participant: others[index], isMainStage: false)),
              ),
            ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          flex: 4,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: _ParticipantTile(participant: main, isMainStage: true),
          ),
        ),
        if (others.isNotEmpty)
          Container(
            width: 280,
            padding: const EdgeInsets.fromLTRB(0, 12, 12, 12),
            child: ListView.builder(
              itemCount: others.length,
              itemBuilder: (context, index) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: _ParticipantTile(participant: others[index], isMainStage: false),
                ),
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
    final bool isHandRaised = context.select<VideoRoomController, bool>((c) => c.remoteHandStates[participant.identity] ?? false);

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
            color: const Color(0xFF1A1B1F),
            border: Border.all(
              color: participant.isSpeaking ? Colors.greenAccent : Colors.white.withOpacity(0.08), 
              width: participant.isSpeaking ? 3 : 1.5
            ),
            boxShadow: [
              if (participant.isSpeaking) BoxShadow(color: Colors.greenAccent.withOpacity(0.2), blurRadius: 20),
              BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 5))
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              // طبقة الفيديو الذكية (Professional Video Rendering)
              Positioned.fill(
                child: hasVideo
                    ? (isScreen 
                        ? VideoTrackRenderer(activeVideoTrack!, fit: VideoViewFit.contain)
                        : Stack(
                            children: [
                              // 1. الخلفية المضببة (لملء الفراغات السوداء في الفيديو الطولي)
                              Positioned.fill(
                                child: ImageFiltered(
                                  imageFilter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                                  child: VideoTrackRenderer(activeVideoTrack!, fit: VideoViewFit.cover),
                                ),
                              ),
                              Container(color: Colors.black26), // طبقة تعتيم خفيفة
                              // 2. الفيديو الأصلي في المنتصف بدون قص
                              Positioned.fill(
                                child: VideoTrackRenderer(activeVideoTrack!, fit: VideoViewFit.contain),
                              ),
                            ],
                          ))
                    : _buildAvatar(displayName, isMainStage),
              ),
              
              // التسمية
              Positioned(
                bottom: 12, left: 12,
                child: _buildNameLabel(displayName, isMe, participant.isMicrophoneEnabled()),
              ),

              // الشارات
              Positioned(
                top: 12, right: 12,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isHandRaised) _buildCircleIcon(Icons.front_hand, Colors.orange),
                    if (isHandRaised) const SizedBox(width: 8),
                    if (isTeacher) _buildBadge("المعلم", Colors.blueAccent, Icons.school),
                  ],
                ),
              ),

              // مؤشر الصوت
              if (participant.isSpeaking)
                Positioned(top: 0, left: 0, right: 0, child: Container(height: 4, decoration: const BoxDecoration(gradient: LinearGradient(colors: [Colors.greenAccent, Colors.transparent, Colors.greenAccent])))),
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
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF2C2D35), Color(0xFF141519)]),
      ),
      child: Center(
        child: CircleAvatar(
          radius: isMain ? 60 : 30,
          backgroundColor: Colors.blueAccent.withOpacity(0.1),
          child: Text(initial, style: TextStyle(color: Colors.blueAccent, fontSize: isMain ? 40 : 20, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _buildNameLabel(String name, bool isMe, bool isMicOn) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          color: Colors.black45,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(isMicOn ? Icons.mic : Icons.mic_off, color: isMicOn ? Colors.white70 : Colors.redAccent, size: 14),
              const SizedBox(width: 6),
              Flexible(child: Text(isMe ? "$name (أنت)" : name, style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'Cairo', fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: color.withOpacity(0.9), borderRadius: BorderRadius.circular(10), boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 5)]),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 12),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
        ],
      ),
    );
  }

  Widget _buildCircleIcon(IconData icon, Color color) {
    return Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 5)]), child: Icon(icon, color: Colors.white, size: 14));
  }
}
