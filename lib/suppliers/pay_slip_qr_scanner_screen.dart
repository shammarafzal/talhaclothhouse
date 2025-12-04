import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'pay_slip_detail_screen.dart';

class PaySlipQrScannerScreen extends StatefulWidget {
  const PaySlipQrScannerScreen({super.key});

  @override
  State<PaySlipQrScannerScreen> createState() =>
      _PaySlipQrScannerScreenState();
}

class _PaySlipQrScannerScreenState extends State<PaySlipQrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _processing = false;
  String? _lastResultText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleBarcode(BarcodeCapture capture) async {
    if (_processing) return;

    final barcode = capture.barcodes.isNotEmpty
        ? capture.barcodes.first
        : null;
    final raw = barcode?.rawValue;

    if (raw == null || raw.isEmpty) return;

    setState(() {
      _processing = true;
      _lastResultText = null;
    });

    try {
      // Expected format: PAYSLIP|supplierId|slipId
      final parts = raw.split('|');
      if (parts.length != 3 || parts[0] != 'PAYSLIP') {
        setState(() {
          _lastResultText =
          "Invalid QR format. This is not a valid pay slip QR.";
        });
        return;
      }

      final supplierId = parts[1];
      final slipId = parts[2];

      final doc = await FirebaseFirestore.instance
          .collection("suppliers")
          .doc(supplierId)
          .collection("paySlips")
          .doc(slipId)
          .get();

      if (!doc.exists) {
        setState(() {
          _lastResultText =
          "Slip not found in database. It may be fake or deleted.";
        });
        return;
      }

      final data = doc.data()!;
      final serial = (data['serialNumber'] ?? '').toString();
      final amount = (data['amount'] ?? 0).toDouble();
      final status = (data['status'] ?? 'Unpaid').toString();
      final date = (data['date'] ?? '').toString();
      final time = (data['time'] ?? '').toString();
      final supplierName = (data['supplierName'] ?? '').toString();

      // Show result in bottom sheet
      if (!mounted) return;
      await showModalBottomSheet(
        context: context,
        isScrollControlled: false,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (ctx) {
          final isPaid = status == 'Paid';
          final statusColor = isPaid ? Colors.green : Colors.red;

          return Padding(
            padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Row(
                  children: [
                    Icon(
                      isPaid ? Icons.verified : Icons.privacy_tip,
                      color: statusColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isPaid
                          ? "Valid Slip (Paid)"
                          : "Valid Slip (Unpaid)",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    serial.isEmpty ? "Serial: (no serial)" : "Serial: $serial",
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Supplier: $supplierName",
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Amount: ${amount.toStringAsFixed(2)} PKR",
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Date: $date  •  Time: $time",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Chip(
                  label: Text(
                    status,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  backgroundColor: statusColor.withOpacity(0.1),
                  labelStyle: TextStyle(color: statusColor),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx); // close bottom sheet
                          // Allow re-scan
                        },
                        icon: const Icon(Icons.qr_code_scanner),
                        label: const Text("Scan Again"),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PaySlipDetailScreen(
                                supplierId: supplierId,
                                slipId: slipId,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.open_in_new),
                        label: const Text("Open Slip"),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _lastResultText = "Error checking slip: $e";
      });
    } finally {
      if (mounted) {
        // Let user scan again after result
        setState(() => _processing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Scan Pay Slip QR"),
        actions: [
          IconButton(
            icon: const Icon(Icons.flip_camera_android),
            onPressed: () => _controller.switchCamera(),
          ),
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => _controller.toggleTorch(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 6,
            child: Stack(
              children: [
                MobileScanner(
                  controller: _controller,
                  onDetect: _handleBarcode,
                ),
                // Overlay
                Center(
                  child: Container(
                    width: 260,
                    height: 260,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isDark ? Colors.white70 : Colors.black54,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 24,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        "Align QR code inside the box",
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Container(
              width: double.infinity,
              color: Colors.grey.shade100,
              padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Slip Verification",
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (_lastResultText == null)
                    const Text(
                      "Scan a pay slip QR to check if it is valid and whether it has been paid or not.",
                      style: TextStyle(fontSize: 12),
                    )
                  else
                    Text(
                      _lastResultText!,
                      style: const TextStyle(fontSize: 12),
                    ),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _processing
                            ? "Checking slip..."
                            : "Ready to scan",
                        style: TextStyle(
                          fontSize: 12,
                          color: _processing
                              ? Colors.orange
                              : Colors.green,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        tooltip: "Restart camera",
                        onPressed: () {
                          setState(() {
                            _processing = false;
                            _lastResultText = null;
                          });
                          _controller.start();
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
