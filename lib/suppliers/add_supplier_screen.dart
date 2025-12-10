import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

class AddSupplierScreen extends StatefulWidget {
  final String? supplierId; // null = add new, not null = edit
  final Map<String, dynamic>? supplierData;

  const AddSupplierScreen({
    super.key,
    this.supplierId,
    this.supplierData,
  });

  bool get isEdit => supplierId != null;

  @override
  State<AddSupplierScreen> createState() => _AddSupplierScreenState();
}

class _AddSupplierScreenState extends State<AddSupplierScreen> {
  final name = TextEditingController();
  final phone = TextEditingController();
  final address = TextEditingController();

  bool loading = false;
  bool initialLoading = false;

  int? supplierNumber;
  String? supplierCode;

  Uint8List? _pickedImageBytes;
  String? _imageUrl;
  bool _imageUploading = false;

  @override
  void initState() {
    super.initState();

    if (widget.supplierData != null) {
      name.text = widget.supplierData!["name"]?.toString() ?? "";
      phone.text = widget.supplierData!["phone"]?.toString() ?? "";
      address.text = widget.supplierData!["address"]?.toString() ?? "";
      supplierNumber = widget.supplierData!["supplierNumber"] as int?;
      supplierCode = widget.supplierData!["supplierCode"]?.toString();
      _imageUrl = widget.supplierData!["imageUrl"]?.toString();
    } else if (widget.supplierId != null) {
      _loadSupplierFromFirestore();
    }
  }

  /// ✅ Sanitize incorrect Firebase URLs
  String fixFirebaseImageUrl(String url) {
    if (url.contains('talhaclothhouse.firebasestorage.app')) {
      return url.replaceAll(
        'talhaclothhouse.firebasestorage.app',
        'talhaclothhouse.appspot.com',
      );
    }
    return url;
  }

  Future<void> _loadSupplierFromFirestore() async {
    setState(() => initialLoading = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection("suppliers")
          .doc(widget.supplierId)
          .get();

      final data = doc.data();
      if (data != null) {
        name.text = data["name"]?.toString() ?? "";
        phone.text = data["phone"]?.toString() ?? "";
        address.text = data["address"]?.toString() ?? "";
        supplierNumber = data["supplierNumber"] as int?;
        supplierCode = data["supplierCode"]?.toString();
        _imageUrl = data["imageUrl"]?.toString();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error loading supplier: $e")));
    } finally {
      if (mounted) setState(() => initialLoading = false);
    }
  }

  Future<Map<String, dynamic>> _generateSupplierNumber() async {
    final counterRef =
    FirebaseFirestore.instance.collection('counters').doc('suppliers');

    return FirebaseFirestore.instance.runTransaction((transaction) async {
      final snap = await transaction.get(counterRef);
      int lastNumber = 0;
      if (snap.exists) {
        final data = snap.data() as Map<String, dynamic>;
        lastNumber = (data['lastNumber'] ?? 0) as int;
      }

      final nextNumber = lastNumber + 1;
      transaction.set(counterRef, {'lastNumber': nextNumber});

      final code = 'SUP-$nextNumber';
      return {'supplierNumber': nextNumber, 'supplierCode': code};
    });
  }

  Future<void> _pickImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (file.bytes == null) return;

      setState(() => _pickedImageBytes = file.bytes);
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error picking image: $e")));
    }
  }

  /// Upload picked image to Firebase Storage under suppliers/{supplierId}.jpg
  ///
  Future<String?> _uploadImage(String docId) async {
    if (_pickedImageBytes == null) return _imageUrl;

    setState(() => _imageUploading = true);
    try {
      final ref = FirebaseStorage.instance.ref().child('suppliers/$docId.jpg');
      final uploadTask = await ref.putData(
        _pickedImageBytes!,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      // ✅ keep the real download URL
      final url = await uploadTask.ref.getDownloadURL();
      _imageUrl = url;
      return url;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error uploading image: $e")),
      );
      return _imageUrl;
    } finally {
      if (mounted) setState(() => _imageUploading = false);
    }
  }


  Future<void> saveSupplier() async {
    if (name.text.trim().isEmpty || phone.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Name and phone are required")),
      );
      return;
    }

    setState(() => loading = true);

    try {
      final suppliers = FirebaseFirestore.instance.collection("suppliers");

      if (widget.isEdit) {
        // UPDATE existing supplier
        final docId = widget.supplierId!;
        final imageUrl = await _uploadImage(docId);

        await suppliers.doc(docId).update({
          "name": name.text.trim(),
          "phone": phone.text.trim(),
          "address": address.text.trim(),
          if (imageUrl != null) "imageUrl": imageUrl,
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("Supplier updated")));
      } else {
        // ADD new supplier with generated ID FIRST
        final numberInfo = await _generateSupplierNumber();
        supplierNumber = numberInfo['supplierNumber'] as int;
        supplierCode = numberInfo['supplierCode'] as String;

        final newDoc = suppliers.doc(); // 🔹 Create doc first
        final imageUrl = await _uploadImage(newDoc.id); // 🔹 Use same ID

        await newDoc.set({
          "name": name.text.trim(),
          "phone": phone.text.trim(),
          "address": address.text.trim(),
          "supplierNumber": supplierNumber,
          "supplierCode": supplierCode,
          "imageUrl": imageUrl,
          "createdAt": DateTime.now(),
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("Supplier saved")));
      }

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error saving: $e")));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }


  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    address.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isEdit ? "Edit Supplier" : "Add Supplier";
    final buttonText = widget.isEdit ? "Update Supplier" : "Save Supplier";

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
                      "Supplier Details",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 🔹 Supplier Avatar
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: Colors.grey.shade200,
                          backgroundImage: _pickedImageBytes != null
                              ? MemoryImage(_pickedImageBytes!)
                          as ImageProvider
                              : (_imageUrl != null &&
                              _imageUrl!.isNotEmpty)
                              ? NetworkImage(fixFirebaseImageUrl(
                              _imageUrl!))
                              : null,
                          child: (_pickedImageBytes == null &&
                              (_imageUrl == null ||
                                  _imageUrl!.isEmpty))
                              ? const Icon(
                            Icons.person,
                            size: 40,
                            color: Colors.grey,
                          )
                              : null,
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: InkWell(
                            onTap: _imageUploading ? null : _pickImage,
                            child: CircleAvatar(
                              radius: 16,
                              backgroundColor: Colors.blue,
                              child: _imageUploading
                                  ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                                  : const Icon(
                                Icons.camera_alt,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    if (supplierCode != null) ...[
                      Chip(
                        label: Text(
                          supplierCode!,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold),
                        ),
                        avatar: const Icon(Icons.tag, size: 18),
                        backgroundColor: Colors.blue.shade50,
                      ),
                      const SizedBox(height: 8),
                    ],

                    TextField(
                      controller: name,
                      decoration: InputDecoration(
                        labelText: "Supplier Name",
                        prefixIcon: const Icon(Icons.store),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: phone,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: "Phone",
                        prefixIcon: const Icon(Icons.phone),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: address,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: "Address",
                        prefixIcon: const Icon(Icons.location_on),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: loading ? null : saveSupplier,
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
                            loading ? "Saving..." : buttonText),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              vertical: 14),
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
