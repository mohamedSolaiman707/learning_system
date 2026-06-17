import 'package:livekit_client/livekit_client.dart';


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

  static bool isTeacher(Participant participant) => participant.identity.startsWith('teacher_') || participant.identity.toLowerCase().contains('teacher');

  static bool isScreenShare(Participant participant) => participant.isScreenShareEnabled();

  static Participant? findChannelParticipant(
      List<Participant> participants,
      String channelId,
      ) {
    if (channelId == 'whiteboard') return null;
    final normalizedChannel = channelId.replaceAll(RegExp(r'[-_]'), '').toLowerCase();
    return participants.where((p) {
      final normalizedIdentity = p.identity.replaceAll(RegExp(r'[-_]'), '').toLowerCase();
      final normalizedName = (p.name ?? '').replaceAll(RegExp(r'[-_]'), '').toLowerCase();
      return normalizedIdentity.contains(normalizedChannel) || normalizedName.contains(normalizedChannel);
    }).firstOrNull;
  }

  static bool hasCameraVideo(Participant participant) {
    // We check if camera is enabled. In LiveKit, if it's enabled, a track should be available or upcoming.
    if (!participant.isCameraEnabled()) return false;

    // Check publications more carefully
    return participant.videoTrackPublications.any((pub) =>
    !pub.isScreenShare &&
        (participant is LocalParticipant || pub.subscribed || pub.track != null));
  }

  static bool hasScreenShareVideo(Participant participant) {
    if (!participant.isScreenShareEnabled()) return false;
    return participant.videoTrackPublications.any((pub) =>
    pub.isScreenShare &&
        (participant is LocalParticipant || pub.subscribed || pub.track != null));
  }

  static Participant? findScreenSharingParticipant(
      List<Participant> participants,
      ) {
    return participants.where(hasScreenShareVideo).firstOrNull;
  }

  static bool isRoomCamActive(Participant? participant) {
    if (participant == null) return false;
    // Room cams are considered active if they are transmitting video
    return hasCameraVideo(participant);
  }

  /// Resolves main-stage content with improved priority:
  /// 1. Screen Share (Priority 1)
  /// 2. Teacher (Priority 2) - Preferred if they exist, even if camera is off (shows avatar)
  /// 3. Selected Room Camera (Priority 3) - Only if actively streaming video
  /// 4. Any other participant with video
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

    // 1. أولوية مطلقة لمشاركة الشاشة
    if (screenSharer != null) {
      main = screenSharer;
      isScreenShare = true;
    }
    // 2. إذا تم اختيار قناة كاميرا قاعة وكانت نشطة
    else if (selectedChannel != 'teacher' && isRoomCamActive(channelCam)) {
      main = channelCam;
    }
    // 3. المدرس كخيار أساسي أو إذا تم اختياره
    else if (teacher != null) {
      main = teacher;
    }
    // 4. Fallback لأي مشترك آخر يبث فيديو
    else {
      main = participants
          .where((p) =>
      p is RemoteParticipant &&
          (hasCameraVideo(p) || hasScreenShareVideo(p)))
          .firstOrNull;
    }

    // Fallback النهائي جداً
    main ??= teacher ??
        participants.where((p) => !p.identity.contains('room-cam-') && !p.identity.contains('roomcam')).firstOrNull ??
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

    // دائماً نظهر المدرس في كارت عائم إذا كانت السبورة مفتوحة
    if (isWhiteboardOpen) return true;

    // إذا كان المعروض حالياً في الشاشة الرئيسية ليس المدرس (مثل شاشة مشاركة أو كاميرا قاعة)، نظهر المدرس عائماً
    if (mainParticipant != null && mainParticipant.identity != teacher.identity) {
      return true;
    }

    return false;
  }

  static bool isStudentParticipant(Participant p, {String? localIdentity}) {
    return !p.identity.contains('room-cam-') &&
        !p.identity.contains('roomcam') &&
        !p.identity.contains('teacher_') &&
        p.identity != localIdentity;
  }

  /// Returns participants matching a set of active channels.
  /// The returned map has channelId -> Participant? (null = offline/unavailable).
  static Map<String, Participant?> resolveMultiSource({
    required List<Participant> participants,
    required Set<String> activeChannels,
  }) {
    final Map<String, Participant?> result = {};
    for (final channelId in activeChannels) {
      if (channelId == 'whiteboard') {
        result[channelId] = null; // whiteboard is a local widget, not a participant
        continue;
      }
      if (channelId == 'screen-share') {
        result[channelId] = findScreenSharingParticipant(participants);
        continue;
      }
      if (channelId == 'teacher') {
        result[channelId] = findTeacher(participants);
        continue;
      }
      // Room cameras
      result[channelId] = findChannelParticipant(participants, channelId);
    }
    return result;
  }
}
