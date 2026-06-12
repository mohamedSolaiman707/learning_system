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
        if (room == null) {
          return const Center(child: CircularProgressIndicator(color: Colors.blue));
        }

        return ListenableBuilder(
          listenable: room,
          builder: (context, _) {
            final controller = context.read<VideoRoomController>();
            final isTeacher = controller.isTeacher;
            final selectedChannel = controller.selectedChannel;

            final List<Participant> allParticipants = [
              if (room.localParticipant != null) room.localParticipant!,
              ...room.remoteParticipants.values,
            ];

            if (allParticipants.isEmpty) {
              return const Center(child: Text("في انتظار دخول المشاركين...", style: TextStyle(color: Colors.white70, fontFamily: 'Cairo')));
            }

            Participant? screenSharingParticipant;
            try {
              screenSharingParticipant = allParticipants.firstWhere((p) => p.isScreenShareEnabled());
            } catch (_) {}


            if (!isTeacher) {
              final channelParticipant = allParticipants.where((p) => p.identity.contains(selectedChannel)).firstOrNull;
              final teacherParticipant = allParticipants.where((p) => p.identity.toLowerCase().contains('teacher')).firstOrNull;

              if (screenSharingParticipant != null) {
                return _buildHybridStudentLayout(context, screenSharingParticipant, channelParticipant);
              } else {
                // نفضل كاميرا القاعة، ولو مش موجودة نظهر المدرس كـ Main
                final mainToDisplay = channelParticipant ?? teacherParticipant;
                
                if (mainToDisplay != null) {
                  return GestureDetector(
                    onTap: () => controller.cycleRoomCamera(),
                    child: ParticipantTile(
                        key: ValueKey("channel_or_teacher_${mainToDisplay.identity}"),
                        participant: mainToDisplay,
                        isMainStage: true
                    ),
                  );
                } else {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(color: Colors.blue, strokeWidth: 2),
                        const SizedBox(height: 16),
                        const Text("في انتظار المدرس أو بث القاعة...", style: TextStyle(color: Colors.white, fontFamily: 'Cairo', fontSize: 16)),
                      ],
                    ),
                  );
                }
              }
            }

            // منطق المدرس
            final bool isDesktop = Responsive.isDesktop(context);

            if (controller.isVideoWallMode) {
              final int pageSize = VideoRoomController.wallPageSize;
              final int currentPage = controller.wallPage;
              final int totalCount = allParticipants.length;
              final int maxPage = ((totalCount - 1) / pageSize).floor();

              final int startIndex = currentPage * pageSize;
              final int endIndex = (startIndex + pageSize).clamp(0, totalCount);
              final pageParticipants = allParticipants.sublist(startIndex, endIndex);

              int crossAxisCount = isDesktop ? 4 : (Responsive.isTablet(context) ? 3 : 2);

              return Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color: Colors.black54,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "المشاركون ${startIndex + 1}–$endIndex من $totalCount",
                          style: const TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'Cairo'),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 18),
                              onPressed: currentPage > 0 ? () => controller.prevWallPage() : null,
                            ),
                            Text("${currentPage + 1} / ${maxPage + 1}", style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                            IconButton(
                              icon: const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 18),
                              onPressed: currentPage < maxPage ? () => controller.nextWallPage(totalCount) : null,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: GridView.builder(
                      padding: const EdgeInsets.all(8),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        childAspectRatio: 16 / 9,
                      ),
                      itemCount: pageParticipants.length,
                      itemBuilder: (context, index) => ParticipantTile(
                        key: ValueKey("wall_${pageParticipants[index].identity}_p$currentPage"),
                        participant: pageParticipants[index],
                        isMainStage: false,
                      ),
                    ),
                  ),
                ],
              );
            }

            // تحديد الـ Main Participant للمدرس
            Participant? mainParticipant = screenSharingParticipant;
            if (mainParticipant == null) {
              // الأولوية لكاميرا القاعة
              mainParticipant = allParticipants.where((p) => p.identity.contains(selectedChannel)).firstOrNull;
              
              if (mainParticipant == null) {
                // لو المدرس لوحده، يظهر هو في الـ Main
                if (allParticipants.length == 1 && allParticipants.first.identity.contains('teacher')) {
                  mainParticipant = allParticipants.first;
                } else {
                  // لو فيه طلاب، نظهر أول طالب
                  try {
                    mainParticipant = allParticipants.firstWhere((p) => !p.identity.toLowerCase().contains('teacher'));
                  } catch (_) {
                    mainParticipant = allParticipants.firstOrNull;
                  }
                }
              }
            }

            final bool isMainSharingScreen = mainParticipant?.isScreenShareEnabled() ?? false;
            final otherParticipants = allParticipants.where((p) {
              if (isMainSharingScreen) return true;
              return p.identity != mainParticipant?.identity;
            }).toList();

            if (isDesktop) return _buildProfessionalDesktopLayout(context, mainParticipant!, otherParticipants, isMainSharingScreen);
            return _buildMobileLayout(context, mainParticipant!, otherParticipants, isMainSharingScreen);
          },
        );
      },
    );
  }

  Widget _buildHybridStudentLayout(BuildContext context, Participant screenPart, Participant? camPart) {
    final bool isDesktop = Responsive.isDesktop(context);
    final controller = context.read<VideoRoomController>();

    return Stack(
      children: [
        Positioned.fill(
          child: ParticipantTile(
            key: ValueKey("student_main_screen_${screenPart.identity}"),
            participant: screenPart,
            isMainStage: true,
            forceShowScreen: true,
          ),
        ),
        if (camPart != null)
          Positioned(
            top: isDesktop ? 40 : 20,
            right: 20,
            child: GestureDetector(
              onTap: () => controller.cycleRoomCamera(),
              child: Container(
                width: isDesktop ? 280 : 140,
                height: isDesktop ? 160 : 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.blue.withOpacity(0.5), width: 2),
                  boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 10)],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: ParticipantTile(
                    key: ValueKey("student_side_cam_${camPart.identity}"),
                    participant: camPart,
                    isMainStage: false,
                    forceShowScreen: false,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildProfessionalDesktopLayout(BuildContext context, Participant main, List<Participant> others, bool isMainSharingScreen) {
    return Container(
      color: const Color(0xFF0F1014),
      padding: others.isEmpty ? EdgeInsets.zero : const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
              flex: 4,
              child: ParticipantTile(
                key: ValueKey("main_${main.identity}"),
                participant: main,
                isMainStage: true,
                forceShowScreen: isMainSharingScreen ? true : null,
              )
          ),
          if (others.isNotEmpty)
            Container(
              width: 240,
              margin: const EdgeInsets.only(left: 16),
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
                child: ListView.builder(
                  itemCount: others.length,
                  itemBuilder: (context, index) {
                    final p = others[index];
                    final bool forceCam = isMainSharingScreen && p.identity == main.identity;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: AspectRatio(
                          aspectRatio: 16 / 10,
                          child: ParticipantTile(
                            key: ValueKey("side_${p.identity}"),
                            participant: p,
                            isMainStage: false,
                            forceShowScreen: forceCam ? false : null,
                          )
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context, Participant main, List<Participant> others, bool isMainSharingScreen) {
    return Column(
      children: [
        Expanded(
            child: Padding(
                padding: others.isEmpty ? EdgeInsets.zero : const EdgeInsets.all(8),
                child: ParticipantTile(
                  participant: main,
                  isMainStage: true,
                  forceShowScreen: isMainSharingScreen ? true : null,
                )
            )
        ),
        if (others.isNotEmpty)
          Container(
            height: 120,
            margin: const EdgeInsets.only(bottom: 8),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: others.length,
              itemBuilder: (context, index) {
                final p = others[index];
                final bool forceCam = isMainSharingScreen && p.identity == main.identity;
                return Container(
                    width: 160,
                    margin: const EdgeInsets.only(right: 8),
                    child: ParticipantTile(
                      participant: p,
                      isMainStage: false,
                      forceShowScreen: forceCam ? false : null,
                    )
                );
              },
            ),
          ),
      ],
    );
  }
}

class ParticipantTile extends StatelessWidget {
  final Participant participant;
  final bool isMainStage;
  final bool? forceHandRaised;
  final bool? forceShowScreen;

  const ParticipantTile({
    super.key,
    required this.participant,
    required this.isMainStage,
    this.forceHandRaised,
    this.forceShowScreen,
  });

  @override
  Widget build(BuildContext context) {
    bool isHandRaised = forceHandRaised ?? false;
    if (forceHandRaised == null) {
      try {
        isHandRaised = context.select<VideoRoomController, bool>(
              (c) => c.remoteHandStates[participant.identity] ?? false,
        );
      } catch (_) {}
    }

    final isSpotlighted = context.select<VideoRoomController, bool>(
          (c) => c.spotlightUserId == participant.identity,
    );

    return ListenableBuilder(
      listenable: participant,
      builder: (context, _) {
        final bool isMe = participant is LocalParticipant;
        final bool isTeacher = participant.identity.toLowerCase().contains('teacher');
        final bool isRoomCam = participant.identity.contains('room-cam-');
        final bool isSpeaking = participant.isSpeaking;

        String displayName = participant.name ?? "";
        if (displayName.isEmpty) {
          displayName = participant.identity.replaceAll("teacher_", "").split('_').first;
        }
        if (displayName.isEmpty) displayName = "مشارك";

        VideoTrack? activeVideoTrack;
        bool isScreen = false;

        if (forceShowScreen == true) {
          final pub = participant.videoTrackPublications.where((p) => p.isScreenShare).firstOrNull;
          if (pub != null && (isMe || pub.subscribed)) activeVideoTrack = pub.track as VideoTrack?;
          isScreen = true;
        } else if (forceShowScreen == false) {
          final pub = participant.videoTrackPublications.where((p) => !p.isScreenShare).firstOrNull;
          if (pub != null && (isMe || pub.subscribed)) activeVideoTrack = pub.track as VideoTrack?;
          isScreen = false;
        } else {
          final screenPub = participant.videoTrackPublications.where((p) => p.isScreenShare).firstOrNull;
          if (screenPub != null && (isMe || screenPub.subscribed) && screenPub.track != null) {
            activeVideoTrack = screenPub.track as VideoTrack?;
            isScreen = true;
          } else {
            final camPub = participant.videoTrackPublications.where((p) => !p.isScreenShare).firstOrNull;
            if (camPub != null && (isMe || camPub.subscribed) && camPub.track != null) {
              activeVideoTrack = camPub.track as VideoTrack?;
            }
          }
        }

        final bool hasVideo = activeVideoTrack != null && (isScreen || participant.isCameraEnabled());

        return AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          decoration: BoxDecoration(
            borderRadius: isMainStage ? BorderRadius.zero : BorderRadius.circular(12),
            color: const Color(0xFF0F1014),
            border: isMainStage 
              ? null 
              : Border.all(
                  color: isSpotlighted ? Colors.amber : (isSpeaking ? Colors.greenAccent : Colors.white.withOpacity(0.05)),
                  width: (isSpotlighted || isSpeaking) ? 3 : 1,
                ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Positioned.fill(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500),
                  child: hasVideo
                      ? VideoTrackRenderer(
                          activeVideoTrack!,
                          fit: VideoViewFit.contain,
                          mirrorMode: isMe ? VideoViewMirrorMode.mirror : VideoViewMirrorMode.off,
                          key: ValueKey(activeVideoTrack.sid),
                        )
                      : _buildAvatar(displayName, isMainStage),
                ),
              ),

              if (isSpotlighted)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.amber.withOpacity(0.1), Colors.transparent, Colors.black.withOpacity(0.4)],
                      ),
                    ),
                  ),
                ),

              Positioned(bottom: 10, left: 10, child: _buildNameLabel(displayName, isMe, participant.isMicrophoneEnabled(), isScreen)),

              Positioned(
                top: 10,
                right: 10,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isHandRaised) _buildCircleIcon(Icons.front_hand, Colors.orange),
                    if (isHandRaised) const SizedBox(width: 8),
                    if (isSpotlighted) _buildBadge("مشاركة مميزة", Colors.amber.shade700, Icons.star),
                    if (isSpotlighted) const SizedBox(width: 8),
                    if (isRoomCam) _buildBadge(displayName, Colors.teal, Icons.videocam)
                    else if (isTeacher) _buildBadge(isScreen ? "شاشة المعلم" : "المعلم", Colors.blueAccent, isScreen ? Icons.desktop_windows : Icons.school),
                  ],
                ),
              ),

              if (isSpeaking && !isScreen) Positioned(bottom: 10, right: 10, child: _AudioVisualizer()),
              if (isSpeaking) Positioned(top: 0, left: 0, right: 0, child: Container(height: 3, color: Colors.greenAccent)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAvatar(String name, bool isMain) {
    String initial = name.isNotEmpty ? name.substring(0, 1).toUpperCase() : "?";
    return Container(
      color: const Color(0xFF0F1014),
      child: Center(
        child: CircleAvatar(
          radius: isMain ? 50 : 25,
          backgroundColor: Colors.blueAccent.withOpacity(0.1),
          child: Text(initial, style: TextStyle(color: Colors.blueAccent, fontSize: isMain ? 36 : 18, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _buildNameLabel(String name, bool isMe, bool isMicOn, bool isScreen) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          color: Colors.black26,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isScreen) ...[
                Icon(isMicOn ? Icons.mic : Icons.mic_off, color: isMicOn ? Colors.white70 : Colors.redAccent, size: 12),
                const SizedBox(width: 4),
              ],
              Flexible(child: Text(isMe ? "$name (أنت)" : (isScreen ? "شاشة $name" : name), style: const TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'Cairo'), overflow: TextOverflow.ellipsis)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.9), borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 10),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
        ],
      ),
    );
  }

  Widget _buildCircleIcon(IconData icon, Color color) {
    return Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: color, shape: BoxShape.circle), child: Icon(icon, color: Colors.white, size: 12));
  }
}

class _AudioVisualizer extends StatefulWidget {
  @override
  State<_AudioVisualizer> createState() => _AudioVisualizerState();
}

class _AudioVisualizerState extends State<_AudioVisualizer> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<double> _heights = [0.2, 0.8, 0.4, 0.7, 0.3];
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 500))..repeat(reverse: true);
  }
  @override
  void dispose() { _controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(_heights.length, (index) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 1),
              width: 2,
              height: 12 * (_heights[index] * _controller.value + 0.2),
              decoration: BoxDecoration(color: Colors.greenAccent, borderRadius: BorderRadius.circular(1)),
            );
          }),
        );
      },
    );
  }
}
