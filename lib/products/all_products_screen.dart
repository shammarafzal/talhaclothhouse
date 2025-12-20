import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class AllProductsScreen extends StatelessWidget {
  const AllProductsScreen({super.key});

  // ---------------- SHOP DETAILS (URDU) ----------------
  static const shopNameUrdu = "طلحہ افضل کلاتھ ہاؤس";
  static const shopPhoneUrdu = "فون: 0303-6339313";
  static const shopAddressUrdu = "ناصر کلاتھ مارکیٹ، ملتان";
  static const rateListTitleUrdu = "قیمت نامہ";
  static const printedOnUrdu = "پرنٹ کی تاریخ";

  // ---------------- PRINT FUNCTION ----------------
  Future<void> _printUrduRateList(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> products,
      ) async {
    final fontData =
    await rootBundle.load('assets/fonts/NotoSansArabic-Regular.ttf');
    final urduFont = pw.Font.ttf(fontData);

    final pdf = pw.Document();

    final dateStr = DateFormat('dd MMM yyyy').format(DateTime.now());

    final titleStyle = pw.TextStyle(
      font: urduFont,
      fontSize: 20,
      fontWeight: pw.FontWeight.bold,
    );

    final headerStyle = pw.TextStyle(
      font: urduFont,
      fontSize: 11,
      fontWeight: pw.FontWeight.bold,
    );

    final itemStyle = pw.TextStyle(
      font: urduFont,
      fontSize: 11,
    );

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        margin: const pw.EdgeInsets.all(18),
        build: (context) {
          return pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Text("قیمت نامہ", style: titleStyle, textAlign: pw.TextAlign.center),
                pw.SizedBox(height: 6),
                pw.Text("طلحہ افضل کلاتھ ہاؤس", style: headerStyle, textAlign: pw.TextAlign.center),
                pw.Text("فون: 0303-6339313", style: itemStyle, textAlign: pw.TextAlign.center),
                pw.Text("ناصر کلاتھ مارکیٹ، ملتان", style: itemStyle, textAlign: pw.TextAlign.center),

                pw.SizedBox(height: 8),
                pw.Text("پرنٹ کی تاریخ: $dateStr",
                    style: pw.TextStyle(font: urduFont, fontSize: 9),
                    textAlign: pw.TextAlign.center),

                pw.Divider(),

                ...products.map((doc) {
                  final data = doc.data();
                  final name = (data['name'] ?? '').toString();
                  final rate = (data['rate'] ?? 0).toDouble();

                  return pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 4),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text("روپے ${rate.toStringAsFixed(0)}", style: itemStyle),
                        pw.Expanded(
                          child: pw.Text(
                            name,
                            style: itemStyle,
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),

                pw.Divider(),
                pw.Text(
                  "قیمتیں بغیر اطلاع کے تبدیل ہو سکتی ہیں",
                  style: pw.TextStyle(font: urduFont, fontSize: 8),
                  textAlign: pw.TextAlign.center,
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
    );
  }


  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("All Products"),
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: () async {
              final snap = await FirebaseFirestore.instance
                  .collection('products')
                  .orderBy('name')
                  .get();

              if (snap.docs.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("کوئی پراڈکٹ موجود نہیں")),
                );
                return;
              }

              await _printUrduRateList(snap.docs);
            },
          ),
        ],
      ),
      body: Container(
        color: Colors.grey.shade100,
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('products')
              .orderBy('name')
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = snapshot.data!.docs;
            if (docs.isEmpty) {
              return const Center(child: Text("No products found."));
            }

            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: docs.length,
              itemBuilder: (_, i) {
                final data = docs[i].data();
                return Card(
                  child: ListTile(
                    title: Text(data['name'] ?? ''),
                    trailing:
                    Text((data['rate'] ?? 0).toString()),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
