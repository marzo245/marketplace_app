class ProductListing {
  final String id;
  final String title;
  final String description;
  final double price;
  final String category;
  final String sellerId;
  final String? sellerName;
  final double? sellerRating;
  final List<String> photos;
  final Model3D? model3d;
  final DateTime createdAt;

  ProductListing({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.category,
    required this.sellerId,
    this.sellerName,
    this.sellerRating,
    required this.photos,
    this.model3d,
    required this.createdAt,
  });

  bool get hasAr => model3d?.isReady ?? false;

  String get firstPhoto => photos.isNotEmpty ? photos.first : '';

  factory ProductListing.fromFirestore(String id, Map<String, dynamic> data) {
    final model3dData = data['model3d'] as Map<String, dynamic>?;

    return ProductListing(
      id: id,
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      price: (data['price'] as num?)?.toDouble() ?? 0,
      category: data['category'] as String? ?? 'otros',
      sellerId: data['sellerId'] as String? ?? '',
      sellerName: data['sellerName'] as String?,
      sellerRating: (data['sellerRating'] as num?)?.toDouble(),
      photos: (data['photos'] as List?)?.cast<String>() ?? [],
      model3d: model3dData != null ? Model3D.fromMap(model3dData) : null,
      createdAt: _parseTimestamp(data['createdAt']),
    );
  }

  static DateTime _parseTimestamp(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    try {
      return (value as dynamic).toDate();
    } catch (_) {
      return DateTime.now();
    }
  }
}

class Model3D {
  final String status;
  final String? glbUrl;
  final String? usdzUrl;
  final String? thumbnailUrl;

  Model3D({
    required this.status,
    this.glbUrl,
    this.usdzUrl,
    this.thumbnailUrl,
  });

  bool get isReady => status == 'ready' && glbUrl != null;

  factory Model3D.fromMap(Map<String, dynamic> map) {
    return Model3D(
      status: map['status'] as String? ?? 'unknown',
      glbUrl: map['glbUrl'] as String?,
      usdzUrl: map['usdzUrl'] as String?,
      thumbnailUrl: map['thumbnailUrl'] as String?,
    );
  }
}
