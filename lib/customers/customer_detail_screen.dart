import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:talhaclothhouse/customers/view_customer_invoice_screen.dart';

import 'CreateCustomerReceiptScreen.dart';
import 'add_customer_screen.dart';


class CustomerDetailScreen extends StatelessWidget {
  final String customerId;
  final Map<String, dynamic> customerData;

  const CustomerDetailScreen({
    super.key,
    required this.customerId,
    required this.customerData,
  });

  @override
  Widget build(BuildContext context) {
    final name = (customerData['name'] ?? '').toString();

    return Scaffold(
      appBar: AppBar(
        title: Text(name.isEmpty ? "Customer" : name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: "Edit Customer",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddCustomerScreen(
                    customerId: customerId,
                    customerData: customerData,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.receipt_long),
            tooltip: "New Sales Invoice",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CreateCustomerReceiptScreen(
                    customerId: customerId,
                    customerData: customerData,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Container(
        color: Colors.grey.shade100,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildHeaderCard(),
              const SizedBox(height: 16),
              _buildSalesSummaryCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    final name = (customerData['name'] ?? '').toString();
    final phone = (customerData['phone'] ?? '').toString();
    final address = (customerData['address'] ?? '').toString();

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              child: Text(
                (name.isEmpty ? "C" : name[0].toUpperCase()),
                style: const TextStyle(fontSize: 22),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name.isEmpty ? "Customer" : name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (phone.isNotEmpty) Text("📞 $phone"),
                  if (address.isNotEmpty) Text("📍 $address"),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSalesSummaryCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection("customers")
              .doc(customerId)
              .collection("sales")
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Text("Error: ${snapshot.error}");
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const LinearProgressIndicator();
            }

            final docs = snapshot.data?.docs ?? [];
            final now = DateTime.now();

            double total7 = 0, total30 = 0, totalAll = 0;
            double remainingAll = 0;

            for (final d in docs) {
              final m = d.data();
              final ts = (m['createdAt'] as Timestamp?)?.toDate() ??
                  DateTime.now();
              final diffDays = now.difference(ts).inDays;
              final total = (m['totalAmount'] ?? 0).toDouble();
              final paid = (m['amountPaid'] ?? 0).toDouble();
              final due = total - paid;

              totalAll += total;
              remainingAll += due;

              if (diffDays <= 7) total7 += total;
              if (diffDays <= 30) total30 += total;
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Sales Summary",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _chip("Last 7 days: PKR ${total7.toStringAsFixed(0)}"),
                    _chip("Last 30 days: PKR ${total30.toStringAsFixed(0)}"),
                    _chip("Total Sales: PKR ${totalAll.toStringAsFixed(0)}"),
                    _chip("Total Due: PKR ${remainingAll.toStringAsFixed(0)}"),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),
                const Text(
                  "All Sales Invoices",
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                if (docs.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text("No invoices yet."),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: docs.length,
                    itemBuilder: (contextList, index) {
                      final doc = docs[index];
                      final m = doc.data();
                      // 🔧 use invoiceNumber (what we save from CreateCustomerReceiptScreen)
                      final invoiceNo = (m['invoiceNumber'] ?? '').toString();
                      final date = (m['date'] ?? '').toString();
                      final total = (m['totalAmount'] ?? 0).toDouble();
                      final paid = (m['amountPaid'] ?? 0).toDouble();
                      final status =
                      (m['paymentStatus'] ?? 'Unpaid').toString();

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

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          leading: const Icon(Icons.receipt_long),
                          title: Text(
                            invoiceNo.isEmpty
                                ? "Invoice"
                                : "Invoice #$invoiceNo",
                          ),
                          subtitle: Text(
                            "$date • Total: ${total.toStringAsFixed(0)} • Paid: ${paid.toStringAsFixed(0)}",
                          ),
                          trailing: Chip(
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
                          onTap: () {
                            Navigator.push(
                              contextList,
                              MaterialPageRoute(
                                builder: (_) => ViewCustomerInvoiceScreen(
                                  customerId: customerId,
                                  saleId: doc.id,
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _chip(String text) {
    return Chip(
      label: Text(text),
      backgroundColor: Colors.blue.shade50,
    );
  }
}
