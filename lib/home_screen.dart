import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:talhaclothhouse/products/all_products_screen.dart';
import 'customers/customer_list_screen.dart';
import 'suppliers/supplier_list_screen.dart';
import 'suppliers/all_suppliers_balance_screen.dart';
import 'suppliers/pay_slips_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  bool isMobile(BuildContext context) =>
      ResponsiveBreakpoints.of(context).smallerThan(TABLET);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: isMobile(context) ? const Drawer(child: Sidebar()) : null,
      body: SafeArea(
        child: Row(
          children: [
            // Sidebar (Desktop / Tablet only)
            if (!isMobile(context)) const Sidebar(),

            // Main body
            Expanded(
              child: Column(
                children: [
                  TopBar(isMobile: isMobile(context)),
                  const Expanded(child: DashboardContent()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------
// SIDEBAR
// ---------------------------------------------------------
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
              "Talha Afzal Cloth House",
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          // For now sidebar items are static; you can wire navigation later
          menuItem(Icons.people, "Customers", () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CustomerListScreen()),
            );
          }),
          menuItem(Icons.store, "Suppliers", () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SupplierListScreen()),
            );
          }),
          menuItem(Icons.shopping_cart, "Sales", () {}),
          menuItem(Icons.inventory, "Inventory", () {}),
          menuItem(Icons.production_quantity_limits, "Purchases", () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const AllProductsScreen(),
              ),
            );
          }),
          menuItem(Icons.shopping_bag, "Purchases", () {}),
          menuItem(Icons.payments, "All Suppliers Payments", () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const AllSuppliersBalanceScreen(),
              ),
            );
          }),
          menuItem(Icons.settings, "Settings", () {}),
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

// ---------------------------------------------------------
// TOP BAR
// ---------------------------------------------------------
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
            "Dashboard",
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),

          const Spacer(),
          const CircleAvatar(child: Icon(Icons.person)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------
// DASHBOARD CONTENT
// ---------------------------------------------------------
class DashboardContent extends StatelessWidget {
  const DashboardContent({super.key});

  @override
  Widget build(BuildContext context) {
    int columns = 1;

    if (ResponsiveBreakpoints.of(context).between(TABLET, DESKTOP)) {
      columns = 2;
    } else if (ResponsiveBreakpoints.of(context).isDesktop) {
      columns = 4;
    }

    // 🔹 Added "All Suppliers Payments" card
    final data = [
      ["Customers", Icons.people],
      ["Suppliers", Icons.store],
      ["Sales", Icons.shopping_cart],
      ["Inventory", Icons.inventory],
      ["All Suppliers Payments", Icons.payments],
      ["Pay Slips", Icons.receipt_long],
    ];

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 3, // smaller cards
      ),
      itemCount: data.length,
      itemBuilder: (_, index) {
        return DashboardCard(
          title: data[index][0] as String,
          icon: data[index][1] as IconData,
            onTap: () {
              switch (data[index][0]) {
                case 'Suppliers':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SupplierListScreen(),
                    ),
                  );
                  break;
                case 'All Suppliers Payments':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AllSuppliersBalanceScreen(),
                    ),
                  );
                  break;
                case 'Pay Slips':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PaySlipsScreen(),
                    ),
                  );
                  break;
                default:
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${data[index][0]} screen coming soon!'),
                    ),
                  );
              }
            }
        );
      },
    );
  }
}

// ---------------------------------------------------------
// CARD
// ---------------------------------------------------------
class DashboardCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback? onTap;

  const DashboardCard({
    super.key,
    required this.title,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 30),
              const SizedBox(height: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
