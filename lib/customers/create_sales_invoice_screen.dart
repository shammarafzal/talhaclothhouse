import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../inventory/inventory_service.dart';

/* ---------------- ITEM MODEL ---------------- */

class InvoiceItem {
  String? productId;
  String name = '';
  final qtyCtrl = TextEditingController();
  final rateCtrl = TextEditingController();

  double get qty => double.tryParse(qtyCtrl.text) ?? 0;
  double get rate => double.tryParse(rateCtrl.text) ?? 0;
  double get amount => qty * rate;

  Map<String, dynamic> toMap() => {
    'productId': productId,
    'name': name,
    'qty': qty,
    'rate': rate,
    'amount': amount,
  };

  void dispose() {
    qtyCtrl.dispose();
    rateCtrl.dispose();
  }
}

/* ---------------- SCREEN ---------------- */

class CreateCustomerInvoiceScreen extends StatefulWidget {
  const CreateCustomerInvoiceScreen({super.key});

  @override
  State<CreateCustomerInvoiceScreen> createState() =>
      _CreateCustomerInvoiceScreenState();
}

class _CreateCustomerInvoiceScreenState
    extends State<CreateCustomerInvoiceScreen> {
  /* SHOP (FIXED) */
  final shopName = 'Talha Afzal Cloth House';
  final shopPhone = '0303-6339313, 0300-6766691';
  final shopAddress = 'Nasir Cloth Market, Multan';

  /* CUSTOMER */
  String customerType = 'Walk-in';
  String? selectedCustomerId;
  Map<String, dynamic>? selectedCustomer;

  final walkinName = TextEditingController();
  final walkinPhone = TextEditingController();
  final walkinAddress = TextEditingController();

  /* PAYMENT */
  String paymentStatus = 'Unpaid';
  String paymentMethod = 'Cash';
  final paidCtrl = TextEditingController();

  /* EMPLOYEE */
  final employees = ['Talha', 'Waqas', 'Ali', 'Ahmed'];
  String selectedEmployee = 'Talha';

  /* PRODUCTS */
  List<Map<String, dynamic>> products = [];
  List<InvoiceItem> items = [];

  bool loadingProducts = true;
  bool saving = false;

  String invoiceNumber = '';
  late String date;
  late String time;

  @override
  void initState() {
    super.initState();
    _initMeta();
    _loadProducts();
    _generateInvoiceNumber();
    _addItem();
  }

  void _initMeta() {
    final now = DateTime.now();
    date = DateFormat('dd/MM/yyyy').format(now);
    time = DateFormat('hh:mm a').format(now);
  }

  /* ---------------- LOAD PRODUCTS ---------------- */

  Future<void> _loadProducts() async {
    final snap = await FirebaseFirestore.instance
        .collection('products')
        .orderBy('name')
        .get();

    products =
        snap.docs.map((d) => {...d.data(), 'id': d.id}).toList();

    setState(() => loadingProducts = false);
  }

  /* ---------------- INVOICE NUMBER ---------------- */

  Future<void> _generateInvoiceNumber() async {
    final ref = FirebaseFirestore.instance
        .collection('counters')
        .doc('customerInvoice');

    final next = await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final last = snap.exists ? (snap['lastNumber'] ?? 0) : 0;
      tx.set(ref, {'lastNumber': last + 1});
      return last + 1;
    });

    setState(() {
      invoiceNumber = 'TCH-CUS-${next.toString().padLeft(3, '0')}';
    });
  }

  /* ---------------- ITEMS ---------------- */

  void _addItem() => setState(() => items.add(InvoiceItem()));

  void _removeItem(int i) {
    if (items.length == 1) return;
    setState(() {
      items[i].dispose();
      items.removeAt(i);
    });
  }

  double get total =>
      items.fold(0, (sum, e) => sum + e.amount);

  /* ---------------- SAVE & PRINT ---------------- */

  Future<void> _saveInvoice() async {
    if (items.every((e) => e.amount == 0)) return;

    setState(() => saving = true);

    /* CUSTOMER */
    String customerId;
    Map<String, dynamic> customerData;

    if (customerType == 'Walk-in') {
      if (walkinName.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter customer name')),
        );
        setState(() => saving = false);
        return;
      }

      final doc =
      await FirebaseFirestore.instance.collection('customers').add({
        'name': walkinName.text.trim(),
        'phone': walkinPhone.text.trim(),
        'address': walkinAddress.text.trim(),
        'createdAt': DateTime.now(),
      });

      customerId = doc.id;
      customerData = {
        'name': walkinName.text,
        'phone': walkinPhone.text,
        'address': walkinAddress.text,
      };
    } else {
      if (selectedCustomerId == null || selectedCustomer == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Select customer')),
        );
        setState(() => saving = false);
        return;
      }
      customerId = selectedCustomerId!;
      customerData = selectedCustomer!;
    }

    double paid = double.tryParse(paidCtrl.text) ?? 0;
    if (paymentStatus == 'Paid') paid = total;
    if (paymentStatus == 'Unpaid') paid = 0;

    final data = {
      'invoiceNumber': invoiceNumber,
      'date': date,
      'time': time,
      'shop': {
        'name': shopName,
        'phone': shopPhone,
        'address': shopAddress,
      },
      'customer': customerData,
      'items': items.map((e) => e.toMap()).toList(),
      'totalAmount': total,
      'amountPaid': paid,
      'amountDue': total - paid,
      'paymentStatus':
      paid == 0 ? 'Unpaid' : paid < total ? 'Partial' : 'Paid',
      'paymentMethod': paymentMethod,
      'createdBy': selectedEmployee,
      'createdAt': DateTime.now(),
    };
// --------------------------------------------
// INVENTORY CHECK & DEDUCT
// --------------------------------------------
    try {
      for (final item in items) {
        if (item.qty <= 0) continue;

        final productId = item.productId;
        if (productId == null || productId.isEmpty) {
          throw Exception("Product ID missing for an item");
        }

        await InventoryService.decreaseStock(
          productId: productId,
          qty: item.qty,
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Stock error: ${e.toString()}")),
      );
      setState(() => saving = false);
      return;
    }

    await FirebaseFirestore.instance
        .collection('customers')
        .doc(customerId)
        .collection('sales')
        .add(data);

    await _printInvoice(
      invoiceData: data,
      customerName: customerType == 'Walk-in'
          ? walkinName.text
          : (selectedCustomer?['name'] ?? ''),
      customerPhone: customerType == 'Walk-in'
          ? walkinPhone.text
          : (selectedCustomer?['phone'] ?? ''),
      customerAddress: customerType == 'Walk-in'
          ? walkinAddress.text
          : (selectedCustomer?['address'] ?? ''),
    );


    setState(() => saving = false);
    Navigator.pop(context);
  }

  /* ---------------- PRINT (A5) ---------------- */

  Future<void> _printInvoice({
    required Map<String, dynamic> invoiceData,
    required String customerName,
    required String customerPhone,
    required String customerAddress,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        margin: const pw.EdgeInsets.fromLTRB(20, 16, 16, 16), // left gap fix
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [

              /// ---------- SHOP HEADER ----------
              pw.Text(
                'Talha Afzal Cloth House',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                'Shop No 21, Nasir Cloth Market, Multan',
                style: const pw.TextStyle(fontSize: 9),
              ),
              pw.Text(
                'Phone: 0303-6339313',
                style: const pw.TextStyle(fontSize: 9),
              ),

              pw.SizedBox(height: 8),
              pw.Divider(),

              /// ---------- INVOICE INFO ----------
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Invoice #: ${invoiceData['invoiceNumber']}'),
                  pw.Text('Date: ${invoiceData['date']}'),
                ],
              ),
              pw.Text('Time: ${invoiceData['time']}'),

              pw.SizedBox(height: 8),
              pw.Divider(),

              /// ---------- CUSTOMER INFO ----------
              pw.Text(
                'Customer Details',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(customerName),
              if (customerPhone.isNotEmpty)
                pw.Text('Phone: $customerPhone'),
              if (customerAddress.isNotEmpty)
                pw.Text('Address: $customerAddress'),

              pw.SizedBox(height: 10),

              /// ---------- ITEMS TABLE ----------
              pw.Table(
                border: pw.TableBorder.all(width: 0.5),
                columnWidths: const {
                  0: pw.FlexColumnWidth(3),
                  1: pw.FlexColumnWidth(1),
                  2: pw.FlexColumnWidth(1),
                  3: pw.FlexColumnWidth(1.5),
                },
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      _cell('Item', bold: true),
                      _cell('Qty', bold: true),
                      _cell('Rate', bold: true),
                      _cell('Amount', bold: true),
                    ],
                  ),

                  ...(invoiceData['items'] as List).map<pw.TableRow>((item) {
                    return pw.TableRow(
                      children: [
                        _cell(item['name']),
                        _cell(item['qty'].toString()),
                        _cell(item['rate'].toString()),
                        _cell(item['amount'].toString()),
                      ],
                    );
                  }).toList(),
                ],
              ),

              pw.SizedBox(height: 8),

              /// ---------- TOTALS ----------
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Total: Rs ${invoiceData['totalAmount']}',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text('Paid: Rs ${invoiceData['amountPaid']}'),
                    pw.Text('Due: Rs ${invoiceData['amountDue']}'),
                    pw.Text('Status: ${invoiceData['paymentStatus']}'),
                  ],
                ),
              ),

              pw.SizedBox(height: 12),

              /// ---------- FOOTER ----------
              pw.Text(
                'Generated by ${invoiceData['createdBy']}',
                style: const pw.TextStyle(fontSize: 8),
              ),
              pw.Align(
                alignment: pw.Alignment.center,
                child: pw.Text(
                  'Thank you for shopping with us',
                  style: const pw.TextStyle(fontSize: 8),
                ),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
    );
  }

  pw.Widget _cell(String text, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }


  /* ---------------- UI ---------------- */

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sales Invoice')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Card(
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 3,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _header(),
                const SizedBox(height: 16),
                _customerSection(),
                const SizedBox(height: 16),
                _itemsSection(),
                const SizedBox(height: 16),
                _paymentSection(),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'Total: Rs ${total.toStringAsFixed(0)}',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: saving ? null : _saveInvoice,
                  icon: const Icon(Icons.print),
                  label: const Text('Save & Print'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /* ---------------- UI PARTS ---------------- */

  Widget _header() => Column(
    children: [
      Text('Sales Invoice',
          style: Theme.of(context).textTheme.titleLarge),
      Text('Invoice # $invoiceNumber'),
      Text('Date: $date  Time: $time'),
    ],
  );

  /// ✅ FIXED EXISTING CUSTOMER DROPDOWN
  Widget _customerSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField(
          value: customerType,
          items: const [
            DropdownMenuItem(value: 'Walk-in', child: Text('Walk-in')),
            DropdownMenuItem(value: 'Existing', child: Text('Existing')),
          ],
          onChanged: (v) => setState(() {
            customerType = v as String;
            selectedCustomerId = null;
            selectedCustomer = null;
          }),
          decoration: const InputDecoration(
            labelText: 'Customer Type',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),

        if (customerType == 'Existing')
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('customers')
                .orderBy('name')
                .snapshots(),
            builder: (_, snap) {
              if (!snap.hasData) {
                return const LinearProgressIndicator();
              }
              return DropdownButtonFormField<String>(
                value: selectedCustomerId,
                items: snap.data!.docs.map((d) {
                  final data = d.data() as Map<String, dynamic>;
                  return DropdownMenuItem(
                    value: d.id,
                    child: Text(data['name'] ?? ''),
                  );
                }).toList(),
                onChanged: (v) {
                  final doc = snap.data!.docs.firstWhere((e) => e.id == v);
                  setState(() {
                    selectedCustomerId = v;
                    selectedCustomer = doc.data() as Map<String, dynamic>;
                  });
                },
                decoration: const InputDecoration(
                  labelText: 'Select Customer',
                  border: OutlineInputBorder(),
                ),
              );
            },
          ),

        if (customerType == 'Walk-in') ...[
          const SizedBox(height: 8),
          TextField(
            controller: walkinName,
            decoration: const InputDecoration(
                labelText: 'Customer Name', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: walkinPhone,
            decoration: const InputDecoration(
                labelText: 'Phone', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: walkinAddress,
            decoration: const InputDecoration(
                labelText: 'Address', border: OutlineInputBorder()),
          ),
        ],
      ],
    );
  }

  /// ✅ PRICE AUTO FILLED & EDITABLE
  Widget _itemsSection() {
    return Column(
      children: [
        ...List.generate(items.length, (i) {
          final item = items[i];
          return Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Row(
              children: [
                Expanded(
                  flex: 4,
                  child: DropdownButtonFormField<String>(
                    value: item.productId,
                    items: products.map((p) {
                      return DropdownMenuItem<String>(
                        value: p['id'],
                        child: Text(p['name']),
                      );
                    }).toList(),
                    onChanged: (v) {
                      final p = products.firstWhere((e) => e['id'] == v);
                      setState(() {
                        item.productId = v;
                        item.name = p['name'];
                        item.rateCtrl.text =
                            (p['rate'] as num).toString();
                      });
                    },
                    decoration: const InputDecoration(
                        labelText: 'Product',
                        border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: TextField(
                    controller: item.qtyCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Qty', border: OutlineInputBorder()),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: TextField(
                    controller: item.rateCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Rate', border: OutlineInputBorder()),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => _removeItem(i),
                )
              ],
            ),
          );
        }),
        TextButton.icon(
          onPressed: _addItem,
          icon: const Icon(Icons.add),
          label: const Text('Add Item'),
        ),
      ],
    );
  }

  Widget _paymentSection() {
    return Column(
      children: [
        DropdownButtonFormField(
          value: paymentStatus,
          items: const [
            DropdownMenuItem(value: 'Unpaid', child: Text('Unpaid')),
            DropdownMenuItem(value: 'Partial', child: Text('Partial')),
            DropdownMenuItem(value: 'Paid', child: Text('Paid')),
          ],
          onChanged: (v) => setState(() => paymentStatus = v as String),
          decoration: const InputDecoration(
              labelText: 'Payment Status', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: paidCtrl,
          decoration: const InputDecoration(
              labelText: 'Paid Amount', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField(
          value: selectedEmployee,
          items: employees
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: (v) => setState(() => selectedEmployee = v as String),
          decoration: const InputDecoration(
              labelText: 'Created By', border: OutlineInputBorder()),
        ),
      ],
    );
  }
}
