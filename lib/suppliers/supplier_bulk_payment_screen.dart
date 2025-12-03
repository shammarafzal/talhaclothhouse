import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class SupplierBulkPaymentScreen extends StatefulWidget {
  final String supplierId;
  final String supplierName;

  const SupplierBulkPaymentScreen({
    super.key,
    required this.supplierId,
    required this.supplierName,
  });

  @override
  State<SupplierBulkPaymentScreen> createState() =>
      _SupplierBulkPaymentScreenState();
}

class _SupplierBulkPaymentScreenState extends State<SupplierBulkPaymentScreen> {
  bool loading = true;
  bool saving = false;

  double totalRemaining = 0;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> invoices = [];

  final amountController = TextEditingController();
  final noteController = TextEditingController();
  String method = 'Cash';

  @override
  void initState() {
    super.initState();
    _loadInvoices();
  }

  Future<void> _loadInvoices() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('suppliers')
          .doc(widget.supplierId)
          .collection('purchases')
          .orderBy('createdAt', descending: false) // oldest first
          .get();

      double totalRem = 0;
      final List<QueryDocumentSnapshot<Map<String, dynamic>>> dueInvoices = [];

      for (final d in snap.docs) {
        final data = d.data();
        final total = (data['totalAmount'] ?? 0).toDouble();
        final paid = (data['amountPaid'] ?? 0).toDouble();
        final remaining = total - paid;
        if (remaining > 0) {
          totalRem += remaining;
          dueInvoices.add(d);
        }
      }

      if (mounted) {
        setState(() {
          invoices = dueInvoices;
          totalRemaining = totalRem;
          loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error loading invoices: $e")),
      );
    }
  }

  Future<void> _applyBulkPayment() async {
    if (saving || totalRemaining <= 0) return;

    double pay = double.tryParse(amountController.text.trim()) ?? 0;
    if (pay <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter a valid amount")),
      );
      return;
    }

    if (pay > totalRemaining) {
      // Clamp to totalRemaining
      pay = totalRemaining;
    }

    setState(() => saving = true);

    try {
      final batch = FirebaseFirestore.instance.batch();
      double remainingPayment = pay;
      final List<Map<String, dynamic>> affectedInvoices = [];

      for (final doc in invoices) {
        if (remainingPayment <= 0) break;

        final data = doc.data();
        final total = (data['totalAmount'] ?? 0).toDouble();
        final alreadyPaid = (data['amountPaid'] ?? 0).toDouble();
        final currentDue = total - alreadyPaid;
        if (currentDue <= 0) continue;

        final payForThis =
        remainingPayment > currentDue ? currentDue : remainingPayment;
        remainingPayment -= payForThis;

        final newPaid = alreadyPaid + payForThis;
        final newDue = total - newPaid;

        String status;
        if (newPaid == 0) {
          status = 'Unpaid';
        } else if (newPaid < total) {
          status = 'Partial';
        } else {
          status = 'Paid';
        }

        final invRef = doc.reference;

        // Update invoice summary
        batch.update(invRef, {
          'amountPaid': newPaid,
          'amountDue': newDue,
          'paymentStatus': status,
          'paymentMethod': method,
        });

        // Add payment record under this invoice
        final payRef = invRef.collection('payments').doc();
        batch.set(payRef, {
          'amount': payForThis,
          'method': method,
          'note': noteController.text.trim(),
          'createdAt': DateTime.now(),
          'bulk': true, // mark as bulk payment
        });

        affectedInvoices.add({
          'invoiceId': doc.id,
          'invoiceNumber': data['invoiceNumber'] ?? '',
          'amount': payForThis,
        });
      }

      final actuallyUsed = pay - remainingPayment;

      // Save supplier-level bulk payment record
      final bulkRef = FirebaseFirestore.instance
          .collection('suppliers')
          .doc(widget.supplierId)
          .collection('bulkPayments')
          .doc();

      batch.set(bulkRef, {
        'requestedAmount': pay,
        'appliedAmount': actuallyUsed,
        'method': method,
        'note': noteController.text.trim(),
        'createdAt': DateTime.now(),
        'invoices': affectedInvoices,
      });

      await batch.commit();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              "Payment of ${actuallyUsed.toStringAsFixed(2)} applied on ${affectedInvoices.length} invoice(s)."),
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error applying payment: $e")),
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
      appBar: AppBar(
        title: Text("New Payment – ${widget.supplierName}"),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
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
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Supplier Payment",
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.blue.shade50,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Total remaining across invoices:",
                            style: TextStyle(
                              color: Colors.blue.shade900,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            totalRemaining.toStringAsFixed(2),
                            style: TextStyle(
                              color: Colors.blue.shade900,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Invoices with remaining: ${invoices.length}",
                            style: TextStyle(
                              color: Colors.blue.shade900,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
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
                    const Text(
                      "Note: Payment will be applied automatically from the oldest invoice to the newest until the amount is finished.",
                      style: TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: saving || totalRemaining <= 0
                            ? null
                            : _applyBulkPayment,
                        icon: saving
                            ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                            : const Icon(Icons.payments),
                        label: Text(
                          saving ? "Processing..." : "Apply Payment",
                        ),
                      ),
                    ),
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
