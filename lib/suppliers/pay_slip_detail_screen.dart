import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class PaySlipDetailScreen extends StatelessWidget {
  final String supplierId;
  final String slipId;

  const PaySlipDetailScreen({
    super.key,
    required this.supplierId,
    required this.slipId,
  });

  Future<void> _updateStatus(BuildContext context, String newStatus) async {
    try {
      final ref = FirebaseFirestore.instance
          .collection("suppliers")
          .doc(supplierId)
          .collection("paySlips")
          .doc(slipId);

      final updateData = {
        'status': newStatus,
        'paidAt': newStatus == 'Paid' ? DateTime.now() : null,
      };

      await ref.update(updateData);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Status updated to $newStatus")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error updating status: $e")),
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
        final serial = (data['serialNumber'] ?? '').toString();
        final amount = (data['amount'] ?? 0).toDouble();
        final status = (data['status'] ?? 'Unpaid').toString();
        final date = (data['date'] ?? '').toString();
        final time = (data['time'] ?? '').toString();
        final dayName = (data['dayName'] ?? '').toString();
        final supplierName = (data['supplierName'] ?? '').toString();
        final supplierPhone = (data['supplierPhone'] ?? '').toString();
        final supplierAddress = (data['supplierAddress'] ?? '').toString();
        final issuerName = (data['issuerName'] ?? '').toString();
        final issuerPhone = (data['issuerPhone'] ?? '').toString();
        final issuerAddress = (data['issuerAddress'] ?? '').toString();
        final note = (data['note'] ?? '').toString();
        final qrData = (data['qrData'] ?? '').toString();

        final statusColor = status == 'Paid' ? Colors.green : Colors.red;

        return Scaffold(
          appBar: AppBar(
            title: Text(serial.isEmpty ? "Pay Slip" : serial),
            actions: [
              IconButton(
                icon: const Icon(Icons.done),
                tooltip: "Mark as Paid",
                onPressed: status == 'Paid'
                    ? null
                    : () => _updateStatus(context, 'Paid'),
              ),
              IconButton(
                icon: const Icon(Icons.undo),
                tooltip: "Mark as Unpaid",
                onPressed: status == 'Unpaid'
                    ? null
                    : () => _updateStatus(context, 'Unpaid'),
              ),
            ],
          ),
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(8),
              child: ConstrainedBox(
                // 👇 roughly A6 width for a small slip
                constraints: const BoxConstraints(maxWidth: 400),
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header
                        Text(
                          "PAY SLIP",
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 6),

                        // Date / Time / Status
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Date: $date",
                                    style: const TextStyle(fontSize: 11)),
                                Text("Time: $time",
                                    style: const TextStyle(fontSize: 11)),
                                Text("Day: $dayName",
                                    style: const TextStyle(fontSize: 11)),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                status,
                                style: TextStyle(
                                  color: statusColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 8),
                        Divider(color: Colors.grey.shade300, height: 16),

                        // Supplier
                        const Text(
                          "Supplier",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                        Text(supplierName,
                            style: const TextStyle(fontSize: 11)),
                        if (supplierPhone.isNotEmpty)
                          Text(supplierPhone,
                              style: const TextStyle(fontSize: 11)),
                        if (supplierAddress.isNotEmpty)
                          Text(supplierAddress,
                              style: const TextStyle(fontSize: 11)),

                        const SizedBox(height: 6),
                        Divider(color: Colors.grey.shade300, height: 16),

                        // Issuer
                        const Text(
                          "Issuer",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                        Text(issuerName,
                            style: const TextStyle(fontSize: 11)),
                        Text(issuerPhone,
                            style: const TextStyle(fontSize: 11)),
                        Text(issuerAddress,
                            style: const TextStyle(fontSize: 11)),

                        const SizedBox(height: 6),
                        Divider(color: Colors.grey.shade300, height: 16),

                        // Amount
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "Amount:",
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              "${amount.toStringAsFixed(2)} PKR",
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        if (note.isNotEmpty)
                          Text(
                            "Note: $note",
                            style: const TextStyle(fontSize: 11),
                          ),

                        const SizedBox(height: 8),
                        Divider(color: Colors.grey.shade300, height: 16),

                        // QR Code small
                        if (qrData.isNotEmpty) ...[
                          Center(
                            child: Column(
                              children: [
                                const Text(
                                  "Scan to Verify",
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                QrImageView(
                                  data: qrData,
                                  version: QrVersions.auto,
                                  size: 80, // 👈 smaller QR for A6
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  serial,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 6),

                        const Text(
                          "Talha Afzal Cloth House - System Generated Slip",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 9,
                            color: Colors.grey,
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
      },
    );
  }
}
