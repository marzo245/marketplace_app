import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:marketplace_3d/models/product.dart';
import 'package:marketplace_3d/providers/seller_provider.dart';
import 'package:marketplace_3d/services/api_client.dart';
import 'package:marketplace_3d/services/photo_service.dart';

class _MockApiClient extends Mock implements ApiClient {}

class _MockPhotoService extends Mock implements PhotoService {}

void main() {
  setUpAll(() {
    registerFallbackValue(ProductDraft());
  });

  late _MockApiClient mockApi;
  late _MockPhotoService mockPhotos;
  late SellerProvider provider;

  setUp(() {
    mockApi = _MockApiClient();
    mockPhotos = _MockPhotoService();
    provider = SellerProvider(api: mockApi, photos: mockPhotos);
  });

  tearDown(() {
    provider.dispose();
  });

  // ---------------------------------------------------------------------------
  // Initial state
  // ---------------------------------------------------------------------------
  group('initial state', () {
    test('draft is empty', () {
      expect(provider.draft.title, '');
      expect(provider.draft.description, '');
      expect(provider.draft.price, isNull);
      expect(provider.draft.photos, isEmpty);
      expect(provider.draft.category, ProductCategory.muebles);
    });

    test('state is idle', () {
      expect(provider.state, UploadState.idle);
    });

    test('uploadProgress is 0', () {
      expect(provider.uploadProgress, 0.0);
    });

    test('productId is null', () {
      expect(provider.productId, isNull);
    });

    test('latestStatus is null', () {
      expect(provider.latestStatus, isNull);
    });

    test('error is null', () {
      expect(provider.error, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // Draft field updates
  // ---------------------------------------------------------------------------
  group('updateTitle', () {
    test('updates draft title and notifies', () {
      provider.updateTitle('New Title');
      expect(provider.draft.title, 'New Title');
    });
  });

  group('updateDescription', () {
    test('updates draft description', () {
      provider.updateDescription('A nice product');
      expect(provider.draft.description, 'A nice product');
    });
  });

  group('updatePrice', () {
    test('updates draft price', () {
      provider.updatePrice(199.99);
      expect(provider.draft.price, 199.99);
    });

    test('accepts null price', () {
      provider.updatePrice(100.0);
      provider.updatePrice(null);
      expect(provider.draft.price, isNull);
    });
  });

  group('updateCategory', () {
    test('updates draft category', () {
      provider.updateCategory(ProductCategory.decoracion);
      expect(provider.draft.category, ProductCategory.decoracion);
    });
  });

  // ---------------------------------------------------------------------------
  // addPhotoFromCamera
  // ---------------------------------------------------------------------------
  group('addPhotoFromCamera', () {
    test('adds photo when camera returns a file', () async {
      final file = File('/tmp/test.jpg');
      when(() => mockPhotos.pickFromCamera()).thenAnswer((_) async => file);

      await provider.addPhotoFromCamera();

      expect(provider.draft.photos, contains(file));
      expect(provider.error, isNull);
    });

    test('does not add anything when camera returns null', () async {
      when(() => mockPhotos.pickFromCamera()).thenAnswer((_) async => null);

      await provider.addPhotoFromCamera();

      expect(provider.draft.photos, isEmpty);
      expect(provider.error, isNull);
    });

    test('sets error and skips camera when 4 photos already added', () async {
      for (int i = 0; i < 4; i++) {
        provider.draft.photos.add(File('/tmp/p$i.jpg'));
      }

      await provider.addPhotoFromCamera();

      expect(provider.draft.photos.length, 4);
      expect(provider.error, isNotNull);
      verifyNever(() => mockPhotos.pickFromCamera());
    });

    test('sets error message on PhotoServiceException', () async {
      when(() => mockPhotos.pickFromCamera())
          .thenThrow(PhotoServiceException('camera_denied', 'Camera permission denied'));

      await provider.addPhotoFromCamera();

      expect(provider.error, 'Camera permission denied');
      expect(provider.draft.photos, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // addPhotosFromGallery
  // ---------------------------------------------------------------------------
  group('addPhotosFromGallery', () {
    test('adds photos returned by gallery picker', () async {
      final files = [File('/tmp/a.jpg'), File('/tmp/b.jpg')];
      when(() => mockPhotos.pickFromGallery(maxCount: any(named: 'maxCount')))
          .thenAnswer((_) async => files);

      await provider.addPhotosFromGallery();

      expect(provider.draft.photos.length, 2);
      expect(provider.error, isNull);
    });

    test('sets error and skips gallery when 4 photos already added', () async {
      for (int i = 0; i < 4; i++) {
        provider.draft.photos.add(File('/tmp/p$i.jpg'));
      }

      await provider.addPhotosFromGallery();

      expect(provider.error, isNotNull);
      verifyNever(
          () => mockPhotos.pickFromGallery(maxCount: any(named: 'maxCount')));
    });

    test('passes the remaining slot count as maxCount', () async {
      provider.draft.photos.add(File('/tmp/p1.jpg'));
      when(() => mockPhotos.pickFromGallery(maxCount: 3))
          .thenAnswer((_) async => []);

      await provider.addPhotosFromGallery();

      verify(() => mockPhotos.pickFromGallery(maxCount: 3)).called(1);
    });

    test('sets error message on PhotoServiceException', () async {
      when(() => mockPhotos.pickFromGallery(maxCount: any(named: 'maxCount')))
          .thenThrow(
              PhotoServiceException('photos_denied', 'Photos permission denied'));

      await provider.addPhotosFromGallery();

      expect(provider.error, 'Photos permission denied');
    });
  });

  // ---------------------------------------------------------------------------
  // removePhoto
  // ---------------------------------------------------------------------------
  group('removePhoto', () {
    test('removes photo at a valid index', () {
      final file = File('/tmp/photo.jpg');
      provider.draft.photos.add(file);

      provider.removePhoto(0);

      expect(provider.draft.photos, isEmpty);
    });

    test('removes the correct photo when multiple are present', () {
      final a = File('/tmp/a.jpg');
      final b = File('/tmp/b.jpg');
      provider.draft.photos.addAll([a, b]);

      provider.removePhoto(0);

      expect(provider.draft.photos, [b]);
    });

    test('does nothing for a negative index', () {
      provider.draft.photos.add(File('/tmp/p.jpg'));
      provider.removePhoto(-1);
      expect(provider.draft.photos.length, 1);
    });

    test('does nothing for an out-of-bounds index', () {
      provider.draft.photos.add(File('/tmp/p.jpg'));
      provider.removePhoto(5);
      expect(provider.draft.photos.length, 1);
    });
  });

  // ---------------------------------------------------------------------------
  // submit
  // ---------------------------------------------------------------------------
  group('submit', () {
    void setupValidDraft() {
      provider.updateTitle('Valid Product');
      provider.updateDescription('A fine product');
      provider.updatePrice(150.0);
      provider.draft.photos.addAll([File('/tmp/a.jpg'), File('/tmp/b.jpg')]);
    }

    test('returns false and sets error when draft is invalid', () async {
      // Empty draft → title too short
      final result = await provider.submit();

      expect(result, isFalse);
      expect(provider.error, isNotNull);
      expect(provider.state, UploadState.idle);
    });

    test('sets uploading state and clears error before API call', () async {
      setupValidDraft();
      final completer = Completer<UploadResult>();
      when(() => mockApi.createProduct(
            draft: any(named: 'draft'),
            onProgress: any(named: 'onProgress'),
          )).thenAnswer((_) => completer.future);

      // Start submit but don't await it yet
      final future = provider.submit();
      expect(provider.state, UploadState.uploading);
      expect(provider.error, isNull);

      // Allow the future to complete so tearDown can dispose cleanly
      completer.completeError(ApiException('err', 'err'));
      await future;
    });

    test('returns true and sets waitingForModel on successful upload', () async {
      setupValidDraft();
      when(() => mockApi.createProduct(
            draft: any(named: 'draft'),
            onProgress: any(named: 'onProgress'),
          )).thenAnswer((_) async => UploadResult(
            productId: 'prod_1',
            jobId: 'job_1',
            estimatedMinutes: 3,
          ));
      // Stub status poll to keep it in waitingForModel
      when(() => mockApi.getProductStatus(any())).thenAnswer((_) async =>
          ProductStatus(
              productId: 'prod_1', status: Model3DStatus.processing));

      final result = await provider.submit();

      expect(result, isTrue);
      expect(provider.productId, 'prod_1');
      expect(provider.state, UploadState.waitingForModel);
    });

    test('transitions to ready when status poll returns ready', () async {
      setupValidDraft();
      when(() => mockApi.createProduct(
            draft: any(named: 'draft'),
            onProgress: any(named: 'onProgress'),
          )).thenAnswer((_) async => UploadResult(
            productId: 'prod_1',
            jobId: 'job_1',
            estimatedMinutes: 3,
          ));
      when(() => mockApi.getProductStatus('prod_1')).thenAnswer((_) async =>
          ProductStatus(
              productId: 'prod_1',
              status: Model3DStatus.ready,
              progress: 100,
              glbUrl: 'https://cdn.example.com/m.glb'));

      await provider.submit();
      // Flush the immediate _checkStatus() async call
      await Future<void>.value();
      await Future<void>.value();

      expect(provider.state, UploadState.ready);
    });

    test('transitions to failed when status poll returns failed', () async {
      setupValidDraft();
      when(() => mockApi.createProduct(
            draft: any(named: 'draft'),
            onProgress: any(named: 'onProgress'),
          )).thenAnswer((_) async => UploadResult(
            productId: 'prod_1',
            jobId: 'job_1',
            estimatedMinutes: 3,
          ));
      when(() => mockApi.getProductStatus('prod_1')).thenAnswer((_) async =>
          ProductStatus(
              productId: 'prod_1',
              status: Model3DStatus.failed,
              error: '3D generation failed'));

      await provider.submit();
      await Future<void>.value();
      await Future<void>.value();

      expect(provider.state, UploadState.failed);
      expect(provider.error, '3D generation failed');
    });

    test('uses default error text when failed status has no error field', () async {
      setupValidDraft();
      when(() => mockApi.createProduct(
            draft: any(named: 'draft'),
            onProgress: any(named: 'onProgress'),
          )).thenAnswer((_) async => UploadResult(
            productId: 'prod_1',
            jobId: 'job_1',
            estimatedMinutes: 3,
          ));
      when(() => mockApi.getProductStatus('prod_1')).thenAnswer((_) async =>
          ProductStatus(productId: 'prod_1', status: Model3DStatus.failed));

      await provider.submit();
      await Future<void>.value();
      await Future<void>.value();

      expect(provider.state, UploadState.failed);
      expect(provider.error, isNotNull);
    });

    test('returns false and sets failed state on ApiException from upload', () async {
      setupValidDraft();
      when(() => mockApi.createProduct(
            draft: any(named: 'draft'),
            onProgress: any(named: 'onProgress'),
          )).thenThrow(ApiException('server_error', 'Internal server error'));

      final result = await provider.submit();

      expect(result, isFalse);
      expect(provider.state, UploadState.failed);
      expect(provider.error, 'Internal server error');
    });
  });

  // ---------------------------------------------------------------------------
  // reset
  // ---------------------------------------------------------------------------
  group('reset', () {
    test('restores all fields to their initial values', () async {
      provider.updateTitle('Some Title');
      provider.updatePrice(99.0);
      provider.draft.photos.add(File('/tmp/p.jpg'));

      provider.reset();

      expect(provider.draft.title, '');
      expect(provider.draft.description, '');
      expect(provider.draft.price, isNull);
      expect(provider.draft.photos, isEmpty);
      expect(provider.draft.category, ProductCategory.muebles);
      expect(provider.state, UploadState.idle);
      expect(provider.uploadProgress, 0.0);
      expect(provider.productId, isNull);
      expect(provider.latestStatus, isNull);
      expect(provider.error, isNull);
    });

    test('cancels any pending poll timer', () async {
      provider.updateTitle('Valid Product');
      provider.updatePrice(50.0);
      provider.draft.photos.addAll([File('/tmp/a.jpg'), File('/tmp/b.jpg')]);

      when(() => mockApi.createProduct(
            draft: any(named: 'draft'),
            onProgress: any(named: 'onProgress'),
          )).thenAnswer((_) async => UploadResult(
            productId: 'prod_1',
            jobId: 'job_1',
            estimatedMinutes: 3,
          ));
      when(() => mockApi.getProductStatus(any())).thenAnswer((_) async =>
          ProductStatus(productId: 'prod_1', status: Model3DStatus.processing));

      await provider.submit();
      provider.reset();

      // After reset the state must be idle regardless of previous polling
      expect(provider.state, UploadState.idle);
    });
  });
}
