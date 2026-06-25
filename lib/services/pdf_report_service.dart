import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:universal_html/html.dart' as html;
import 'package:intl/intl.dart';
import '../models/order_model.dart';

class PdfReportService {
  static Future<void> downloadAnalyticsReport({
    required String periodLabel,
    required double totalSalesVolume,
    required String topDomains,
    required int booksSold,
    required List<OrderModel> orders,
  }) async {
    final pdf = pw.Document();
    
    // Add page
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            _buildHeader(periodLabel),
            pw.SizedBox(height: 20),
            _buildSummary(totalSalesVolume, topDomains, booksSold),
            pw.SizedBox(height: 20),
            pw.Text('Order Details', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            _buildOrdersTable(orders),
          ];
        },
      ),
    );

    // Get bytes
    final Uint8List bytes = await pdf.save();
    
    // Download file
    final blob = html.Blob([bytes], 'application/pdf');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.document.createElement('a') as html.AnchorElement
      ..href = url
      ..style.display = 'none'
      ..download = 'Analytics_Report_${DateTime.now().millisecondsSinceEpoch}.pdf';
    
    html.document.body?.children.add(anchor);
    anchor.click();
    
    html.document.body?.children.remove(anchor);
    html.Url.revokeObjectUrl(url);
  }

  static pw.Widget _buildHeader(String periodLabel) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('UTeM Book Thrift', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
        pw.SizedBox(height: 4),
        pw.Text('Analytics Report', style: pw.TextStyle(fontSize: 18, color: PdfColors.grey700)),
        pw.SizedBox(height: 8),
        pw.Text('Period: $periodLabel', style: pw.TextStyle(fontSize: 14)),
        pw.Divider(),
      ],
    );
  }

  static pw.Widget _buildSummary(double totalSales, String topDomains, int booksSold) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: const pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          _summaryItem('Total Sales Volume', 'RM ${totalSales.toStringAsFixed(2)}'),
          _summaryItem('Top Domains', topDomains),
          _summaryItem('Books Sold', booksSold.toString()),
        ],
      ),
    );
  }

  static pw.Widget _summaryItem(String title, String value) {
    return pw.Expanded(
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title, style: pw.TextStyle(fontSize: 12, color: PdfColors.grey600)),
          pw.SizedBox(height: 4),
          pw.Text(value, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  static pw.Widget _buildOrdersTable(List<OrderModel> orders) {
    if (orders.isEmpty) {
      return pw.Text('No orders in this period.', style: pw.TextStyle(color: PdfColors.grey600));
    }

    final headers = ['Order ID', 'Date', 'Qty', 'Amount', 'Status'];
    
    final data = orders.map((o) {
      final date = DateTime.tryParse(o.orderedAt);
      final formattedDate = date != null ? DateFormat('MMM dd, yyyy').format(date) : o.orderedAt;
      final qty = o.items?.length ?? 0;
      return [
        o.orderID.toString(),
        formattedDate,
        qty.toString(),
        'RM ${o.totalPrice.toStringAsFixed(2)}',
        o.status,
      ];
    }).toList();

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: data,
      border: null,
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
      cellHeight: 30,
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.center,
        3: pw.Alignment.centerRight,
        4: pw.Alignment.centerRight,
      },
      rowDecoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
      ),
    );
  }
}
