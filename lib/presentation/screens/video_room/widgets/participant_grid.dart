import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/utils/responsive.dart';
import '../utils/classroom_participant_utils.dart';
import '../video_room_controller.dart';

int _gridCrossAxisCount(BuildContext context) {
  final width = MediaQuery.of(context).size.width;
  if (width >= 1100) return 4;
  if (width >= 850) return 3;
  return 2;
}

class ParticipantGrid extends StatelessWidget {
  const ParticipantGrid({super.key});
  @override
  Widget build(BuildContext context) {
    return Selector<VideoRoomController, Room?>(
      selector: (_, c) => c.room,
      builder: (context, room, _) {
        if (room == null) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.blue),
          );
        }
        return Selector<VideoRoomController, (String, bool)>(
          selector: (_, c) => (c.selectedChannel, c.isVideoWallMode),
          builder: (context, layoutState, _) {
            return ListenableBuilder(
              listenable: room,
              builder: (context, _) {
                final controller = context.read<VideoRoomController>();
                final participants = ClassroomParticipantUtils.allFromRoom(
                  room,
                );
                final screenSharer =
                    ClassroomParticipantUtils.findScreenSharingParticipant(
                  participants,
                );
                if (!controller.isTeacher) {
                  return _buildStudentLayout(
                    context,
                    participants,
                    screenSharer,
                    layoutState.$1,
                  );
                }
                if (layoutState.$2) {
                  return _buildTeacherVideoWall(
                    context,
                    controller,
                    participants,
                    screenSharer,
                  );
                }
                return _buildProfessionalTeacherLayout(
                  context,
                  controller,
                  participants,
                  screenSharer,
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildProfessionalTeacherLayout(
    BuildContext context,
    VideoRoomController controller,
    List<Participant> allParticipants,
    Participant? screenSharingParticipant,
  ) {
    final resolution = ClassroomParticipantUtils.resolveMainStage(
      participants: allParticipants,
      selectedChannel: controller.selectedChannel,
    );
    final mainParticipant = resolution?.participant;
    if (mainParticipant == null) return _buildWaitingState();
    final otherParticipants =
        allParticipants
            .where(
              (p) =>
                  p.identity != mainParticipant.identity &&
                  !p.identity.contains('room-cam-') &&
                  !p.identity.contains('roomcam'),
            )
            .toList();
    return Container(
      color: const Color(0xFF0F1014),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: ParticipantTile(
              key: ValueKey('teacher_main_${mainParticipant.identity}'),
              participant: mainParticipant,
              isMainStage: true,
              forceShowScreen: resolution!.isScreenShare,
            ),
          ),
          if (otherParticipants.isNotEmpty) ...[
            // إزاحة ناحية اليسار (في العربية) لزيادة المسافة بين الطالب والمعلم
            const SizedBox(width: 32),
            Container(
              width:
                  Responsive.isDesktop(context)
                      ? 260
                      : Responsive.isTablet(context)
                      ? 180
                      : 120,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: otherParticipants.length,
                itemBuilder:
                    (context, index) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: AspectRatio(
                        aspectRatio: 1.5,
                        child: ParticipantTile(
                          participant: otherParticipants[index],
                          isMainStage: false,
                        ),
                      ),
                    ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWaitingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.blue, strokeWidth: 2),
          SizedBox(height: 16),
          Text(
            'جاري الاتصال بالقاعة...',
            style: TextStyle(color: Colors.white54, fontFamily: 'Cairo'),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentLayout(
    BuildContext context,
    List<Participant> allParticipants,
    Participant? screenSharingParticipant,
    String selectedChannel,
  ) {
    if (screenSharingParticipant != null) {
      final channelParticipant =
          ClassroomParticipantUtils.findChannelParticipant(
            allParticipants,
            selectedChannel,
          );
      return _buildHybridStudentLayout(
        context,
        screenSharingParticipant,
        channelParticipant,
      );
    }
    final resolution = ClassroomParticipantUtils.resolveMainStage(
      participants: allParticipants,
      selectedChannel: selectedChannel,
    );
    if (resolution != null) {
      return ParticipantTile(
        key: ValueKey('student_main_${resolution.participant.identity}'),
        participant: resolution.participant,
        isMainStage: true,
        forceShowScreen: resolution.isScreenShare,
      );
    }
    return allParticipants.isNotEmpty
        ? ParticipantTile(participant: allParticipants.first, isMainStage: true)
        : _buildWaitingState();
  }

  Widget _buildTeacherVideoWall(
    BuildContext context,
    VideoRoomController controller,
    List<Participant> allParticipants,
    Participant? screenSharingParticipant,
  ) {
    return Selector<VideoRoomController, String>(
      selector: (_, c) => c.seatsLayoutKey,
      builder: (context, _, __) {
        final seats = controller.seats;
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.4),
                border: const Border(
                  bottom: BorderSide(color: Colors.white10, width: 0.5),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.grid_view_rounded,
                    color: Colors.blue,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'وضع جدار الفيديو - توزيع المقاعد',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Cairo',
                      fontSize: 13,
                    ),
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: () => controller.toggleVideoWallMode(),
                    icon: const Icon(Icons.close, size: 14),
                    label: const Text(
                      'إغلاق العرض',
                      style: TextStyle(fontFamily: 'Cairo', fontSize: 11),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.withOpacity(0.1),
                      foregroundColor: Colors.redAccent,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Row(
                children: [
                  if (screenSharingParticipant != null ||
                      controller.isWhiteboardOpen)
                    Expanded(
                      flex: 2,
                      child: Container(
                        margin: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.withOpacity(0.1),
                              blurRadius: 30,
                              spreadRadius: -10,
                            ),
                          ],
                          border: Border.all(
                            color: Colors.blue.withOpacity(0.3),
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child:
                              screenSharingParticipant != null
                                  ? ParticipantTile(
                                    participant: screenSharingParticipant,
                                    isMainStage: true,
                                    forceShowScreen: true,
                                  )
                                  : const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  Expanded(
                    flex: 3,
                    child: GridView.builder(
                      padding: const EdgeInsets.all(12),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: _gridCrossAxisCount(context),
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.5,
                      ),
                      itemCount: seats.length,
                      itemBuilder: (context, index) {
                        final seat = seats[index];
                        final String? studentId = seat['student_id'] as String?;
                        Participant? participant;
                        if (studentId != null) {
                          participant =
                              allParticipants
                                  .where(
                                    (p) => p.identity.startsWith(studentId),
                                  )
                                  .firstOrNull;
                        }
                        if (participant != null) {
                          return ParticipantTile(
                            key: ValueKey(
                              'seat_${seat['id']}_${participant.identity}',
                            ),
                            participant: participant,
                            isMainStage: false,
                            displayName:
                                seat['student_name'] as String? ??
                                participant.name,
                          );
                        }
                        return _buildEmptySeat(
                          seat['seat_number'] as int,
                          seat['student_name'] as String?,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmptySeat(int number, String? assignedName) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1B22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.03),
            Colors.transparent,
          ],
        ),
      ),
      child: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.person_add_alt_1_rounded,
                  color: Colors.white.withOpacity(0.05),
                  size: 32,
                ),
                const SizedBox(height: 6),
                Text(
                  assignedName ?? 'مقعد متاح',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.2),
                    fontSize: 10,
                    fontFamily: 'Cairo',
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 10,
            right: 12,
            child: Text(
              '$number',
              style: TextStyle(
                color: Colors.white.withOpacity(0.12),
                fontSize: 20,
                fontWeight: FontWeight.w900,
                fontFamily: 'Cairo',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHybridStudentLayout(
    BuildContext context,
    Participant screenPart,
    Participant? camPart,
  ) {
    final controller = context.read<VideoRoomController>();
    return Stack(
      children: [
        Positioned.fill(
          child: ParticipantTile(
            participant: screenPart,
            isMainStage: true,
            forceShowScreen: true,
          ),
        ),
        if (camPart != null &&
            ClassroomParticipantUtils.hasCameraVideo(camPart))
          Positioned(
            top: 20,
            right: 20,
            child: GestureDetector(
              onTap: () => controller.cycleRoomCamera(),
              child: Container(
                width:
                    Responsive.isDesktop(context)
                        ? 260
                        : Responsive.isTablet(context)
                        ? 200
                        : 130,
                height:
                    Responsive.isDesktop(context)
                        ? 150
                        : Responsive.isTablet(context)
                        ? 115
                        : 75,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: Colors.blue.withOpacity(0.5),
                    width: 2,
                  ),
                  boxShadow: const [
                    BoxShadow(color: Colors.black54, blurRadius: 10),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: ParticipantTile(
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
}

class ParticipantTile extends StatefulWidget {
  final Participant participant;
  final bool isMainStage;
  final bool? forceHandRaised;
  final bool? forceShowScreen;
  final String? displayName;

  static final Map<String, String?> _avatarCache = {};
  static final Set<String> _loadingIds = {};

  const ParticipantTile({
    super.key,
    required this.participant,
    required this.isMainStage,
    this.forceHandRaised,
    this.forceShowScreen,
    this.displayName,
  });

  @override
  State<ParticipantTile> createState() => _ParticipantTileState();
}

class _ParticipantTileState extends State<ParticipantTile> {
  bool _showVideo = false;
  Timer? _delayTimer;
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _startDelay();
    _resolveAvatar();
  }

  @override
  void didUpdateWidget(ParticipantTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.participant.identity != oldWidget.participant.identity ||
        widget.participant.metadata != oldWidget.participant.metadata) {
      _startDelay();
      _resolveAvatar();
    }
  }

  String _extractUserId(String identity) {
    if (identity.startsWith('teacher_')) {
      return identity.substring('teacher_'.length);
    }
    if (identity.contains('_')) {
      return identity.split('_').first;
    }
    return identity;
  }

  String? _getAvatarFromMetadata(String? metadata) {
    if (metadata == null || metadata.isEmpty) return null;
    if (metadata.startsWith('http://') || metadata.startsWith('https://')) {
      return metadata;
    }
    try {
      final decoded = jsonDecode(metadata);
      if (decoded is Map && decoded.containsKey('avatar_url')) {
        return decoded['avatar_url'] as String?;
      }
    } catch (_) {}
    return null;
  }

  void _resolveAvatar() {
    final metaAvatar = _getAvatarFromMetadata(widget.participant.metadata);
    if (metaAvatar != null && metaAvatar.isNotEmpty) {
      setState(() {
        _avatarUrl = metaAvatar;
      });
      return;
    }

    final identity = widget.participant.identity;
    if (identity.contains('room-cam-') ||
        identity.startsWith('roomcam_') ||
        identity.startsWith('wall_')) {
      setState(() {
        _avatarUrl = null;
      });
      return;
    }

    final targetUserId = _extractUserId(identity);

    if (ParticipantTile._avatarCache.containsKey(targetUserId)) {
      setState(() {
        _avatarUrl = ParticipantTile._avatarCache[targetUserId];
      });
      return;
    }

    if (ParticipantTile._loadingIds.contains(targetUserId)) {
      return;
    }

    ParticipantTile._loadingIds.add(targetUserId);

    Supabase.instance.client
        .from('profiles')
        .select('avatar_url')
        .eq('id', targetUserId)
        .maybeSingle()
        .then((res) {
          String? url;
          if (res != null) {
            url = res['avatar_url'] as String?;
          }
          ParticipantTile._avatarCache[targetUserId] = url;
          ParticipantTile._loadingIds.remove(targetUserId);
          if (mounted) {
            setState(() {
              _avatarUrl = url;
            });
          }
        })
        .catchError((e) {
          ParticipantTile._loadingIds.remove(targetUserId);
          debugPrint("Error loading avatar: $e");
        });
  }

  void _startDelay() {
    _delayTimer?.cancel();
    _showVideo = false;
    _delayTimer = Timer(const Duration(milliseconds: 150), () {
      if (mounted) {
        setState(() {
          _showVideo = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isHandRaised = widget.forceHandRaised ?? false;
    if (widget.forceHandRaised == null) {
      try {
        isHandRaised = context.select<VideoRoomController, bool>(
          (c) => c.remoteHandStates[widget.participant.identity] ?? false,
        );
      } catch (_) {}
    }
    bool isSpotlighted = false;
    try {
      isSpotlighted = context.select<VideoRoomController, bool>(
        (c) => c.spotlightUserId == widget.participant.identity,
      );
    } catch (_) {}
    return ListenableBuilder(
      listenable: widget.participant,
      builder: (context, _) {
        final bool isMe = widget.participant is LocalParticipant;
        final bool isTeacher = widget.participant.identity
            .toLowerCase()
            .contains('teacher');
        final bool isRoomCam = widget.participant.identity.contains(
          'room-cam-',
        );
        final bool isSpeaking = widget.participant.isSpeaking;
        String nameToShow = widget.displayName ?? widget.participant.name ?? '';
        if (nameToShow.isEmpty) {
          nameToShow = widget.participant.identity
              .replaceAll('teacher_', '')
              .split('_')
              .first;
        }
        if (nameToShow.isEmpty) nameToShow = 'مشارك';
        VideoTrack? activeVideoTrack;
        var isScreen = false;
        if (widget.forceShowScreen == true) {
          final pub =
              widget.participant.videoTrackPublications
                  .where((p) => p.isScreenShare)
                  .firstOrNull;
          if (pub != null && (isMe || pub.subscribed)) {
            activeVideoTrack = pub.track as VideoTrack?;
          }
          isScreen = true;
        } else if (widget.forceShowScreen == false) {
          final pub =
              widget.participant.videoTrackPublications
                  .where((p) => !p.isScreenShare)
                  .firstOrNull;
          if (pub != null && (isMe || pub.subscribed)) {
            activeVideoTrack = pub.track as VideoTrack?;
          }
        } else {
          final screenPub =
              widget.participant.videoTrackPublications
                  .where((p) => p.isScreenShare)
                  .firstOrNull;
          if (screenPub != null &&
              (isMe || screenPub.subscribed) &&
              screenPub.track != null) {
            activeVideoTrack = screenPub.track as VideoTrack?;
            isScreen = true;
          } else {
            final camPub =
                widget.participant.videoTrackPublications
                    .where((p) => !p.isScreenShare)
                    .firstOrNull;
            if (camPub != null &&
                (isMe || camPub.subscribed) &&
                camPub.track != null) {
              activeVideoTrack = camPub.track as VideoTrack?;
            }
          }
        }
        final bool hasVideo =
            _showVideo &&
            activeVideoTrack != null &&
            (isScreen
                ? ClassroomParticipantUtils.hasScreenShareVideo(
                  widget.participant,
                )
                : ClassroomParticipantUtils.hasCameraVideo(
                  widget.participant,
                ));
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          decoration: BoxDecoration(
            borderRadius:
                widget.isMainStage ? BorderRadius.zero : BorderRadius.circular(16),
            color: const Color(0xFF131418),
            border:
                widget.isMainStage
                    ? null
                    : Border.all(
                      color:
                          isSpotlighted
                              ? Colors.amber
                              : (isSpeaking
                                  ? Colors.greenAccent
                                  : Colors.white.withOpacity(0.1)),
                      width: (isSpotlighted || isSpeaking) ? 3 : 1.5,
                    ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Positioned.fill(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child:
                      hasVideo
                          ? VideoTrackRenderer(
                            activeVideoTrack!,
                            fit: VideoViewFit.contain,
                            mirrorMode:
                                isMe
                                    ? VideoViewMirrorMode.mirror
                                    : VideoViewMirrorMode.off,
                            key: ValueKey(activeVideoTrack.sid),
                          )
                          : (() {
                            final metaAvatar = _getAvatarFromMetadata(
                              widget.participant.metadata,
                            );
                            final String? finalAvatar =
                                (metaAvatar != null && metaAvatar.isNotEmpty)
                                    ? metaAvatar
                                    : _avatarUrl;
                            return _buildAvatar(
                              nameToShow,
                              widget.isMainStage,
                              finalAvatar,
                            );
                          })(),
                ),
              ),
              if (isSpotlighted)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.amber.withOpacity(0.1),
                          Colors.transparent,
                          Colors.black.withOpacity(0.4),
                        ],
                      ),
                    ),
                  ),
                ),
              Positioned(
                bottom: 10,
                left: 10,
                child: _buildNameLabel(
                  nameToShow,
                  isMe,
                  widget.participant.isMicrophoneEnabled(),
                  isScreen,
                ),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isHandRaised)
                      _buildCircleIcon(Icons.front_hand, Colors.orange),
                    if (isHandRaised) const SizedBox(width: 8),
                    if (isSpotlighted)
                      _buildBadge(
                        'مشاركة مميزة',
                        Colors.amber.shade700,
                        Icons.star,
                      ),
                    if (isSpotlighted) const SizedBox(width: 8),
                    if (isRoomCam)
                      _buildBadge(nameToShow, Colors.teal, Icons.videocam)
                    else if (isTeacher)
                      _buildBadge(
                        isScreen ? 'شاشة المعلم' : 'المعلم',
                        Colors.blueAccent,
                        isScreen ? Icons.desktop_windows : Icons.school,
                      ),
                  ],
                ),
              ),
              if (isSpeaking && !isScreen)
                Positioned(bottom: 10, right: 10, child: _AudioVisualizer()),
              if (isSpeaking)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(height: 3, color: Colors.greenAccent),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAvatar(String name, bool isMain, String? avatarUrl) {
    final initial = name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?';
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F1014),
        gradient: RadialGradient(
          colors: [
            Colors.blueAccent.withOpacity(0.05),
            Colors.transparent,
          ],
        ),
      ),
      child: Center(
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.blueAccent.withOpacity(0.1),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: CircleAvatar(
            radius: isMain ? 55 : 30,
            backgroundColor: const Color(0xFF1A1B1F),
            backgroundImage:
                (avatarUrl != null && avatarUrl.isNotEmpty)
                    ? NetworkImage(avatarUrl)
                    : null,
            onBackgroundImageError:
                (avatarUrl != null && avatarUrl.isNotEmpty)
                    ? (exception, stackTrace) {
                      debugPrint("Error loading avatar image: $exception");
                    }
                    : null,
            child:
                (avatarUrl != null && avatarUrl.isNotEmpty)
                    ? null
                    : Text(
                      initial,
                      style: TextStyle(
                        color: Colors.blueAccent,
                        fontSize: isMain ? 42 : 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
          ),
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
                Icon(
                  isMicOn ? Icons.mic : Icons.mic_off,
                  color: isMicOn ? Colors.white70 : Colors.redAccent,
                  size: 12,
                ),
                const SizedBox(width: 4),
              ],
              Flexible(
                child: Text(
                  isMe ? '$name (أنت)' : (isScreen ? 'شاشة $name' : name),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontFamily: 'Cairo',
                  ),
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
      decoration: BoxDecoration(
        color: color.withOpacity(0.9),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 10),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              fontFamily: 'Cairo',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCircleIcon(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Icon(icon, color: Colors.white, size: 12),
    );
  }
}

class _AudioVisualizer extends StatefulWidget {
  @override
  State<_AudioVisualizer> createState() => _AudioVisualizerState();
}

class _AudioVisualizerState extends State<_AudioVisualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<double> _heights = [0.2, 0.8, 0.4, 0.7, 0.3];
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

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
              decoration: BoxDecoration(
                color: Colors.greenAccent,
                borderRadius: BorderRadius.circular(1),
              ),
            );
          }),
        );
      },
    );
  }
}
