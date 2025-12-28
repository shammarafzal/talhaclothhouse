import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AllSuppliersBalanceScreen extends StatefulWidget {
  const AllSuppliersBalanceScreen({super.key});

  @override
  State<AllSuppliersBalanceScreen> createState() =>
      _AllSuppliersBalanceScreenState();
}

class _AllSuppliersBalanceScreenState
    extends State<AllSuppliersBalanceScreen> {
  bool loading = true;
  String? error;
  List<_SupplierBalance> suppliers = [];
  double totalRemainingAll = 0;

  @override
  void initState() {
    super.initState();
    _loadSuppliersWithBalance();
  }

  Future<void> _loadSuppliersWithBalance() async {
    try {
      final fs = FirebaseFirestore.instance;

      final supplierSnap =
      await fs.collection('suppliers').orderBy('name').get();

      final List<_SupplierBalance> list = [];
      double grandTotal = 0;

      for (final sDoc in supplierSnap.docs) {
        final sData = sDoc.data();
        final name = (sData['name'] ?? '').toString();

        final purchasesSnap = await fs
            .collection('suppliers')
            .doc(sDoc.id)
            .collection('purchases')
            .get();

        double remainingForSupplier = 0;

        for (final pDoc in purchasesSnap.docs) {
          final inv = pDoc.data();
          final total = (inv['totalAmount'] ?? 0).toDouble();
          final paid = (inv['amountPaid'] ?? 0).toDouble();
          remainingForSupplier += (total - paid);
        }

        if (remainingForSupplier < 0) remainingForSupplier = 0;

        grandTotal += remainingForSupplier;

        list.add(
          _SupplierBalance(
            supplierId: sDoc.id,
            name: name,
            remaining: remainingForSupplier,
          ),
        );
      }

      if (!mounted) return;
      setState(() {
        suppliers = list;
        totalRemainingAll = grandTotal;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality( // ✅ RTL applied here
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("کل باقی (تمام لوم والے)"),
          centerTitle: true,
        ),
        body: Container(
          color: Colors.grey.shade100,
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : error != null
              ? Center(
            child: Text(
              "خرابی: $error",
              textAlign: TextAlign.center,
            ),
          )
              : suppliers.isEmpty
              ? const Center(
            child: Text(
              "کوئی لوم والا موجود نہیں",
              style: TextStyle(fontSize: 16),
            ),
          )
              : Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: suppliers.length,
                  itemBuilder: (context, index) {
                    final s = suppliers[index];
                    final sr = "SUP-${index + 1}";
                    return _SupplierBalanceCard(
                      srNo: sr,
                      supplier: s,
                    );
                  },
                ),
              ),

              // 🔻 Footer Total
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 6,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Text(
                      "کل باقی (تمام لوم والے):",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      totalRemainingAll.toStringAsFixed(2),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SupplierBalance {
  final String supplierId;
  final String name;
  final double remaining;

  _SupplierBalance({
    required this.supplierId,
    required this.name,
    required this.remaining,
  });
}

class _SupplierBalanceCard extends StatelessWidget {
  final String srNo;
  final _SupplierBalance supplier;

  const _SupplierBalanceCard({
    required this.srNo,
    required this.supplier,
  });

  @override
  Widget build(BuildContext context) {
    final rem = supplier.remaining;
    final remColor = rem > 0 ? Colors.red : Colors.green;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: Colors.deepPurple.shade50,
              child: Text(
                srNo.split('-').last,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple.shade700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, // RTL auto handles
                children: [
                  Text(
                    supplier.name.isEmpty
                        ? "بے نام لوم والا"
                        : supplier.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "کل باقی: ${rem.toStringAsFixed(2)}",
                    style: TextStyle(
                      color: remColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
