import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'pay_slip_qr_scanner_screen.dart';

import 'create_pay_slip_screen.dart';
import 'supplier_pay_slips_screen.dart';

class PaySlipsScreen extends StatelessWidget {
  const PaySlipsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Pay Slips"),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: "Create Pay Slip",
            onPressed: () {
              // Navigator.push(
              //   context,
              //   MaterialPageRoute(
              //     builder: (_) => const CreatePaySlipScreen(),
              //   ),
              // );
            },
          ),
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: "Scan Pay Slip",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const PaySlipQrScannerScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: Container(
        color: Colors.grey.shade100,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: const [
                  Text(
                    "Suppliers",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection("suppliers")
                    .orderBy("name")
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
                      child: Text("No suppliers found."),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: docs.length,
                    itemBuilder: (contextList, index) {
                      final doc = docs[index];
                      final data = doc.data();
                      final name = (data["name"] ?? "").toString();
                      final phone = (data["phone"] ?? "").toString();

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Text(
                              name.isEmpty
                                  ? "S"
                                  : name[0].toUpperCase(),
                            ),
                          ),
                          title: Text(name.isEmpty
                              ? "Unnamed Supplier"
                              : name),
                          subtitle: phone.isEmpty ? null : Text(phone),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            Navigator.push(
                              contextList,
                              MaterialPageRoute(
                                builder: (_) => SupplierPaySlipsScreen(
                                  supplierId: doc.id,
                                  supplierName: name.isEmpty
                                      ? "Supplier"
                                      : name,
                                  supplierData: data,
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
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // Navigator.push(
          //   context,
          //   MaterialPageRoute(
          //     builder: (_) => const CreatePaySlipScreen(),
          //   ),
          // );
        },
        icon: const Icon(Icons.add),
        label: const Text("Create Pay Slip"),
      ),
    );
  }
}
