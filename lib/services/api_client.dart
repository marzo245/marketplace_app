import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/product.dart';

class ApiException implements Exception {
  final String code;
  final String message;
  final int? statusCode;
  ApiException(this.code, this.message, {this.statusCode});

  @override
  String toString() => 'ApiException($code): $message';
}

class ApiClient {
  late final Dio _dio;

  ApiClient() {
    String? envBaseUrl;
    String? envTimeout;
    try {
      envBaseUrl = dotenv.env['API_BASE_URL'];
      envTimeout = dotenv.env['API_TIMEOUT_SECONDS'];
    } catch (_) {
      envBaseUrl = null;
      envTimeout = null;
    }

    final baseUrl = envBaseUrl ?? 'http://10.0.2.2:3000';
    final timeout = int.tryParse(envTimeout ?? '') ?? 30;
    final defaultHeaders = <String, String>{'Accept': 'application/json'};
    if (baseUrl.contains('ngrok-free.dev') || baseUrl.contains('ngrok-free.app')) {
      defaultHeaders['ngrok-skip-browser-warning'] = '1';
    }

    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: Duration(seconds: timeout),
      receiveTimeout: Duration(seconds: timeout),
      sendTimeout: const Duration(minutes: 3),
      headers: defaultHeaders,
    ));

    _dio.interceptors.add(LogInterceptor(
      requestBody: false,
      responseBody: true,
      logPrint: (o) => print('[API] $o'),
    ));
  }

  void setAuthToken(String? token) {
    if (token == null) {
      _dio.options.headers.remove('Authorization');
    } else {
      _dio.options.headers['Authorization'] = 'Bearer $token';
    }
  }

  Future<UploadResult> createProduct({
    required ProductDraft draft,
    void Function(int sent, int total)? onProgress,
  }) async {
    try {
      final formData = FormData.fromMap({
        'title': draft.title.trim(),
        'description': draft.description.trim(),
        'price': draft.price,
        'category': draft.category.slug,
        'photos': [
          for (int i = 0; i < draft.photos.length; i++)
            await MultipartFile.fromFile(
              draft.photos[i].path,
              filename: 'photo_$i.jpg',
            ),
        ],
      });

      final response = await _dio.post(
        '/api/v1/products/create',
        data: formData,
        onSendProgress: onProgress,
      );

      return UploadResult.fromJson(response.data);
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  Future<ProductStatus> getProductStatus(String productId) async {
    try {
      final response = await _dio.get('/api/v1/products/$productId/status');
      return ProductStatus.fromJson(response.data);
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  ApiException _mapDioError(DioException e) {
    final status = e.response?.statusCode;
    final data = e.response?.data;

    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return ApiException('timeout', 'La conexión tardó demasiado');
    }

    if (e.type == DioExceptionType.connectionError) {
      return ApiException('no_connection', 'Sin conexión a internet');
    }

    if (status == 400 && data is Map && data['error'] == 'not_enough_photos') {
      return ApiException('not_enough_photos', data['message'] ?? 'Faltan fotos');
    }

    if (status == 400) {
      return ApiException('validation', 'Revisa los datos del producto', statusCode: status);
    }

    if (status == 401 || status == 403) {
      return ApiException('unauthorized', 'Debes iniciar sesión para publicar', statusCode: status);
    }

    return ApiException(
      'server_error',
      data is Map ? (data['message']?.toString() ?? 'Error del servidor') : 'Error del servidor',
      statusCode: status,
    );
  }
}
