// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:flutter/material.dart';
// import 'package:intl/intl.dart';
// import 'package:pdf/widgets.dart' as pw;
// import 'package:pdf/pdf.dart';
// import 'package:printing/printing.dart';
//
// class _InvoiceItem {
//   final TextEditingController qtyController = TextEditingController();
//   final TextEditingController rateController = TextEditingController();
//   String? productId;
//   String? productName;
//
//   double get qty => double.tryParse(qtyController.text) ?? 0;
//   double get rate => double.tryParse(rateController.text) ?? 0;
//   double get amount => qty * rate;
//
//   Map<String, dynamic> toMap() {
//     return {
//       'productId': productId,
//       'name': productName ?? '',
//       'qty': qty,
//       'rate': rate,
//       'amount': amount,
//     };
//   }
//
//   bool get isEmpty => (productName == null || productName!.isEmpty) && qty == 0;
//
//   void dispose() {
//     qtyController.dispose();
//     rateController.dispose();
//   }
// }
//
// class CreateInvoiceScreen extends StatefulWidget {
//   final String supplierId;
//   final Map<String, dynamic> supplierData;
//
//   const CreateInvoiceScreen({
//     super.key,
//     required this.supplierId,
//     required this.supplierData,
//   });
//
//   @override
//   State<CreateInvoiceScreen> createState() => _CreateInvoiceScreenState();
// }
//
// class _CreateInvoiceScreenState extends State<CreateInvoiceScreen> {
//   // Buyer info (can be your shop details or customer)
//   final TextEditingController buyerNameController = TextEditingController();
//   final TextEditingController buyerPhoneController = TextEditingController();
//   final TextEditingController buyerAddressController = TextEditingController();
//
//   late String invoiceNumber;
//   late String invoiceDate;
//   late String invoiceTime;
//   late String dayName;
//
//   bool saving = false;
//   bool productsLoading = true;
//   String? productsError;
//
//   final List<_InvoiceItem> items = [];
//   List<QueryDocumentSnapshot<Map<String, dynamic>>> products = [];
//
//   @override
//   void initState() {
//     super.initState();
//     _initInvoiceMeta();
//     _addItemRow();
//     _loadProducts();
//   }
//
//   void _initInvoiceMeta() {
//     final now = DateTime.now();
//     invoiceNumber = (now.millisecondsSinceEpoch ~/ 1000).toString();
//     invoiceDate = DateFormat('dd/MM/yyyy').format(now);
//     invoiceTime = DateFormat('HH:mm').format(now);
//     dayName = DateFormat('EEEE').format(now);
//   }
//
//   Future<void> _loadProducts() async {
//     try {
//       final snap = await FirebaseFirestore.instance
//           .collection("suppliers")
//           .doc(widget.supplierId)
//           .collection("products")
//           .get();
//
//       setState(() {
//         products = snap.docs;
//         productsLoading = false;
//       });
//     } catch (e) {
//       setState(() {
//         productsError = e.toString();
//         productsLoading = false;
//       });
//     }
//   }
//
//   void _addItemRow() {
//     setState(() {
//       items.add(_InvoiceItem());
//     });
//   }
//
//   void _removeItemRow(int index) {
//     if (items.length == 1) return;
//     setState(() {
//       items.removeAt(index);
//     });
//   }
//
//   double get totalAmount {
//     double total = 0;
//     for (final item in items) {
//       total += item.amount;
//     }
//     return total;
//   }
//
//   Future<void> _saveInvoice() async {
//     if (saving) return;
//
//     final validItems = items
//         .where((item) => !item.isEmpty && item.amount > 0)
//         .map((e) => e.toMap())
//         .toList();
//
//     if (validItems.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text("Add at least one valid item")),
//       );
//       return;
//     }
//
//     setState(() => saving = true);
//
//     try {
//       final total = validItems.fold<double>(
//         0,
//             (prev, element) => prev + (element['amount'] as double),
//       );
//
//       final data = {
//         'invoiceNumber': invoiceNumber,
//         'supplierId': widget.supplierId,
//         'supplierName': widget.supplierData['name'] ?? '',
//         'supplierPhone': widget.supplierData['phone'] ?? '',
//         'supplierAddress': widget.supplierData['address'] ?? '',
//         'date': invoiceDate,
//         'time': invoiceTime,
//         'dayName': dayName,
//         'buyerName': buyerNameController.text.trim(),
//         'buyerPhone': buyerPhoneController.text.trim(),
//         'buyerAddress': buyerAddressController.text.trim(),
//         'items': validItems,
//         'totalAmount': total,
//         'createdAt': DateTime.now(),
//       };
//
//       final docRef = await FirebaseFirestore.instance
//           .collection('suppliers')
//           .doc(widget.supplierId)
//           .collection('purchases')
//           .add(data);
//
//       // TODO later: also update a global inventory collection here.
//
//       if (!mounted) return;
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text("Invoice saved")),
//       );
//
//       // Print invoice
//       await _printInvoice(data);
//
//       Navigator.pop(context);
//     } catch (e) {
//       if (!mounted) return;
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text("Error saving invoice: $e")),
//       );
//     } finally {
//       if (mounted) setState(() => saving = false);
//     }
//   }
//
//   Future<void> _printInvoice(Map<String, dynamic> data) async {
//     final pdf = pw.Document();
//
//     final itemsList =
//     (data['items'] as List).cast<Map<String, dynamic>>();
//
//     pdf.addPage(
//       pw.Page(
//         pageFormat: PdfPageFormat.a4,
//         build: (context) {
//           return pw.Padding(
//             padding: const pw.EdgeInsets.all(24),
//             child: pw.Column(
//               crossAxisAlignment: pw.CrossAxisAlignment.start,
//               children: [
//                 pw.Text(
//                   "Purchase Invoice",
//                   style: pw.TextStyle(
//                     fontSize: 22,
//                     fontWeight: pw.FontWeight.bold,
//                   ),
//                 ),
//                 pw.SizedBox(height: 12),
//                 pw.Row(
//                   crossAxisAlignment: pw.CrossAxisAlignment.start,
//                   children: [
//                     pw.Expanded(
//                       child: pw.Column(
//                         crossAxisAlignment:
//                         pw.CrossAxisAlignment.start,
//                         children: [
//                           pw.Text("Supplier: ${data['supplierName']}"),
//                           pw.Text("Phone: ${data['supplierPhone']}"),
//                           pw.Text("Address: ${data['supplierAddress']}"),
//                         ],
//                       ),
//                     ),
//                     pw.SizedBox(width: 16),
//                     pw.Expanded(
//                       child: pw.Column(
//                         crossAxisAlignment:
//                         pw.CrossAxisAlignment.start,
//                         children: [
//                           pw.Text("Invoice #: ${data['invoiceNumber']}"),
//                           pw.Text("Date: ${data['date']}"),
//                           pw.Text("Time: ${data['time']}"),
//                           pw.Text("Day: ${data['dayName']}"),
//                         ],
//                       ),
//                     ),
//                   ],
//                 ),
//                 pw.SizedBox(height: 12),
//                 pw.Text("Buyer: ${data['buyerName'] ?? ''}"),
//                 pw.Text("Buyer Phone: ${data['buyerPhone'] ?? ''}"),
//                 pw.Text("Buyer Address: ${data['buyerAddress'] ?? ''}"),
//                 pw.SizedBox(height: 16),
//                 pw.Table.fromTextArray(
//                   headers: ["Item", "Qty", "Rate", "Amount"],
//                   data: itemsList
//                       .map(
//                         (it) => [
//                       it['name'] ?? '',
//                       it['qty'].toString(),
//                       it['rate'].toString(),
//                       it['amount'].toString(),
//                     ],
//                   )
//                       .toList(),
//                 ),
//                 pw.SizedBox(height: 12),
//                 pw.Align(
//                   alignment: pw.Alignment.centerRight,
//                   child: pw.Text(
//                     "Total: ${data['totalAmount']}",
//                     style: pw.TextStyle(
//                       fontSize: 16,
//                       fontWeight: pw.FontWeight.bold,
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           );
//         },
//       ),
//     );
//
//     await Printing.layoutPdf(
//       onLayout: (PdfPageFormat format) async => pdf.save(),
//     );
//   }
//
//   @override
//   void dispose() {
//     buyerNameController.dispose();
//     buyerPhoneController.dispose();
//     buyerAddressController.dispose();
//     for (final item in items) {
//       item.dispose();
//     }
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     const maxWidth = 900.0;
//
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Purchase Invoice'),
//       ),
//       body: Center(
//         child: SingleChildScrollView(
//           padding: const EdgeInsets.all(16),
//           child: ConstrainedBox(
//             constraints: const BoxConstraints(maxWidth: maxWidth),
//             child: Card(
//               elevation: 3,
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(16),
//               ),
//               child: Padding(
//                 padding: const EdgeInsets.all(16),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.stretch,
//                   children: [
//                     Text(
//                       'Purchase Invoice',
//                       textAlign: TextAlign.center,
//                       style: Theme.of(context).textTheme.titleLarge,
//                     ),
//                     const SizedBox(height: 16),
//                     _buildTopInfo(),
//                     const SizedBox(height: 16),
//                     _buildBuyerInfoCard(),
//                     const SizedBox(height: 16),
//                     if (productsLoading)
//                       const Center(child: CircularProgressIndicator())
//                     else if (productsError != null)
//                       Text("Error loading products: $productsError")
//                     else
//                       _buildItemsSection(),
//                     const SizedBox(height: 16),
//                     Align(
//                       alignment: Alignment.centerRight,
//                       child: Text(
//                         'Total: ${totalAmount.toStringAsFixed(2)}',
//                         style: Theme.of(context)
//                             .textTheme
//                             .titleMedium
//                             ?.copyWith(fontWeight: FontWeight.bold),
//                       ),
//                     ),
//                     const SizedBox(height: 16),
//                     ElevatedButton.icon(
//                       onPressed: saving || productsLoading ? null : _saveInvoice,
//                       icon: saving
//                           ? const SizedBox(
//                         width: 18,
//                         height: 18,
//                         child: CircularProgressIndicator(strokeWidth: 2),
//                       )
//                           : const Icon(Icons.save),
//                       label: Text(saving ? 'Saving...' : 'Save & Print'),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget _buildTopInfo() {
//     return LayoutBuilder(
//       builder: (context, constraints) {
//         final isMobile = constraints.maxWidth < 600;
//         if (isMobile) {
//           return Column(
//             children: [
//               _buildSupplierInfoCard(),
//               const SizedBox(height: 12),
//               _buildInvoiceInfoCard(),
//             ],
//           );
//         }
//         return Row(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Expanded(child: _buildSupplierInfoCard()),
//             const SizedBox(width: 12),
//             Expanded(child: _buildInvoiceInfoCard()),
//           ],
//         );
//       },
//     );
//   }
//
//   Widget _buildSupplierInfoCard() {
//     return Container(
//       padding: const EdgeInsets.all(8),
//       decoration: BoxDecoration(
//         border: Border.all(color: Colors.grey.shade300),
//         borderRadius: BorderRadius.circular(12),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           const Text('Supplier'),
//           const SizedBox(height: 4),
//           Text(
//             widget.supplierData['name'] ?? '',
//             style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
//           ),
//           const SizedBox(height: 2),
//           Text(widget.supplierData['phone'] ?? ''),
//           Text(widget.supplierData['address'] ?? ''),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildInvoiceInfoCard() {
//     return Container(
//       padding: const EdgeInsets.all(8),
//       decoration: BoxDecoration(
//         border: Border.all(color: Colors.grey.shade300),
//         borderRadius: BorderRadius.circular(12),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           const Text('Invoice Info'),
//           const SizedBox(height: 4),
//           _infoRow('Invoice #', invoiceNumber),
//           _infoRow('Date', invoiceDate),
//           _infoRow('Time', invoiceTime),
//           _infoRow('Day', dayName),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildBuyerInfoCard() {
//     return Container(
//       padding: const EdgeInsets.all(8),
//       decoration: BoxDecoration(
//         border: Border.all(color: Colors.grey.shade300),
//         borderRadius: BorderRadius.circular(12),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           const Text('Buyer'),
//           const SizedBox(height: 8),
//           TextField(
//             controller: buyerNameController,
//             decoration: const InputDecoration(
//               labelText: 'Buyer Name',
//               border: OutlineInputBorder(),
//             ),
//           ),
//           const SizedBox(height: 8),
//           TextField(
//             controller: buyerPhoneController,
//             decoration: const InputDecoration(
//               labelText: 'Buyer Phone',
//               border: OutlineInputBorder(),
//             ),
//           ),
//           const SizedBox(height: 8),
//           TextField(
//             controller: buyerAddressController,
//             maxLines: 2,
//             decoration: const InputDecoration(
//               labelText: 'Buyer Address',
//               border: OutlineInputBorder(),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildItemsSection() {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(
//           'Items',
//           style:
//           Theme.of(context).textTheme.titleMedium?.copyWith(
//             fontWeight: FontWeight.w600,
//           ),
//         ),
//         const SizedBox(height: 8),
//         ...List.generate(items.length, (index) => _buildItemRow(index)),
//         const SizedBox(height: 8),
//         Align(
//           alignment: Alignment.centerLeft,
//           child: TextButton.icon(
//             onPressed: _addItemRow,
//             icon: const Icon(Icons.add),
//             label: const Text('Add Item'),
//           ),
//         ),
//       ],
//     );
//   }
//
//   Widget _buildItemRow(int index) {
//     final item = items[index];
//
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 4),
//       child: Row(
//         children: [
//           // Product dropdown
//           Expanded(
//             flex: 4,
//             child: DropdownButtonFormField<String>(
//               value: item.productId,
//               isExpanded: true,
//               decoration: const InputDecoration(
//                 isDense: true,
//                 border: OutlineInputBorder(),
//                 labelText: "Product",
//               ),
//               items: products
//                   .map(
//                     (doc) => DropdownMenuItem<String>(
//                   value: doc.id,
//                   child: Text(doc.data()['name'] ?? ''),
//                 ),
//               )
//                   .toList(),
//               onChanged: (val) {
//                 setState(() {
//                   item.productId = val;
//                   final product =
//                   products.firstWhere((p) => p.id == val);
//                   final data = product.data();
//                   item.productName = data['name'] ?? '';
//                   final rate = (data['rate'] ?? 0).toString();
//                   item.rateController.text = rate;
//                 });
//               },
//             ),
//           ),
//
//           const SizedBox(width: 4),
//
//           // Qty
//           Expanded(
//             flex: 2,
//             child: TextField(
//               controller: item.qtyController,
//               keyboardType:
//               const TextInputType.numberWithOptions(decimal: true),
//               decoration: const InputDecoration(
//                 isDense: true,
//                 border: OutlineInputBorder(),
//                 labelText: "Qty",
//               ),
//               onChanged: (_) => setState(() {}),
//             ),
//           ),
//
//           const SizedBox(width: 4),
//
//           // Rate (can edit)
//           Expanded(
//             flex: 2,
//             child: TextField(
//               controller: item.rateController,
//               keyboardType:
//               const TextInputType.numberWithOptions(decimal: true),
//               decoration: const InputDecoration(
//                 isDense: true,
//                 border: OutlineInputBorder(),
//                 labelText: "Rate",
//               ),
//               onChanged: (_) => setState(() {}),
//             ),
//           ),
//
//           const SizedBox(width: 4),
//
//           // Amount
//           Expanded(
//             flex: 2,
//             child: Container(
//               padding:
//               const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
//               decoration: BoxDecoration(
//                 borderRadius: BorderRadius.circular(4),
//                 border: Border.all(color: Colors.grey.shade400),
//               ),
//               alignment: Alignment.centerRight,
//               child: Text(item.amount.toStringAsFixed(2)),
//             ),
//           ),
//
//           const SizedBox(width: 4),
//
//           IconButton(
//             icon: const Icon(Icons.close, size: 18),
//             onPressed: items.length == 1
//                 ? null
//                 : () => _removeItemRow(index),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _infoRow(String label, String value) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 2),
//       child: Row(
//         children: [
//           SizedBox(width: 90, child: Text(label)),
//           Expanded(
//             child: Text(
//               value,
//               textAlign: TextAlign.right,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

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
  // Buyer info
  final TextEditingController buyerNameController = TextEditingController();
  final TextEditingController buyerPhoneController = TextEditingController();
  final TextEditingController buyerAddressController = TextEditingController();

  // Payment info
  final TextEditingController paymentAmountController = TextEditingController();
  final TextEditingController paymentNoteController = TextEditingController();
  String _paymentStatus = 'Unpaid'; // Unpaid, Partial, Paid
  String _paymentMethod = 'Cash';   // Cash, JazzCash, Easypaisa, Bank Transfer, Other

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
  Future<String> _generateInvoiceNumber() async {
    final counterRef = FirebaseFirestore.instance
        .collection('counters')
        .doc('purchaseInvoice');

    return FirebaseFirestore.instance.runTransaction((transaction) async {
      final snap = await transaction.get(counterRef);

      int lastNumber = 0;
      if (snap.exists) {
        final data = snap.data() as Map<String, dynamic>;
        lastNumber = (data['lastNumber'] ?? 0) as int;
      }

      final nextNumber = lastNumber + 1;

      transaction.set(counterRef, {'lastNumber': nextNumber});

      // Format: TCH-01, TCH-02, TCH-10, ...
      final padded = nextNumber.toString().padLeft(2, '0');
      return 'TCH-$padded';
    });
  }


  @override
  void initState() {
    super.initState();

    // ✅ Default buyer details (your shop) – you can edit these later
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

    // ---- PAYMENT LOGIC ----
    double paidNow = double.tryParse(paymentAmountController.text.trim()) ?? 0;
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

    // If user selected Paid but forgot amount, auto set to full:
    if (_paymentStatus == 'Paid' && paidNow == 0) {
      paidNow = total;
      amountDue = 0;
      paymentStatus = 'Paid';
    }

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
          .collection('suppliers')
          .doc(widget.supplierId)
          .collection('purchases')
          .add(data);

      // If we paid something now, add initial payment record
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

      // Print invoice
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
                  "Purchase Invoice",
                  style: pw.TextStyle(
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 12),
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text("Supplier: ${data['supplierName']}"),
                          pw.Text("Phone: ${data['supplierPhone']}"),
                          pw.Text("Address: ${data['supplierAddress']}"),
                        ],
                      ),
                    ),
                    pw.SizedBox(width: 16),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
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
                pw.Text("Buyer: ${data['buyerName'] ?? ''}"),
                pw.Text("Buyer Phone: ${data['buyerPhone'] ?? ''}"),
                pw.Text("Buyer Address: ${data['buyerAddress'] ?? ''}"),
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
        title: const Text('Purchase Invoice'),
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
                      'Purchase Invoice',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    _buildTopInfo(),
                    const SizedBox(height: 16),
                    _buildBuyerInfoCard(),
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
                      onPressed: saving || productsLoading ? null : _saveInvoice,
                      icon: saving
                          ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                          : const Icon(Icons.save),
                      label: Text(saving ? 'Saving...' : 'Save & Print'),
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
              _buildSupplierInfoCard(),
              const SizedBox(height: 12),
              _buildInvoiceInfoCard(),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildSupplierInfoCard()),
            const SizedBox(width: 12),
            Expanded(child: _buildInvoiceInfoCard()),
          ],
        );
      },
    );
  }

  Widget _buildSupplierInfoCard() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Supplier'),
          const SizedBox(height: 4),
          Text(
            widget.supplierData['name'] ?? '',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(widget.supplierData['phone'] ?? ''),
          Text(widget.supplierData['address'] ?? ''),
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
          _infoRow('Invoice #', invoiceNumber ?? (invoiceNoLoading ? 'Generating...' : 'N/A')),
          _infoRow('Date', invoiceDate),
          _infoRow('Time', invoiceTime),
          _infoRow('Day', dayName),
        ],
      ),
    );
  }

  Widget _buildBuyerInfoCard() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Buyer'),
          const SizedBox(height: 8),
          TextField(
            controller: buyerNameController,
            decoration: const InputDecoration(
              labelText: 'Buyer Name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: buyerPhoneController,
            decoration: const InputDecoration(
              labelText: 'Buyer Phone',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: buyerAddressController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Buyer Address',
              border: OutlineInputBorder(),
            ),
          ),
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
          style:
          Theme.of(context).textTheme.titleMedium?.copyWith(
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
          // Product dropdown
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
              items: products
                  .map(
                    (doc) => DropdownMenuItem<String>(
                  value: doc.id,
                  child: Text(doc.data()['name'] ?? ''),
                ),
              )
                  .toList(),
              onChanged: (val) {
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
              padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
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
            onPressed: items.length == 1
                ? null
                : () => _removeItemRow(index),
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
                        // 🔹 Auto set full total when “Paid in full”
                        paymentAmountController.text =
                            totalAmount.toStringAsFixed(2);
                      } else {
                        // (Optional) clear amount when switching away
                        // paymentAmountController.clear();
                      }
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: paymentAmountController,
                  readOnly: _paymentStatus == 'Paid', // 🔒 lock when paid in full
                  keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Amount Paid Now',
                    border: const OutlineInputBorder(),
                    isDense: true,
                    // Just to visually hint it’s locked
                    fillColor:
                    _paymentStatus == 'Paid' ? Colors.grey.shade100 : null,
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
