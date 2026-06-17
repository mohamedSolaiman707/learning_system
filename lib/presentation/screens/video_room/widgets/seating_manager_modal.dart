import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:livekit_client/livekit_client.dart';
import '../video_room_controller.dart';

/// نوع البيانات المنقولة أثناء الـ Drag
/// يمكن أن تكون:
///   - [_DragStudent]: سحب طالب من قائمة الانتظار
///   - [_DragSeat]: سحب مقعد محجوز (نقل بين شاشات)
class _DragStudent {
  final String studentId;
  final String studentName;
  const _DragStudent({required this.studentId, required this.studentName});
}

class _DragSeat {
  final int fromSeatNumber;
  final String studentId;
  final String studentName;
  const _DragSeat({
    required this.fromSeatNumber,
    required this.studentId,
    required this.studentName,
  });
}

typedef _DragData = Object; // _DragStudent | _DragSeat

/// Modal كامل الشاشة لتوزيع المقاعد على الشاشات
class SeatingManagerModal extends StatefulWidget {
  const SeatingManagerModal({super.key});

  /// يفتح الـ modal كـ dialog كامل الشاشة
  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<VideoRoomController>(),
        child: const SeatingManagerModal(),
      ),
    );
  }

  @override
  State<SeatingManagerModal> createState() => _SeatingManagerModalState();
}

class _SeatingManagerModalState extends State<SeatingManagerModal> {
  // مجموعة مقاعد يتم التحويم عليها حالياً
  final Set<int> _hoveredSeats = {};

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0D1117), Color(0xFF161B22)],
          ),
        ),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Column(
            children: [
              _buildTopBar(context),
              Expanded(
                child: Row(
                  children: [
                    _buildStudentsList(context),
                    const VerticalDivider(
                        color: Color(0xFF30363D), width: 1, thickness: 1),
                    Expanded(child: _buildScreensGrid(context)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── شريط العنوان العلوي ──────────────────────────────────────────
  Widget _buildTopBar(BuildContext context) {
    final ctrl = context.watch<VideoRoomController>();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        color: Color(0xFF161B22),
        border: Border(bottom: BorderSide(color: Color(0xFF30363D))),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF1F6FEB).withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.event_seat_rounded,
                color: Color(0xFF58A6FF), size: 22),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'مدير توزيع المقاعد',
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                '${ctrl.screenCount} شاشة — ${ctrl.seatsPerScreen} مقاعد/شاشة',
                style: const TextStyle(
                  color: Color(0xFF8B949E),
                  fontFamily: 'Cairo',
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const Spacer(),
          // زر التوزيع التلقائي
          _buildAutoAssignButton(context, ctrl),
          const SizedBox(width: 12),
          // زر الإغلاق
          InkWell(
            onTap: () => Navigator.of(context).pop(),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF30363D)),
              ),
              child: const Icon(Icons.close_rounded,
                  color: Color(0xFF8B949E), size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAutoAssignButton(
      BuildContext context, VideoRoomController ctrl) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      child: ElevatedButton.icon(
        onPressed: ctrl.isProcessing
            ? null
            : () async {
                await ctrl.autoAssignSeats();
              },
        icon: ctrl.isProcessing
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.auto_fix_high_rounded, size: 16),
        label: Text(
          ctrl.isProcessing ? 'جارٍ التوزيع...' : 'توزيع تلقائي',
          style: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF238636),
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFF238636).withOpacity(0.4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  // ─── قائمة الطلاب غير الموزعين (يسار) ───────────────────────────
  Widget _buildStudentsList(BuildContext context) {
    final ctrl = context.watch<VideoRoomController>();
    final room = ctrl.room;

    // الطلاب المتصلين (ليسوا معلمين أو كاميرات قاعة)
    final List<Participant> connectedStudents = room == null
        ? []
        : room.remoteParticipants.values
            .where((p) =>
                !p.identity.startsWith('wall_') &&
                !p.identity.toLowerCase().contains('teacher') &&
                !p.identity.contains('room-cam-'))
            .toList()
          ..sort((a, b) => (a.name).compareTo(b.name));

    // الطلاب الموزعين فعلاً
    final assignedIds = ctrl.seats
        .where((s) =>
            s['student_id'] != null &&
            (s['student_id'] as String).isNotEmpty)
        .map((s) => s['student_id'] as String)
        .toSet();

    // الطلاب غير الموزعين
    final unassigned = connectedStudents
        .where((p) => !assignedIds.any((id) => p.identity.contains(id)))
        .toList();

    return Container(
      width: 220,
      color: const Color(0xFF0D1117),
      child: Column(
        children: [
          // رأس القائمة
          Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFF21262D))),
            ),
            child: Row(
              children: [
                const Icon(Icons.people_alt_rounded,
                    color: Color(0xFF58A6FF), size: 16),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'الطلاب',
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1F6FEB).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${unassigned.length}',
                    style: const TextStyle(
                      color: Color(0xFF58A6FF),
                      fontFamily: 'Cairo',
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // تحذير لو محفيش طلاب غير موزعين
          if (unassigned.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_rounded,
                        color: const Color(0xFF238636).withOpacity(0.7),
                        size: 36),
                    const SizedBox(height: 8),
                    const Text(
                      'كل الطلاب\nموزعون ✅',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF8B949E),
                        fontFamily: 'Cairo',
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                itemCount: unassigned.length,
                itemBuilder: (context, i) {
                  final student = unassigned[i];
                  final studentId = student.identity.split('_').first;
                  final studentName = student.name.isNotEmpty
                      ? student.name
                      : student.identity;
                  final initial = studentName.isNotEmpty
                      ? studentName.substring(0, 1).toUpperCase()
                      : '?';

                  final dragData = _DragStudent(
                    studentId: studentId,
                    studentName: studentName,
                  );

                  return Draggable<_DragData>(
                    data: dragData,
                    feedback: _DraggingChip(label: studentName),
                    childWhenDragging: Opacity(
                      opacity: 0.35,
                      child: _StudentListItem(
                          initial: initial, name: studentName),
                    ),
                    child: _StudentListItem(initial: initial, name: studentName),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  // ─── شبكة الشاشات مع الـ Drag & Drop (يمين) ────────────────────
  Widget _buildScreensGrid(BuildContext context) {
    final ctrl = context.watch<VideoRoomController>();
    final zones = ctrl.screenZones;

    if (zones.isEmpty) {
      return const Center(
        child: Text('لا توجد شاشات',
            style: TextStyle(
                color: Color(0xFF8B949E), fontFamily: 'Cairo')),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _crossAxisCount(context),
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.7,
      ),
      itemCount: zones.length,
      itemBuilder: (context, index) {
        final zone = zones[index];
        return _buildScreenCard(context, ctrl, zone, index + 1);
      },
    );
  }

  int _crossAxisCount(BuildContext context) {
    final w = MediaQuery.of(context).size.width - 221; // exclude sidebar
    if (w >= 1200) return 5;
    if (w >= 900) return 4;
    if (w >= 600) return 3;
    return 2;
  }

  Widget _buildScreenCard(
    BuildContext context,
    VideoRoomController ctrl,
    String zone,
    int screenNumber,
  ) {
    final seats = ctrl.seats
        .where((s) => s['zone'] == zone)
        .toList()
      ..sort((a, b) =>
          (a['seat_number'] as int).compareTo(b['seat_number'] as int));

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Column(
        children: [
          // رأس الشاشة
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF21262D),
              borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
            ),
            child: Row(
              children: [
                const Icon(Icons.desktop_windows_rounded,
                    color: Color(0xFF58A6FF), size: 14),
                const SizedBox(width: 6),
                Text(
                  'شاشة $screenNumber',
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                // عداد المقاعد المحجوزة
                Text(
                  '${seats.where((s) => s['student_id'] != null && (s['student_id'] as String).isNotEmpty).length}/${seats.length}',
                  style: const TextStyle(
                    color: Color(0xFF8B949E),
                    fontFamily: 'Cairo',
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          // قائمة المقاعد
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(6),
              itemCount: seats.length,
              itemBuilder: (context, i) {
                final seat = seats[i];
                return _buildSeatTile(context, ctrl, seat);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeatTile(
    BuildContext context,
    VideoRoomController ctrl,
    Map<String, dynamic> seat,
  ) {
    final int seatNum = seat['seat_number'] as int;
    final String? studentId = seat['student_id'] as String?;
    final String? studentName = seat['student_name'] as String?;
    final bool isOccupied = studentId != null && studentId.isNotEmpty;
    final bool isHovered = _hoveredSeats.contains(seatNum);

    if (!isOccupied) {
      // مقعد فارغ — DragTarget فقط
      return DragTarget<_DragData>(
        onWillAcceptWithDetails: (details) {
          setState(() => _hoveredSeats.add(seatNum));
          return true;
        },
        onLeave: (_) => setState(() => _hoveredSeats.remove(seatNum)),
        onAcceptWithDetails: (details) {
          setState(() => _hoveredSeats.remove(seatNum));
          final data = details.data;
          if (data is _DragStudent) {
            ctrl.assignStudentToSeat(
              seatNumber: seatNum,
              studentId: data.studentId,
              studentName: data.studentName,
            );
          } else if (data is _DragSeat) {
            ctrl.moveSeat(data.fromSeatNumber, seatNum);
          }
        },
        builder: (ctx, candidates, _) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.only(bottom: 4),
            height: 44,
            decoration: BoxDecoration(
              color: (isHovered || candidates.isNotEmpty)
                  ? const Color(0xFF1F6FEB).withOpacity(0.15)
                  : const Color(0xFF0D1117).withOpacity(0.5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: (isHovered || candidates.isNotEmpty)
                    ? const Color(0xFF1F6FEB)
                    : const Color(0xFF21262D),
                width: (isHovered || candidates.isNotEmpty) ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  (isHovered || candidates.isNotEmpty)
                      ? Icons.add_circle_rounded
                      : Icons.add_circle_outline_rounded,
                  color: (isHovered || candidates.isNotEmpty)
                      ? const Color(0xFF1F6FEB)
                      : const Color(0xFF30363D),
                  size: 14,
                ),
                const SizedBox(width: 4),
                Text(
                  'مقعد $seatNum',
                  style: TextStyle(
                    color: (isHovered || candidates.isNotEmpty)
                        ? const Color(0xFF58A6FF)
                        : const Color(0xFF484F58),
                    fontFamily: 'Cairo',
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          );
        },
      );
    }

    // مقعد محجوز — Draggable + DragTarget
    final dragData = _DragSeat(
      fromSeatNumber: seatNum,
      studentId: studentId,
      studentName: studentName ?? 'طالب',
    );

    final initial = (studentName != null && studentName.isNotEmpty)
        ? studentName.substring(0, 1).toUpperCase()
        : '?';

    final seatWidget = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      margin: const EdgeInsets.only(bottom: 4),
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: isHovered
            ? const Color(0xFF1F6FEB).withOpacity(0.25)
            : const Color(0xFF1F6FEB).withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isHovered
              ? const Color(0xFF1F6FEB)
              : const Color(0xFF1F6FEB).withOpacity(0.3),
          width: isHovered ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: const Color(0xFF1F6FEB).withOpacity(0.2),
            child: Text(
              initial,
              style: const TextStyle(
                  color: Color(0xFF58A6FF),
                  fontSize: 10,
                  fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              studentName ?? 'طالب',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'Cairo',
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Icon(Icons.drag_indicator_rounded,
              color: Color(0xFF8B949E), size: 14),
        ],
      ),
    );

    return DragTarget<_DragData>(
      onWillAcceptWithDetails: (details) {
        // لا نقبل نفس المقعد على نفسه
        if (details.data is _DragSeat &&
            (details.data as _DragSeat).fromSeatNumber == seatNum) {
          return false;
        }
        setState(() => _hoveredSeats.add(seatNum));
        return true;
      },
      onLeave: (_) => setState(() => _hoveredSeats.remove(seatNum)),
      onAcceptWithDetails: (details) {
        setState(() => _hoveredSeats.remove(seatNum));
        final data = details.data;
        if (data is _DragStudent) {
          ctrl.assignStudentToSeat(
            seatNumber: seatNum,
            studentId: data.studentId,
            studentName: data.studentName,
          );
        } else if (data is _DragSeat) {
          ctrl.moveSeat(data.fromSeatNumber, seatNum);
        }
      },
      builder: (ctx, candidates, _) {
        return Draggable<_DragData>(
          data: dragData,
          feedback: _DraggingChip(label: studentName ?? 'طالب'),
          childWhenDragging: Opacity(opacity: 0.3, child: seatWidget),
          child: GestureDetector(
            onLongPress: () => _showSeatOptions(context, ctrl, seatNum, studentName),
            child: candidates.isNotEmpty
                ? Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: const Color(0xFF1F6FEB), width: 2),
                    ),
                    child: seatWidget,
                  )
                : seatWidget,
          ),
        );
      },
    );
  }

  /// خيارات المقعد عند الضغط المطوّل
  void _showSeatOptions(
    BuildContext context,
    VideoRoomController ctrl,
    int seatNum,
    String? studentName,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161B22),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: const Color(0xFF30363D),
                    borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 16),
              Text(
                studentName ?? 'طالب',
                style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.bold,
                    fontSize: 16),
              ),
              Text(
                'مقعد $seatNum',
                style: const TextStyle(
                    color: Color(0xFF8B949E),
                    fontFamily: 'Cairo',
                    fontSize: 13),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.person_remove_rounded,
                    color: Color(0xFFDA3633)),
                title: const Text('إزالة من المقعد',
                    style: TextStyle(
                        color: Color(0xFFDA3633), fontFamily: 'Cairo')),
                onTap: () {
                  Navigator.pop(context);
                  ctrl.clearSeat(seatNum);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Widgets مساعدة ───────────────────────────────────────────────

class _StudentListItem extends StatelessWidget {
  final String initial;
  final String name;
  const _StudentListItem({required this.initial, required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF21262D),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: const Color(0xFF1F6FEB).withOpacity(0.15),
            child: Text(
              initial,
              style: const TextStyle(
                  color: Color(0xFF58A6FF),
                  fontSize: 12,
                  fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              name,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'Cairo',
                fontSize: 12,
              ),
            ),
          ),
          const Icon(Icons.drag_indicator_rounded,
              color: Color(0xFF484F58), size: 16),
        ],
      ),
    );
  }
}

class _DraggingChip extends StatelessWidget {
  final String label;
  const _DraggingChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1F6FEB),
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(color: Colors.black54, blurRadius: 12, spreadRadius: 1),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.person_rounded, color: Colors.white, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'Cairo',
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
