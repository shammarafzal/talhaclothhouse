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
        const SnackBar(content: Text("Enter valid bill number & amount")),
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
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      setState(() => saving = false);
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
      appBar: AppBar(title: const Text("Add Old Bill")),
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
                    "Old Customer Bill",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: billNoController,
                    decoration: const InputDecoration(
                      labelText: "Old Bill Number",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountController,
                    keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: "Bill Amount",
                      prefixText: "Rs ",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: saving ? null : _saveOldBill,
                      icon: saving
                          ? const SizedBox(
                        width: 18,
                        height: 18,
                        child:
                        CircularProgressIndicator(strokeWidth: 2),
                      )
                          : const Icon(Icons.save),
                      label: const Text("Save Old Bill"),
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
