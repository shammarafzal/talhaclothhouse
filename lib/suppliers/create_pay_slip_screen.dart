import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class CreatePaySlipScreen extends StatefulWidget {
  final String? supplierId;
  final Map<String, dynamic>? supplierData;

  const CreatePaySlipScreen({
    super.key,
    required this.supplierId,
    required this.supplierData,
  });

  @override
  State<CreatePaySlipScreen> createState() => _CreatePaySlipScreenState();
}

class _CreatePaySlipScreenState extends State<CreatePaySlipScreen> {
  String? selectedSupplierId;
  Map<String, dynamic>? selectedSupplierData;

  final amountController = TextEditingController();
  final noteController = TextEditingController();
  final payDateController = TextEditingController();

  DateTime? _selectedPayDate;
  bool saving = false;

  final String issuerName = "Talha Afzal Cloth House";
  final String issuerPhone =
      "Talha Afzal: 0303-6339313, Waqas Afzal: 0300-6766691, Abbas Afzal: 0303-2312531";
  final String issuerAddress =
      "Shop No 21, Nasir Cloth Market, Chungi No 11, Multan";

  @override
  void initState() {
    super.initState();
    _selectedPayDate = DateTime.now();
    payDateController.text = DateFormat('dd/MM/yyyy').format(_selectedPayDate!);
  }

  @override
  void dispose() {
    amountController.dispose();
    noteController.dispose();
    payDateController.dispose();
    super.dispose();
  }

  Future<String> _generateSlipSerial() async {
    final counterRef =
    FirebaseFirestore.instance.collection('counters').doc('paySlip');

    return FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(counterRef);
      int last = 0;
      if (snap.exists) {
        final data = snap.data() as Map<String, dynamic>;
        last = (data['lastNumber'] ?? 0) as int;
      }
      final next = last + 1;
      tx.set(counterRef, {'lastNumber': next});
      final padded = next.toString().padLeft(3, '0');
      return 'PS-$padded';
    });
  }

  Future<void> _pickPayDate() async {
    final now = DateTime.now();
    final initial = _selectedPayDate ?? now;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        _selectedPayDate = picked;
        payDateController.text = DateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }

  Future<void> _printSlip(Map<String, dynamic> slipData) async {
    final fontData =
    await rootBundle.load('assets/fonts/NotoSansArabic-Regular.ttf');
    final urduFont = pw.Font.ttf(fontData);
    final small = pw.TextStyle(
      font: urduFont,
      fontSize: 9,
    );

    final bold = pw.TextStyle(
      font: urduFont,
      fontSize: 9,
      fontWeight: pw.FontWeight.bold,
    );


    final pdf = pw.Document();
    final amountInWords = amountToWordsPKR((slipData['amount'] ?? 0).toDouble());
    final serial = slipData['serialNumber'] ?? '';
    final amount = (slipData['amount'] ?? 0).toDouble();
    final status = slipData['status'] ?? 'Unpaid';
    final payDate = slipData['payDate'] ?? '';
    final payDay = slipData['payDayName'] ?? '';
    final slipDate = slipData['slipDate'] ?? '';
    final slipDay = slipData['slipDayName'] ?? '';
    final time = slipData['time'] ?? '';
    final supplierName = slipData['supplierName'] ?? '';
    final supplierPhone = slipData['supplierPhone'] ?? '';
    final supplierAddress = slipData['supplierAddress'] ?? '';
    final issuerName = slipData['issuerName'] ?? '';
    final issuerPhone = slipData['issuerPhone'] ?? '';
    final issuerAddress = slipData['issuerAddress'] ?? '';
    final note = slipData['note'] ?? '';
    final qrData = slipData['qrData'] ?? '';
    final cashedBy = slipData['cashedBy'] ?? '';

    final statusColor = status == 'Paid' ? PdfColors.green : PdfColors.red;


    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        margin: const pw.EdgeInsets.only(left: 16, right: 8, top: 8, bottom: 8),
        build: (context) {
          return pw.Directionality(
              textDirection: pw.TextDirection.rtl,
            child: pw.Container(
            padding: const pw.EdgeInsets.all(8),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                // ---------- HEADER ----------
                pw.Container(
                  padding: const pw.EdgeInsets.only(bottom: 8),
                  child: pw.Column(
                    children: [
                      pw.Text(
                        "ادائیگی کی پرچی",
                        style: pw.TextStyle(
                          font: urduFont,
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        "طلحہ افضل کلاتھ ہاؤس",
                        style: pw.TextStyle(font: urduFont, fontSize: 10),
                      ),
                      pw.Text(
                        "فون: 0303-6339313",
                        style: pw.TextStyle(font: urduFont, fontSize: 9),
                      ),
                    ],
                  ),
                ),

                pw.Divider(),

                // 🔹 Dates (Slip Date + Pay Date)
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text("پرچی کی تاریخ: $slipDate ($slipDay)", style: small),
                        pw.Text("ادائیگی کی تاریخ: $payDate ($payDay)", style: small),
                        pw.Text("وقت: $time", style: small),
                        pw.Text("پرچی نمبر: $serial", style: small),
                      ],
                    ),
                    pw.Container(
                      padding:
                      const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.grey200,
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Text(
                        status,
                        style: pw.TextStyle(
                            color: statusColor,
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                  ],
                ),

                pw.SizedBox(height: 6),
                pw.Divider(),

                // Supplier
                pw.Text("لوم والا کی تفصیل", style: bold),
                pw.Text(supplierName, style: small),
                if (supplierPhone.toString().isNotEmpty)
                  pw.Text(supplierPhone, style: small),
                if (supplierAddress.toString().isNotEmpty)
                  pw.Text(supplierAddress, style: small),

                pw.SizedBox(height: 6),
                pw.Divider(),

                // Issuer
                pw.Text("دکاندار کی تفصیل", style: bold),
                pw.Text(issuerName, style: small),
                pw.Text(issuerPhone, style: small),
                pw.Text(issuerAddress, style: small),

                pw.SizedBox(height: 6),
                pw.Divider(),

                // Amount + Note
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text("رقم:", style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                    )),
                    pw.Text(
                      "${amount.toStringAsFixed(2)} روپے",
                      style: pw.TextStyle(
                        fontSize: 13,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text("رقم الفاظ میں:", style: bold),
                    pw.Text(
                      amountInWords,
                      style: small,
                    ),
                  ],
                ),
                if (note.toString().isNotEmpty)
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(top: 2),
                    child: pw.Text("نوٹ: $note", style: small),
                  ),

                pw.SizedBox(height: 6),

                // ✅ Cash Date + Cashed By block
                pw.Container(
                  padding:
                  const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  decoration: pw.BoxDecoration(
                    borderRadius: pw.BorderRadius.circular(4),
                    border:
                    pw.Border.all(color: PdfColors.grey300, width: 0.5),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text("ادائیگی کی تاریخ: $payDate", style: small),
                          pw.Text("نقد وصولی کی تاریخ: ____________", style: small),
                        ],
                      ),
                      pw.SizedBox(height: 3),
                      pw.Text(
                        "وصول کرنے والا: ${cashedBy.toString().isNotEmpty ? cashedBy : "______________________"}",
                        style: small,
                      ),
                    ],
                  ),
                ),

                pw.SizedBox(height: 8),
                pw.Divider(),

                if (qrData.toString().isNotEmpty)
                  pw.Center(
                    child: pw.Column(
                      children: [
                        pw.Text("تصدیق کے لیے اسکین کریں", style: bold),
                        pw.SizedBox(height: 3),
                        pw.BarcodeWidget(
                          barcode: pw.Barcode.qrCode(),
                          data: qrData,
                          width: 70,
                          height: 70,
                        ),
                        pw.SizedBox(height: 3),
                        pw.Text(serial, style: bold),
                      ],
                    ),
                  ),

                pw.SizedBox(height: 6),
                pw.Divider(),
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 6),
                  child: pw.Text(
                    "یہ کمپیوٹر سے تیار کردہ پرچی ہے",
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                      font: urduFont,
                      fontSize: 8,
                    ),
                  ),
                ),
              ],
            ),
            )
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }
  String amountToWordsPKR(num amount) {
    if (amount == 0) return "Zero Rupees Only";

    final units = [
      "",
      "One",
      "Two",
      "Three",
      "Four",
      "Five",
      "Six",
      "Seven",
      "Eight",
      "Nine",
      "Ten",
      "Eleven",
      "Twelve",
      "Thirteen",
      "Fourteen",
      "Fifteen",
      "Sixteen",
      "Seventeen",
      "Eighteen",
      "Nineteen"
    ];

    final tens = [
      "",
      "",
      "Twenty",
      "Thirty",
      "Forty",
      "Fifty",
      "Sixty",
      "Seventy",
      "Eighty",
      "Ninety"
    ];

    String convertBelowThousand(int n) {
      String result = "";
      if (n >= 100) {
        result += "${units[n ~/ 100]} Hundred ";
        n %= 100;
      }
      if (n >= 20) {
        result += "${tens[n ~/ 10]} ";
        n %= 10;
      }
      if (n > 0) {
        result += "${units[n]} ";
      }
      return result.trim();
    }

    int rupees = amount.floor();
    int paisa = ((amount - rupees) * 100).round();

    String words = "";

    if (rupees >= 10000000) {
      words +=
      "${convertBelowThousand(rupees ~/ 10000000)} Crore ";
      rupees %= 10000000;
    }

    if (rupees >= 100000) {
      words +=
      "${convertBelowThousand(rupees ~/ 100000)} Lac ";
      rupees %= 100000;
    }

    if (rupees >= 1000) {
      words +=
      "${convertBelowThousand(rupees ~/ 1000)} Thousand ";
      rupees %= 1000;
    }

    if (rupees > 0) {
      words += convertBelowThousand(rupees);
    }

    words = words.trim() + " Rupees";

    if (paisa > 0) {
      words +=
      " and ${convertBelowThousand(paisa)} Paisa";
    }

    return "$words Only";
  }


  Future<void> _saveSlip() async {
    // if (selectedSupplierId == null || selectedSupplierData == null) {
    //   ScaffoldMessenger.of(context)
    //       .showSnackBar(const SnackBar(content: Text("Please select a supplier")));
    //   return;
    // }

    if (_selectedPayDate == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("ادائیگی کی تاریخ منتخب کریں")),);
      return;
    }

    final amount = double.tryParse(amountController.text.trim()) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("درست رقم درج کریں")),);
      return;
    }

    setState(() => saving = true);

    try {
      final now = DateTime.now();
      final payDate = _selectedPayDate!;
      final slipDateStr = DateFormat('dd/MM/yyyy').format(now);
      final payDateStr = DateFormat('dd/MM/yyyy').format(payDate);
      final slipDayName = DateFormat('EEEE').format(now);
      final payDayName = DateFormat('EEEE').format(payDate);
      final timeStr = DateFormat('hh:mm a').format(now);

      final serialNumber = await _generateSlipSerial();

      final slipRef = FirebaseFirestore.instance
          .collection("suppliers")
          .doc(widget.supplierId)
          .collection("paySlips")
          .doc();

      final slipData = {
        'serialNumber': serialNumber,
        'slipId': slipRef.id,
        'supplierId': widget.supplierId,
        'supplierName': widget.supplierData?['name'] ?? '',
        'supplierPhone': widget.supplierData?['phone'] ?? '',
        'supplierAddress': widget.supplierData?['address'] ?? '',
        'issuerName': issuerName,
        'issuerPhone': issuerPhone,
        'issuerAddress': issuerAddress,
        'amount': amount,
        'status': 'Unpaid',
        'note': noteController.text.trim().isEmpty
            ? null
            : noteController.text.trim(),
        'payDate': payDateStr,
        'payDayName': payDayName,
        'slipDate': slipDateStr,
        'slipDayName': slipDayName,
        'time': timeStr,
        'createdAt': now,
        'paidAt': null,
        'cashDate': null,
        'cashedBy': null,
        'qrData': 'PAYSLIP|$selectedSupplierId|${slipRef.id}',
      };

      await slipRef.set(slipData);
      await _printSlip(slipData);

      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("پرچی محفوظ ہو گئی اور پرنٹ ہو گئی")),);
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("پرچی بنائیں"),
      ),
      body: Container(
        color: Colors.grey.shade100,
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 550),
            child: Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "پرچی کی تفصیل",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 16),


                    const SizedBox(height: 12),

                    // Pay Date selector
                    TextField(
                      controller: payDateController,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: "ادائیگی کی تاریخ",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.date_range),
                      ),
                      onTap: _pickPayDate,
                    ),

                    const SizedBox(height: 12),

                    TextField(
                      controller: amountController,
                      keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: "رقم",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.currency_rupee),
                      ),
                    ),

                    const SizedBox(height: 12),

                    TextField(
                      controller: noteController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: "نوٹ",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.note),
                      ),
                    ),

                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: saving ? null : _saveSlip,
                        icon: saving
                            ? const SizedBox(
                          width: 18,
                          height: 18,
                          child:
                          CircularProgressIndicator(strokeWidth: 2),
                        )
                            : const Icon(Icons.print),
                        label: Text(
                          saving ? "محفوظ ہو رہا ہے..." : "محفوظ کریں اور پرنٹ کریں",
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
