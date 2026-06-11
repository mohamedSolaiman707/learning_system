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
  bool _isSubmitting = false;
  String _activeZone = 'right'; 

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<VideoRoomController>();
    final seats = controller.seats;
    
    final zoneSeats = seats.where((s) => s['zone'] == _activeZone).toList()
      ..sort((a, b) => (a['seat_number'] as int).compareTo(b['seat_number'] as int));

    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: const Color(0xFF1A1B1F),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 500),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "اختر مكانك على الشاشة",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
              ),
              const SizedBox(height: 8),
              const Text(
                "حدد الشاشة ثم اختر المقعد المفضل لك",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 13, fontFamily: 'Cairo'),
              ),
              const SizedBox(height: 25),

              // اختيار الشاشة - 3 أزرار
              Row(
                children: [
                  _buildZoneTab("شاشة 1", "right"),
                  const SizedBox(width: 8),
                  _buildZoneTab("شاشة 2", "center"),
                  const SizedBox(width: 8),
                  _buildZoneTab("شاشة 3", "left"),
                ],
              ),
              
              const SizedBox(height: 20),

              // قائمة المقاعد
              Flexible(
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 300),
                  child: seats.isEmpty
                      ? const Center(child: CircularProgressIndicator(color: Colors.blue))
                      : GridView.builder(
                          shrinkWrap: true,
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 2.8,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                          ),
                          itemCount: zoneSeats.length,
                          itemBuilder: (context, index) => _buildSeatButton(zoneSeats[index], controller),
                        ),
                ),
              ),

              const SizedBox(height: 25),

              // زر التأكيد
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _selectedSeat == null || _isSubmitting
                      ? null
                      : () async {
                          setState(() => _isSubmitting = true);
                          final success = await controller.claimSeat(_selectedSeat!);
                          if (success && mounted) {
                            Navigator.pop(context);
                          } else if (mounted) {
                            setState(() => _isSubmitting = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("هذا المقعد محجوز بالفعل، اختر غيره", style: TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.red),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    disabledBackgroundColor: Colors.white10,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text("تأكيد المكان", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildZoneTab(String label, String zone) {
    final bool isSelected = _activeZone == zone;
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              _activeZone = zone;
              _selectedSeat = null;
            });
          },
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSelected ? Colors.blue : Colors.white10,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white38,
                fontWeight: FontWeight.bold,
                fontSize: 12,
                fontFamily: 'Cairo',
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSeatButton(Map<String, dynamic> seat, VideoRoomController controller) {
    final int seatNum = seat['seat_number'];
    final String? studentId = seat['student_id'];
    final bool isOccupied = studentId != null && studentId != controller.userId;
    final bool isSelected = _selectedSeat == seatNum;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isOccupied ? null : () => setState(() => _selectedSeat = seatNum),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? Colors.blue.withOpacity(0.2) : (isOccupied ? Colors.white10 : Colors.white.withOpacity(0.05)),
            border: Border.all(color: isSelected ? Colors.blue : (isOccupied ? Colors.transparent : Colors.white12)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            isOccupied ? "محجوز" : "مقعد $seatNum",
            style: TextStyle(
              color: isOccupied ? Colors.white24 : (isSelected ? Colors.blue : Colors.white70),
              fontFamily: 'Cairo',
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}
