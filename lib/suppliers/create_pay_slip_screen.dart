import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class CreatePaySlipScreen extends StatefulWidget {
  const CreatePaySlipScreen({super.key});

  @override
  State<CreatePaySlipScreen> createState() => _CreatePaySlipScreenState();
}

class _CreatePaySlipScreenState extends State<CreatePaySlipScreen> {
  String? selectedSupplierId;
  Map<String, dynamic>? selectedSupplierData;

  final amountController = TextEditingController();
  final noteController = TextEditingController();
  bool saving = false;

  // Issuer fixed details (you can change later)
  final String issuerName = "Talha Afzal Cloth House";
  final String issuerPhone =
      "Talha Afzal: 0303-6339313, Waqas Afzal: 0300-6766691, Abbas Afzal: 0303-2312531";
  final String issuerAddress =
      "Shop No 21, Nasir Cloth Market, Chungi No 11, Multan";

  @override
  void dispose() {
    amountController.dispose();
    noteController.dispose();
    super.dispose();
  }

  Future<String> _generateSlipSerial() async {
    final counterRef = FirebaseFirestore.instance
        .collection('counters')
        .doc('paySlip');

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

  Future<void> _printSlip(Map<String, dynamic> slipData) async {
    final pdf = pw.Document();

    final serial = (slipData['serialNumber'] ?? '').toString();
    final amount = (slipData['amount'] ?? 0).toDouble();
    final status = (slipData['status'] ?? 'Unpaid').toString();
    final date = (slipData['date'] ?? '').toString();
    final time = (slipData['time'] ?? '').toString();
    final dayName = (slipData['dayName'] ?? '').toString();
    final supplierName = (slipData['supplierName'] ?? '').toString();
    final supplierPhone = (slipData['supplierPhone'] ?? '').toString();
    final supplierAddress = (slipData['supplierAddress'] ?? '').toString();
    final issuerName = (slipData['issuerName'] ?? '').toString();
    final issuerPhone = (slipData['issuerPhone'] ?? '').toString();
    final issuerAddress = (slipData['issuerAddress'] ?? '').toString();
    final note = (slipData['note'] ?? '').toString();
    final qrData = (slipData['qrData'] ?? '').toString();

    final statusColor = status == 'Paid'
        ? PdfColors.green
        : PdfColors.red;

    pdf.addPage(
      pw.Page(
        // A6 size: 105 x 148 mm
        pageFormat:
        PdfPageFormat(105 * PdfPageFormat.mm, 148 * PdfPageFormat.mm),
        margin: const pw.EdgeInsets.all(8),
        build: (context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(6),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                pw.Text(
                  "PAY SLIP",
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 4),

                // Date / status
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text("Date: $date",
                            style: const pw.TextStyle(fontSize: 9)),
                        pw.Text("Time: $time",
                            style: const pw.TextStyle(fontSize: 9)),
                        pw.Text("Day: $dayName",
                            style: const pw.TextStyle(fontSize: 9)),
                      ],
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 4, vertical: 2),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.grey200,
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Text(
                        status,
                        style: pw.TextStyle(
                          color: statusColor,
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),

                pw.SizedBox(height: 4),
                pw.Divider(),

                // Supplier
                pw.Text(
                  "Supplier",
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(supplierName,
                    style: const pw.TextStyle(fontSize: 9)),
                if (supplierPhone.isNotEmpty)
                  pw.Text(supplierPhone,
                      style: const pw.TextStyle(fontSize: 8)),
                if (supplierAddress.isNotEmpty)
                  pw.Text(supplierAddress,
                      style: const pw.TextStyle(fontSize: 8)),

                pw.SizedBox(height: 4),
                pw.Divider(),

                // Issuer
                pw.Text(
                  "Issuer",
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(issuerName,
                    style: const pw.TextStyle(fontSize: 9)),
                pw.Text(issuerPhone,
                    style: const pw.TextStyle(fontSize: 8)),
                pw.Text(issuerAddress,
                    style: const pw.TextStyle(fontSize: 8)),

                pw.SizedBox(height: 4),
                pw.Divider(),

                // Amount
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      "Amount:",
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      "${amount.toStringAsFixed(2)} PKR",
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                if (note.isNotEmpty)
                  pw.Text("Note: $note",
                      style: const pw.TextStyle(fontSize: 8)),

                pw.SizedBox(height: 4),
                pw.Divider(),

                // QR + serial
                if (qrData.isNotEmpty)
                  pw.Center(
                    child: pw.Column(
                      children: [
                        pw.Text(
                          "Scan to Verify",
                          style: pw.TextStyle(
                            fontSize: 8,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.BarcodeWidget(
                          barcode: pw.Barcode.qrCode(),
                          data: qrData,
                          width: 60,
                          height: 60,
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          serial,
                          style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                pw.SizedBox(height: 4),
                pw.Text(
                  "Talha Afzal Cloth House - System Generated Slip",
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(
                    fontSize: 7,
                    color: PdfColors.grey,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  Future<void> _saveSlip() async {
    if (selectedSupplierId == null || selectedSupplierData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a supplier")),
      );
      return;
    }

    final amount = double.tryParse(amountController.text.trim()) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter a valid amount")),
      );
      return;
    }

    setState(() => saving = true);

    try {
      final now = DateTime.now();
      final date = DateFormat('dd/MM/yyyy').format(now);
      final time = DateFormat('hh:mm a').format(now);
      final dayName = DateFormat('EEEE').format(now);

      final serialNumber = await _generateSlipSerial();

      final slipRef = FirebaseFirestore.instance
          .collection("suppliers")
          .doc(selectedSupplierId)
          .collection("paySlips")
          .doc();

      final slipData = {
        'serialNumber': serialNumber,
        'slipId': slipRef.id,
        'supplierId': selectedSupplierId,
        'supplierName': selectedSupplierData!['name'] ?? '',
        'supplierPhone': selectedSupplierData!['phone'] ?? '',
        'supplierAddress': selectedSupplierData!['address'] ?? '',
        'issuerName': issuerName,
        'issuerPhone': issuerPhone,
        'issuerAddress': issuerAddress,
        'amount': amount,
        'status': 'Unpaid', // default
        'note': noteController.text.trim().isEmpty
            ? null
            : noteController.text.trim(),
        'date': date,
        'time': time,
        'dayName': dayName,
        'createdAt': now,
        'paidAt': null,
        // QR content – app can scan & verify
        'qrData': 'PAYSLIP|$selectedSupplierId|${slipRef.id}',
      };

      // Save in Firestore
      await slipRef.set(slipData);

      // 🔹 Print immediately after save
      await _printSlip(slipData);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Pay slip saved & sent to printer")),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error saving pay slip: $e")),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Create Pay Slip")),
      body: Container(
        color: Colors.grey.shade100,
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 550),
            child: Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "Pay Slip Details",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Supplier dropdown
                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection("suppliers")
                          .orderBy("name")
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Text("Error: ${snapshot.error}");
                        }
                        if (!snapshot.hasData) {
                          return const LinearProgressIndicator();
                        }

                        final docs = snapshot.data!.docs;
                        if (docs.isEmpty) {
                          return const Text(
                            "No suppliers found. Please add supplier first.",
                          );
                        }

                        return DropdownButtonFormField<String>(
                          value: selectedSupplierId,
                          decoration: const InputDecoration(
                            labelText: "Supplier",
                            border: OutlineInputBorder(),
                          ),
                          items: docs.map((d) {
                            final data = d.data();
                            final name =
                            (data['name'] ?? 'Supplier').toString();
                            return DropdownMenuItem<String>(
                              value: d.id,
                              child: Text(name),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val == null) return;
                            final doc = docs.firstWhere((d) => d.id == val);
                            setState(() {
                              selectedSupplierId = val;
                              selectedSupplierData = doc.data();
                            });
                          },
                        );
                      },
                    ),

                    const SizedBox(height: 12),

                    TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: const InputDecoration(
                        labelText: "Amount",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.currency_rupee),
                      ),
                    ),

                    const SizedBox(height: 12),

                    TextField(
                      controller: noteController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: "Note (optional)",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.note),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Issuer info (read-only)
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.blue.shade50,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Issuer (fixed)",
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text(issuerName),
                          Text(issuerPhone),
                          Text(issuerAddress),
                        ],
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
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                            : const Icon(Icons.print),
                        label: Text(
                          saving ? "Saving & Printing..." : "Save & Print",
                        ),
                      ),
                    )
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
