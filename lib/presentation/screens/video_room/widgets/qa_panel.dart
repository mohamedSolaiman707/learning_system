import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../video_room_controller.dart';

class QAPanel extends StatefulWidget {
  const QAPanel({super.key});

  @override
  State<QAPanel> createState() => _QAPanelState();
}

class _QAPanelState extends State<QAPanel> {
  final TextEditingController _msgController = TextEditingController();
  final FocusNode _msgFocusNode = FocusNode();
  
  // Local state for tracking current active question interaction
  String? _selectedOption;
  final TextEditingController _openAnswerController = TextEditingController();
  bool _hasAnswered = false;
  Map<String, dynamic>? _lastQuestion;

  @override
  void dispose() {
    _msgController.dispose();
    _msgFocusNode.dispose();
    _openAnswerController.dispose();
    super.dispose();
  }

  void _replyTo(String userName) {
    setState(() {
      _msgController.text = "@$userName ";
      _msgController.selection = TextSelection.fromPosition(TextPosition(offset: _msgController.text.length));
    });
    _msgFocusNode.requestFocus();
  }

  void _showNewQuestionBottomSheet(VideoRoomController controller) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => _NewQuestionBottomSheet(controller: controller),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<VideoRoomController>();
    final isTeacher = controller.isTeacher;

    // Reset local interaction state if the active question has changed
    if (controller.activeQuestion != _lastQuestion) {
      _lastQuestion = controller.activeQuestion;
      _hasAnswered = false;
      _selectedOption = null;
      _openAnswerController.clear();
    }

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
      ),
      child: Column(
        children: [
          _buildHeader(controller),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                if (isTeacher) ...[
                  ElevatedButton.icon(
                    onPressed: () => _showNewQuestionBottomSheet(controller),
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text("إطلاق سؤال جديد", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                if (controller.activeQuestion != null) ...[
                  _buildActiveQuestionCard(controller),
                  const SizedBox(height: 24),
                ],

                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8.0),
                  child: Text("الأسئلة العامة", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                ),

                if (controller.questions.isEmpty && controller.activeQuestion == null)
                  const Center(child: Padding(
                    padding: EdgeInsets.all(40.0),
                    child: Text("لا يوجد أسئلة حالياً", style: TextStyle(color: Colors.grey, fontFamily: 'Cairo')),
                  ))
                else
                  ...controller.questions.map((q) => _buildQuestionItem(q, controller)).toList(),
              ],
            ),
          ),
          _buildInput(controller),
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
          const Text("الأسئلة المباشرة", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Cairo')),
          IconButton(icon: const Icon(Icons.close), onPressed: controller.toggleQA),
        ],
      ),
    );
  }

  Widget _buildActiveQuestionCard(VideoRoomController controller) {
    final q = controller.activeQuestion!;
    final isTeacher = controller.isTeacher;
    final type = q['type'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue, width: 2),
        boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
                child: Text(type == 'mcq' ? "اختيار من متعدد" : "سؤال مفتوح", 
                  style: const TextStyle(color: Colors.blue, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
              ),
              const Spacer(),
              if (isTeacher)
                TextButton.icon(
                  onPressed: () => controller.closeQuestion(),
                  icon: const Icon(Icons.close, size: 16, color: Colors.red),
                  label: const Text("إغلاق السؤال", style: TextStyle(color: Colors.red, fontFamily: 'Cairo', fontSize: 12)),
                )
              else
                const Icon(Icons.wb_incandescent, color: Colors.orange, size: 22),
            ],
          ),
          const SizedBox(height: 12),
          Text(q['text'] ?? "", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, fontFamily: 'Cairo', height: 1.4)),
          const SizedBox(height: 16),
          
          if (!isTeacher) _buildStudentInteraction(controller, q)
          else _buildTeacherInteraction(controller, q),
        ],
      ),
    );
  }

  Widget _buildStudentInteraction(VideoRoomController controller, Map<String, dynamic> q) {
    final type = q['type'];
    final correctAnswer = q['correctAnswer'] ?? "";

    if (type == 'mcq') {
      return Column(
        children: (q['options'] as List).map((opt) {
          bool isSelected = _selectedOption == opt;
          bool showResult = _hasAnswered && correctAnswer.isNotEmpty;
          
          Color textColor = Colors.black87;
          Color bgColor = isSelected ? Colors.blue.shade50 : Colors.grey.shade50;
          Color borderColor = isSelected ? Colors.blue : Colors.transparent;

          if (showResult) {
             if (opt == correctAnswer) {
               textColor = Colors.green;
               bgColor = Colors.green.shade50;
               borderColor = Colors.green;
             } else if (isSelected) {
               textColor = Colors.red;
               bgColor = Colors.red.shade50;
               borderColor = Colors.red;
             }
          } else if (isSelected) {
            textColor = Colors.blue;
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 10.0),
            child: ElevatedButton(
              onPressed: _hasAnswered ? null : () {
                setState(() {
                  _selectedOption = opt;
                  _hasAnswered = true;
                });
                controller.submitAnswer(opt);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: bgColor,
                foregroundColor: textColor,
                elevation: 0,
                minimumSize: const Size(double.infinity, 50),
                disabledForegroundColor: textColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12), 
                  side: BorderSide(color: borderColor, width: 1.5)
                ),
              ),
              child: Text(opt, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          );
        }).toList(),
      );
    } else {
      return Column(
        children: [
          TextField(
            controller: _openAnswerController,
            enabled: !_hasAnswered,
            style: const TextStyle(fontFamily: 'Cairo'),
            decoration: InputDecoration(
              hintText: "اكتب إجابتك هنا...",
              hintStyle: const TextStyle(fontFamily: 'Cairo'),
              filled: true,
              fillColor: Colors.grey.shade50,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 12),
          if (!_hasAnswered)
            ElevatedButton(
              onPressed: () {
                if (_openAnswerController.text.trim().isNotEmpty) {
                  setState(() => _hasAnswered = true);
                  controller.submitAnswer(_openAnswerController.text.trim());
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue, 
                foregroundColor: Colors.white, 
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text("إرسال الإجابة", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
            ),
          if (_hasAnswered) ...[
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 18),
                SizedBox(width: 8),
                Text("تم إرسال إجابتك بنجاح ✅", style: TextStyle(color: Colors.green, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
              ],
            ),
            if (correctAnswer.isNotEmpty)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(12)),
                child: Text("الإجابة الصحيحة: $correctAnswer", 
                  style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
              ),
          ]
        ],
      );
    }
  }

  Widget _buildTeacherInteraction(VideoRoomController controller, Map<String, dynamic> q) {
    final type = q['type'];
    final correctAnswer = q['correctAnswer'] ?? "";
    final answers = controller.studentAnswers;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (type == 'mcq' && correctAnswer.isEmpty) ...[
          const Text("حدد الإجابة الصحيحة لتظهر للطلاب:", style: TextStyle(fontSize: 12, fontFamily: 'Cairo', color: Colors.grey)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: (q['options'] as List).map((opt) => ActionChip(
              label: Text(opt, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
              backgroundColor: Colors.blue.shade50,
              onPressed: () => controller.revealCorrectAnswer(opt),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            )).toList(),
          ),
        ] else if (correctAnswer.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(10)),
            child: Row(
              children: [
                const Icon(Icons.verified, color: Colors.green, size: 20),
                const SizedBox(width: 8),
                Text("الإجابة الصحيحة: $correctAnswer", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
              ],
            ),
          ),
        ],
        const Padding(
          padding: EdgeInsets.only(top: 24, bottom: 12),
          child: Row(
            children: [
              Icon(Icons.people_outline, size: 20),
              SizedBox(width: 8),
              Text("إجابات الطلاب الحالية:", style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 14)),
            ],
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: MediaQuery.of(context).size.width > 600 ? 2 : 1,
            mainAxisExtent: 64,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: answers.length,
          itemBuilder: (context, index) {
            final name = answers.keys.elementAt(index);
            final ans = answers[name]!;
            bool isCorrect = correctAnswer.isNotEmpty && ans == correctAnswer;
            bool isWrong = correctAnswer.isNotEmpty && ans != correctAnswer;

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16, 
                    backgroundColor: Colors.blue.shade100,
                    child: Text(name[0], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'Cairo'), overflow: TextOverflow.ellipsis),
                        Text(ans, 
                          style: TextStyle(fontSize: 12, fontFamily: 'Cairo', fontWeight: FontWeight.w600, color: isCorrect ? Colors.green : (isWrong ? Colors.red : Colors.black87)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildQuestionItem(Map<String, dynamic> q, VideoRoomController controller) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade200)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: Colors.blue.shade100,
                  child: Text(q['from']?[0].toUpperCase() ?? '?', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8),
                Text(q['from'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Cairo')),
                const Spacer(),
                if (q['is_answered'] == true)
                  const Icon(Icons.check_circle, color: Colors.green, size: 16),
              ],
            ),
            const SizedBox(height: 10),
            Text(q['text'] ?? '', style: const TextStyle(fontSize: 15, fontFamily: 'Cairo', height: 1.4)),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (controller.isTeacher && q['is_answered'] != true)
                  TextButton(
                    onPressed: () => controller.markQuestionAsAnswered(q['id']),
                    child: const Text("تمت الإجابة", style: TextStyle(color: Colors.green, fontSize: 12, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                  ),
                TextButton.icon(
                  onPressed: () => _replyTo(q['from']),
                  icon: const Icon(Icons.reply, size: 16),
                  label: const Text("رد", style: TextStyle(fontSize: 12, fontFamily: 'Cairo')),
                ),
                IconButton(
                  icon: Icon(Icons.thumb_up, size: 16, color: (q['upvotes'] ?? 0) > 0 ? Colors.blue : Colors.grey),
                  onPressed: () => controller.upvoteQuestion(q['id']),
                ),
                Text("${q['upvotes'] ?? 0}", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildInput(VideoRoomController controller) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(color: Colors.grey.shade50, border: Border(top: BorderSide(color: Colors.grey.shade200))),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _msgController,
              focusNode: _msgFocusNode,
              decoration: InputDecoration(
                hintText: "اسأل سؤالاً أو أجب...",
                hintStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 14),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              onSubmitted: (_) => _send(controller),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: Colors.blue,
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white, size: 20),
              onPressed: () => _send(controller),
            ),
          ),
        ],
      ),
    );
  }

  void _send(VideoRoomController controller) {
    if (_msgController.text.trim().isNotEmpty) {
      controller.sendQuestion(_msgController.text.trim());
      _msgController.clear();
      FocusScope.of(context).unfocus();
    }
  }
}

class _NewQuestionBottomSheet extends StatefulWidget {
  final VideoRoomController controller;
  const _NewQuestionBottomSheet({required this.controller});

  @override
  State<_NewQuestionBottomSheet> createState() => _NewQuestionBottomSheetState();
}

class _NewQuestionBottomSheetState extends State<_NewQuestionBottomSheet> {
  final _mcqTextCtrl = TextEditingController();
  final _mcqCorrectCtrl = TextEditingController();
  final List<TextEditingController> _mcqOptions = [TextEditingController(), TextEditingController()];

  final _openTextCtrl = TextEditingController();
  final _openCorrectCtrl = TextEditingController();

  @override
  void dispose() {
    _mcqTextCtrl.dispose();
    _mcqCorrectCtrl.dispose();
    for (var ctrl in _mcqOptions) {
      ctrl.dispose();
    }
    _openTextCtrl.dispose();
    _openCorrectCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.65,
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const TabBar(
                tabs: [Tab(text: "اختيار من متعدد"), Tab(text: "إجابة مفتوحة")],
                labelStyle: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                labelColor: Colors.blue,
                unselectedLabelColor: Colors.grey,
                indicatorColor: Colors.blue,
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildMcqForm(),
                    _buildOpenForm(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMcqForm() {
    return ListView(
      padding: const EdgeInsets.only(top: 16),
      children: [
        TextField(
          controller: _mcqTextCtrl, 
          style: const TextStyle(fontFamily: 'Cairo'),
          decoration: const InputDecoration(labelText: "نص السؤال", labelStyle: TextStyle(fontFamily: 'Cairo'))
        ),
        const SizedBox(height: 16),
        ..._mcqOptions.asMap().entries.map((e) => Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Row(
            children: [
              Expanded(child: TextField(controller: e.value, decoration: InputDecoration(labelText: "خيار ${e.key + 1}", labelStyle: const TextStyle(fontFamily: 'Cairo')))),
              if (_mcqOptions.length > 2) 
                IconButton(icon: const Icon(Icons.remove_circle, color: Colors.red), onPressed: () => setState(() => _mcqOptions.removeAt(e.key))),
            ],
          ),
        )).toList(),
        if (_mcqOptions.length < 4)
          TextButton.icon(
            onPressed: () => setState(() => _mcqOptions.add(TextEditingController())), 
            icon: const Icon(Icons.add), 
            label: const Text("إضافة خيار", style: TextStyle(fontFamily: 'Cairo'))
          ),
        const SizedBox(height: 12),
        TextField(
          controller: _mcqCorrectCtrl, 
          style: const TextStyle(fontFamily: 'Cairo'),
          decoration: const InputDecoration(labelText: "الإجابة الصحيحة (اختياري)", hintText: "اتركه فارغاً إن لم تحدد", hintStyle: TextStyle(fontFamily: 'Cairo', fontSize: 12))
        ),
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: () {
            if (_mcqTextCtrl.text.trim().isNotEmpty) {
              widget.controller.launchQuestion({
                'type': 'mcq',
                'text': _mcqTextCtrl.text,
                'options': _mcqOptions.map((e) => e.text).toList(),
                'correctAnswer': _mcqCorrectCtrl.text,
              });
              Navigator.pop(context);
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue, 
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text("إطلاق السؤال", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildOpenForm() {
    return ListView(
      padding: const EdgeInsets.only(top: 16),
      children: [
        TextField(
          controller: _openTextCtrl, 
          style: const TextStyle(fontFamily: 'Cairo'),
          decoration: const InputDecoration(labelText: "نص السؤال", labelStyle: TextStyle(fontFamily: 'Cairo'))
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _openCorrectCtrl, 
          style: const TextStyle(fontFamily: 'Cairo'),
          decoration: const InputDecoration(labelText: "الإجابة الصحيحة (اختياري)", labelStyle: TextStyle(fontFamily: 'Cairo'))
        ),
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: () {
            if (_openTextCtrl.text.trim().isNotEmpty) {
              widget.controller.launchQuestion({
                'type': 'open',
                'text': _openTextCtrl.text,
                'correctAnswer': _openCorrectCtrl.text,
              });
              Navigator.pop(context);
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue, 
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text("إطلاق السؤال", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
