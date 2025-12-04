import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

class _InvoiceItem {
  final TextEditingController qtyController = TextEditingController();
  final TextEditingController rateController = TextEditingController();
  String? productId;
  String? productName;

  double get qty => double.tryParse(qtyController.text) ?? 0;
  double get rate => double.tryParse(rateController.text) ?? 0;
  double get amount => qty * rate;

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'name': productName ?? '',
      'qty': qty,
      'rate': rate,
      'amount': amount,
    };
  }

  bool get isEmpty => (productName == null || productName!.isEmpty) && qty == 0;

  void dispose() {
    qtyController.dispose();
    rateController.dispose();
  }
}

class CreateCustomerReceiptScreen extends StatefulWidget {
  final String customerId;
  final Map<String, dynamic> customerData;

  const CreateCustomerReceiptScreen({
    super.key,
    required this.customerId,
    required this.customerData,
  });

  @override
  State<CreateCustomerReceiptScreen> createState() =>
      _CreateInvoiceScreenState();
}

class _CreateInvoiceScreenState extends State<CreateCustomerReceiptScreen> {
  // Shop (buyer) info
  final TextEditingController buyerNameController = TextEditingController();
  final TextEditingController buyerPhoneController = TextEditingController();
  final TextEditingController buyerAddressController = TextEditingController();

  // Payment info
  final TextEditingController paymentAmountController =
  TextEditingController();
  final TextEditingController paymentNoteController = TextEditingController();
  String _paymentStatus = 'Unpaid'; // Unpaid, Partial, Paid
  String _paymentMethod =
      'Cash'; // Cash, JazzCash, Easypaisa, Bank Transfer, Other

  String? invoiceNumber;
  bool invoiceNoLoading = true;
  late String invoiceDate;
  late String invoiceTime;
  late String dayName;

  bool saving = false;
  bool productsLoading = true;
  String? productsError;

  final List<_InvoiceItem> items = [];

  // All products from all suppliers
  List<QueryDocumentSnapshot<Map<String, dynamic>>> products = [];

  Future<void> _loadInvoiceNumber() async {
    try {
      final invNo = await _generateInvoiceNumber();
      if (!mounted) return;
      setState(() {
        invoiceNumber = invNo;
        invoiceNoLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      invoiceNoLoading = false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error generating invoice no: $e")),
      );
    }
  }

  /// Generate invoice number like TCH-01, TCH-02 using Firestore counter
  /// Generate customer invoice number like TCH-CUS-01, TCH-CUS-02...
  Future<String> _generateInvoiceNumber() async {
    // separate counter document for customer invoices
    final counterRef = FirebaseFirestore.instance
        .collection('counters')
        .doc('customerInvoice');

    return FirebaseFirestore.instance.runTransaction((transaction) async {
      final snap = await transaction.get(counterRef);

      int lastNumber = 0;
      if (snap.exists) {
        final data = snap.data() as Map<String, dynamic>;
        lastNumber = (data['lastNumber'] ?? 0) as int;
      }

      final nextNumber = lastNumber + 1;
      transaction.set(counterRef, {'lastNumber': nextNumber});

      final padded = nextNumber.toString().padLeft(2, '0');
      return 'TCH-CUS-$padded';
    });
  }


  @override
  void initState() {
    super.initState();

    // Default shop details (your shop)
    buyerNameController.text = 'Talha Afzal Cloth House';
    buyerPhoneController.text =
    'Talha Afzal: 0303-6339313, Waqas Afzal: 0300-6766691, Abbas Afzal: 0303-2312531';
    buyerAddressController.text =
    'Shop No 21, Nasir Cloth Market, Chungi No 11, Multan';

    _initInvoiceMeta();
    _addItemRow();
    _loadProducts();
    _loadInvoiceNumber();
  }

  void _initInvoiceMeta() {
    final now = DateTime.now();
    invoiceDate = DateFormat('dd/MM/yyyy').format(now);
    invoiceTime = DateFormat('hh:mm a').format(now);
    dayName = DateFormat('EEEE').format(now);
  }

  /// 🔧 Load all products from all suppliers: suppliers/*/products
  Future<void> _loadProducts() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection("products")          // 🔹 global products table
          .orderBy('name')
          .get();

      setState(() {
        products = snap.docs;
        productsLoading = false;
      });
    } catch (e) {
      setState(() {
        productsError = e.toString();
        productsLoading = false;
      });
    }
  }


  void _addItemRow() {
    setState(() {
      items.add(_InvoiceItem());
    });
  }

  void _removeItemRow(int index) {
    if (items.length == 1) return;
    setState(() {
      items.removeAt(index);
    });
  }

  double get totalAmount {
    double total = 0;
    for (final item in items) {
      total += item.amount;
    }
    return total;
  }

  Future<void> _saveInvoice() async {
    if (saving) return;

    final validItems = items
        .where((item) => !item.isEmpty && item.amount > 0)
        .map((e) => e.toMap())
        .toList();

    if (validItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Add at least one valid item")),
      );
      return;
    }
    if (invoiceNumber == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Invoice number not ready yet")),
      );
      return;
    }

    final total = totalAmount;
    if (total <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Total amount must be greater than 0")),
      );
      return;
    }

    // Payment logic
    double paidNow =
        double.tryParse(paymentAmountController.text.trim()) ?? 0;
    if (_paymentStatus == 'Unpaid') {
      paidNow = 0;
    }
    if (paidNow < 0) paidNow = 0;
    if (paidNow > total) paidNow = total;

    double amountDue = total - paidNow;

    String paymentStatus;
    if (paidNow == 0) {
      paymentStatus = 'Unpaid';
    } else if (paidNow < total) {
      paymentStatus = 'Partial';
    } else {
      paymentStatus = 'Paid';
    }

    if (_paymentStatus == 'Paid' && paidNow == 0) {
      paidNow = total;
      amountDue = 0;
      paymentStatus = 'Paid';
    }

    setState(() => saving = true);

    try {
      final data = {
        'invoiceNumber': invoiceNumber,
        // these keys are from old supplier structure, but this is actually CUSTOMER
        'supplierId': widget.customerId,
        'supplierName': widget.customerData['name'] ?? '',
        'supplierPhone': widget.customerData['phone'] ?? '',
        'supplierAddress': widget.customerData['address'] ?? '',
        // shop details here
        'date': invoiceDate,
        'time': invoiceTime,
        'dayName': dayName,
        'buyerName': buyerNameController.text.trim(),
        'buyerPhone': buyerPhoneController.text.trim(),
        'buyerAddress': buyerAddressController.text.trim(),
        'items': validItems,
        'totalAmount': total,
        'amountPaid': paidNow,
        'amountDue': amountDue,
        'paymentStatus': paymentStatus,
        'paymentMethod': paidNow > 0 ? _paymentMethod : null,
        'paymentNote': paymentNoteController.text.trim().isEmpty
            ? null
            : paymentNoteController.text.trim(),
        'createdAt': DateTime.now(),
      };

      final docRef = await FirebaseFirestore.instance
          .collection('customers')
          .doc(widget.customerId)
          .collection('sales')
          .add(data);

      if (paidNow > 0) {
        await docRef.collection('payments').add({
          'amount': paidNow,
          'method': _paymentMethod,
          'note': paymentNoteController.text.trim(),
          'createdAt': DateTime.now(),
        });
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Invoice saved")),
      );

      await _printInvoice(data);

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error saving invoice: $e")),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _printInvoice(Map<String, dynamic> data) async {
    final pdf = pw.Document();
    final itemsList =
    (data['items'] as List).cast<Map<String, dynamic>>();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(24),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  "Sales Invoice",
                  style: pw.TextStyle(
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 12),
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Shop (your shop)
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment:
                        pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text("Shop: ${data['buyerName']}"),
                          pw.Text("Phone: ${data['buyerPhone']}"),
                          pw.Text("Address: ${data['buyerAddress']}"),
                        ],
                      ),
                    ),
                    pw.SizedBox(width: 16),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment:
                        pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text("Invoice #: ${data['invoiceNumber']}"),
                          pw.Text("Date: ${data['date']}"),
                          pw.Text("Time: ${data['time']}"),
                          pw.Text("Day: ${data['dayName']}"),
                        ],
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 12),
                // Customer details under header
                pw.Text("Customer: ${data['supplierName'] ?? ''}"),
                pw.Text("Customer Phone: ${data['supplierPhone'] ?? ''}"),
                pw.Text("Customer Address: ${data['supplierAddress'] ?? ''}"),
                pw.SizedBox(height: 16),
                pw.Table.fromTextArray(
                  headers: ["Item", "Qty", "Rate", "Amount"],
                  data: itemsList
                      .map(
                        (it) => [
                      it['name'] ?? '',
                      it['qty'].toString(),
                      it['rate'].toString(),
                      it['amount'].toString(),
                    ],
                  )
                      .toList(),
                ),
                pw.SizedBox(height: 12),
                pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        "Total: ${data['totalAmount']}",
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        "Paid: ${data['amountPaid']}",
                        style: const pw.TextStyle(fontSize: 12),
                      ),
                      pw.Text(
                        "Due: ${data['amountDue']}",
                        style: const pw.TextStyle(fontSize: 12),
                      ),
                      if (data['paymentStatus'] != null)
                        pw.Text(
                          "Status: ${data['paymentStatus']}",
                          style: const pw.TextStyle(fontSize: 12),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  @override
  void dispose() {
    buyerNameController.dispose();
    buyerPhoneController.dispose();
    buyerAddressController.dispose();
    paymentAmountController.dispose();
    paymentNoteController.dispose();
    for (final item in items) {
      item.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const maxWidth = 900.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales Invoice'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: maxWidth),
            child: Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Sales Invoice',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    _buildTopInfo(),
                    const SizedBox(height: 16),
                    _buildCustomerInfoCard(),
                    const SizedBox(height: 16),
                    if (productsLoading)
                      const Center(child: CircularProgressIndicator())
                    else if (productsError != null)
                      Text("Error loading products: $productsError")
                    else
                      _buildItemsSection(),
                    const SizedBox(height: 16),
                    _buildPaymentSection(),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'Total: ${totalAmount.toStringAsFixed(2)}',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed:
                      saving || productsLoading ? null : _saveInvoice,
                      icon: saving
                          ? const SizedBox(
                        width: 18,
                        height: 18,
                        child:
                        CircularProgressIndicator(strokeWidth: 2),
                      )
                          : const Icon(Icons.save),
                      label: Text(
                          saving ? 'Saving...' : 'Save & Print'),
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

  Widget _buildTopInfo() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        if (isMobile) {
          return Column(
            children: [
              _buildShopInfoCard(),
              const SizedBox(height: 12),
              _buildInvoiceInfoCard(),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildShopInfoCard()),
            const SizedBox(width: 12),
            Expanded(child: _buildInvoiceInfoCard()),
          ],
        );
      },
    );
  }

  // 🔁 This card now shows YOUR SHOP
  Widget _buildShopInfoCard() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Shop'),
          const SizedBox(height: 4),
          Text(
            buyerNameController.text,
            style:
            const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(buyerPhoneController.text),
          Text(buyerAddressController.text),
        ],
      ),
    );
  }

  Widget _buildInvoiceInfoCard() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Invoice Info'),
          const SizedBox(height: 4),
          _infoRow(
            'Invoice #',
            invoiceNumber ?? (invoiceNoLoading ? 'Generating...' : 'N/A'),
          ),
          _infoRow('Date', invoiceDate),
          _infoRow('Time', invoiceTime),
          _infoRow('Day', dayName),
        ],
      ),
    );
  }

  // 🔁 This card now shows CUSTOMER details (read-only)
  Widget _buildCustomerInfoCard() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Customer'),
          const SizedBox(height: 8),
          Text(
            widget.customerData['name'] ?? '',
            style:
            const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(widget.customerData['phone'] ?? ''),
          Text(widget.customerData['address'] ?? ''),
        ],
      ),
    );
  }

  Widget _buildItemsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Items',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        ...List.generate(items.length, (index) => _buildItemRow(index)),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _addItemRow,
            icon: const Icon(Icons.add),
            label: const Text('Add Item'),
          ),
        ),
      ],
    );
  }

  Widget _buildItemRow(int index) {
    final item = items[index];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          // Product dropdown from all suppliers
          Expanded(
            flex: 4,
            child: DropdownButtonFormField<String>(
              value: item.productId,
              isExpanded: true,
              decoration: const InputDecoration(
                isDense: true,
                border: OutlineInputBorder(),
                labelText: "Product",
              ),
              items: products.map((doc) {
                final data = doc.data();
                final name = (data['name'] ?? '').toString();
                final rate = (data['rate'] ?? 0).toDouble();
                final supplierName = (data['supplierName'] ?? '').toString();

                final display =
                    "$name - $supplierName - Rs. ${rate.toStringAsFixed(0)}";

                return DropdownMenuItem<String>(
                  value: doc.id,
                  child: Text(
                    display,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),

              onChanged: (val) {
                if (val == null) return;
                setState(() {
                  item.productId = val;
                  final product =
                  products.firstWhere((p) => p.id == val);
                  final data = product.data();
                  item.productName = data['name'] ?? '';
                  final rate = (data['rate'] ?? 0).toString();
                  item.rateController.text = rate;
                });
              },
            ),
          ),

          const SizedBox(width: 4),

          // Qty
          Expanded(
            flex: 2,
            child: TextField(
              controller: item.qtyController,
              keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                isDense: true,
                border: OutlineInputBorder(),
                labelText: "Qty",
              ),
              onChanged: (_) => setState(() {
                if (_paymentStatus == 'Paid') {
                  paymentAmountController.text =
                      totalAmount.toStringAsFixed(2);
                }
              }),
            ),
          ),

          const SizedBox(width: 4),

          // Rate (can edit)
          Expanded(
            flex: 2,
            child: TextField(
              controller: item.rateController,
              keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                isDense: true,
                border: OutlineInputBorder(),
                labelText: "Rate",
              ),
              onChanged: (_) => setState(() {
                if (_paymentStatus == 'Paid') {
                  paymentAmountController.text =
                      totalAmount.toStringAsFixed(2);
                }
              }),
            ),
          ),

          const SizedBox(width: 4),

          // Amount
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.grey.shade400),
              ),
              alignment: Alignment.centerRight,
              child: Text(item.amount.toStringAsFixed(2)),
            ),
          ),

          const SizedBox(width: 4),

          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed:
            items.length == 1 ? null : () => _removeItemRow(index),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentSection() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Payment',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _paymentStatus,
                  decoration: const InputDecoration(
                    labelText: 'Payment Status',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'Unpaid',
                      child: Text('Unpaid'),
                    ),
                    DropdownMenuItem(
                      value: 'Partial',
                      child: Text('Partial'),
                    ),
                    DropdownMenuItem(
                      value: 'Paid',
                      child: Text('Paid in full'),
                    ),
                  ],
                  onChanged: (val) {
                    if (val == null) return;
                    setState(() {
                      _paymentStatus = val;

                      if (_paymentStatus == 'Paid') {
                        paymentAmountController.text =
                            totalAmount.toStringAsFixed(2);
                      }
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: paymentAmountController,
                  readOnly:
                  _paymentStatus == 'Paid',
                  keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Amount Paid Now',
                    border: const OutlineInputBorder(),
                    isDense: true,
                    fillColor: _paymentStatus == 'Paid'
                        ? Colors.grey.shade100
                        : null,
                    filled: _paymentStatus == 'Paid',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _paymentMethod,
            decoration: const InputDecoration(
              labelText: 'Payment Method',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: const [
              DropdownMenuItem(value: 'Cash', child: Text('Cash')),
              DropdownMenuItem(value: 'JazzCash', child: Text('JazzCash')),
              DropdownMenuItem(value: 'Easypaisa', child: Text('Easypaisa')),
              DropdownMenuItem(
                  value: 'Bank Transfer', child: Text('Bank Transfer')),
              DropdownMenuItem(value: 'Other', child: Text('Other')),
            ],
            onChanged: (val) {
              if (val == null) return;
              setState(() {
                _paymentMethod = val;
              });
            },
          ),
          const SizedBox(height: 8),
          TextField(
            controller: paymentNoteController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Payment Note (optional)',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(width: 90, child: Text(label)),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
