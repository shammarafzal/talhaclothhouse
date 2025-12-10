import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

class _InvoiceItem {
  final TextEditingController qtyController = TextEditingController();
  String? productId;
  String? productName;
  double rate = 0; // from product, not shown in UI

  double get qty => double.tryParse(qtyController.text) ?? 0;
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

  bool get isEmpty =>
      (productName == null || productName!.isEmpty) && qty == 0;

  void dispose() {
    qtyController.dispose();
  }
}

class CreateInvoiceScreen extends StatefulWidget {
  final String supplierId;
  final Map<String, dynamic> supplierData;

  const CreateInvoiceScreen({
    super.key,
    required this.supplierId,
    required this.supplierData,
  });

  @override
  State<CreateInvoiceScreen> createState() => _CreateInvoiceScreenState();
}

class _CreateInvoiceScreenState extends State<CreateInvoiceScreen> {
  /// Your shop (buyer) – fixed, you will change in code if needed
  final TextEditingController buyerNameController = TextEditingController();
  final TextEditingController buyerPhoneController = TextEditingController();
  final TextEditingController buyerAddressController = TextEditingController();

  String? invoiceNumber;
  bool invoiceNoLoading = true;
  late String invoiceDate;
  late String invoiceTime;
  late String dayName;

  bool saving = false;
  bool productsLoading = true;
  String? productsError;

  final List<_InvoiceItem> items = [];
  List<QueryDocumentSnapshot<Map<String, dynamic>>> products = [];

  @override
  void initState() {
    super.initState();

    // ✅ Default buyer details (your shop) – change text here in code if needed
    buyerNameController.text = 'Talha Afzal Cloth House';
    buyerPhoneController.text =
    'Talha Afzal: 0303-6339313 \nWaqas Afzal: 0300-6766691 \nAbbas Afzal: 0303-2312531';
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

  /// Generate supplier purchase invoice number like TCH-01, TCH-02
  Future<String> _generateInvoiceNumber() async {
    final counterRef =
    FirebaseFirestore.instance.collection('counters').doc('purchaseInvoice');

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
      return 'TCH-$padded';
    });
  }

  Future<void> _loadProducts() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection("suppliers")
          .doc(widget.supplierId)
          .collection("products")
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
        .where((item) => !item.isEmpty && item.qty > 0)
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

    final total = validItems.fold<double>(
      0,
          (prev, element) => prev + (element['amount'] as double),
    );

    setState(() => saving = true);

    try {
      final data = {
        'invoiceNumber': invoiceNumber,
        'supplierId': widget.supplierId,
        'supplierName': widget.supplierData['name'] ?? '',
        'supplierPhone': widget.supplierData['phone'] ?? '',
        'supplierAddress': widget.supplierData['address'] ?? '',
        'date': invoiceDate,
        'time': invoiceTime,
        'dayName': dayName,
        'buyerName': buyerNameController.text.trim(),
        'buyerPhone': buyerPhoneController.text.trim(),
        'buyerAddress': buyerAddressController.text.trim(),
        'items': validItems,
        'totalAmount': total,
        'createdAt': DateTime.now(),
      };

      await FirebaseFirestore.instance
          .collection('suppliers')
          .doc(widget.supplierId)
          .collection('purchases')
          .add(data);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Invoice saved")),
      );

      // Modern A5 print
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

    // Proper A5 with safe margins all around
    final a5 = PdfPageFormat.a5;
    final pageFormat = PdfPageFormat(
      a5.width,
      a5.height,
      marginLeft: 24,
      marginRight: 24,
      marginTop: 24,
      marginBottom: 24,
    );

    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // HEADER BAR
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 12,
                ),
                decoration: pw.BoxDecoration(
                  color: PdfColors.blue700,
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(6),
                  ),
                ),
                child: pw.Row(
                  children: [
                    pw.Text(
                      "PURCHASE RECEIVING",
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Spacer(),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          data['invoiceNumber'] ?? '',
                          style: const pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 10,
                          ),
                        ),
                        pw.Text(
                          (data['date'] ?? '') +
                              (data['time'] != null
                                  ? "  ${data['time']}"
                                  : ""),
                          style: const pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 9,
                          ),
                        ),
                        if (data['dayName'] != null)
                          pw.Text(
                            data['dayName'],
                            style: const pw.TextStyle(
                              color: PdfColors.white,
                              fontSize: 9,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 14),

              // SUPPLIER + BUYER CARDS
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Supplier card
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      decoration: pw.BoxDecoration(
                        borderRadius: const pw.BorderRadius.all(
                          pw.Radius.circular(6),
                        ),
                        border: pw.Border.all(color: PdfColors.grey300),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            "Supplier",
                            style: pw.TextStyle(
                              fontSize: 10,
                              color: PdfColors.grey700,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.SizedBox(height: 3),
                          pw.Text(
                            data['supplierName'] ?? '',
                            style: pw.TextStyle(
                              fontSize: 11,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          if ((data['supplierPhone'] ?? '')
                              .toString()
                              .isNotEmpty)
                            pw.Text(
                              "${data['supplierPhone']}",
                              style: const pw.TextStyle(fontSize: 9),
                            ),
                          if ((data['supplierAddress'] ?? '')
                              .toString()
                              .isNotEmpty)
                            pw.Text(
                              "${data['supplierAddress']}",
                              style: const pw.TextStyle(fontSize: 9),
                            ),
                        ],
                      ),
                    ),
                  ),

                  pw.SizedBox(width: 10),

                  // Buyer card
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      decoration: pw.BoxDecoration(
                        borderRadius: const pw.BorderRadius.all(
                          pw.Radius.circular(6),
                        ),
                        border: pw.Border.all(color: PdfColors.grey300),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            "Buyer",
                            style: pw.TextStyle(
                              fontSize: 10,
                              color: PdfColors.grey700,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.SizedBox(height: 3),
                          pw.Text(
                            data['buyerName'] ?? '',
                            style: pw.TextStyle(
                              fontSize: 11,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          if ((data['buyerPhone'] ?? '')
                              .toString()
                              .isNotEmpty)
                            pw.Text(
                              data['buyerPhone'],
                              style: const pw.TextStyle(fontSize: 9),
                            ),
                          if ((data['buyerAddress'] ?? '')
                              .toString()
                              .isNotEmpty)
                            pw.Text(
                              data['buyerAddress'],
                              style: const pw.TextStyle(fontSize: 9),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 16),

              // ITEMS TABLE (Item + Qty) WITH ROOM
              pw.Text(
                "Items Received",
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.black,
                ),
              ),
              pw.SizedBox(height: 6),

              pw.Container(
                decoration: pw.BoxDecoration(
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(6),
                  ),
                  border: pw.Border.all(color: PdfColors.grey300),
                ),
                child: pw.Table.fromTextArray(
                  headerDecoration: const pw.BoxDecoration(
                    color: PdfColors.grey200,
                  ),
                  headerStyle: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                  cellStyle: const pw.TextStyle(
                    fontSize: 9,
                  ),
                  cellPadding: const pw.EdgeInsets.symmetric(
                    vertical: 5,
                    horizontal: 6,
                  ),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(3),
                    1: const pw.FlexColumnWidth(1),
                  },
                  headers: ["Item", "Qty"],
                  data: itemsList
                      .map(
                        (it) => [
                      it['name'] ?? '',
                      it['qty'].toString(),
                    ],
                  )
                      .toList(),
                ),
              ),

              pw.SizedBox(height: 50),

              // SIGNATURE LINES WITH SPACE
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    children: [
                      pw.Container(
                        width: 90,
                        height: 0.7,
                        color: PdfColors.grey500,
                      ),
                      pw.SizedBox(height: 4),
                       pw.Text(
                        "Supplier Sign",
                        style: pw.TextStyle(fontSize: 9),
                      ),
                    ],
                  ),
                  pw.Column(
                    children: [
                      pw.Container(
                        width: 90,
                        height: 0.7,
                        color: PdfColors.grey500,
                      ),
                      pw.SizedBox(height: 4),
                       pw.Text(
                        "Receiver Sign",
                        style: pw.TextStyle(fontSize: 9),
                      ),
                    ],
                  ),
                ],
              ),
            ],
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
    for (final item in items) {
      item.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const maxWidth = 900.0;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Purchase Invoice'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: maxWidth),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeaderBanner(),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildTopInfoRow(),
                        const SizedBox(height: 16),
                        // Buyer details are fixed – just shown, not editable
                        _buildBuyerInfoReadOnly(),
                        const SizedBox(height: 16),
                        if (productsLoading)
                          const Center(child: CircularProgressIndicator())
                        else if (productsError != null)
                          Text("Error loading products: $productsError")
                        else
                          _buildItemsSection(),
                        const SizedBox(height: 16),
                        Align(
                          alignment: Alignment.centerRight,
                          child: ElevatedButton.icon(
                            onPressed: saving || productsLoading
                                ? null
                                : _saveInvoice,
                            icon: saving
                                ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                                : const Icon(Icons.print),
                            label: Text(
                              saving ? 'Saving...' : 'Save & Print',
                            ),
                            style: ElevatedButton.styleFrom(
                              padding:
                              const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderBanner() {
    return Container(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        gradient: LinearGradient(
          colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          const Icon(Icons.receipt_long, color: Colors.white, size: 26),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Purchase Receiving",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                invoiceNumber == null
                    ? (invoiceNoLoading ? "Invoice #: Generating..." : "")
                    : "Invoice #: $invoiceNumber",
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                invoiceDate,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.95),
                  fontSize: 13,
                ),
              ),
              Text(
                "$invoiceTime • $dayName",
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopInfoRow() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 650;

        final supplierCard = Expanded(child: _buildSupplierInfoCard());
        final invoiceCard = Expanded(child: _buildInvoiceInfoCard());

        if (isMobile) {
          return Column(
            children: [
              supplierCard,
              const SizedBox(height: 10),
              invoiceCard,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            supplierCard,
            const SizedBox(width: 12),
            invoiceCard,
          ],
        );
      },
    );
  }

  Widget _buildSupplierInfoCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.blueGrey.shade100),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.blueGrey.shade200,
            child: const Icon(Icons.store, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Supplier",
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blueGrey,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.supplierData['name'] ?? '',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                if ((widget.supplierData['phone'] ?? '').toString().isNotEmpty)
                  Text(
                    widget.supplierData['phone'],
                    style: const TextStyle(fontSize: 13),
                  ),
                if ((widget.supplierData['address'] ?? '')
                    .toString()
                    .isNotEmpty)
                  Text(
                    widget.supplierData['address'],
                    style: const TextStyle(fontSize: 12),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceInfoCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Invoice Info",
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          _infoRow("Invoice #",
              invoiceNumber ?? (invoiceNoLoading ? "Generating..." : "N/A")),
          _infoRow("Date", invoiceDate),
          _infoRow("Time", invoiceTime),
          _infoRow("Day", dayName),
        ],
      ),
    );
  }

  Widget _buildBuyerInfoReadOnly() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Buyer (Your Shop) - Fixed',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            buyerNameController.text,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            buyerPhoneController.text,
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 2),
          Text(
            buyerAddressController.text,
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 6),
          const Text(
            "To change these details, edit the values in code.",
            style: TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Items Received',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Select product and enter quantity received.',
            style: TextStyle(fontSize: 11, color: Colors.grey),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: const [
                Expanded(
                  flex: 5,
                  child: Text(
                    "Product",
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
                SizedBox(width: 4),
                Expanded(
                  flex: 3,
                  child: Text(
                    "Qty",
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
                SizedBox(width: 32),
              ],
            ),
          ),
          const SizedBox(height: 4),
          ...List.generate(items.length, (index) => _buildItemRow(index)),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _addItemRow,
            icon: const Icon(Icons.add),
            label: const Text('Add Item'),
          ),
        ],
      ),
    );
  }

  Widget _buildItemRow(int index) {
    final item = items[index];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: DropdownButtonFormField<String>(
              value: item.productId,
              isExpanded: true,
              decoration: const InputDecoration(
                isDense: true,
                border: OutlineInputBorder(),
                labelText: "Product",
              ),
              items: products
                  .map(
                    (doc) => DropdownMenuItem<String>(
                  value: doc.id,
                  child: Text(doc.data()['name'] ?? ''),
                ),
              )
                  .toList(),
              onChanged: (val) {
                if (val == null) return;
                setState(() {
                  item.productId = val;
                  final product =
                  products.firstWhere((p) => p.id == val);
                  final data = product.data();
                  item.productName = data['name'] ?? '';
                  item.rate = (data['rate'] ?? 0).toDouble();
                });
              },
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            flex: 3,
            child: TextField(
              controller: item.qtyController,
              keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                isDense: true,
                border: OutlineInputBorder(),
                labelText: "Qty",
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            tooltip: "Remove",
            onPressed:
            items.length == 1 ? null : () => _removeItemRow(index),
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
