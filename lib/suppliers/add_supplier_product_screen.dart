import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../inventory/inventory_service.dart';


class AddSupplierProductScreen extends StatefulWidget {
  final String supplierId;
  final String? supplierName; // optional, for convenience
  final String? productId; // null = add, not null = edit
  final Map<String, dynamic>? productData;

  const AddSupplierProductScreen({
    super.key,
    required this.supplierId,
    this.supplierName,
    this.productId,
    this.productData,
  });

  bool get isEdit => productId != null;

  @override
  State<AddSupplierProductScreen> createState() =>
      _AddSupplierProductScreenState();
}

class _AddSupplierProductScreenState extends State<AddSupplierProductScreen> {
  final name = TextEditingController();
  final rate = TextEditingController();
  bool loading = false;
  bool initialLoading = false;
  String? _supplierName;

  @override
  void initState() {
    super.initState();
    _supplierName = widget.supplierName;

    // Prefill product if provided
    if (widget.productData != null) {
      name.text = widget.productData!['name']?.toString() ?? '';
      rate.text = (widget.productData!['rate'] ?? '').toString();
    } else if (widget.productId != null) {
      _loadProductFromFirestore();
    }

    // If supplierName not passed, try load it
    if (_supplierName == null) {
      _loadSupplierName();
    }
  }

  Future<void> _loadSupplierName() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection("suppliers")
          .doc(widget.supplierId)
          .get();
      final data = doc.data();
      if (mounted && data != null) {
        setState(() {
          _supplierName = (data['name'] ?? '').toString();
        });
      }
    } catch (_) {
      // ignore, not critical
    }
  }

  Future<void> _loadProductFromFirestore() async {
    setState(() => initialLoading = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection("suppliers")
          .doc(widget.supplierId)
          .collection("products")
          .doc(widget.productId)
          .get();

      final data = doc.data();
      if (data != null) {
        name.text = data['name']?.toString() ?? '';
        rate.text = (data['rate'] ?? '').toString();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error loading product: $e")),
      );
    } finally {
      if (mounted) setState(() => initialLoading = false);
    }
  }

  Future<void> saveProduct() async {
    if (name.text.trim().isEmpty || rate.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Product name and rate are required")),
      );
      return;
    }

    final parsedRate = double.tryParse(rate.text.trim()) ?? 0;
    if (parsedRate <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Rate must be greater than 0")),
      );
      return;
    }

    setState(() => loading = true);

    try {
      final productsRef = FirebaseFirestore.instance
          .collection("suppliers")
          .doc(widget.supplierId)
          .collection("products");

      // Ensure we have supplierName for global products collection
      final supplierName = _supplierName ?? '';

      final productData = {
        "name": name.text.trim(),
        "rate": parsedRate,
        "supplierId": widget.supplierId,
        "supplierName": supplierName,
      };

      String productId;

      if (widget.isEdit) {
        // UPDATE existing
        productId = widget.productId!;
        await productsRef.doc(productId).update(productData);

        // Update global products collection
        await FirebaseFirestore.instance
            .collection('products')
            .doc(productId)
            .set(productData, SetOptions(merge: true));

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Product updated")),
        );
      } else {
        // ADD new
        final newDoc = await productsRef.add(productData);
        productId = newDoc.id;

        // Add to global products with same ID
        await FirebaseFirestore.instance
            .collection('products')
            .doc(productId)
            .set({
          ...productData,
          "createdAt": DateTime.now(),
        });

        /// ✅ CREATE INVENTORY ENTRY (ONLY ONCE)
        await InventoryService.createInventoryIfNotExists(
          productId: productId,
          productName: productData['name'].toString(),
        );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Product saved")),
        );
      }


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
    final title = widget.isEdit ? "Edit Product" : "Add Product";
    final buttonText = widget.isEdit ? "Update Product" : "Save Product";

    return Scaffold(
      appBar: AppBar(title: Text(title)),
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
                child: initialLoading
                    ? const SizedBox(
                  height: 120,
                  child: Center(child: CircularProgressIndicator()),
                )
                    : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "Product Details",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
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
                      const TextInputType.numberWithOptions(
                          decimal: true),
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
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                            : const Icon(Icons.save),
                        label: Text(
                          loading ? "Saving..." : buttonText,
                        ),
                        style: ElevatedButton.styleFrom(
                          padding:
                          const EdgeInsets.symmetric(vertical: 14),
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
