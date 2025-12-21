import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'add_customer_screen.dart';
import 'customer_detail_screen.dart';

class CustomerListScreen extends StatefulWidget {
  const CustomerListScreen({super.key});

  @override
  State<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends State<CustomerListScreen> {
  final TextEditingController searchCtrl = TextEditingController();

  String selectedCity = 'All';

  /// 🔹 Load remaining amount (unchanged logic)
  Future<double> _loadCustomerRemaining(String customerId) async {
    final snap = await FirebaseFirestore.instance
        .collection('customers')
        .doc(customerId)
        .collection('sales')
        .get();

    double remaining = 0;
    for (final d in snap.docs) {
      final data = d.data();
      final total = (data['totalAmount'] ?? 0).toDouble();
      final paid = (data['amountPaid'] ?? 0).toDouble();
      remaining += (total - paid);
    }
    if (remaining < 0) remaining = 0;
    return remaining;
  }
  Future<pw.Widget> buildUrduHeader() async {
    final fontData =
    await rootBundle.load('assets/fonts/NotoSansArabic-Regular.ttf');
    final urduFont = pw.Font.ttf(fontData);

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(width: 1), // black border
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [

              // 🏷️ LEFT SIDE — SHOP BRAND (BIG & BOLD)
              pw.Container(
                width: 220,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      "طلحہ افضل",
                      style: pw.TextStyle(
                        font: urduFont,
                        fontSize: 30, // 🔥 BIG BRAND
                        fontWeight: pw.FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      "رضائی، کمبل، بیڈ شیٹ اسٹور",
                      style: pw.TextStyle(
                        font: urduFont,
                        fontSize: 15,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              // 📞 RIGHT SIDE — CONTACT DETAILS
              pw.Container(
                width: 130,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      "طلحہ افضل",
                      style: pw.TextStyle(
                        font: urduFont,
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      "0303-6339313",
                      style: pw.TextStyle(
                        font: urduFont,
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),

                    pw.SizedBox(height: 6),

                    pw.Text(
                      "وقاص افضل",
                      style: pw.TextStyle(
                        font: urduFont,
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      "0300-0359074",
                      style: pw.TextStyle(
                        font: urduFont,
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),

                    pw.SizedBox(height: 6),

                    pw.Text(
                      "عباس افضل",
                      style: pw.TextStyle(
                        font: urduFont,
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      "0303-2312531",
                      style: pw.TextStyle(
                        font: urduFont,
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),




          pw.SizedBox(height: 6),
          pw.Divider(),

          // 📍 Address
          pw.Text(
            "دکان نمبر 49، 48 ہول سیل کلاتھ مارکیٹ نزد سلطان مارکیٹ چونگی نمبر 11، مخدوم رشید روڈ، ملتان",
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
              font: urduFont,
              fontSize: 9,
              fontWeight: pw.FontWeight.bold
            ),
          ),
        ],
      ),
    );
  }


  /// 🔹 Print filtered customers
  Future<void> _printCustomers(List<QueryDocumentSnapshot> customers) async {
    final pdf = pw.Document();

    // 🔤 Load Urdu Font
    final fontData =
    await rootBundle.load('assets/fonts/NotoSansArabic-Regular.ttf');
    final urduFont = pw.Font.ttf(fontData);

    // 🧾 Build Header FIRST (async)
    final headerWidget = await buildUrduHeader();

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
                // ✅ HEADER
                headerWidget,

                pw.SizedBox(height: 10),

                // 🧾 TITLE
                pw.Text(
                  'گاہکوں کی فہرست',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    font: urduFont,
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),

                pw.SizedBox(height: 6),

                // 🏙️ CITY
                pw.Text(
                  'شہر: $selectedCity',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(font: urduFont, fontSize: 11),
                ),

                pw.SizedBox(height: 10),


                // 📋 TABLE
                pw.Table.fromTextArray(
                  headerAlignment: pw.Alignment.centerRight,
                  cellAlignment: pw.Alignment.centerRight,
                  headerStyle: pw.TextStyle(
                    font: urduFont,
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 10,
                  ),
                  cellStyle: pw.TextStyle(
                    font: urduFont,
                    fontSize: 9,
                  ),
                  headers: ['پتہ','فون نمبر', 'نام'],
                  data: customers.map((doc) {
                    final d = doc.data() as Map<String, dynamic>;
                    return [
                      d['address'] ?? '',
                      d['phone'] ?? '',
                      d['name'] ?? '',
                    ];
                  }).toList(),
                ),

                pw.SizedBox(height: 12),


                // 🕒 FOOTER DATE
                pw.Text(
                  'پرنٹ کی تاریخ: ${DateFormat('dd/MM/yyyy hh:mm a').format(DateTime.now())}',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(font: urduFont, fontSize: 9),
                ),

                pw.SizedBox(height: 6),

                // 🖥️ SYSTEM NOTE
                pw.Text(
                  'یہ فہرست کمپیوٹر سے تیار کی گئی ہے',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(font: urduFont, fontSize: 8),
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


  @override
  void dispose() {
    searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("گاہک"),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            tooltip: "نیا گاہک",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AddCustomerScreen(),
                ),
              );
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(110),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Column(
              children: [
                // 🔍 SEARCH
                TextField(
                  controller: searchCtrl,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: "گاہک کا نام تلاش کریں",
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // 🏙️ CITY FILTER + PRINT
                Row(
                  children: [
                    Expanded(
                      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: FirebaseFirestore.instance
                            .collection("customers")
                            .snapshots(),
                        builder: (context, snap) {
                          if (!snap.hasData) {
                            return const SizedBox();
                          }

                          // collect unique cities
                          final cities = <String>{};
                          for (final d in snap.data!.docs) {
                            final data = d.data();
                            final city = (data['city'] ??
                                data['address'] ??
                                '')
                                .toString()
                                .trim();
                            if (city.isNotEmpty) cities.add(city);
                          }

                          final cityList = ['All', ...cities.toList()];

                          return DropdownButtonFormField<String>(
                            value: selectedCity,
                            items: cityList
                                .map(
                                  (c) => DropdownMenuItem(
                                value: c,
                                child: Text(c),
                              ),
                            )
                                .toList(),
                            onChanged: (v) {
                              if (v == null) return;
                              setState(() => selectedCity = v);
                            },
                            decoration: const InputDecoration(
                              labelText: 'شہر کے مطابق فلٹر',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: "منتخب گاہک پرنٹ کریں",
                      icon: const Icon(Icons.print),
                      onPressed: () async {
                        final snap = await FirebaseFirestore.instance
                            .collection("customers")
                            .get();

                        final filtered = snap.docs.where((d) {
                          final data = d.data();
                          final name =
                          (data['name'] ?? '').toString().toLowerCase();
                          final city =
                          (data['city'] ?? data['address'] ?? '')
                              .toString();

                          if (searchCtrl.text.isNotEmpty &&
                              !name.contains(
                                  searchCtrl.text.toLowerCase())) {
                            return false;
                          }

                          if (selectedCity != 'All' &&
                              city != selectedCity) {
                            return false;
                          }

                          return true;
                        }).toList();

                        if (filtered.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("کوئی گاہک موجود نہیں"),
                            ),
                          );
                          return;
                        }

                        await _printCustomers(filtered);
                      },
                    )
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      body: Container(
        color: Colors.grey.shade100,
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection("customers")
              .orderBy("name")
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = snapshot.data!.docs;

            final query = searchCtrl.text.toLowerCase();

            final filtered = docs.where((d) {
              final data = d.data();
              final name =
              (data['name'] ?? '').toString().toLowerCase();
              final city =
              (data['city'] ?? data['address'] ?? '').toString();

              if (query.isNotEmpty && !name.contains(query)) {
                return false;
              }
              if (selectedCity != 'All' && city != selectedCity) {
                return false;
              }
              return true;
            }).toList();

            if (filtered.isEmpty) {
              return const Center(child: Text("کوئی گاہک موجود نہیں"));
            }

            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: filtered.length,
              itemBuilder: (contextList, index) {
                final doc = filtered[index];
                final data = doc.data();
                final name = (data['name'] ?? '').toString();
                final phone = (data['phone'] ?? '').toString();
                final address = (data['address'] ?? '').toString();

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Text(
                        name.isEmpty ? "C" : name[0].toUpperCase(),
                      ),
                    ),
                    title: Text(name.isEmpty ? "بے نام گاہک" : name),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (phone.isNotEmpty) Text(phone),
                        if (address.isNotEmpty)
                          Text(
                            address,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                    trailing: FutureBuilder<double>(
                      future: _loadCustomerRemaining(doc.id),
                      builder: (ctx, snapRem) {
                        if (!snapRem.hasData) {
                          return const SizedBox(
                            width: 60,
                            height: 12,
                            child: LinearProgressIndicator(),
                          );
                        }
                        final rem = snapRem.data!;
                        final color =
                        rem > 0 ? Colors.red : Colors.green;
                        return Text(
                          rem.toStringAsFixed(0),
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: color,
                          ),
                        );
                      },
                    ),
                    onTap: () {
                      Navigator.push(
                        contextList,
                        MaterialPageRoute(
                          builder: (_) => CustomerDetailScreen(
                            customerId: doc.id,
                            customerData: data,
                          ),
                        ),
                      );
                    },
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
