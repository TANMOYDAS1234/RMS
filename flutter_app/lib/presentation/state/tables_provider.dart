import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/dio_client.dart';
import '../state/auth_provider.dart';

class TableModel {
  final String id;
  final String label;
  final int capacity;
  final String status;
  final String? activeOrderId;

  const TableModel({
    required this.id,
    required this.label,
    required this.capacity,
    required this.status,
    this.activeOrderId,
  });

  factory TableModel.fromJson(Map<String, dynamic> j) => TableModel(
        id: j['_id'] ?? j['id'] ?? '',
        label: j['label'] ?? '',
        capacity: j['capacity'] ?? 2,
        status: j['status'] ?? 'available',
        activeOrderId: j['activeOrderId'],
      );

  bool get isAvailable => status == 'available';
}

final tablesProvider = FutureProvider.autoDispose<List<TableModel>>((ref) async {
  final token = ref.watch(authProvider).token;
  if (token == null) throw Exception('Not authenticated');
  final dio = createDioClient(token);
  final res = await dio.get('/tables');
  return (res.data as List).map((j) => TableModel.fromJson(j)).toList();
});
