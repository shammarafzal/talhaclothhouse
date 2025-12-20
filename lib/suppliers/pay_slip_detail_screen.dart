import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

class PaySlipDetailScreen extends StatelessWidget {
  final String supplierId;
  final String slipId;

  const PaySlipDetailScreen({
    super.key,
    required this.supplierId,
    required this.slipId,
  });

  /// 🔹 Ask who cashed & cash date, then mark as paid
  Future<void> _markAsPaid(BuildContext context) async {
    final cashedByCtrl = TextEditingController();
    DateTime cashDate = DateTime.now();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text("Mark Slip as Paid"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: cashedByCtrl,
                decoration: const InputDecoration(
                  labelText: "Cashed By",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: cashDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    cashDate = picked;
                  }
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: "Cash Date",
                    border: OutlineInputBorder(),
                  ),
                  child: Text(
                    DateFormat('dd/MM/yyyy').format(cashDate),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                if (cashedByCtrl.text.trim().isEmpty) return;
                Navigator.pop(ctx, true);
              },
              child: const Text("Confirm"),
            ),
          ],
        );
      },
    );

    if (result != true) return;

    try {
      await FirebaseFirestore.instance
          .collection("suppliers")
          .doc(supplierId)
          .collection("paySlips")
          .doc(slipId)
          .update({
        'status': 'Paid',
        'paidAt': DateTime.now(),
        'cashDate': DateFormat('dd/MM/yyyy').format(cashDate),
        'cashedBy': cashedByCtrl.text.trim(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Slip marked as Paid")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection("suppliers")
          .doc(supplierId)
          .collection("paySlips")
          .doc(slipId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final d = snapshot.data!.data()!;
        final status = d['status'] ?? 'Unpaid';
        final statusColor = status == 'Paid' ? Colors.green : Colors.red;

        return Scaffold(
          appBar: AppBar(
            title: Text(d['serialNumber'] ?? 'Pay Slip'),
            actions: [
              if (status != 'Paid')
                IconButton(
                  icon: const Icon(Icons.done),
                  tooltip: "Mark as Paid",
                  onPressed: () => _markAsPaid(context),
                ),
            ],
          ),
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 450),
                child: Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          "PAY SLIP",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),

                        /// Dates + Status
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Slip Date: ${d['slipDate']} (${d['slipDayName']})"),
                                Text("Pay Date: ${d['payDate']} (${d['payDayName']})"),
                                Text("Time: ${d['time']}"),
                              ],
                            ),
                            Chip(
                              label: Text(status),
                              backgroundColor: statusColor.withOpacity(0.1),
                              labelStyle: TextStyle(
                                  color: statusColor,
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),

                        const Divider(height: 24),

                        /// Supplier
                        const Text("Supplier", style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(d['supplierName'] ?? ''),
                        if ((d['supplierPhone'] ?? '').toString().isNotEmpty)
                          Text(d['supplierPhone']),
                        if ((d['supplierAddress'] ?? '').toString().isNotEmpty)
                          Text(d['supplierAddress']),

                        const Divider(height: 24),

                        /// Issuer
                        const Text("Issuer", style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(d['issuerName']),
                        Text(d['issuerPhone']),
                        Text(d['issuerAddress']),

                        const Divider(height: 24),

                        /// Amount
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("Amount:",
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            Text(
                              "${(d['amount'] ?? 0).toStringAsFixed(2)} PKR",
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ],
                        ),

                        if ((d['note'] ?? '').toString().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text("Note: ${d['note']}"),
                          ),

                        const Divider(height: 24),

                        /// Cash info
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Cash Date: ${d['cashDate'] ?? '—'}"),
                              Text("Cashed By: ${d['cashedBy'] ?? '—'}"),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        /// QR
                        if ((d['qrData'] ?? '').toString().isNotEmpty)
                          Column(
                            children: [
                              const Text("Scan to Verify"),
                              const SizedBox(height: 6),
                              QrImageView(
                                data: d['qrData'],
                                size: 90,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                d['serialNumber'],
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),

                        const SizedBox(height: 12),
                        const Text(
                          "Talha Afzal Cloth House - System Generated Slip",
                          textAlign: TextAlign.center,
                          style:
                          TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                      ],
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
}
