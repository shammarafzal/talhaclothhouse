import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import 'add_payment_screen.dart';

class ViewInvoiceScreen extends StatefulWidget {
  final String supplierId;
  final String invoiceId;

  const ViewInvoiceScreen({
    super.key,
    required this.supplierId,
    required this.invoiceId,
  });

  @override
  State<ViewInvoiceScreen> createState() => _ViewInvoiceScreenState();
}

class _ViewInvoiceScreenState extends State<ViewInvoiceScreen> {
  Future<void> _printInvoice(Map<String, dynamic> data) async {
    final pdf = pw.Document();
    final items =
    (data['items'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(24),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  "Purchase Invoice",
                  style: pw.TextStyle(
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 12),
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text("Supplier: ${data['supplierName'] ?? ''}"),
                          pw.Text("Phone: ${data['supplierPhone'] ?? ''}"),
                          pw.Text("Address: ${data['supplierAddress'] ?? ''}"),
                        ],
                      ),
                    ),
                    pw.SizedBox(width: 16),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text("Invoice #: ${data['invoiceNumber'] ?? ''}"),
                          pw.Text("Date: ${data['date'] ?? ''}"),
                          pw.Text("Time: ${data['time'] ?? ''}"),
                          pw.Text("Day: ${data['dayName'] ?? ''}"),
                        ],
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 12),
                pw.Text("Buyer: ${data['buyerName'] ?? ''}"),
                pw.Text("Buyer Phone: ${data['buyerPhone'] ?? ''}"),
                pw.Text("Buyer Address: ${data['buyerAddress'] ?? ''}"),
                pw.SizedBox(height: 16),
                pw.Table.fromTextArray(
                  headers: const ["Item", "Qty", "Rate", "Amount"],
                  data: items
                      .map(
                        (it) => [
                      it['name'] ?? '',
                      (it['qty'] ?? '').toString(),
                      (it['rate'] ?? '').toString(),
                      (it['amount'] ?? '').toString(),
                    ],
                  )
                      .toList(),
                ),
                pw.SizedBox(height: 12),
                pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        "Total: ${data['totalAmount'] ?? 0}",
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text("Paid: ${data['amountPaid'] ?? 0}"),
                      pw.Text("Due: ${data['amountDue'] ?? 0}"),
                      pw.Text("Status: ${data['paymentStatus'] ?? 'Unpaid'}"),
                      if (data['paymentMethod'] != null)
                        pw.Text("Method: ${data['paymentMethod']}"),
                    ],
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Invoice"),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('suppliers')
            .doc(widget.supplierId)
            .collection('purchases')
            .doc(widget.invoiceId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text("Error: ${snapshot.error}"),
            );
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.data()!;
          final items =
          (data['items'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();

          final total = (data['totalAmount'] ?? 0).toDouble();
          final paid = (data['amountPaid'] ?? 0).toDouble();
          final due = (data['amountDue'] ?? (total - paid)).toDouble();
          final status = (data['paymentStatus'] ?? 'Unpaid').toString();
          final method = (data['paymentMethod'] ?? '-').toString();
          final note = (data['paymentNote'] ?? '').toString();

          return Scaffold(
            appBar: AppBar(
              title: Text("Invoice #${data['invoiceNumber'] ?? ''}"),
              actions: [
                IconButton(
                  icon: const Icon(Icons.payments),
                  tooltip: "Add Payment",
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AddPaymentScreen(
                          supplierId: widget.supplierId,
                          invoiceId: widget.invoiceId,
                        ),
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.print),
                  tooltip: "Print Invoice",
                  onPressed: () => _printInvoice(data),
                ),
              ],
            ),
            body: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            "Purchase Invoice",
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 16),

                          // Supplier + Invoice info
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final isMobile = constraints.maxWidth < 600;
                              final supplier =
                              _buildSupplierInfoCard(context, data);
                              final inv =
                              _buildInvoiceInfoCard(context, data);

                              if (isMobile) {
                                return Column(
                                  children: [
                                    supplier,
                                    const SizedBox(height: 12),
                                    inv,
                                  ],
                                );
                              } else {
                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(child: supplier),
                                    const SizedBox(width: 12),
                                    Expanded(child: inv),
                                  ],
                                );
                              }
                            },
                          ),

                          const SizedBox(height: 16),

                          _buildBuyerInfoCard(context, data),

                          const SizedBox(height: 16),

                          _buildPaymentSummaryCard(
                            context,
                            total: total,
                            paid: paid,
                            due: due,
                            status: status,
                            method: method,
                            note: note,
                          ),

                          const SizedBox(height: 16),

                          Text(
                            'Items',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),

                          _buildItemsTable(context, items),

                          const SizedBox(height: 16),

                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              'Total: ${total.toStringAsFixed(2)}',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),

                          const SizedBox(height: 16),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () => Navigator.pop(context),
                                icon: const Icon(Icons.close),
                                label: const Text("Close"),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                onPressed: () => _printInvoice(data),
                                icon: const Icon(Icons.print),
                                label: const Text("Print"),
                              ),
                            ],
                          )
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSupplierInfoCard(
      BuildContext context, Map<String, dynamic> data) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Supplier'),
          const SizedBox(height: 4),
          Text(
            data['supplierName'] ?? '',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(data['supplierPhone'] ?? ''),
          Text(data['supplierAddress'] ?? ''),
        ],
      ),
    );
  }

  Widget _buildInvoiceInfoCard(
      BuildContext context, Map<String, dynamic> data) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Invoice Info'),
          const SizedBox(height: 4),
          _infoRow('Invoice #', data['invoiceNumber']?.toString() ?? ''),
          _infoRow('Date', data['date']?.toString() ?? ''),
          _infoRow('Time', data['time']?.toString() ?? ''),
          _infoRow('Day', data['dayName']?.toString() ?? ''),
        ],
      ),
    );
  }

  Widget _buildBuyerInfoCard(
      BuildContext context, Map<String, dynamic> data) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Buyer'),
          const SizedBox(height: 4),
          Text("Name: ${data['buyerName'] ?? ''}"),
          Text("Phone: ${data['buyerPhone'] ?? ''}"),
          Text("Address: ${data['buyerAddress'] ?? ''}"),
        ],
      ),
    );
  }

  Widget _buildPaymentSummaryCard(
      BuildContext context, {
        required double total,
        required double paid,
        required double due,
        required String status,
        required String method,
        required String note,
      }) {
    Color chipColor;
    switch (status) {
      case 'Paid':
        chipColor = Colors.green.shade100;
        break;
      case 'Partial':
        chipColor = Colors.orange.shade100;
        break;
      default:
        chipColor = Colors.red.shade100;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Payment Summary',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              Chip(
                label: Text("Status: $status"),
                backgroundColor: chipColor,
              ),
              Chip(
                label: Text("Total: ${total.toStringAsFixed(2)}"),
              ),
              Chip(
                label: Text("Paid: ${paid.toStringAsFixed(2)}"),
              ),
              Chip(
                label: Text("Due: ${due.toStringAsFixed(2)}"),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text("Method: $method"),
          if (note.isNotEmpty) Text("Note: $note"),
        ],
      ),
    );
  }

  Widget _buildItemsTable(
      BuildContext context, List<Map<String, dynamic>> items) {
    if (items.isEmpty) {
      return const Text("No items in this invoice.");
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Colors.grey.shade400),
            ),
          ),
          child: Row(
            children: const [
              Expanded(flex: 4, child: Text("Item")),
              Expanded(flex: 2, child: Text("Qty", textAlign: TextAlign.right)),
              Expanded(flex: 2, child: Text("Rate", textAlign: TextAlign.right)),
              Expanded(
                  flex: 2,
                  child: Text("Amount", textAlign: TextAlign.right)),
            ],
          ),
        ),
        ...items.map((it) {
          final name = it['name'] ?? '';
          final qty = (it['qty'] ?? '').toString();
          final rate = (it['rate'] ?? '').toString();
          final amount = (it['amount'] ?? '').toString();

          return Container(
            padding:
            const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
            child: Row(
              children: [
                Expanded(flex: 4, child: Text(name.toString())),
                Expanded(
                  flex: 2,
                  child: Text(qty, textAlign: TextAlign.right),
                ),
                Expanded(
                  flex: 2,
                  child: Text(rate, textAlign: TextAlign.right),
                ),
                Expanded(
                  flex: 2,
                  child: Text(amount, textAlign: TextAlign.right),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(width: 90, child: Text(label)),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
