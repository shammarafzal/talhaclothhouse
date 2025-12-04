import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

class ViewCustomerInvoiceScreen extends StatelessWidget {
  final String customerId;
  final String saleId;

  const ViewCustomerInvoiceScreen({
    super.key,
    required this.customerId,
    required this.saleId,
  });

  Future<void> _printInvoice(Map<String, dynamic> data) async {
    final pdf = pw.Document();
    final itemsList =
    (data['items'] as List).cast<Map<String, dynamic>>();

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
                  "Sales Invoice",
                  style: pw.TextStyle(
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 12),
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Shop
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment:
                        pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text("Shop: ${data['buyerName'] ?? ''}"),
                          pw.Text("Phone: ${data['buyerPhone'] ?? ''}"),
                          pw.Text("Address: ${data['buyerAddress'] ?? ''}"),
                        ],
                      ),
                    ),
                    pw.SizedBox(width: 16),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment:
                        pw.CrossAxisAlignment.start,
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
                // Customer block
                pw.Text("Customer: ${data['supplierName'] ?? ''}"),
                pw.Text("Customer Phone: ${data['supplierPhone'] ?? ''}"),
                pw.Text(
                    "Customer Address: ${data['supplierAddress'] ?? ''}"),
                pw.SizedBox(height: 16),
                pw.Table.fromTextArray(
                  headers: ["Item", "Qty", "Rate", "Amount"],
                  data: itemsList
                      .map(
                        (it) => [
                      it['name'] ?? '',
                      it['qty'].toString(),
                      it['rate'].toString(),
                      it['amount'].toString(),
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
                        "Total: ${data['totalAmount']}",
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        "Paid: ${data['amountPaid']}",
                        style: const pw.TextStyle(fontSize: 12),
                      ),
                      pw.Text(
                        "Due: ${data['amountDue']}",
                        style: const pw.TextStyle(fontSize: 12),
                      ),
                      if (data['paymentStatus'] != null)
                        pw.Text(
                          "Status: ${data['paymentStatus']}",
                          style: const pw.TextStyle(fontSize: 12),
                        ),
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
    return StreamBuilder<
        DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('customers')
          .doc(customerId)
          .collection('sales')
          .doc(saleId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(child: Text("Error: ${snapshot.error}")),
          );
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final data = snapshot.data!.data()!;
        final invoiceNo = (data['invoiceNumber'] ?? '').toString();
        final status = (data['paymentStatus'] ?? 'Unpaid').toString();
        final total = (data['totalAmount'] ?? 0).toDouble();
        final paid = (data['amountPaid'] ?? 0).toDouble();
        final due = (data['amountDue'] ?? 0).toDouble();

        Color statusColor;
        switch (status) {
          case 'Paid':
            statusColor = Colors.green;
            break;
          case 'Partial':
            statusColor = Colors.orange;
            break;
          default:
            statusColor = Colors.red;
        }

        final itemsList =
        (data['items'] as List).cast<Map<String, dynamic>>();

        return Scaffold(
          appBar: AppBar(
            title: Text(
              invoiceNo.isEmpty ? "Sales Invoice" : "Invoice #$invoiceNo",
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.print),
                tooltip: "Print",
                onPressed: () => _printInvoice(data),
              ),
            ],
          ),
          body: Container(
            color: Colors.grey.shade100,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Center(
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
                        crossAxisAlignment:
                        CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            "Sales Invoice",
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge,
                          ),
                          const SizedBox(height: 16),
                          // Top info: shop + invoice info
                          _buildTopInfo(context, data, status, statusColor),
                          const SizedBox(height: 16),
                          _buildCustomerCard(data),
                          const SizedBox(height: 16),
                          _buildItemsTable(itemsList),
                          const SizedBox(height: 16),
                          _buildTotals(context, total, paid, due, status,
                              statusColor),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTopInfo(BuildContext context, Map<String, dynamic> data,
      String status, Color statusColor) {
    final invoiceNo = (data['invoiceNumber'] ?? '').toString();
    final date = (data['date'] ?? '').toString();
    final time = (data['time'] ?? '').toString();
    final day = (data['dayName'] ?? '').toString();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        final shopCard = Expanded(
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Shop"),
                const SizedBox(height: 4),
                Text(
                  (data['buyerName'] ?? '').toString(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 2),
                Text((data['buyerPhone'] ?? '').toString()),
                Text((data['buyerAddress'] ?? '').toString()),
              ],
            ),
          ),
        );

        final invoiceCard = Expanded(
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Invoice Info"),
                const SizedBox(height: 4),
                Text("Invoice #: $invoiceNo"),
                Text("Date: $date"),
                Text("Time: $time"),
                Text("Day: $day"),
                const SizedBox(height: 4),
                Chip(
                  label: Text(
                    status,
                    style: const TextStyle(fontSize: 11),
                  ),
                  backgroundColor: statusColor.withOpacity(0.1),
                  labelStyle: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );

        if (isMobile) {
          return Column(
            children: [
              shopCard,
              const SizedBox(height: 8),
              invoiceCard,
            ],
          );
        }

        return Row(
          children: [
            shopCard,
            const SizedBox(width: 12),
            invoiceCard,
          ],
        );
      },
    );
  }

  Widget _buildCustomerCard(Map<String, dynamic> data) {
    final name = (data['supplierName'] ?? '').toString();
    final phone = (data['supplierPhone'] ?? '').toString();
    final address = (data['supplierAddress'] ?? '').toString();

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Customer"),
          const SizedBox(height: 4),
          Text(
            name,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          if (phone.isNotEmpty) Text(phone),
          if (address.isNotEmpty) Text(address),
        ],
      ),
    );
  }

  Widget _buildItemsTable(List<Map<String, dynamic>> itemsList) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Items",
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        Table(
          border: TableBorder.all(color: Colors.grey.shade300),
          columnWidths: const {
            0: FlexColumnWidth(4),
            1: FlexColumnWidth(2),
            2: FlexColumnWidth(2),
            3: FlexColumnWidth(2),
          },
          children: [
            const TableRow(
              decoration: BoxDecoration(color: Color(0xFFEFEFEF)),
              children: [
                Padding(
                  padding: EdgeInsets.all(4.0),
                  child: Text("Item",
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
                Padding(
                  padding: EdgeInsets.all(4.0),
                  child: Text("Qty",
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
                Padding(
                  padding: EdgeInsets.all(4.0),
                  child: Text("Rate",
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
                Padding(
                  padding: EdgeInsets.all(4.0),
                  child: Text("Amount",
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            ...itemsList.map((it) {
              return TableRow(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Text((it['name'] ?? '').toString()),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Text((it['qty'] ?? '').toString()),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Text((it['rate'] ?? '').toString()),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Text((it['amount'] ?? '').toString()),
                  ),
                ],
              );
            }).toList(),
          ],
        ),
      ],
    );
  }

  Widget _buildTotals(BuildContext context, double total, double paid,
      double due, String status, Color statusColor) {
    return Align(
      alignment: Alignment.centerRight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            "Total: ${total.toStringAsFixed(2)}",
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text("Paid: ${paid.toStringAsFixed(2)}"),
          Text("Due: ${due.toStringAsFixed(2)}"),
          const SizedBox(height: 4),
          Chip(
            label: Text(
              status,
              style: const TextStyle(fontSize: 11),
            ),
            backgroundColor: statusColor.withOpacity(0.1),
            labelStyle: TextStyle(
              color: statusColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
