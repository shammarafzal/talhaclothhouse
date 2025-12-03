import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'supplier_bulk_payment_screen.dart';

class SupplierInvoicesSummaryScreen extends StatelessWidget {
  final String supplierId;
  final String supplierName;

  const SupplierInvoicesSummaryScreen({
    super.key,
    required this.supplierId,
    required this.supplierName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Invoices – $supplierName"),
        centerTitle: true,
      ),
      body: Container(
        color: Colors.grey.shade100,
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('suppliers')
              .doc(supplierId)
              .collection('purchases')
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Text("Error: ${snapshot.error}"),
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = snapshot.data?.docs ?? [];

            if (docs.isEmpty) {
              return const Center(
                child: Text(
                  "No invoices found for this supplier.",
                  style: TextStyle(fontSize: 16),
                ),
              );
            }

            double totalRemaining = 0;
            for (final d in docs) {
              final data = d.data();
              final total = (data['totalAmount'] ?? 0).toDouble();
              final paid = (data['amountPaid'] ?? 0).toDouble();
              totalRemaining += (total - paid);
            }

            return Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: docs.length,
                    itemBuilder: (contextList, index) {
                      final doc = docs[index];
                      final data = doc.data();
                      final srNo = "SR-${index + 1}";

                      return _InvoiceSummaryCard(
                        srNo: srNo,
                        supplierId: supplierId,
                        invoiceId: doc.id,
                        invoiceData: data,
                      );
                    },
                  ),
                ),

                // Total remaining footer
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 6,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Total Remaining from all invoices:",
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            totalRemaining.toStringAsFixed(2),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: totalRemaining <= 0
                            ? null
                            : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SupplierBulkPaymentScreen(
                                supplierId: supplierId,
                                supplierName: supplierName,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.payments),
                        label: const Text("Make New Payment"),
                      ),
                    ],
                  ),
                ),

              ],
            );
          },
        ),
      ),
    );
  }
}

class _InvoiceSummaryCard extends StatelessWidget {
  final String srNo;
  final String supplierId;
  final String invoiceId;
  final Map<String, dynamic> invoiceData;

  const _InvoiceSummaryCard({
    required this.srNo,
    required this.supplierId,
    required this.invoiceId,
    required this.invoiceData,
  });

  String _formatStatus(String status) {
    switch (status) {
      case 'Paid':
        return 'Paid full';
      case 'Partial':
        return 'Partial paid';
      case 'Unpaid':
      default:
        return 'Paid zero';
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Paid':
        return Colors.green;
      case 'Partial':
        return Colors.orange;
      case 'Unpaid':
      default:
        return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    final date = (invoiceData['date'] ?? '').toString();
    final invNo = (invoiceData['invoiceNumber'] ?? '').toString();
    final total = (invoiceData['totalAmount'] ?? 0).toDouble();
    final paid = (invoiceData['amountPaid'] ?? 0).toDouble();
    final remaining = total - paid;
    final statusRaw = (invoiceData['paymentStatus'] ?? 'Unpaid').toString();
    final status = _formatStatus(statusRaw);

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(top: 8),
          leading: CircleAvatar(
            radius: 22,
            backgroundColor: Colors.blue.shade50,
            child: Text(
              srNo.split('-').last, // show only number part
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
          ),
          title: Text(
            invNo.isEmpty ? "Invoice" : invNo,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Date: $date"),
                const SizedBox(height: 2),
                Text("Total: ${total.toStringAsFixed(2)}"),
                Text("Paid: ${paid.toStringAsFixed(2)}"),
                Text(
                  "Remaining: ${remaining.toStringAsFixed(2)}",
                  style: TextStyle(
                    color: remaining > 0 ? Colors.red : Colors.green,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          trailing: Chip(
            label: Text(
              status,
              style: const TextStyle(fontSize: 12),
            ),
            backgroundColor: _statusColor(statusRaw).withOpacity(0.1),
            labelStyle: TextStyle(
              color: _statusColor(statusRaw),
              fontWeight: FontWeight.w600,
            ),
          ),
          children: [
            const Divider(),
            const Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Text(
                  "Payments",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            _InvoicePaymentsList(
              supplierId: supplierId,
              invoiceId: invoiceId,
            ),
          ],
        ),
      ),
    );
  }
}

class _InvoicePaymentsList extends StatelessWidget {
  final String supplierId;
  final String invoiceId;

  const _InvoicePaymentsList({
    required this.supplierId,
    required this.invoiceId,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('suppliers')
          .doc(supplierId)
          .collection('purchases')
          .doc(invoiceId)
          .collection('payments')
          .orderBy('createdAt', descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text("Error loading payments: ${snapshot.error}"),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(8.0),
            child: LinearProgressIndicator(),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text("No payments yet (Paid zero)."),
          );
        }

        final df = DateFormat('dd/MM/yy');

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: docs.map((d) {
            final data = d.data();
            final amount = (data['amount'] ?? 0).toDouble();
            final method = (data['method'] ?? '').toString();
            final ts = data['createdAt'] as Timestamp?;
            final dateStr =
            ts != null ? df.format(ts.toDate()) : '-';

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2.0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      "${amount.toStringAsFixed(2)} on $dateStr",
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  if (method.isNotEmpty)
                    Text(
                      method,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
