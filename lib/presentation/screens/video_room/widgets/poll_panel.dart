import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../video_room_controller.dart';

class PollPanel extends StatefulWidget {
  const PollPanel({super.key});

  @override
  State<PollPanel> createState() => _PollPanelState();
}

class _PollPanelState extends State<PollPanel> {
  final TextEditingController _questionCtrl = TextEditingController();
  final List<TextEditingController> _optionsCtrls = [
    TextEditingController(),
    TextEditingController()
  ];

  @override
  void dispose() {
    _questionCtrl.dispose();
    for (var ctrl in _optionsCtrls) {
      ctrl.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<VideoRoomController>();
    final poll = controller.activePoll;
    final isTeacher = controller.isTeacher;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          _buildHeader(controller),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: poll == null
                  ? (isTeacher ? _buildCreatePollForm(controller) : _buildNoPollState())
                  : _buildActivePollState(controller, poll),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(VideoRoomController controller) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text("استطلاعات الرأي", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Cairo')),
          IconButton(icon: const Icon(Icons.close), onPressed: controller.togglePolls),
        ],
      ),
    );
  }

  Widget _buildNoPollState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.poll_outlined, size: 60, color: Colors.grey),
          const SizedBox(height: 16),
          Text("لا يوجد تصويت نشط حالياً", style: TextStyle(color: Colors.grey, fontFamily: 'Cairo')),
        ],
      ),
    );
  }

  Widget _buildCreatePollForm(VideoRoomController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("إنشاء تصويت جديد", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, fontFamily: 'Cairo')),
        const SizedBox(height: 20),
        TextField(
          controller: _questionCtrl,
          style: const TextStyle(fontFamily: 'Cairo'),
          decoration: InputDecoration(
            labelText: "سؤال التصويت",
            labelStyle: const TextStyle(fontFamily: 'Cairo'),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 16),
        ..._optionsCtrls.asMap().entries.map((e) => Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: e.value,
                  style: const TextStyle(fontFamily: 'Cairo'),
                  decoration: InputDecoration(
                    labelText: "الخيار ${e.key + 1}",
                    labelStyle: const TextStyle(fontFamily: 'Cairo'),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              if (_optionsCtrls.length > 2)
                IconButton(
                  icon: const Icon(Icons.remove_circle, color: Colors.red),
                  onPressed: () => setState(() => _optionsCtrls.removeAt(e.key)),
                ),
            ],
          ),
        )),
        if (_optionsCtrls.length < 4)
          TextButton.icon(
            onPressed: () => setState(() => _optionsCtrls.add(TextEditingController())),
            icon: const Icon(Icons.add),
            label: const Text("إضافة خيار", style: TextStyle(fontFamily: 'Cairo')),
          ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () {
            if (_questionCtrl.text.isNotEmpty && _optionsCtrls.every((e) => e.text.isNotEmpty)) {
              controller.createPoll(
                _questionCtrl.text,
                _optionsCtrls.map((e) => e.text).toList(),
              );
              _questionCtrl.clear();
              for (var c in _optionsCtrls) {
                c.clear();
              }
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text("بدء التصويت", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildActivePollState(VideoRoomController controller, Map<String, dynamic> poll) {
    final totalVotes = controller.pollResults.values.fold(0, (sum, item) => sum + item);
    final hasVoted = controller.myCurrentPollVote != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.shade100),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.poll, color: Colors.blue),
              const SizedBox(width: 8),
              Expanded(child: Text(poll['question'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Cairo'))),
            ],
          ),
          const SizedBox(height: 20),
          ...poll['options'].map<Widget>((option) {
            final votes = controller.pollResults[option] ?? 0;
            final percent = totalVotes == 0 ? 0.0 : votes / totalVotes;
            final isMyVote = controller.myCurrentPollVote == option;

            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: InkWell(
                onTap: (controller.isTeacher || hasVoted) ? null : () {
                  controller.votePoll(option);
                },
                borderRadius: BorderRadius.circular(8),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(option, style: TextStyle(fontFamily: 'Cairo', fontWeight: isMyVote ? FontWeight.bold : FontWeight.w500, color: isMyVote ? Colors.blue : Colors.black87)),
                            if (isMyVote) ...[const SizedBox(width: 8), const Icon(Icons.check_circle, size: 14, color: Colors.blue)],
                          ],
                        ),
                        Text("$votes صوت (${(percent * 100).toStringAsFixed(1)}%)",
                            style: const TextStyle(fontSize: 12, color: Colors.grey, fontFamily: 'Cairo')),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: percent,
                        minHeight: 10,
                        backgroundColor: Colors.grey.shade100,
                        color: isMyVote ? Colors.blue : Colors.blue.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
          if (controller.isTeacher) ...[
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => controller.endPoll(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade50,
                foregroundColor: Colors.red,
                minimumSize: const Size(double.infinity, 50),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.red.shade100)),
              ),
              child: const Text("إنهاء التصويت للجميع", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
            ),
          ] else if (hasVoted) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(12)),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 20),
                  SizedBox(width: 8),
                  Text("تم تسجيل تصويتك بنجاح ✅", style: TextStyle(color: Colors.green, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
