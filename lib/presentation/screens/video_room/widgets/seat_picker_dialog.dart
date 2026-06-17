import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../video_room_controller.dart';
import 'dart:ui';

class SeatPickerDialog extends StatefulWidget {
  const SeatPickerDialog({super.key});

  @override
  State<SeatPickerDialog> createState() => _SeatPickerDialogState();
}

class _SeatPickerDialogState extends State<SeatPickerDialog> {
  int? _selectedSeat;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctrl = context.read<VideoRoomController>();
      if (ctrl.seats.isEmpty) {
        ctrl.loadAndExpandSeats();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<VideoRoomController>();
    final seats = controller.seats;
    final screenZones = controller.screenZones;
    final screenCount = controller.screenCount;

    if (seats.isEmpty) {
      return Dialog(
        backgroundColor: const Color(0xFF131418),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Container(
          width: 400,
          height: 300,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.blue.withOpacity(0.1)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Colors.blue, strokeWidth: 3),
              const SizedBox(height: 24),
              const Text(
                "جاري تجهيز خريطة القاعة...",
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'Cairo',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "يرجى الانتظار لحظة",
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontFamily: 'Cairo',
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: const Color(0xFF0F1014),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000, maxHeight: 800),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF1A1B22),
                  const Color(0xFF0F1014),
                ],
              ),
            ),
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.event_seat_rounded, color: Colors.blue),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "اختر مكانك المفضل",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              fontFamily: 'Cairo',
                            ),
                          ),
                          Text(
                            "سيتم عرض صورتك للمعلم في هذا الموقع المختار",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 14,
                              fontFamily: 'Cairo',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Virtual Stage Indicator
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.withOpacity(0.2)),
                  ),
                  child: const Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.school_rounded, color: Colors.blue, size: 18),
                        SizedBox(width: 10),
                        Text(
                          "منصة المعلم (أمامك مباشرة)",
                          style: TextStyle(
                            color: Colors.blue,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Cairo',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Grid of Screens
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;
                      int cols = 3;
                      if (width >= 850) cols = 3;
                      else if (width >= 600) cols = 2;
                      else cols = 1;
                      
                      final columns = cols > screenCount ? screenCount : cols;
                      final cardWidth = (width - (16 * (columns - 1))) / columns;

                      return SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Wrap(
                          spacing: 16,
                          runSpacing: 24,
                          alignment: WrapAlignment.center,
                          children: List.generate(screenCount, (index) {
                            final zone = screenZones[index];
                            final zoneSeats = seats.where((s) => s['zone'] == zone).toList()
                              ..sort((a, b) => (a['seat_number'] as int).compareTo(b['seat_number'] as int));

                            return SizedBox(
                              width: cardWidth,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Screen Header Look
                                  Container(
                                    width: double.infinity,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF25262B),
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                                    ),
                                    child: Center(
                                      child: Text(
                                        "شاشة عرض ${index + 1}",
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'Cairo',
                                        ),
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF131418),
                                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                                    ),
                                    child: GridView.count(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      crossAxisCount: 2,
                                      mainAxisSpacing: 10,
                                      crossAxisSpacing: 10,
                                      childAspectRatio: 1.8,
                                      children: zoneSeats.map((seat) {
                                        final seatNum = seat['seat_number'] as int;
                                        final isMyId = seat['student_id'] == controller.userId;
                                        final isOccupied = seat['student_id'] != null && !isMyId;
                                        final isSelected = _selectedSeat == seatNum;

                                        return _SeatWidget(
                                          number: seatNum,
                                          isOccupied: isOccupied,
                                          isSelected: isSelected,
                                          isMe: isMyId,
                                          studentName: seat['student_name'] as String?,
                                          onTap: isOccupied || isMyId ? null : () {
                                            setState(() => _selectedSeat = isSelected ? null : seatNum);
                                          },
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 32),

                // Action Button
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: _selectedSeat == null || _isLoading ? null : () async {
                      setState(() => _isLoading = true);
                      final success = await controller.claimSeat(_selectedSeat!);
                      if (success && mounted) {
                        Navigator.pop(context);
                      } else if (mounted) {
                        setState(() { _isLoading = false; _selectedSeat = null; });
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("هذا المقعد تم حجزه للتو، يرجى اختيار آخر")),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _selectedSeat != null ? Colors.blue : const Color(0xFF25262B),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFF1A1B22),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      elevation: _selectedSeat != null ? 12 : 0,
                      shadowColor: Colors.blue.withOpacity(0.4),
                    ),
                    child: _isLoading 
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                      : Text(
                          _selectedSeat == null ? "اختر مقعداً للمتابعة" : "تأكيد المقعد رقم $_selectedSeat",
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SeatWidget extends StatelessWidget {
  final int number;
  final bool isOccupied;
  final bool isSelected;
  final bool isMe;
  final String? studentName;
  final VoidCallback? onTap;

  const _SeatWidget({
    required this.number,
    required this.isOccupied,
    required this.isSelected,
    required this.isMe,
    this.studentName,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color getBgColor() {
      if (isMe) return Colors.blue;
      if (isSelected) return Colors.blue.withOpacity(0.2);
      if (isOccupied) return Colors.white.withOpacity(0.02);
      return Colors.greenAccent.withOpacity(0.05);
    }

    Color getBorderColor() {
      if (isMe || isSelected) return Colors.blue;
      if (isOccupied) return Colors.white10;
      return Colors.greenAccent.withOpacity(0.3);
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: getBgColor(),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: getBorderColor(), width: (isSelected || isMe) ? 2 : 1),
          boxShadow: isSelected ? [BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 10)] : null,
        ),
        child: Stack(
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isOccupied && !isMe)
                      Icon(Icons.person, size: 14, color: Colors.white.withOpacity(0.1))
                    else if (isMe)
                      const Icon(Icons.check_circle, size: 14, color: Colors.white)
                    else
                      Text(
                        "$number",
                        style: TextStyle(
                          color: isSelected ? Colors.blue : Colors.greenAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    const SizedBox(height: 2),
                    Text(
                      isMe ? "أنت" : (isOccupied ? (studentName ?? "محجوز") : "متاح"),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isMe ? Colors.white : (isOccupied ? Colors.white24 : Colors.white70),
                        fontSize: 9,
                        fontFamily: 'Cairo',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
