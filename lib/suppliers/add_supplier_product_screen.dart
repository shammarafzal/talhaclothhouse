import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AddSupplierProductScreen extends StatefulWidget {
  final String supplierId;

  const AddSupplierProductScreen({super.key, required this.supplierId});

  @override
  State<AddSupplierProductScreen> createState() =>
      _AddSupplierProductScreenState();
}

class _AddSupplierProductScreenState extends State<AddSupplierProductScreen> {
  final name = TextEditingController();
  final rate = TextEditingController();
  bool loading = false;

  Future<void> saveProduct() async {
    if (name.text.trim().isEmpty || rate.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Product name and rate are required")),
      );
      return;
    }

    setState(() => loading = true);

    try {
      await FirebaseFirestore.instance
          .collection("suppliers")
          .doc(widget.supplierId)
          .collection("products")
          .add({
        "name": name.text.trim(),
        "rate": double.tryParse(rate.text.trim()) ?? 0,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Product saved")),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error saving: $e")),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    name.dispose();
    rate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add Product")),
      body: Container(
        color: Colors.grey.shade100,
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "Product Details",
                      style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: name,
                      decoration: InputDecoration(
                        labelText: "Product Name",
                        prefixIcon: const Icon(Icons.inventory),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: rate,
                      keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: "Rate (per unit)",
                        prefixIcon: const Icon(Icons.price_change),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: loading ? null : saveProduct,
                        icon: loading
                            ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                            : const Icon(Icons.save),
                        label: Text(loading ? "Saving..." : "Save Product"),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    )
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
