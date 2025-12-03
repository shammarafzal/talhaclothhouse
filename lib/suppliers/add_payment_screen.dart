import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AddPaymentScreen extends StatefulWidget {
  final String supplierId;
  final String invoiceId;

  const AddPaymentScreen({
    super.key,
    required this.supplierId,
    required this.invoiceId,
  });

  @override
  State<AddPaymentScreen> createState() => _AddPaymentScreenState();
}

class _AddPaymentScreenState extends State<AddPaymentScreen> {
  bool loading = true;
  bool saving = false;

  double totalAmount = 0;
  double alreadyPaid = 0;
  double amountDue = 0;

  final amountController = TextEditingController();
  final noteController = TextEditingController();
  String method = 'Cash';

  @override
  void initState() {
    super.initState();
    _loadInvoice();
  }

  Future<void> _loadInvoice() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('suppliers')
          .doc(widget.supplierId)
          .collection('purchases')
          .doc(widget.invoiceId)
          .get();

      final data = doc.data() as Map<String, dynamic>? ?? {};
      totalAmount = (data['totalAmount'] ?? 0).toDouble();
      alreadyPaid = (data['amountPaid'] ?? 0).toDouble();
      amountDue = totalAmount - alreadyPaid;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error loading invoice: $e")),
      );
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> _savePayment() async {
    if (saving || amountDue <= 0) return;

    double pay = double.tryParse(amountController.text.trim()) ?? 0;
    if (pay <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter a valid amount")),
      );
      return;
    }

    if (pay > amountDue) {
      pay = amountDue; // don't allow overpay
    }

    setState(() => saving = true);

    try {
      final invoiceRef = FirebaseFirestore.instance
          .collection('suppliers')
          .doc(widget.supplierId)
          .collection('purchases')
          .doc(widget.invoiceId);

      // Add payment record
      await invoiceRef.collection('payments').add({
        'amount': pay,
        'method': method,
        'note': noteController.text.trim(),
        'createdAt': DateTime.now(),
      });

      // Update summary on invoice document
      final newPaid = alreadyPaid + pay;
      final newDue = totalAmount - newPaid;
      String status;
      if (newPaid == 0) {
        status = 'Unpaid';
      } else if (newPaid < totalAmount) {
        status = 'Partial';
      } else {
        status = 'Paid';
      }

      await invoiceRef.update({
        'amountPaid': newPaid,
        'amountDue': newDue,
        'paymentStatus': status,
        'paymentMethod': method,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Payment saved")),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error saving payment: $e")),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  void dispose() {
    amountController.dispose();
    noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add Payment")),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 450),
            child: Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      "Invoice Summary",
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Text("Total: ${totalAmount.toStringAsFixed(2)}"),
                    Text("Already Paid: ${alreadyPaid.toStringAsFixed(2)}"),
                    Text("Due: ${amountDue.toStringAsFixed(2)}"),
                    const SizedBox(height: 16),
                    TextField(
                      controller: amountController,
                      keyboardType:
                      const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: const InputDecoration(
                        labelText: "Amount to pay now",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: method,
                      decoration: const InputDecoration(
                        labelText: "Payment Method",
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: 'Cash', child: Text('Cash')),
                        DropdownMenuItem(
                            value: 'JazzCash', child: Text('JazzCash')),
                        DropdownMenuItem(
                            value: 'Easypaisa',
                            child: Text('Easypaisa')),
                        DropdownMenuItem(
                            value: 'Bank Transfer',
                            child: Text('Bank Transfer')),
                        DropdownMenuItem(
                            value: 'Other', child: Text('Other')),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() => method = v);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: noteController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: "Payment Note (optional)",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed:
                        saving || amountDue <= 0 ? null : _savePayment,
                        icon: saving
                            ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                            : const Icon(Icons.save),
                        label: Text(
                            saving ? "Saving..." : "Save Payment"),
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
