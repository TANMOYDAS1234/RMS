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
  /// Backend sets this to `/menu/<id>/image` after the admin/manager
  /// uploads a photo. Null until that happens. Combine with
  /// `AppConfig.baseUrl` to build a full URL.
  final String? imageUrl;
  /// Same shape — `/menu/<id>/glb` when a 3D model is on file.
  final String? glbUrl;
  /// iOS-specific Quick Look variant. Apple's AR only accepts USDZ;
  /// model-viewer's `ios-src` attribute will pick this on iPhones.
  final String? usdzUrl;

  const MenuItemModel({
    required this.id,
    required this.name,
    required this.category,
    required this.basePrice,
    required this.isAvailable,
    this.description,
    this.prepTimeMinutes = 0,
    this.imageUrl,
    this.glbUrl,
    this.usdzUrl,
  });

  factory MenuItemModel.fromJson(Map<String, dynamic> j) => MenuItemModel(
        id: j['_id'] ?? j['id'] ?? '',
        name: j['name'] ?? '',
        category: j['category'] ?? '',
        basePrice: (j['basePrice'] ?? 0).toDouble(),
        isAvailable: j['isAvailable'] ?? true,
        description: j['description'],
        prepTimeMinutes: j['prepTimeMinutes'] ?? 0,
        imageUrl: j['imageUrl'] as String?,
        glbUrl: j['glbUrl'] as String?,
        usdzUrl: j['usdzUrl'] as String?,
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
