import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'pay_slip_detail_screen.dart';

class SupplierPaySlipsScreen extends StatelessWidget {
  final String supplierId;
  final String supplierName;
  final Map<String, dynamic> supplierData;

  const SupplierPaySlipsScreen({
    super.key,
    required this.supplierId,
    required this.supplierName,
    required this.supplierData,
  });

  Color _statusColor(String status) {
    switch (status) {
      case 'Paid':
        return Colors.green;
      case 'Unpaid':
      default:
        return Colors.red;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'Paid':
        return 'Paid';
      case 'Unpaid':
      default:
        return 'Unpaid';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Pay Slips – $supplierName"),
      ),
      body: Container(
        color: Colors.grey.shade100,
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection("suppliers")
              .doc(supplierId)
              .collection("paySlips")
              .orderBy("createdAt", descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text("Error: ${snapshot.error}"));
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = snapshot.data?.docs ?? [];
            if (docs.isEmpty) {
              return const Center(
                child: Text("No pay slips for this supplier."),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: docs.length,
              itemBuilder: (contextList, index) {
                final doc = docs[index];
                final data = doc.data();
                final serial = (data['serialNumber'] ?? '').toString();
                final date = (data['date'] ?? '').toString();
                final amount =
                (data['amount'] ?? 0).toDouble();
                final status =
                (data['status'] ?? 'Unpaid').toString();

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                      _statusColor(status).withOpacity(0.1),
                      child: Text(
                        (index + 1).toString(),
                        style: TextStyle(
                          color: _statusColor(status),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    title: Text(serial.isEmpty ? "Pay Slip" : serial),
                    subtitle: Text("Date: $date\nAmount: ${amount.toStringAsFixed(2)}"),
                    isThreeLine: true,
                    trailing: Chip(
                      label: Text(
                        _statusLabel(status),
                        style: const TextStyle(fontSize: 12),
                      ),
                      backgroundColor:
                      _statusColor(status).withOpacity(0.1),
                      labelStyle: TextStyle(
                        color: _statusColor(status),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onTap: () {
                      Navigator.push(
                        contextList,
                        MaterialPageRoute(
                          builder: (_) => PaySlipDetailScreen(
                            supplierId: supplierId,
                            slipId: doc.id,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
