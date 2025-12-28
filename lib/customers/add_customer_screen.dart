import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AddCustomerScreen extends StatefulWidget {
  final String? customerId;
  final Map<String, dynamic>? customerData;

  const AddCustomerScreen({
    super.key,
    this.customerId,
    this.customerData,
  });

  bool get isEdit => customerId != null;

  @override
  State<AddCustomerScreen> createState() => _AddCustomerScreenState();
}

class _AddCustomerScreenState extends State<AddCustomerScreen> {
  final name = TextEditingController();
  final phone = TextEditingController();
  final address = TextEditingController();
  bool loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.customerData != null) {
      name.text = widget.customerData!['name']?.toString() ?? '';
      phone.text = widget.customerData!['phone']?.toString() ?? '';
      address.text = widget.customerData!['address']?.toString() ?? '';
    }
  }

  Future<void> saveCustomer() async {
    if (name.text.trim().isEmpty || phone.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("نام اور فون نمبر ضروری ہیں")),
      );
      return;
    }

    setState(() => loading = true);

    try {
      final data = {
        "name": name.text.trim(),
        "phone": phone.text.trim(),
        "address": address.text.trim(),
      };

      if (widget.isEdit) {
        await FirebaseFirestore.instance
            .collection("customers")
            .doc(widget.customerId)
            .update(data);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("گاہک کی معلومات اپڈیٹ ہو گئیں")),
        );
      } else {
        await FirebaseFirestore.instance.collection("customers").add({
          ...data,
          "createdAt": DateTime.now(),
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("گاہک محفوظ ہو گیا")),
        );
      }

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("محفوظ کرنے میں خرابی: $e")),
      );
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
    final title = widget.isEdit ? "گاہک میں ترمیم کریں" : "نیا گاہک شامل کریں";
    final btnText = widget.isEdit ? "گاہک اپڈیٹ کریں" : "گاہک محفوظ کریں";

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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "گاہک کی تفصیل",
                      style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 16),

                    TextField(
                      controller: name,
                      decoration: InputDecoration(
                        labelText: "گاہک کا نام",
                        prefixIcon: const Icon(Icons.person),
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
                        labelText: "فون نمبر",
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
                        labelText: "پتہ",
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
                        onPressed: loading ? null : saveCustomer,
                        icon: loading
                            ? const SizedBox(
                          width: 18,
                          height: 18,
                          child:
                          CircularProgressIndicator(strokeWidth: 2),
                        )
                            : const Icon(Icons.save),
                        label: Text(
                          loading ? "محفوظ ہو رہا ہے..." : btnText,
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
