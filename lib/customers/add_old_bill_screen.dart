import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AddOldBillScreen extends StatefulWidget {
  final String customerId;

  const AddOldBillScreen({super.key, required this.customerId});

  @override
  State<AddOldBillScreen> createState() => _AddOldBillScreenState();
}

class _AddOldBillScreenState extends State<AddOldBillScreen> {
  final billNoController = TextEditingController();
  final amountController = TextEditingController();
  bool saving = false;

  Future<void> _saveOldBill() async {
    final billNo = billNoController.text.trim();
    final amount = double.tryParse(amountController.text.trim()) ?? 0;

    if (billNo.isEmpty || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("درست بل نمبر اور رقم درج کریں"),
        ),
      );
      return;
    }

    setState(() => saving = true);

    try {
      await FirebaseFirestore.instance
          .collection('customers')
          .doc(widget.customerId)
          .collection('oldBills')
          .add({
        'billNumber': billNo,
        'amount': amount,
        'createdAt': DateTime.now(),
      });

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("خرابی: $e")),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  void dispose() {
    billNoController.dispose();
    amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("پرانا بل شامل کریں"),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 450),
          child: Card(
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "پرانے گاہک کا بل",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 🧾 Old Bill Number
                  TextField(
                    controller: billNoController,
                    decoration: const InputDecoration(
                      labelText: "پرانا بل نمبر",
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // 💰 Bill Amount
                  TextField(
                    controller: amountController,
                    keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: "بل کی رقم",
                      prefixText: "روپے ",
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 💾 Save Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: saving ? null : _saveOldBill,
                      icon: saving
                          ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                          : const Icon(Icons.save),
                      label: Text(
                        saving ? "محفوظ ہو رہا ہے..." : "پرانا بل محفوظ کریں",
                      ),
                    ),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
