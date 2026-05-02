import 'dart:io';

enum ProductCategory {
  muebles('Muebles', 'muebles'),
  decoracion('Decoración', 'decoracion'),
  electrodomesticos('Electrodomésticos', 'electro'),
  iluminacion('Iluminación', 'iluminacion'),
  otros('Otros', 'otros');

  final String label;
  final String slug;
  const ProductCategory(this.label, this.slug);
}

class ProductDraft {
  String title;
  String description;
  double? price;
  ProductCategory category;
  final List<File> photos;

  ProductDraft({
    this.title = '',
    this.description = '',
    this.price,
    this.category = ProductCategory.muebles,
    List<File>? photos,
  }) : photos = photos ?? [];

  bool get isValid =>
      title.trim().length >= 3 &&
      price != null &&
      price! > 0 &&
      photos.length >= 2 &&
      photos.length <= 4;

  String? get validationError {
    if (title.trim().length < 3) return 'El título necesita al menos 3 caracteres';
    if (price == null || price! <= 0) return 'Ingresa un precio válido';
    if (photos.length < 2) return 'Sube al menos 2 fotos desde ángulos distintos';
    if (photos.length > 4) return 'Máximo 4 fotos por producto';
    return null;
  }
}

enum Model3DStatus {
  queued,
  processing,
  ready,
  failed,
  unknown;

  static Model3DStatus fromString(String? s) {
    return switch (s) {
      'queued' => queued,
      'processing' => processing,
      'ready' => ready,
      'failed' => failed,
      _ => unknown,
    };
  }

  String get displayText => switch (this) {
    queued => 'En cola...',
    processing => 'Generando modelo 3D',
    ready => 'Modelo listo',
    failed => 'Error al generar',
    unknown => 'Estado desconocido',
  };
}

class ProductStatus {
  final String productId;
  final Model3DStatus status;
  final int progress;
  final String? glbUrl;
  final String? usdzUrl;
  final String? error;

  ProductStatus({
    required this.productId,
    required this.status,
    this.progress = 0,
    this.glbUrl,
    this.usdzUrl,
    this.error,
  });

  factory ProductStatus.fromJson(Map<String, dynamic> json) {
    return ProductStatus(
      productId: json['productId'] as String,
      status: Model3DStatus.fromString(json['status'] as String?),
      progress: (json['progress'] as num?)?.toInt() ?? 0,
      glbUrl: json['glbUrl'] as String?,
      usdzUrl: json['usdzUrl'] as String?,
      error: json['error'] as String?,
    );
  }
}

class UploadResult {
  final String productId;
  final String jobId;
  final int estimatedMinutes;

  UploadResult({
    required this.productId,
    required this.jobId,
    required this.estimatedMinutes,
  });

  factory UploadResult.fromJson(Map<String, dynamic> json) {
    return UploadResult(
      productId: json['productId'] as String,
      jobId: json['jobId'] as String,
      estimatedMinutes: (json['estimatedMinutes'] as num?)?.toInt() ?? 3,
    );
  }
}
