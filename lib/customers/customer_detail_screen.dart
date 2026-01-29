import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'add_customer_screen.dart';
import 'view_customer_invoice_screen.dart';
import 'add_old_bill_screen.dart';
import 'view_oldbill.dart';
import 'dart:ui' as ui;

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

    return Directionality(
        textDirection: ui.TextDirection.rtl,
        child: Scaffold(
      appBar: AppBar(
        title: Text(name.isEmpty ? "گاہک" : name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: "گاہک میں ترمیم کریں",
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
            icon: const Icon(Icons.history),
            tooltip: "پرانا بل شامل کریں",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddOldBillScreen(
                    customerId: customerId,
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
              _buildSalesAndBillsCard(context),
            ],
          ),
        ),
      ),
        ),
    );
  }

  // ================= HEADER =================

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
                name.isNotEmpty ? name[0].toUpperCase() : "C",
                style: const TextStyle(fontSize: 22),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name.isEmpty ? "گاہک" : name,
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

  // ================= SALES + OLD BILLS =================

  Widget _buildSalesAndBillsCard(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "سیلز اور بل",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),

            // ================= SALES INVOICES =================

            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection("customers")
                  .doc(customerId)
                  .collection("sales")
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const LinearProgressIndicator();
                }

                final docs = snap.data!.docs;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "سیلز انوائس",
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    if (docs.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(8),
                        child: Text("ابھی کوئی انوائس موجود نہیں"),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: docs.length,
                        itemBuilder: (ctx, i) {
                          final m = docs[i].data();
                          final invoiceNo =
                          (m['invoiceNumber'] ?? '').toString();
                          final date = (m['date'] ?? '').toString();
                          final total =
                          (m['totalAmount'] ?? 0).toDouble();
                          final paid =
                          (m['amountPaid'] ?? 0).toDouble();
                          final status =
                          (m['paymentStatus'] ?? 'Unpaid').toString();

                          Color color = status == 'Paid'
                              ? Colors.green
                              : status == 'Partial'
                              ? Colors.orange
                              : Colors.red;

                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            child: ListTile(
                              leading:
                              const Icon(Icons.receipt_long),
                              title: Text("انوائس نمبر: $invoiceNo"),
                              subtitle: Text(
                                "$date • کل رقم: ${total.toStringAsFixed(0)} • ادا شدہ: ${paid.toStringAsFixed(0)}",
                              ),
                              trailing: Chip(
                                label: Text(status,
                                    style:
                                    const TextStyle(fontSize: 11)),
                                backgroundColor:
                                color.withOpacity(0.1),
                                labelStyle: TextStyle(
                                  color: color,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              onTap: () {
                                Navigator.push(
                                  ctx,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        ViewCustomerInvoiceScreen(
                                          customerId: customerId,
                                          saleId: docs[i].id,
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

            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),

            // ================= OLD BILLS =================

            const Text(
              "پرانے بل",
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),

            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection("customers")
                  .doc(customerId)
                  .collection("oldBills")
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const LinearProgressIndicator();
                }

                final docs = snap.data!.docs;

                if (docs.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text("کوئی پرانا بل موجود نہیں"),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: docs.length,
                  itemBuilder: (ctx, i) {
                    final m = docs[i].data();
                    final billNo =
                    (m['billNumber'] ?? 'پرانا بل').toString();
                    final amount =
                    (m['amount'] ?? 0).toDouble();

                    final ts =
                    (m['createdAt'] as Timestamp?)?.toDate();
                    final dateText = ts == null
                        ? ''
                        : DateFormat('dd/MM/yyyy').format(ts);

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        leading: const Icon(Icons.history),
                        title: Text(billNo),
                        subtitle: Text(
                          "تاریخ: $dateText • رقم: ${amount.toStringAsFixed(0)}",
                        ),
                        trailing: const Chip(
                          label: Text("پرانا",
                              style: TextStyle(fontSize: 11)),
                          backgroundColor: Color(0xFFE3F2FD),
                        ),
                        onTap: () {
                          Navigator.push(
                            ctx,
                            MaterialPageRoute(
                              builder: (_) => ViewOldBillScreen(
                                customerId: customerId,
                                billId: docs[i].id,
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
          ],
        ),
      ),
    );
  }
}
