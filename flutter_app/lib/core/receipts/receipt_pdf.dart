// ─── Receipt PDF Generator ───────────────────────────────────────────────────
//
// Builds a 58mm thermal-printer-style PDF for a paid bill. Used by both
// the in-app print sheet (via the `printing` package) and the share
// intent (via `share_plus`).
//
// Width is set to 58mm so it formats well on the most common thermal
// receipt printer; on a sheet printer it just renders as a narrow strip.

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../presentation/state/billing_provider.dart';

class ReceiptPdf {
  static Future<pw.Document> build({
    required BillModel bill,
    required String branchName,
    required String? branchAddress,
    String? cashierName,
  }) async {
    final doc = pw.Document(
      author: 'DINE OPS',
      title: 'Receipt ${bill.id}',
    );
    final paidAt = bill.paidAt ?? DateTime.now();
    final formatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹', // ₹ — escaped so the source file stays ASCII-safe
      decimalDigits: 2,
    );

    doc.addPage(
      pw.Page(
        // 58mm × ~150mm receipt-style page.
        pageFormat: PdfPageFormat(
          58 * PdfPageFormat.mm,
          150 * PdfPageFormat.mm,
          marginAll: 6 * PdfPageFormat.mm,
        ),
        build: (ctx) {
          final headerStyle = pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold);
          final small = const pw.TextStyle(fontSize: 8);
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Center(child: pw.Text(branchName, style: headerStyle)),
              if (branchAddress != null && branchAddress.isNotEmpty)
                pw.Center(child: pw.Text(branchAddress, style: small, textAlign: pw.TextAlign.center)),
              pw.Center(child: pw.Text('--- RECEIPT ---', style: small)),
              pw.SizedBox(height: 6),
              _kv('Table', bill.tableLabel, small),
              _kv('Bill #', bill.id.substring(bill.id.length - 8), small),
              _kv('Paid', DateFormat('dd MMM yyyy, HH:mm').format(paidAt), small),
              if (cashierName != null) _kv('Cashier', cashierName, small),
              if (bill.paymentMethod != null)
                _kv('Method', bill.paymentMethod!.toUpperCase(), small),
              pw.Divider(thickness: 0.5, height: 8),
              _kv('Subtotal', formatter.format(bill.subtotal), small),
              if (bill.discountAmount > 0)
                _kv('Discount', '- ' + formatter.format(bill.discountAmount), small),
              _kv('GST', formatter.format(bill.gstAmount), small),
              pw.Divider(thickness: 0.5, height: 8),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TOTAL', style: headerStyle),
                  pw.Text(formatter.format(bill.total), style: headerStyle),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Center(child: pw.Text('Thank you for dining with us!', style: small)),
              pw.SizedBox(height: 4),
              pw.Center(child: pw.Text('Powered by DINE OPS', style: small.copyWith(color: PdfColors.grey))),
            ],
          );
        },
      ),
    );
    return doc;
  }

  static pw.Widget _kv(String key, String value, pw.TextStyle style) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(key, style: style),
          pw.Text(value, style: style),
        ],
      ),
    );
  }
}
