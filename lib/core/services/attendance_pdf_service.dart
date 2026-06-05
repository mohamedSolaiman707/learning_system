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
    
    final dateStr = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());

    pdf.addPage(
      pw.MultiPage(
        theme: pw.ThemeData.withFont(base: arabicFont, bold: boldFont),
        textDirection: pw.TextDirection.rtl,
        build: (context) => [
          _buildHeader(subjectName, teacherName, dateStr, studentsData.length),
          pw.SizedBox(height: 20),
          _buildTable(studentsData),
          pw.SizedBox(height: 40),
          _buildFooter(),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Attendance_Report_${subjectName}_$dateStr.pdf',
    );
  }

  pw.Widget _buildHeader(String subject, String teacher, String date, int count) {
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
                pw.Text('المادة: $subject', style: const pw.TextStyle(fontSize: 14)),
                pw.Text('المعلم: $teacher', style: const pw.TextStyle(fontSize: 14)),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('التاريخ: $date', style: const pw.TextStyle(fontSize: 14)),
                pw.Text('إجمالي الحضور: $count', style: const pw.TextStyle(fontSize: 14)),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Divider(thickness: 2, color: PdfColors.blue900),
      ],
    );
  }

  pw.Widget _buildTable(List<Map<String, dynamic>> students) {
    // تم عكس الترتيب: المدة في اليسار واسم الطالب في اليمين
    final headers = ['المدة', 'وقت المغادرة', 'وقت الانضمام', 'الحالة', 'اسم الطالب'];

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: students.map((s) => [
        '${s['duration'] ?? 0} د',
        s['left_at'] ?? '---',
        s['joined_at'] ?? '---',
        s['present'] ? 'حاضر' : 'غائب',
        s['name'] ?? 'غير معروف',
      ]).toList(),
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
      cellHeight: 30,
      cellAlignments: {
        0: pw.Alignment.center,
        1: pw.Alignment.center,
        2: pw.Alignment.center,
        3: pw.Alignment.center,
        4: pw.Alignment.centerRight, // محاذاة الاسم لليمين
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
