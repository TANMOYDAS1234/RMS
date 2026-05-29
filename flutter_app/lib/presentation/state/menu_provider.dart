import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/dio_client.dart';
import '../state/auth_provider.dart';

class MenuItemModel {
  final String id;
  final String name;
  final String category;
  final double basePrice;
  final bool isAvailable;
  final String? description;
  final int prepTimeMinutes;

  const MenuItemModel({
    required this.id,
    required this.name,
    required this.category,
    required this.basePrice,
    required this.isAvailable,
    this.description,
    this.prepTimeMinutes = 0,
  });

  factory MenuItemModel.fromJson(Map<String, dynamic> j) => MenuItemModel(
        id: j['_id'] ?? j['id'] ?? '',
        name: j['name'] ?? '',
        category: j['category'] ?? '',
        basePrice: (j['basePrice'] ?? 0).toDouble(),
        isAvailable: j['isAvailable'] ?? true,
        description: j['description'],
        prepTimeMinutes: j['prepTimeMinutes'] ?? 0,
      );
}

final menuProvider = FutureProvider.autoDispose.family<List<MenuItemModel>, String?>((ref, branchId) async {
  final token = ref.watch(authProvider).token;
  final dio = createDioClient(token);
  final path = (branchId != null && branchId.isNotEmpty)
      ? '/menu/branch/$branchId'
      : '/menu';
  final res = await dio.get(path);
  return (res.data as List).map((j) => MenuItemModel.fromJson(j)).toList();
});
