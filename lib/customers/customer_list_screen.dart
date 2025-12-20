import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'add_customer_screen.dart';
import 'customer_detail_screen.dart';

class CustomerListScreen extends StatefulWidget {
  const CustomerListScreen({super.key});

  @override
  State<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends State<CustomerListScreen> {
  final TextEditingController searchCtrl = TextEditingController();

  String selectedCity = 'All';

  /// 🔹 Load remaining amount (unchanged logic)
  Future<double> _loadCustomerRemaining(String customerId) async {
    final snap = await FirebaseFirestore.instance
        .collection('customers')
        .doc(customerId)
        .collection('sales')
        .get();

    double remaining = 0;
    for (final d in snap.docs) {
      final data = d.data();
      final total = (data['totalAmount'] ?? 0).toDouble();
      final paid = (data['amountPaid'] ?? 0).toDouble();
      remaining += (total - paid);
    }
    if (remaining < 0) remaining = 0;
    return remaining;
  }

  /// 🔹 Print filtered customers
  Future<void> _printCustomers(List<QueryDocumentSnapshot> customers) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Customer List',
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                'City: $selectedCity',
                style: const pw.TextStyle(fontSize: 12),
              ),
              pw.SizedBox(height: 12),
              pw.Table.fromTextArray(
                headers: ['Name', 'Phone', 'Address'],
                data: customers.map((doc) {
                  final d = doc.data() as Map<String, dynamic>;
                  return [
                    d['name'] ?? '',
                    d['phone'] ?? '',
                    d['address'] ?? '',
                  ];
                }).toList(),
              ),
              pw.SizedBox(height: 12),
              pw.Text(
                'Generated on ${DateFormat('dd/MM/yyyy hh:mm a').format(DateTime.now())}',
                style: const pw.TextStyle(fontSize: 9),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
    );
  }

  @override
  void dispose() {
    searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Customers"),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            tooltip: "Add Customer",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AddCustomerScreen(),
                ),
              );
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(110),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Column(
              children: [
                // 🔍 SEARCH
                TextField(
                  controller: searchCtrl,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: "Search customer by name",
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // 🏙️ CITY FILTER + PRINT
                Row(
                  children: [
                    Expanded(
                      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: FirebaseFirestore.instance
                            .collection("customers")
                            .snapshots(),
                        builder: (context, snap) {
                          if (!snap.hasData) {
                            return const SizedBox();
                          }

                          // collect unique cities
                          final cities = <String>{};
                          for (final d in snap.data!.docs) {
                            final data = d.data();
                            final city = (data['city'] ??
                                data['address'] ??
                                '')
                                .toString()
                                .trim();
                            if (city.isNotEmpty) cities.add(city);
                          }

                          final cityList = ['All', ...cities.toList()];

                          return DropdownButtonFormField<String>(
                            value: selectedCity,
                            items: cityList
                                .map(
                                  (c) => DropdownMenuItem(
                                value: c,
                                child: Text(c),
                              ),
                            )
                                .toList(),
                            onChanged: (v) {
                              if (v == null) return;
                              setState(() => selectedCity = v);
                            },
                            decoration: const InputDecoration(
                              labelText: 'Filter by City',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: "Print Filtered Customers",
                      icon: const Icon(Icons.print),
                      onPressed: () async {
                        final snap = await FirebaseFirestore.instance
                            .collection("customers")
                            .get();

                        final filtered = snap.docs.where((d) {
                          final data = d.data();
                          final name =
                          (data['name'] ?? '').toString().toLowerCase();
                          final city =
                          (data['city'] ?? data['address'] ?? '')
                              .toString();

                          if (searchCtrl.text.isNotEmpty &&
                              !name.contains(
                                  searchCtrl.text.toLowerCase())) {
                            return false;
                          }

                          if (selectedCity != 'All' &&
                              city != selectedCity) {
                            return false;
                          }

                          return true;
                        }).toList();

                        if (filtered.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("No customers to print"),
                            ),
                          );
                          return;
                        }

                        await _printCustomers(filtered);
                      },
                    )
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      body: Container(
        color: Colors.grey.shade100,
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection("customers")
              .orderBy("name")
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = snapshot.data!.docs;

            final query = searchCtrl.text.toLowerCase();

            final filtered = docs.where((d) {
              final data = d.data();
              final name =
              (data['name'] ?? '').toString().toLowerCase();
              final city =
              (data['city'] ?? data['address'] ?? '').toString();

              if (query.isNotEmpty && !name.contains(query)) {
                return false;
              }
              if (selectedCity != 'All' && city != selectedCity) {
                return false;
              }
              return true;
            }).toList();

            if (filtered.isEmpty) {
              return const Center(child: Text("No customers found"));
            }

            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: filtered.length,
              itemBuilder: (contextList, index) {
                final doc = filtered[index];
                final data = doc.data();
                final name = (data['name'] ?? '').toString();
                final phone = (data['phone'] ?? '').toString();
                final address = (data['address'] ?? '').toString();

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Text(
                        name.isEmpty ? "C" : name[0].toUpperCase(),
                      ),
                    ),
                    title: Text(name.isEmpty ? "Unnamed Customer" : name),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (phone.isNotEmpty) Text(phone),
                        if (address.isNotEmpty)
                          Text(
                            address,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                    trailing: FutureBuilder<double>(
                      future: _loadCustomerRemaining(doc.id),
                      builder: (ctx, snapRem) {
                        if (!snapRem.hasData) {
                          return const SizedBox(
                            width: 60,
                            height: 12,
                            child: LinearProgressIndicator(),
                          );
                        }
                        final rem = snapRem.data!;
                        final color =
                        rem > 0 ? Colors.red : Colors.green;
                        return Text(
                          rem.toStringAsFixed(0),
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: color,
                          ),
                        );
                      },
                    ),
                    onTap: () {
                      Navigator.push(
                        contextList,
                        MaterialPageRoute(
                          builder: (_) => CustomerDetailScreen(
                            customerId: doc.id,
                            customerData: data,
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
