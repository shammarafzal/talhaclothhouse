import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:responsive_framework/responsive_framework.dart';

import 'customers/customer_list_screen.dart';
import 'inventory/inventory_view.dart';
import 'products/all_products_screen.dart';
import 'suppliers/all_suppliers_balance_screen.dart';
import 'suppliers/pay_slips_screen.dart';
import 'suppliers/supplier_list_screen.dart';
import 'customers/create_sales_invoice_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  bool isMobile(BuildContext context) =>
      ResponsiveBreakpoints.of(context).smallerThan(TABLET);

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl, // ✅ RTL ENABLED
      child: Scaffold(
        drawer: isMobile(context) ? const Drawer(child: Sidebar()) : null,
        body: SafeArea(
          child: Row(
            children: [
              if (!isMobile(context)) const Sidebar(),
              Expanded(
                child: Column(
                  children: [
                    TopBar(isMobile: isMobile(context)),
                     Expanded(child: DashboardContent()),
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

// =======================================================
// SIDEBAR
// =======================================================
class Sidebar extends StatelessWidget {
  const Sidebar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      color: Colors.blueGrey.shade900,
      child: ListView(
        children: [
          DrawerHeader(
            child: Text(
              "طلحہ افضل کلاتھ ہاؤس",
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          menuItem(Icons.people, "گاہک", () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CustomerListScreen()),
            );
          }),

          menuItem(Icons.store, "لوم والے", () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SupplierListScreen()),
            );
          }),

          menuItem(Icons.shopping_cart, "سیلز", () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const CreateCustomerInvoiceScreen(),
              ),
            );
          }),

          menuItem(Icons.inventory, "اسٹاک", () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const InventoryScreen()),
            );
          }),

          menuItem(Icons.production_quantity_limits, "پراڈکٹس", () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AllProductsScreen()),
            );
          }),

          menuItem(Icons.payments, "تمام لوم والوں کی ادائیگیاں", () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const AllSuppliersBalanceScreen(),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget menuItem(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(title, style: GoogleFonts.poppins(color: Colors.white)),
      onTap: onTap,
    );
  }
}

// =======================================================
// TOP BAR
// =======================================================
class TopBar extends StatelessWidget {
  final bool isMobile;
  const TopBar({super.key, required this.isMobile});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: Colors.white,
      child: Row(
        children: [
          if (isMobile)
            Builder(
              builder: (ctx) => IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => Scaffold.of(ctx).openDrawer(),
              ),
            ),
          Text(
            "ڈیش بورڈ",
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          // const CircleAvatar(child: Icon(Icons.person)),
        ],
      ),
    );
  }
}

// =======================================================
// DASHBOARD CONTENT (LIVE STATS)
// =======================================================
class DashboardContent extends StatefulWidget {
  @override
  State<DashboardContent> createState() => _DashboardContentState();
}

class _DashboardContentState extends State<DashboardContent> {
  late Stream<Map<String, dynamic>> _statsStream;

  @override
  void initState() {
    super.initState();
    _statsStream = _buildStatsStream();
  }

  Stream<Map<String, dynamic>> _buildStatsStream() async* {
    final fs = FirebaseFirestore.instance;

    yield* fs.collection('customers').snapshots().asyncMap((customersSnap) async {
      final suppliersSnap = await fs.collection('suppliers').get();

      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);

      int todayBills = 0;
      int todayPaySlips = 0;
      double todaySales = 0;

      // 🔥 SALES
      for (final c in customersSnap.docs) {
        final salesSnap = await fs
            .collection('customers')
            .doc(c.id)
            .collection('sales')
            .where('createdAt', isGreaterThanOrEqualTo: startOfDay)
            .get();

        for (final s in salesSnap.docs) {
          todayBills++;
          todaySales += (s['totalAmount'] ?? 0).toDouble();
        }
      }

      // 🔥 PAY SLIPS
      for (final s in suppliersSnap.docs) {
        final slipSnap = await fs
            .collection('suppliers')
            .doc(s.id)
            .collection('paySlips')
            .where('createdAt', isGreaterThanOrEqualTo: startOfDay)
            .get();

        todayPaySlips += slipSnap.docs.length;
      }

      return {
        'customers': customersSnap.docs.length,
        'suppliers': suppliersSnap.docs.length,
        'todayBills': todayBills,
        'todaySales': todaySales,
        'todayPaySlips': todayPaySlips,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    int columns = 1;
    if (ResponsiveBreakpoints.of(context).between(TABLET, DESKTOP)) {
      columns = 2;
    } else if (ResponsiveBreakpoints.of(context).isDesktop) {
      columns = 4;
    }

    return StreamBuilder<Map<String, dynamic>>(
      stream: _statsStream,
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final d = snap.data!;
        final cards = [
          ("کل گاہک", d['customers'], Icons.people),
          ("کل لوم والے", d['suppliers'], Icons.store),
          ("آج کے بل", d['todayBills'], Icons.receipt),
          ("آج کی سیلز", d['todaySales'], Icons.attach_money),
          ("آج کی پرچیاں", d['todayPaySlips'], Icons.payments),
        ];

        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 2.8,
          ),
          itemCount: cards.length,
          itemBuilder: (_, i) {
            return DashboardStatCard(
              title: cards[i].$1,
              value: cards[i].$2.toString(),
              icon: cards[i].$3,
            );
          },
        );
      },
    );
  }
}



// =======================================================
// DASHBOARD CARD
// =======================================================
class DashboardStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const DashboardStatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(icon, size: 36, color: Colors.blueGrey),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
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
