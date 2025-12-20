import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'add_supplier_screen.dart';
import 'add_supplier_product_screen.dart';
import 'create_invoice_screen.dart';
import 'supplier_invoices_summary_screen.dart';
import 'view_invoice_screen.dart';
import 'create_pay_slip_screen.dart';
import 'pay_slip_detail_screen.dart';

class SupplierDetailScreen extends StatelessWidget {
  final String supplierId;
  final Map<String, dynamic> supplierData;

  const SupplierDetailScreen({
    super.key,
    required this.supplierId,
    required this.supplierData,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(supplierData["name"] ?? "Supplier"),
        actions: [
          /// ✏️ Edit Supplier
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: "Edit Supplier",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddSupplierScreen(
                    supplierId: supplierId,
                    supplierData: supplierData,
                  ),
                ),
              );
            },
          ),

          /// 🧾 New Purchase Invoice
          IconButton(
            icon: const Icon(Icons.receipt_long),
            tooltip: "New Purchase Invoice",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CreateInvoiceScreen(
                    supplierId: supplierId,
                    supplierData: supplierData,
                  ),
                ),
              );
            },
          ),

          /// 💵 New Pay Slip
          IconButton(
            icon: const Icon(Icons.payments_outlined),
            tooltip: "New Pay Slip",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CreatePaySlipScreen(
                    supplierId: supplierId,
                    supplierData: supplierData,
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
              _buildSupplierHeaderCard(),
              const SizedBox(height: 16),
              _buildProductsCard(context),
              const SizedBox(height: 16),
              _buildPurchasesAndPaySlipsCard(context),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // HEADER
  // ---------------------------------------------------------------------------

  Widget _buildSupplierHeaderCard() {
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
                (supplierData["name"] ?? "S")[0].toUpperCase(),
                style: const TextStyle(fontSize: 22),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    supplierData["name"] ?? "",
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                  if ((supplierData["phone"] ?? "").toString().isNotEmpty)
                    Text("📞 ${supplierData["phone"]}"),
                  if ((supplierData["address"] ?? "").toString().isNotEmpty)
                    Text("📍 ${supplierData["address"]}"),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // PRODUCTS
  // ---------------------------------------------------------------------------

  Widget _buildProductsCard(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                const Text(
                  "Products",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            AddSupplierProductScreen(supplierId: supplierId),
                      ),
                    );
                  },
                  icon: const Icon(Icons.add),
                  label: const Text("Add Product"),
                ),
              ],
            ),
            const Divider(),

            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection("suppliers")
                  .doc(supplierId)
                  .collection("products")
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const LinearProgressIndicator();
                }

                final products = snapshot.data!.docs;
                if (products.isEmpty) {
                  return const Text("No products added yet.");
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: products.length,
                  itemBuilder: (_, i) {
                    final p = products[i].data() as Map<String, dynamic>;
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.inventory_2_outlined),
                      title: Text(p["name"] ?? ""),
                      subtitle: Text("Rate: ${p["rate"] ?? 0}"),
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

  // ---------------------------------------------------------------------------
  // PURCHASES + PAY SLIPS
  // ---------------------------------------------------------------------------

  Widget _buildPurchasesAndPaySlipsCard(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Purchase Invoices",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),

            /// PURCHASE INVOICES
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection("suppliers")
                  .doc(supplierId)
                  .collection("purchases")
                  .orderBy("createdAt", descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const LinearProgressIndicator();
                }

                final invoices = snapshot.data!.docs;
                if (invoices.isEmpty) {
                  return const Text("No purchase invoices.");
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: invoices.length,
                  itemBuilder: (_, i) {
                    final m = invoices[i].data() as Map<String, dynamic>;
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        leading: const Icon(Icons.receipt_long),
                        title: Text("Invoice #${m['invoiceNumber'] ?? ''}"),
                        subtitle: Text(m['date'] ?? ''),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ViewInvoiceScreen(
                                supplierId: supplierId,
                                invoiceId: invoices[i].id,
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

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),

            /// PAY SLIPS
            const Text(
              "Pay Slips",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),

            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection("suppliers")
                  .doc(supplierId)
                  .collection("paySlips")
                  .orderBy("createdAt", descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const LinearProgressIndicator();
                }

                final slips = snapshot.data!.docs;
                if (slips.isEmpty) {
                  return const Text("No pay slips yet.");
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: slips.length,
                  itemBuilder: (_, i) {
                    final m = slips[i].data();
                    final status = m['status'] ?? 'Unpaid';
                    final color =
                    status == 'Paid' ? Colors.green : Colors.red;

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        leading: const Icon(Icons.payments),
                        title: Text(m['serialNumber'] ?? ''),
                        subtitle: Text(
                          "Pay Date: ${m['payDate']} • PKR ${m['amount']}",
                        ),
                        trailing: Chip(
                          label: Text(status),
                          backgroundColor: color.withOpacity(0.1),
                          labelStyle: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PaySlipDetailScreen(
                                supplierId: supplierId,
                                slipId: slips[i].id,
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
