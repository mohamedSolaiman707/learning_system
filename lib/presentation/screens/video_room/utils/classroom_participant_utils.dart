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

  /// Resolves main-stage content with improved priority:
  /// 1. Screen Share
  /// 2. Teacher with Camera Video (Priority over Room Cams)
  /// 3. Selected Room Camera (if active)
  /// 4. Teacher Avatar (Default)
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

    // 1. أولوية قصوى لمشاركة الشاشة
    if (screenSharer != null) {
      main = screenSharer;
      isScreenShare = true;
    } 
    // 2. فيديو المدرس (إذا كان مفعلاً) - لضمان ظهوره للطالب فوراً
    else if (teacher != null && hasCameraVideo(teacher)) {
      main = teacher;
    }

    // 3. كاميرا القاعة المختارة (إذا كانت تبث فيديو ولم يكن المدرس فاتح كاميرا)
    else if (isRoomCamActive(channelCam)) {
      main = channelCam;
    } 
    // 4. المدرس كخيار افتراضي (Avatar)
    else if (teacher != null) {
      main = teacher;
    }
    // 5. أي مشترك آخر يبث فيديو كخيار احتياطي
    else {
      main = participants.first;
    }

    // Fallback النهائي جداً
    main ??= teacher ??
        participants.where((p) => !p.identity.contains('room-cam-')).firstOrNull ??
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

    if (mainParticipant != null && mainParticipant.identity != teacher.identity) {
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
