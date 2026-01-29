import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../inventory/inventory_service.dart';
import 'sales_invoice_printer.dart';

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
  String paymentStatus = 'نہیں بھارہ';
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

    if (paymentStatus == 'پورہ بھارہ') {
      paid = total;
    } else if (paymentStatus == 'نہیں بھارہ') {
      paid = 0;
    } else if (paymentStatus == 'کچھ بھارہ') {
      if (paid <= 0) {
        paid = 0;
      }
      if (paid >= total) {
        paid = total;
      }
    }

    final double due = total - paid;


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
      'amountDue': due,
      'paymentStatus': paymentStatus,
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

    await printSalesInvoice(
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


  // Future<void> printSalesInvoice({
  //   required Map<String, dynamic> invoiceData,
  //   required String customerName,
  //   required String customerPhone,
  //   required String customerAddress,
  // }) async {
  //   final fontData =
  //   await rootBundle.load('assets/fonts/NotoSansArabic-Regular.ttf');
  //   final urduFont = pw.Font.ttf(fontData);
  //
  //   final normal = pw.TextStyle(font: urduFont, fontSize: 9);
  //   final bold = pw.TextStyle(
  //     font: urduFont,
  //     fontSize: 9,
  //     fontWeight: pw.FontWeight.bold,
  //   );
  //   final title = pw.TextStyle(
  //     font: urduFont,
  //     fontSize: 16,
  //     fontWeight: pw.FontWeight.bold,
  //   );
  //
  //   pw.Widget buildHeader() {
  //
  //     final urduFont = pw.Font.ttf(fontData);
  //
  //     return pw.Container(
  //       padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8), // 🔽 less padding
  //       decoration: pw.BoxDecoration(
  //         border: pw.Border.all(width: 1),
  //       ),
  //       child: pw.Column(
  //         crossAxisAlignment: pw.CrossAxisAlignment.stretch,
  //         children: [
  //           pw.Row(
  //             mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
  //             crossAxisAlignment: pw.CrossAxisAlignment.start,
  //             children: [
  //               // 🏷️ LEFT — SHOP BRAND
  //               pw.Container(
  //                 width: 210, // 🔽 slightly smaller
  //                 child: pw.Column(
  //                   crossAxisAlignment: pw.CrossAxisAlignment.start,
  //                   children: [
  //                     pw.Text(
  //                       "طلحہ افضل",
  //                       style: pw.TextStyle(
  //                         font: urduFont,
  //                         fontSize: 26, // ⬇️ was 30
  //                         fontWeight: pw.FontWeight.bold,
  //                         letterSpacing: 0.6,
  //                       ),
  //                     ),
  //                     pw.SizedBox(height: 2), // ⬇️ tighter
  //                     pw.Text(
  //                       "رضائی، کمبل، بیڈ شیٹ اسٹور",
  //                       style: pw.TextStyle(
  //                         font: urduFont,
  //                         fontSize: 13, // ⬇️ was 15
  //                         fontWeight: pw.FontWeight.bold,
  //                       ),
  //                     ),
  //                   ],
  //                 ),
  //               ),
  //
  //               // 📞 RIGHT — CONTACT DETAILS
  //               pw.Container(
  //                 width: 125, // 🔽 slightly smaller
  //                 child: pw.Column(
  //                   crossAxisAlignment: pw.CrossAxisAlignment.end,
  //                   children: [
  //                     pw.Text(
  //                       "طلحہ افضل",
  //                       style: pw.TextStyle(
  //                         font: urduFont,
  //                         fontSize: 9, // ⬇️ was 10
  //                         fontWeight: pw.FontWeight.bold,
  //                       ),
  //                     ),
  //                     pw.Text(
  //                       "0303-6339313",
  //                       style: pw.TextStyle(
  //                         font: urduFont,
  //                         fontSize: 9,
  //                         fontWeight: pw.FontWeight.bold,
  //                       ),
  //                     ),
  //                     pw.Text(
  //                       "0300-0359074",
  //                       style: pw.TextStyle(
  //                         font: urduFont,
  //                         fontSize: 9,
  //                         fontWeight: pw.FontWeight.bold,
  //                       ),
  //                     ),
  //
  //                     pw.SizedBox(height: 4), // ⬇️ was 6
  //
  //                     pw.Text(
  //                       "وقاص افضل",
  //                       style: pw.TextStyle(
  //                         font: urduFont,
  //                         fontSize: 9,
  //                         fontWeight: pw.FontWeight.bold,
  //                       ),
  //                     ),
  //                     pw.Text(
  //                       "0300-6766691",
  //                       style: pw.TextStyle(
  //                         font: urduFont,
  //                         fontSize: 9,
  //                         fontWeight: pw.FontWeight.bold,
  //                       ),
  //                     ),
  //
  //                     pw.SizedBox(height: 4),
  //
  //                     pw.Text(
  //                       "عباس افضل",
  //                       style: pw.TextStyle(
  //                         font: urduFont,
  //                         fontSize: 9,
  //                         fontWeight: pw.FontWeight.bold,
  //                       ),
  //                     ),
  //                     pw.Text(
  //                       "0303-2312531",
  //                       style: pw.TextStyle(
  //                         font: urduFont,
  //                         fontSize: 9,
  //                         fontWeight: pw.FontWeight.bold,
  //                       ),
  //                     ),
  //                   ],
  //                 ),
  //               ),
  //             ],
  //           ),
  //
  //           pw.SizedBox(height: 4), // ⬇️ was 6
  //           pw.Divider(),
  //
  //           // 📍 Address
  //           pw.Text(
  //             "دکان نمبر 49، 48 ہول سیل کلاتھ مارکیٹ نزد سلطان مارکیٹ چونگی نمبر 11، مخدوم رشید روڈ، ملتان",
  //             textAlign: pw.TextAlign.center,
  //             style: pw.TextStyle(
  //               font: urduFont,
  //               fontSize: 8.5, // ⬇️ was 9
  //               fontWeight: pw.FontWeight.bold,
  //             ),
  //           ),
  //         ],
  //       ),
  //     );
  //   }
  //
  //   /// ================= PDF =================
  //   final pdf = pw.Document();
  //
  //   pdf.addPage(
  //     pw.MultiPage(
  //       pageFormat: PdfPageFormat.a5,
  //       margin: const pw.EdgeInsets.only(left: 14, right: 14, top: 10, bottom: 10),
  //       textDirection: pw.TextDirection.rtl,
  //
  //       header: (context) => pw.Column(
  //         children: [
  //           buildHeader(),
  //
  //           // ✅ THIS CREATES SPACE AFTER HEADER (ALL PAGES)
  //           pw.SizedBox(height: 12),
  //         ],
  //       ),
  //
  //
  //       build: (context) => [
  //         pw.SizedBox(height: 6),
  //
  //         /// ================= TITLE =================
  //         pw.Text("سیلز بل", textAlign: pw.TextAlign.center, style: title),
  //
  //         pw.Divider(),
  //
  //         /// ================= META =================
  //         pw.Text("بل نمبر: ${invoiceData['invoiceNumber']}", style: normal),
  //         pw.Text("تاریخ: ${invoiceData['date']}", style: normal),
  //         pw.Text("وقت: ${invoiceData['time']}", style: normal),
  //
  //         pw.Divider(height: 10),
  //
  //         /// ================= CUSTOMER =================
  //         pw.Text("گاہک کی تفصیل", style: bold),
  //         pw.SizedBox(height: 4),
  //
  //         pw.Text("نام: $customerName", style: normal),
  //         if (customerPhone.isNotEmpty)
  //           pw.Text("فون: $customerPhone", style: normal),
  //         if (customerAddress.isNotEmpty)
  //           pw.Text("پتہ: $customerAddress", style: normal),
  //
  //         pw.Divider(height: 12),
  //
  //         /// ================= ITEMS TABLE =================
  //         pw.Table(
  //           border: pw.TableBorder.all(width: 0.5),
  //           columnWidths: const {
  //             0: pw.FlexColumnWidth(3),
  //             1: pw.FlexColumnWidth(1),
  //             2: pw.FlexColumnWidth(1),
  //             3: pw.FlexColumnWidth(1.5),
  //           },
  //           children: [
  //             pw.TableRow(
  //               decoration: const pw.BoxDecoration(color: PdfColors.grey200),
  //               children: [
  //                 _cellUrdu("کل", urduFont, bold: true),
  //                 _cellUrdu("ریٹ", urduFont, bold: true),
  //                 _cellUrdu("مقدار", urduFont, bold: true),
  //                 _cellUrdu("آئٹم", urduFont, bold: true),
  //
  //
  //
  //               ],
  //             ),
  //             ...(invoiceData['items'] as List).map<pw.TableRow>((item) {
  //               return pw.TableRow(
  //                 children: [
  //                   _cellUrdu(item['amount'].toString(), urduFont),
  //                   _cellUrdu(item['rate'].toString(), urduFont),
  //                   _cellUrdu(item['qty'].toString(), urduFont),
  //                   _cellUrdu(item['name'], urduFont),
  //                 ],
  //               );
  //             }).toList(),
  //           ],
  //         ),
  //
  //         pw.SizedBox(height: 10),
  //
  //         /// ================= TOTAL =================
  //         pw.Container(
  //           padding: const pw.EdgeInsets.all(6),
  //           decoration: pw.BoxDecoration(border: pw.Border.all()),
  //           child: pw.Column(
  //             crossAxisAlignment: pw.CrossAxisAlignment.end,
  //             children: [
  //               pw.Text(
  //                 "کل رقم: ${invoiceData['totalAmount']} روپے",
  //                 style: pw.TextStyle(
  //                   font: urduFont,
  //                   fontSize: 14,
  //                   fontWeight: pw.FontWeight.bold,
  //                 ),
  //               ),
  //               pw.Text("ادا شدہ: ${invoiceData['amountPaid']}", style: normal),
  //               pw.Text("بقایا: ${invoiceData['amountDue']}", style: normal),
  //               pw.Text("بل: ${invoiceData['paymentStatus']}", style: normal),
  //             ],
  //           ),
  //         ),
  //
  //         pw.SizedBox(height: 12),
  //
  //         /// ================= FOOTER =================
  //         pw.Text(
  //           "یہ کمپیوٹر سے تیار کردہ سیلز بل ہے",
  //           textAlign: pw.TextAlign.center,
  //           style: pw.TextStyle(font: urduFont, fontSize: 8),
  //         ),
  //       ],
  //     ),
  //   );
  //
  //   await Printing.layoutPdf(
  //     onLayout: (PdfPageFormat format) async => pdf.save(),
  //   );
  // }

  /// ================= CELL HELPER =================
  // pw.Widget _cellUrdu(
  //     String text,
  //     pw.Font font, {
  //       bool bold = false,
  //     }) {
  //   return pw.Padding(
  //     padding: const pw.EdgeInsets.all(4),
  //     child: pw.Text(
  //       text,
  //       style: pw.TextStyle(
  //         font: font,
  //         fontSize: 9,
  //         fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
  //       ),
  //     ),
  //   );
  // }

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
            DropdownMenuItem(value: 'نہیں بھارہ', child: Text('نہیں بھارہ')),
            DropdownMenuItem(value: 'کچھ بھارہ', child: Text('کچھ بھارہ')),
            DropdownMenuItem(value: 'پورہ بھارہ', child: Text('پورہ بھارہ')),
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
