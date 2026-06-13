import 'package:livekit_client/livekit_client.dart';

/// Result of resolving who appears on the main stage and whether the teacher
/// floating card should be visible.
class MainStageResolution {
  final Participant participant;
  final bool isScreenShare;
  final bool showTeacherFloatingCard;

  const MainStageResolution({
    required this.participant,
    required this.isScreenShare,
    required this.showTeacherFloatingCard,
  });
}

/// Single source of truth for virtual-classroom participant selection.
///
/// Priority: [Screen Share] > [Active Room Cam] > [Teacher (default)]
class ClassroomParticipantUtils {
  ClassroomParticipantUtils._();

  static List<Participant> allFromRoom(Room? room) => [
        if (room?.localParticipant != null) room!.localParticipant!,
        ...room?.remoteParticipants.values ?? [],
      ];

  static Participant? findTeacher(List<Participant> participants) {
    return participants
        .where((p) =>
            p.identity.startsWith('teacher_') ||
            p.identity.toLowerCase().contains('teacher'))
        .firstOrNull;
  }

  static Participant? findChannelParticipant(
    List<Participant> participants,
    String channelId,
  ) {
    if (channelId == 'whiteboard') return null;
    return participants.where((p) => p.identity.contains(channelId)).firstOrNull;
  }

  static bool hasCameraVideo(Participant participant) {
    if (!participant.isCameraEnabled()) return false;
    return participant.videoTrackPublications.any((pub) =>
        !pub.isScreenShare &&
        pub.track != null &&
        (participant is LocalParticipant || pub.subscribed));
  }

  static bool hasScreenShareVideo(Participant participant) {
    if (!participant.isScreenShareEnabled()) return false;
    return participant.videoTrackPublications.any((pub) =>
        pub.isScreenShare &&
        pub.track != null &&
        (participant is LocalParticipant || pub.subscribed));
  }

  static Participant? findScreenSharingParticipant(
    List<Participant> participants,
  ) {
    return participants.where(hasScreenShareVideo).firstOrNull;
  }

  static bool isRoomCamActive(Participant? participant) {
    if (participant == null) return false;
    return hasCameraVideo(participant);
  }

  /// Resolves main-stage content. Returns null only when [participants] is empty.
  static MainStageResolution? resolveMainStage({
    required List<Participant> participants,
    required String selectedChannel,
    bool isWhiteboardOpen = false,
  }) {
    if (participants.isEmpty) return null;

    final teacher = findTeacher(participants);
    final screenSharer = findScreenSharingParticipant(participants);
    final channelCam = findChannelParticipant(participants, selectedChannel);

    Participant? main;
    var isScreenShare = false;

    if (screenSharer != null) {
      main = screenSharer;
      isScreenShare = true;
    } else if (isRoomCamActive(channelCam)) {
      main = channelCam;
    } else if (teacher != null) {
      main = teacher;
    } else {
      main = participants
          .where((p) =>
              p is RemoteParticipant &&
              (hasCameraVideo(p) || hasScreenShareVideo(p)))
          .firstOrNull;
    }

    main ??= teacher ??
        participants.whereType<RemoteParticipant>().firstOrNull ??
        participants.first;

    final showFloating = shouldShowTeacherFloatingCard(
      participants: participants,
      selectedChannel: selectedChannel,
      isWhiteboardOpen: isWhiteboardOpen,
      mainParticipant: main,
    );

    return MainStageResolution(
      participant: main,
      isScreenShare: isScreenShare,
      showTeacherFloatingCard: showFloating,
    );
  }

  static bool shouldShowTeacherFloatingCard({
    required List<Participant> participants,
    required String selectedChannel,
    required bool isWhiteboardOpen,
    Participant? mainParticipant,
  }) {
    final teacher = findTeacher(participants);
    if (teacher == null) return false;
    if (isWhiteboardOpen) return true;

    final screenSharer = findScreenSharingParticipant(participants);
    if (screenSharer != null) return true;

    final channelCam = findChannelParticipant(participants, selectedChannel);
    if (isRoomCamActive(channelCam) && mainParticipant?.identity != teacher.identity) {
      return true;
    }

    return false;
  }

  static bool isStudentParticipant(Participant p, {String? localIdentity}) {
    return !p.identity.contains('room-cam-') &&
        !p.identity.contains('teacher_') &&
        p.identity != localIdentity;
  }
}
