import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AllProductsScreen extends StatelessWidget {
  const AllProductsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("All Products"),
      ),
      body: Container(
        color: Colors.grey.shade100,
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('products')
              .orderBy('name')
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
                child: Text("No products found."),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: docs.length,
              itemBuilder: (contextList, index) {
                final doc = docs[index];
                final data = doc.data();
                final name = (data['name'] ?? '').toString();
                final rate = (data['rate'] ?? 0).toDouble();
                final supplierName =
                (data['supplierName'] ?? '').toString();

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Text(
                        name.isEmpty ? "P" : name[0].toUpperCase(),
                      ),
                    ),
                    title: Text(name.isEmpty ? "Product" : name),
                    subtitle: Text(
                      supplierName.isEmpty
                          ? "Unknown Supplier"
                          : "Supplier: $supplierName",
                    ),
                    trailing: Text(
                      rate.toStringAsFixed(2),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
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
