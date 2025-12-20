import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ViewOldBillScreen extends StatelessWidget {
  final String customerId;
  final String billId;

  const ViewOldBillScreen({
    super.key,
    required this.customerId,
    required this.billId,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection("customers")
          .doc(customerId)
          .collection("oldBills")
          .doc(billId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final data = snapshot.data!.data()!;
        final billNo = data['billNumber'] ?? '';
        final amount = (data['amount'] ?? 0).toDouble();

        return Scaffold(
          appBar: AppBar(title: Text(billNo)),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Old Bill",
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    Text("Bill Number: $billNo"),
                    Text("Amount: PKR ${amount.toStringAsFixed(0)}"),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
