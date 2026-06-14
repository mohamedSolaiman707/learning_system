import 'dart:async';
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
  bool _showSkipOption = false;
  Timer? _loadingTimer;

  @override
  void initState() {
    super.initState();
    // إظهار خيار التخطي بعد 7 ثوانٍ إذا لم تحمل المقاعد
    _loadingTimer = Timer(const Duration(seconds: 7), () {
      if (mounted && context.read<VideoRoomController>().seats.isEmpty) {
        setState(() => _showSkipOption = true);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctrl = context.read<VideoRoomController>();
      if (ctrl.seats.isEmpty) {
        ctrl.loadAndExpandSeats();
      }
    });
  }

  @override
  void dispose() {
    _loadingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<VideoRoomController>();
    final seats = controller.seats;
    final screenZones = controller.screenZones;
    final screenCount = controller.screenCount;

    // حالة التحميل مع خيار التخطي
    if (seats.isEmpty) {
      return Dialog(
        backgroundColor: const Color(0xFF1A1B1F),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Colors.blue),
              const SizedBox(height: 24),
              const Text("جاري تحميل خريطة المقاعد...",
                  style: TextStyle(color: Colors.white, fontFamily: 'Cairo', fontSize: 16)),
              const SizedBox(height: 10),
              const Text("تأكد من استقرار الإنترنت لديك",
                  style: TextStyle(color: Colors.white54, fontFamily: 'Cairo', fontSize: 12)),
              if (_showSkipOption) ...[
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white10),
                  child: const Text("تخطي والدخول للقاعة", style: TextStyle(color: Colors.white, fontFamily: 'Cairo')),
                ),
                TextButton(
                  onPressed: () => controller.loadAndExpandSeats(),
                  child: const Text("إعادة المحاولة", style: TextStyle(color: Colors.blue, fontFamily: 'Cairo')),
                ),
              ]
            ],
          ),
        ),
      );
    }

    final columnsPerRow = screenCount <= 3 ? screenCount
      : screenCount <= 6 ? 3
      : screenCount <= 9 ? 3
      : 4;

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
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                const SizedBox(height: 8),
                const Text("ستظهر صورتك على الشاشة المقابلة في القاعة",
                  style: TextStyle(color: Colors.white54, fontSize: 13, fontFamily: 'Cairo')),
                const SizedBox(height: 24),

                Expanded(
                  child: GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columnsPerRow,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 0.55,
                    ),
                    itemCount: screenCount,
                    itemBuilder: (context, index) {
                      final zone = screenZones[index];
                      final zoneSeats = seats.where((s) => s['zone'] == zone).toList()
                        ..sort((a, b) => (a['seat_number'] as int).compareTo(b['seat_number'] as int));

                      return Column(
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue.withOpacity(0.3)),
                            ),
                            child: Text("📺 شاشة ${index + 1}",
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.blue, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(minHeight: 200, maxHeight: 400),
                              child: ListView.builder(
                                itemCount: zoneSeats.length,
                                itemBuilder: (context, si) {
                                  final seat = zoneSeats[si];
                                  final seatNum = seat['seat_number'] as int;
                                  final isMyId = seat['student_id'] == controller.userId;
                                  final isOccupied = seat['student_id'] != null && !isMyId;
                                  final isSelected = _selectedSeat == seatNum;

                                  Color bgColor = isMyId ? Colors.blue : (isSelected ? Colors.blue.withOpacity(0.3) : (isOccupied ? Colors.white.withOpacity(0.05) : Colors.transparent));
                                  Color borderColor = (isMyId || isSelected) ? Colors.blue : Colors.white24;
                                  String text = isMyId ? "أنت ✓" : (isOccupied ? (seat['student_name'] ?? "محجوز") : "مقعد $seatNum");

                                  return GestureDetector(
                                    onTap: isOccupied || isMyId ? null : () => setState(() => _selectedSeat = isSelected ? null : seatNum),
                                    child: Container(
                                      margin: const EdgeInsets.only(bottom: 5),
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                                      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(7), border: Border.all(color: borderColor)),
                                      child: Text(text, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis,
                                        style: TextStyle(color: isOccupied && !isMyId ? Colors.white38 : Colors.white70, fontSize: 10, fontFamily: 'Cairo')),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _selectedSeat == null || _isLoading ? null : () async {
                      setState(() => _isLoading = true);
                      final success = await controller.claimSeat(_selectedSeat!);
                      if (success && mounted) Navigator.pop(context);
                      else if (mounted) setState(() { _isLoading = false; _selectedSeat = null; });
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: _selectedSeat != null ? Colors.blue : Colors.grey.shade800),
                    child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("تأكيد المكان الآن", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
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
