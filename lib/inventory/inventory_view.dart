import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class InventoryScreen extends StatelessWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Inventory"),
      ),
      body: Container(
        color: Colors.grey.shade100,
        padding: const EdgeInsets.all(16),
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('inventory')
              .orderBy('productName')
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
                child: Text("No inventory items found"),
              );
            }

            return ListView.builder(
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final data = docs[index].data();

                final name = data['productName'] ?? '';
                final stock = data['currentStock'] ?? 0;
                final unit = data['unit'] ?? 'pcs';

                final lowStock = stock <= 10;

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                      lowStock ? Colors.red.shade100 : Colors.blue.shade100,
                      child: Icon(
                        Icons.inventory_2,
                        color: lowStock ? Colors.red : Colors.blue,
                      ),
                    ),
                    title: Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      "Stock: $stock $unit",
                      style: TextStyle(
                        color: lowStock ? Colors.red : Colors.black87,
                        fontWeight:
                        lowStock ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                    trailing: lowStock
                        ? const Chip(
                      label: Text(
                        "LOW",
                        style: TextStyle(color: Colors.red),
                      ),
                      backgroundColor: Color(0xFFFFEBEE),
                    )
                        : null,
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
