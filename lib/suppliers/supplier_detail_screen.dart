import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:talhaclothhouse/suppliers/view_invoice_screen.dart';

import 'supplier_invoices_summary_screen.dart';

import 'add_supplier_product_screen.dart';
import 'create_invoice_screen.dart';

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
              _buildPurchasesAndStatsCard(),
            ],
          ),
        ),
      ),
    );
  }

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
                  const SizedBox(height: 4),
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
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
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
                )
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
                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text("Error: ${snapshot.error}"),
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: LinearProgressIndicator(),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text("No products added yet."),
                  );
                }

                final products = snapshot.data!.docs;

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: products.length,
                  itemBuilder: (_, index) {
                    final p =
                    products[index].data() as Map<String, dynamic>;
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

  Widget _buildPurchasesAndStatsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection("suppliers")
              .doc(supplierId)
              .collection("purchases")
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

            double total7 = 0, total10 = 0, total30 = 0;
            final Map<String, double> itemQty7 = {};
            final Map<String, double> itemQty10 = {};
            final Map<String, double> itemQty30 = {};

            for (final d in docs) {
              final m = d.data() as Map<String, dynamic>;
              final ts = (m['createdAt'] as Timestamp?)?.toDate() ??
                  DateTime.now();
              final diffDays = now.difference(ts).inDays;
              final total = (m['totalAmount'] ?? 0).toDouble();
              final items = (m['items'] as List<dynamic>? ?? [])
                  .cast<Map<String, dynamic>>();

              void addTo(Map<String, double> map) {
                for (final it in items) {
                  final name = (it['name'] ?? '').toString();
                  final qty = (it['qty'] ?? 0).toDouble();
                  if (name.isEmpty) continue;
                  map[name] = (map[name] ?? 0) + qty;
                }
              }

              if (diffDays <= 7) {
                total7 += total;
                addTo(itemQty7);
              }
              if (diffDays <= 10) {
                total10 += total;
                addTo(itemQty10);
              }
              if (diffDays <= 30) {
                total30 += total;
                addTo(itemQty30);
              }
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Purchase Summary",
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
                    _chip("Last 10 days: PKR ${total10.toStringAsFixed(0)}"),
                    _chip("Last 30 days: PKR ${total30.toStringAsFixed(0)}"),
                  ],
                ),
                const SizedBox(height: 12),

                if (itemQty7.isNotEmpty) ...[
                  const Text("Items in last 7 days:"),
                  const SizedBox(height: 4),
                  _buildItemQtyList(itemQty7),
                  const SizedBox(height: 8),
                ],
                if (itemQty30.isNotEmpty) ...[
                  const Text("Items in last 30 days:"),
                  const SizedBox(height: 4),
                  _buildItemQtyList(itemQty30),
                  const SizedBox(height: 8),
                ],

                const Divider(),
                const SizedBox(height: 8),
                const Text(
                  "All Purchase Invoices",
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SupplierInvoicesSummaryScreen(
                            supplierId: supplierId,
                            supplierName: supplierData["name"] ?? "Supplier",
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.list_alt),
                    label: const Text("View invoices summary"),
                  ),
                ),
                const SizedBox(height: 4),

                if (docs.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text("No invoices yet."),
                  )
                // inside _buildPurchasesAndStatsCard(), where you currently have ListView.builder for invoices:
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: docs.length,
                    itemBuilder: (contextList, index) {
                      final doc = docs[index];
                      final m = doc.data() as Map<String, dynamic>;
                      final invNo = m['invoiceNumber'] ?? '';
                      final date = m['date'] ?? '';
                      final total = (m['totalAmount'] ?? 0).toDouble();

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          leading: const Icon(Icons.receipt_long),
                          title: Text("Invoice #$invNo"),
                          subtitle: Text(date.toString()),
                          trailing: IconButton(
                            icon: const Icon(Icons.open_in_new),
                            tooltip: "Open Invoice",
                            onPressed: () {
                              Navigator.push(
                                contextList,
                                MaterialPageRoute(
                                  builder: (_) => ViewInvoiceScreen(
                                    invoiceId: doc.id,
                                    supplierId: supplierId,
                                  ),

                                ),
                              );
                            },
                          ),
                          onTap: () {
                            Navigator.push(
                                contextList,
                                MaterialPageRoute(
                                  builder: (_) => ViewInvoiceScreen(
                                    supplierId: supplierId,
                                    invoiceId: doc.id,
                                  ),
                                )
                            );
                          },
                        ),
                      );
                    },
                  )

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

  Widget _buildItemQtyList(Map<String, double> map) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: map.entries
          .map(
            (e) => Text("• ${e.key}: ${e.value.toStringAsFixed(2)}"),
      )
          .toList(),
    );
  }
}
