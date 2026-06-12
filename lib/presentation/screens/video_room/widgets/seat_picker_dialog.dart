import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../video_room_controller.dart';

class SeatPickerDialog extends StatefulWidget {
  const SeatPickerDialog({super.key});

  @override
  State<SeatPickerDialog> createState() => _SeatPickerDialogState();
}

class _SeatPickerDialogState extends State<SeatPickerDialog> {
  int? _selectedSeat;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<VideoRoomController>();
    final seats = controller.seats;
    final seatsPerScreen = controller.seatsPerScreen;

    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: const Color(0xFF1A1B1F),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900, maxHeight: 700),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Text("اختر مكانك على الشاشة",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Cairo',
                    )),
                const SizedBox(height: 8),
                const Text(
                  "ستظهر صورتك على الشاشة المقابلة في القاعة",
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 13,
                    fontFamily: 'Cairo',
                  ),
                ),
                const SizedBox(height: 24),

                // 3 screens layout
                Expanded(
                  child: Row(
                    children: [
                      _buildScreenColumn(
                        context,
                        controller,
                        "📺 شاشة 1",
                        seats.where((s) => s['zone'] == 'right').toList(),
                        seatsPerScreen,
                      ),
                      const SizedBox(width: 12),
                      _buildScreenColumn(
                        context,
                        controller,
                        "📺 شاشة 2",
                        seats.where((s) => s['zone'] == 'center').toList(),
                        seatsPerScreen,
                      ),
                      const SizedBox(width: 12),
                      _buildScreenColumn(
                        context,
                        controller,
                        "📺 شاشة 3",
                        seats.where((s) => s['zone'] == 'left').toList(),
                        seatsPerScreen,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Confirm button
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _selectedSeat == null || _isLoading
                        ? null
                        : () async {
                            setState(() => _isLoading = true);
                            final success = await controller.claimSeat(_selectedSeat!);
                            if (success && mounted) {
                              Navigator.pop(context);
                            } else if (mounted) {
                              setState(() {
                                _isLoading = false;
                                _selectedSeat = null;
                              });
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                content: Text("المقعد محجوز، اختر مقعداً آخر",
                                    style: TextStyle(fontFamily: 'Cairo')),
                                backgroundColor: Colors.red,
                                behavior: SnackBarBehavior.floating,
                              ));
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _selectedSeat != null ? Colors.blue : Colors.grey.shade800,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text("تأكيد المكان الآن",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Cairo',
                            )),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScreenColumn(
    BuildContext context,
    VideoRoomController controller,
    String label,
    List<Map<String, dynamic>> zoneSeats,
    int seatsPerScreen,
  ) {
    zoneSeats.sort((a, b) => (a['seat_number'] as int).compareTo(b['seat_number'] as int));

    return Expanded(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.withOpacity(0.2)),
            ),
            child: Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.blue,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Cairo',
                )),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: zoneSeats.isEmpty
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : ListView.builder(
                    itemCount: zoneSeats.length,
                    itemBuilder: (context, index) {
                      final seat = zoneSeats[index];
                      final seatNum = seat['seat_number'] as int;
                      final studentId = seat['student_id'];
                      final studentName = seat['student_name'];
                      final isMyId = studentId == controller.userId;
                      final isOccupied = studentId != null && !isMyId;
                      final isSelected = _selectedSeat == seatNum;

                      Color bgColor = Colors.white.withOpacity(0.03);
                      Color borderColor = Colors.white10;
                      Color textColor = Colors.white60;
                      String text = "مقعد $seatNum";

                      if (isMyId) {
                        bgColor = Colors.blue;
                        borderColor = Colors.blue;
                        textColor = Colors.white;
                        text = "أنت هنا ✓";
                      } else if (isOccupied) {
                        bgColor = Colors.white.withOpacity(0.05);
                        borderColor = Colors.transparent;
                        textColor = Colors.white24;
                        text = studentName ?? "محجوز";
                      } else if (isSelected) {
                        bgColor = Colors.blue.withOpacity(0.2);
                        borderColor = Colors.blue;
                        textColor = Colors.white;
                      }

                      return GestureDetector(
                        onTap: isOccupied || isMyId
                            ? null
                            : () => setState(() => _selectedSeat = isSelected ? null : seatNum),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                          decoration: BoxDecoration(
                            color: bgColor,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: borderColor, width: 1),
                          ),
                          child: Text(text,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: textColor,
                                fontSize: 11,
                                fontFamily: 'Cairo',
                                fontWeight: isSelected || isMyId ? FontWeight.bold : FontWeight.normal,
                              )),
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
