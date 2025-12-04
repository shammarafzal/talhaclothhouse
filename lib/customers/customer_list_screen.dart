import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'add_customer_screen.dart';
import 'customer_detail_screen.dart';

class CustomerListScreen extends StatelessWidget {
  const CustomerListScreen({super.key});

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
      ),
      body: Container(
        color: Colors.grey.shade100,
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection("customers")
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
                child: Text("No customers yet. Add your first customer."),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: docs.length,
              itemBuilder: (contextList, index) {
                final doc = docs[index];
                final data = doc.data();
                final name = (data['name'] ?? '').toString();
                final phone = (data['phone'] ?? '').toString();
                final address = (data['address'] ?? '').toString();

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Text(
                        name.isEmpty
                            ? "C"
                            : name[0].toUpperCase(),
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
                        final color = rem > 0 ? Colors.red : Colors.green;
                        return Text(
                          rem.toStringAsFixed(0),
                          style: TextStyle(
                            fontSize: 13,
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
