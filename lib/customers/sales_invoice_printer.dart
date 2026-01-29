// lib/printing/sales_invoice_printer.dart

import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

Future<void> printSalesInvoice({
  required Map<String, dynamic> invoiceData,
  required String customerName,
  required String customerPhone,
  required String customerAddress,
}) async {
  final fontData =
  await rootBundle.load('assets/fonts/NotoSansArabic-Regular.ttf');
  final urduFont = pw.Font.ttf(fontData);

  final normal = pw.TextStyle(font: urduFont, fontSize: 9);
  final bold = pw.TextStyle(
    font: urduFont,
    fontSize: 9,
    fontWeight: pw.FontWeight.bold,
  );
  final title = pw.TextStyle(
    font: urduFont,
    fontSize: 16,
    fontWeight: pw.FontWeight.bold,
  );

  pw.Widget buildHeader() {

    final urduFont = pw.Font.ttf(fontData);

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8), // 🔽 less padding
      decoration: pw.BoxDecoration(
        border: pw.Border.all(width: 1),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // 🏷️ LEFT — SHOP BRAND
              pw.Container(
                width: 210, // 🔽 slightly smaller
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      "طلحہ افضل",
                      style: pw.TextStyle(
                        font: urduFont,
                        fontSize: 26, // ⬇️ was 30
                        fontWeight: pw.FontWeight.bold,
                        letterSpacing: 0.6,
                      ),
                    ),
                    pw.SizedBox(height: 2), // ⬇️ tighter
                    pw.Text(
                      "رضائی، کمبل، بیڈ شیٹ اسٹور",
                      style: pw.TextStyle(
                        font: urduFont,
                        fontSize: 13, // ⬇️ was 15
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              // 📞 RIGHT — CONTACT DETAILS
              pw.Container(
                width: 125, // 🔽 slightly smaller
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      "طلحہ افضل",
                      style: pw.TextStyle(
                        font: urduFont,
                        fontSize: 9, // ⬇️ was 10
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      "0303-6339313",
                      style: pw.TextStyle(
                        font: urduFont,
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      "0300-0359074",
                      style: pw.TextStyle(
                        font: urduFont,
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),

                    pw.SizedBox(height: 4), // ⬇️ was 6

                    pw.Text(
                      "وقاص افضل",
                      style: pw.TextStyle(
                        font: urduFont,
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      "0300-6766691",
                      style: pw.TextStyle(
                        font: urduFont,
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),

                    pw.SizedBox(height: 4),

                    pw.Text(
                      "عباس افضل",
                      style: pw.TextStyle(
                        font: urduFont,
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      "0303-2312531",
                      style: pw.TextStyle(
                        font: urduFont,
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          pw.SizedBox(height: 4), // ⬇️ was 6
          pw.Divider(),

          // 📍 Address
          pw.Text(
            "دکان نمبر 49، 48 ہول سیل کلاتھ مارکیٹ نزد سلطان مارکیٹ چونگی نمبر 11، مخدوم رشید روڈ، ملتان",
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
              font: urduFont,
              fontSize: 8.5, // ⬇️ was 9
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  /// ================= PDF =================
  final pdf = pw.Document();

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a5,
      margin: const pw.EdgeInsets.only(left: 14, right: 14, top: 10, bottom: 10),
      textDirection: pw.TextDirection.rtl,

      header: (context) => pw.Column(
        children: [
          buildHeader(),

          // ✅ THIS CREATES SPACE AFTER HEADER (ALL PAGES)
          pw.SizedBox(height: 12),
        ],
      ),


      build: (context) => [
        pw.SizedBox(height: 6),

        /// ================= TITLE =================
        pw.Text("سیلز بل", textAlign: pw.TextAlign.center, style: title),

        pw.Divider(),

        /// ================= META =================
        pw.Text("بل نمبر: ${invoiceData['invoiceNumber']}", style: normal),
        pw.Text("تاریخ: ${invoiceData['date']}", style: normal),
        pw.Text("وقت: ${invoiceData['time']}", style: normal),

        pw.Divider(height: 10),

        /// ================= CUSTOMER =================
        pw.Text("گاہک کی تفصیل", style: bold),
        pw.SizedBox(height: 4),

        pw.Text("نام: $customerName", style: normal),
        if (customerPhone.isNotEmpty)
          pw.Text("فون: $customerPhone", style: normal),
        if (customerAddress.isNotEmpty)
          pw.Text("پتہ: $customerAddress", style: normal),

        pw.Divider(height: 12),

        /// ================= ITEMS TABLE =================
        pw.Table(
          border: pw.TableBorder.all(width: 0.5),
          columnWidths: const {
            0: pw.FlexColumnWidth(3),
            1: pw.FlexColumnWidth(1),
            2: pw.FlexColumnWidth(1),
            3: pw.FlexColumnWidth(1.5),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                _cellUrdu("کل", urduFont, bold: true),
                _cellUrdu("ریٹ", urduFont, bold: true),
                _cellUrdu("مقدار", urduFont, bold: true),
                _cellUrdu("آئٹم", urduFont, bold: true),



              ],
            ),
            ...(invoiceData['items'] as List).map<pw.TableRow>((item) {
              return pw.TableRow(
                children: [
                  _cellUrdu(item['amount'].toString(), urduFont),
                  _cellUrdu(item['rate'].toString(), urduFont),
                  _cellUrdu(item['qty'].toString(), urduFont),
                  _cellUrdu(item['name'], urduFont),
                ],
              );
            }).toList(),
          ],
        ),

        pw.SizedBox(height: 10),

        /// ================= TOTAL =================
        pw.Container(
          padding: const pw.EdgeInsets.all(6),
          decoration: pw.BoxDecoration(border: pw.Border.all()),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                "کل رقم: ${invoiceData['totalAmount']} روپے",
                style: pw.TextStyle(
                  font: urduFont,
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text("ادا شدہ: ${invoiceData['amountPaid']}", style: normal),
              pw.Text("بقایا: ${invoiceData['amountDue']}", style: normal),
              pw.Text("بل: ${invoiceData['paymentStatus']}", style: normal),
            ],
          ),
        ),

        pw.SizedBox(height: 12),

        /// ================= FOOTER =================
        pw.Text(
          "یہ کمپیوٹر سے تیار کردہ سیلز بل ہے",
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(font: urduFont, fontSize: 8),
        ),
      ],
    ),
  );

  await Printing.layoutPdf(
    onLayout: (PdfPageFormat format) async => pdf.save(),
  );
}
pw.Widget _cellUrdu(
    String text,
    pw.Font font, {
      bool bold = false,
    }) {
  return pw.Padding(
    padding: const pw.EdgeInsets.all(4),
    child: pw.Text(
      text,
      style: pw.TextStyle(
        font: font,
        fontSize: 9,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      ),
    ),
  );
}