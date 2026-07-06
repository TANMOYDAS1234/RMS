import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/dio_client.dart';
import '../state/auth_provider.dart';

/// One sizing/portion option for a menu item — e.g. "Regular" / "Large".
/// Pricing is absolute: picking the variant replaces basePrice.
class MenuVariant {
  final String name;
  final double price;
  const MenuVariant({required this.name, required this.price});
  factory MenuVariant.fromJson(Map<String, dynamic> j) =>
      MenuVariant(name: j['name'] ?? '', price: (j['price'] ?? 0).toDouble());
}

/// Add-on modifier — extra cheese, no onion, etc. extraPrice is added on
/// top of the base/variant price. May also carry its own 3D model
/// (`glbUrl` + `usdzUrl`) so the AR preview swaps when a customer
/// toggles it. Falls back to the item's base model when null.
class MenuModifier {
  final String name;
  final double extraPrice;
  final String? glbUrl;
  final String? usdzUrl;
  const MenuModifier({
    required this.name,
    required this.extraPrice,
    this.glbUrl,
    this.usdzUrl,
  });
  factory MenuModifier.fromJson(Map<String, dynamic> j) => MenuModifier(
        name: j['name'] ?? '',
        extraPrice: (j['extraPrice'] ?? 0).toDouble(),
        glbUrl: j['glbUrl'] as String?,
        usdzUrl: j['usdzUrl'] as String?,
      );
}

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
  final List<MenuVariant> variants;
  final List<MenuModifier> modifiers;
  /// Mongoose `timestamps: true` on the menu item — bumps every time the
  /// admin re-uploads the photo. Used as the cache-buster (`?v=<ms>`)
  /// so a new upload replaces the cached body instead of getting served
  /// the stale one.
  final DateTime? updatedAt;

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
    this.variants = const [],
    this.modifiers = const [],
    this.updatedAt,
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
        variants: (j['variants'] as List? ?? [])
            .map((v) => MenuVariant.fromJson(Map<String, dynamic>.from(v)))
            .toList(),
        modifiers: (j['modifiers'] as List? ?? [])
            .map((m) => MenuModifier.fromJson(Map<String, dynamic>.from(m)))
            .toList(),
        updatedAt: j['updatedAt'] != null
            ? DateTime.tryParse(j['updatedAt'].toString())
            : null,
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
