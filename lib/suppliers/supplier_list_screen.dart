import 'package:cloud_firestore/cloud_firestore.dart';
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

  /// ✅ Keep Firebase image URLs mostly as-is
  /// We only touch very old appspot links; all new firebasestorage.app
  /// download URLs from getDownloadURL() are used directly.
  String fixFirebaseImageUrl(String url) {
    if (url.isEmpty) return url;

    // If it's a full URL already (starts with http), don't mess with it
    if (url.startsWith('http')) {
      // If you *do* have some old appspot URLs saved, you can normalize them here:
      if (url.contains('talhaclothhouse.appspot.com')) {
        url = url.replaceAll(
          'talhaclothhouse.appspot.com',
          'talhaclothhouse.firebasestorage.app',
        );
      }
      return url;
    }

    // If in some case you only stored the path (very unlikely in your case),
    // you could build a full URL here. But for now we just return it.
    return url;
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
                hintText: "Search by name, phone, or number (e.g., 1 or SUP-1)",
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
              final imageUrl = data["imageUrl"]?.toString() ?? "";

              final fixedUrl = fixFirebaseImageUrl(imageUrl);

              return Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.grey.shade200,
                    backgroundImage: fixedUrl.isNotEmpty
                        ? NetworkImage(fixedUrl)
                        : null,
                    onBackgroundImageError: (_, __) {
                      debugPrint("❌ Failed to load image: $fixedUrl");
                    },
                    child: fixedUrl.isEmpty
                        ? Text(
                      number.isNotEmpty
                          ? number
                          : (name.isNotEmpty
                          ? name[0].toUpperCase()
                          : "?"),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                        : null,
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
