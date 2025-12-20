import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

import 'add_supplier_screen.dart';
import 'supplier_detail_screen.dart';

class SupplierListScreen extends StatefulWidget {
  const SupplierListScreen({super.key});

  @override
  State<SupplierListScreen> createState() => _SupplierListScreenState();
}

class _SupplierListScreenState extends State<SupplierListScreen> {
  final TextEditingController searchCtrl = TextEditingController();

  @override
  void dispose() {
    searchCtrl.dispose();
    super.dispose();
  }

  /// 🔹 Get image download URL from Firebase Storage using supplierId
  Future<String?> _getSupplierImageUrl(String supplierId) async {
    try {
      final ref = FirebaseStorage.instance.ref('suppliers/$supplierId.jpg');
      final url = await ref.getDownloadURL();
      debugPrint('✅ Got image URL for $supplierId -> $url');
      return url;
    } catch (e) {
      debugPrint('❌ No image for $supplierId or error: $e');
      return null;
    }
  }

  /// 🔹 Build avatar with FutureBuilder so web uses Firebase JS SDK to fetch URL
  Widget _buildSupplierAvatar({
    required String supplierId,
    required String name,
    required String number,
  }) {
    return FutureBuilder<String?>(
      future: _getSupplierImageUrl(supplierId),
      builder: (context, snapshot) {
        // While loading or if error, show initials / number
        if (snapshot.connectionState == ConnectionState.waiting ||
            snapshot.hasError ||
            snapshot.data == null ||
            snapshot.data!.isEmpty) {
          final label = number.isNotEmpty
              ? number
              : (name.isNotEmpty ? name[0].toUpperCase() : "?");

          return CircleAvatar(
            radius: 24,
            backgroundColor: Colors.grey.shade200,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          );
        }

        final url = snapshot.data!;
        return CircleAvatar(
          radius: 24,
          backgroundColor: Colors.grey.shade200,
          backgroundImage: NetworkImage(url),
          onBackgroundImageError: (error, stackTrace) {
            debugPrint("❌ Failed to load image from NetworkImage: $url");
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Suppliers"),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: TextField(
              controller: searchCtrl,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText:
                "Search by name, phone, or number (e.g., 1 or SUP-1)",
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AddSupplierScreen(),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("suppliers")
            .orderBy("createdAt", descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];

          final query = searchCtrl.text.trim().toLowerCase();
          final filtered = docs.where((d) {
            final data = d.data() as Map<String, dynamic>;
            final name = (data["name"] ?? "").toString().toLowerCase();
            final phone = (data["phone"] ?? "").toString().toLowerCase();
            final supplierNumber = (data["supplierNumber"] ?? "").toString();
            final supplierCode =
            (data["supplierCode"] ?? "").toString().toLowerCase();

            if (query.isEmpty) return true;

            return name.contains(query) ||
                phone.contains(query) ||
                supplierNumber.contains(query) ||
                supplierCode.contains(query);
          }).toList();

          if (filtered.isEmpty) {
            return const Center(child: Text("No suppliers found"));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: filtered.length,
            itemBuilder: (_, index) {
              final doc = filtered[index];
              final data = doc.data() as Map<String, dynamic>;
              final id = doc.id;

              final code = data["supplierCode"]?.toString() ?? "";
              final number = data["supplierNumber"]?.toString() ?? "";
              final name = data["name"]?.toString() ?? "";
              final phone = data["phone"]?.toString() ?? "";
              final address = data["address"]?.toString() ?? "";

              return Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: _buildSupplierAvatar(
                    supplierId: id,
                    name: name,
                    number: number,
                  ),
                  title: Text(name),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (code.isNotEmpty) Text("Code: $code"),
                      if (phone.isNotEmpty) Text("Phone: $phone"),
                      if (address.isNotEmpty) Text("Address: $address"),
                    ],
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SupplierDetailScreen(
                          supplierId: id,
                          supplierData: data,
                        ),
                      ),
                    );
                  },
                  trailing: IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AddSupplierScreen(
                            supplierId: id,
                            supplierData: data,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
