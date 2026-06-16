import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

class AttendancePdfService {
  Future<void> generateReport({
    required String subjectName,
    required String teacherName,
    required List<Map<String, dynamic>> studentsData,
  }) async {
    final pdf = pw.Document();
    final arabicFont = await PdfGoogleFonts.cairoRegular();
    final boldFont = await PdfGoogleFonts.cairoBold();
    
    final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

    final totalCount = studentsData.length;
    final presentCount = studentsData.where((s) => s['present'] == true).length;

    pdf.addPage(
      pw.MultiPage(
        theme: pw.ThemeData.withFont(base: arabicFont, bold: boldFont),
        textDirection: pw.TextDirection.rtl,
        build: (context) => [
          _buildHeader(
            subjectName: subjectName,
            teacherName: teacherName,
            dateStr: dateStr,
            presentCount: presentCount,
            totalCount: totalCount,
          ),
          pw.SizedBox(height: 20),
          _buildTable(studentsData),
          pw.SizedBox(height: 40),
          _buildFooter(),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Attendance_${subjectName}_$dateStr.pdf',
    );
  }

  pw.Widget _buildHeader({
    required String subjectName,
    required String teacherName,
    required String dateStr,
    required int presentCount,
    required int totalCount,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'تقرير حضور الحصة الافتراضية',
          style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
        ),
        pw.SizedBox(height: 10),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('المادة: $subjectName', style: const pw.TextStyle(fontSize: 14)),
                pw.Text('المعلم: $teacherName', style: const pw.TextStyle(fontSize: 14)),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('التاريخ: $dateStr', style: const pw.TextStyle(fontSize: 14)),
                pw.Text('إجمالي الحاضرين: $presentCount / $totalCount', style: const pw.TextStyle(fontSize: 14)),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Divider(thickness: 2, color: PdfColors.blue900),
      ],
    );
  }

  String _formatTime(dynamic value) {
    if (value == null || value == '---' || value == '') return '---';
    try {
      String valStr = value.toString();
      
      // التحقق إذا كان النص بتنسيق التاريخ ISO (يحتوي على T)
      if (valStr.contains('T')) {
        final dt = DateTime.parse(valStr).toLocal();
        return DateFormat('hh:mm a').format(dt)
            .replaceAll('AM', 'صباحاً')
            .replaceAll('PM', 'مساءً');
      }
      
      // إذا كان النص يحتوي بالفعل على "ص" أو "م" كأحرف منفصلة للتوقيت
      // نستخدم المسافات لضمان عدم استبدال أحرف داخل الكلمات (مثل "لم يحضر")
      return valStr
          .replaceAll(' ص', ' صباحاً')
          .replaceAll(' م', ' مساءً');
    } catch (_) {
      return '---';
    }
  }

  pw.Widget _buildTable(List<Map<String, dynamic>> students) {
    final headers = ['المدة', 'وقت المغادرة', 'وقت الانضمام', 'الحالة', 'اسم الطالب'];

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: students.map((s) {
        final bool isPresent = s['present'] == true;
        
        return [
          isPresent ? '${s['duration'] ?? 0} د' : '---',
          isPresent ? _formatTime(s['left_at']) : '---',
          isPresent ? _formatTime(s['joined_at']) : '---',
          isPresent ? 'حاضر' : 'غائب',
          s['name'] ?? 'غير معروف',
        ];
      }).toList(),
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
      cellStyle: const pw.TextStyle(fontSize: 10),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
      cellHeight: 35,
      columnWidths: {
        0: const pw.FixedColumnWidth(45),
        1: const pw.FixedColumnWidth(100),
        2: const pw.FixedColumnWidth(100),
        3: const pw.FixedColumnWidth(55),
        4: const pw.FlexColumnWidth(),
      },
      cellAlignments: {
        0: pw.Alignment.center,
        1: pw.Alignment.center,
        2: pw.Alignment.center,
        3: pw.Alignment.center,
        4: pw.Alignment.centerRight,
      },
    );
  }

  pw.Widget _buildFooter() {
    return pw.Column(
      children: [
        pw.Divider(color: PdfColors.grey300),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('تم إنشاء هذا التقرير تلقائياً بواسطة نظام Learning By Video Call', 
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
            pw.Text('توقيع المعلم: ..........................', 
                style: const pw.TextStyle(fontSize: 10)),
          ],
        ),
      ],
    );
  }
}
