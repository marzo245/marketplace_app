import 'package:flutter_test/flutter_test.dart';
import 'package:marketplace_3d/services/api_client.dart';
import 'package:marketplace_3d/services/photo_service.dart';

void main() {
  // ---------------------------------------------------------------------------
  // ApiException
  // ---------------------------------------------------------------------------
  group('ApiException', () {
    test('toString includes code and message', () {
      final e = ApiException('test_code', 'Test message');
      expect(e.toString(), 'ApiException(test_code): Test message');
    });

    test('statusCode is null by default', () {
      final e = ApiException('code', 'message');
      expect(e.statusCode, isNull);
    });

    test('statusCode can be provided', () {
      final e = ApiException('unauthorized', 'Forbidden', statusCode: 403);
      expect(e.statusCode, 403);
    });

    test('is an Exception', () {
      expect(ApiException('c', 'm'), isA<Exception>());
    });
  });

  // ---------------------------------------------------------------------------
  // PhotoServiceException
  // ---------------------------------------------------------------------------
  group('PhotoServiceException', () {
    test('toString returns the message', () {
      final e = PhotoServiceException('camera_denied', 'Camera permission denied');
      expect(e.toString(), 'Camera permission denied');
    });

    test('code and message are accessible', () {
      final e = PhotoServiceException('file_too_large', 'File exceeds 10 MB');
      expect(e.code, 'file_too_large');
      expect(e.message, 'File exceeds 10 MB');
    });

    test('is an Exception', () {
      expect(PhotoServiceException('c', 'm'), isA<Exception>());
    });
  });
}
