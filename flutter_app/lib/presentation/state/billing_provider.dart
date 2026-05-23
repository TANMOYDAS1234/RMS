import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/dio_client.dart';
import '../state/auth_provider.dart';

class BillModel {
  final String id;
  final String orderId;
  final String tableLabel;
  final double subtotal;
  final double discountAmount;
  final double gstAmount;
  final double total;
  final bool isPaid;
  final String? paymentMethod;
  final DateTime? paidAt;

  const BillModel({
    required this.id,
    required this.orderId,
    required this.tableLabel,
    required this.subtotal,
    required this.discountAmount,
    required this.gstAmount,
    required this.total,
    required this.isPaid,
    this.paymentMethod,
    this.paidAt,
  });

  factory BillModel.fromJson(Map<String, dynamic> j) => BillModel(
        id: j['_id'] ?? j['id'] ?? '',
        orderId: j['orderId']?.toString() ?? '',
        tableLabel: j['tableLabel'] ?? '',
        subtotal: (j['subtotal'] ?? 0).toDouble(),
        discountAmount: (j['discountAmount'] ?? 0).toDouble(),
        gstAmount: (j['gstAmount'] ?? 0).toDouble(),
        total: (j['total'] ?? 0).toDouble(),
        isPaid: j['isPaid'] ?? false,
        paymentMethod: j['paymentMethod'],
        paidAt: j['paidAt'] != null ? DateTime.parse(j['paidAt']) : null,
      );
}

final billingProvider = FutureProvider.autoDispose<List<BillModel>>((ref) async {
  final token = ref.watch(authProvider).token;
  if (token == null) throw Exception('Not authenticated');
  final dio = createDioClient(token);
  final res = await dio.get('/billing');
  return (res.data as List).map((j) => BillModel.fromJson(j)).toList();
});

final dailyRevenueProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final token = ref.watch(authProvider).token;
  if (token == null) throw Exception('Not authenticated');
  final dio = createDioClient(token);
  final res = await dio.get('/billing/revenue/daily');
  return Map<String, dynamic>.from(res.data);
});
