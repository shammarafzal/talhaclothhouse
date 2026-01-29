import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'sales_invoice_printer.dart';

class ViewCustomerInvoiceScreen extends StatelessWidget {
  final String customerId;
  final String saleId;

  const ViewCustomerInvoiceScreen({
    super.key,
    required this.customerId,
    required this.saleId,
  });

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('customers')
            .doc(customerId)
            .collection('sales')
            .doc(saleId)
            .snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          final data = snap.data!.data()!;
          final shop = data['shop'] ?? {};
          final customer = data['customer'] ?? {};
          final items =
          (data['items'] as List).cast<Map<String, dynamic>>();

          return Scaffold(
            appBar: AppBar(
              title: Text("سیلز بل"),
              actions: [
                IconButton(
                  icon: const Icon(Icons.print),
                  onPressed: () async {
                    final customer = data['customer'] ?? {};

                    await printSalesInvoice(
                      invoiceData: data,
                      customerName: (customer['name'] ?? '').toString(),
                      customerPhone: (customer['phone'] ?? '').toString(),
                      customerAddress: (customer['address'] ?? '').toString(),
                    );
                  },
                ),
              ],
            ),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
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
                      /// SHOP
                      _block(
                        "دکان کی تفصیل",
                        [
                          shop['name'],
                          shop['phone'],
                          shop['address'],
                        ],
                      ),

                      const SizedBox(height: 12),

                      /// CUSTOMER
                      _block(
                        "گاہک کی تفصیل",
                        [
                          customer['name'],
                          customer['phone'],
                          customer['address'],
                        ],
                      ),

                      const SizedBox(height: 12),

                      /// ITEMS
                      const Text(
                        "خریداری",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 6),

                      Table(
                        border: TableBorder.all(),
                        children: [
                           TableRow(
                            decoration:
                            BoxDecoration(color: Color(0xFFEFEFEF)),
                            children: [
                              _cell("آئٹم"),
                              _cell("مقدار"),
                              _cell("ریٹ"),
                              _cell("کل"),
                            ],
                          ),
                          ...items.map((e) {
                            return TableRow(
                              children: [
                                _cell(e['name']),
                                _cell(e['qty'].toString()),
                                _cell(e['rate'].toString()),
                                _cell(e['amount'].toString()),
                              ],
                            );
                          }).toList(),
                        ],
                      ),

                      const SizedBox(height: 12),

                      /// TOTAL
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("کل رقم: ${data['totalAmount']}"),
                            Text("ادا شدہ: ${data['amountPaid']}"),
                            Text("بقایا: ${data['amountDue']}"),
                            // Text(
                            //   "حالت: ${_urduStatus(data['paymentStatus'])}",
                            // ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ================= HELPERS =================
  Widget _block(String title, List<dynamic> lines) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 4),
        ...lines.where((e) => e != null && e.toString().isNotEmpty).map(
              (e) => Text(e.toString()),
        ),
      ],
    );
  }

  static Widget _cell(String t) {
    return Padding(
      padding: const EdgeInsets.all(6),
      child: Text(t),
    );
  }
}
