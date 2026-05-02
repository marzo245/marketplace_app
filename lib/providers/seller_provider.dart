import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/product.dart';
import '../services/api_client.dart';
import '../services/photo_service.dart';

enum UploadState { idle, uploading, waitingForModel, ready, failed }

class SellerProvider extends ChangeNotifier {
  final ApiClient _api;
  final PhotoService _photos;

  SellerProvider({
    required ApiClient api,
    required PhotoService photos,
  }) : _api = api, _photos = photos;

  ProductDraft _draft = ProductDraft();
  ProductDraft get draft => _draft;

  UploadState _state = UploadState.idle;
  UploadState get state => _state;

  double _uploadProgress = 0.0;
  double get uploadProgress => _uploadProgress;

  String? _productId;
  String? get productId => _productId;

  ProductStatus? _latestStatus;
  ProductStatus? get latestStatus => _latestStatus;

  String? _error;
  String? get error => _error;

  Timer? _pollTimer;

  void updateTitle(String v) { _draft.title = v; notifyListeners(); }
  void updateDescription(String v) { _draft.description = v; notifyListeners(); }
  void updatePrice(double? v) { _draft.price = v; notifyListeners(); }
  void updateCategory(ProductCategory c) { _draft.category = c; notifyListeners(); }

  Future<void> addPhotoFromCamera() async {
    if (_draft.photos.length >= 4) {
      _error = 'Ya tienes el máximo de 4 fotos';
      notifyListeners();
      return;
    }
    try {
      final file = await _photos.pickFromCamera();
      if (file != null) {
        _draft.photos.add(file);
        _error = null;
        notifyListeners();
      }
    } on PhotoServiceException catch (e) {
      _error = e.message;
      notifyListeners();
    }
  }

  Future<void> addPhotosFromGallery() async {
    final remaining = 4 - _draft.photos.length;
    if (remaining <= 0) {
      _error = 'Ya tienes el máximo de 4 fotos';
      notifyListeners();
      return;
    }
    try {
      final files = await _photos.pickFromGallery(maxCount: remaining);
      _draft.photos.addAll(files);
      _error = null;
      notifyListeners();
    } on PhotoServiceException catch (e) {
      _error = e.message;
      notifyListeners();
    }
  }

  void removePhoto(int index) {
    if (index >= 0 && index < _draft.photos.length) {
      _draft.photos.removeAt(index);
      notifyListeners();
    }
  }

  Future<bool> submit() async {
    final validationError = _draft.validationError;
    if (validationError != null) {
      _error = validationError;
      notifyListeners();
      return false;
    }

    _state = UploadState.uploading;
    _uploadProgress = 0;
    _error = null;
    notifyListeners();

    try {
      final result = await _api.createProduct(
        draft: _draft,
        onProgress: (sent, total) {
          if (total > 0) {
            _uploadProgress = sent / total;
            notifyListeners();
          }
        },
      );

      _productId = result.productId;
      _state = UploadState.waitingForModel;
      notifyListeners();

      _startPolling();
      return true;
    } on ApiException catch (e) {
      _state = UploadState.failed;
      _error = e.message;
      notifyListeners();
      return false;
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _checkStatus());
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    if (_productId == null) return;
    try {
      final status = await _api.getProductStatus(_productId!);
      _latestStatus = status;

      if (status.status == Model3DStatus.ready) {
        _state = UploadState.ready;
        _pollTimer?.cancel();
      } else if (status.status == Model3DStatus.failed) {
        _state = UploadState.failed;
        _error = status.error ?? 'El modelo 3D no pudo generarse';
        _pollTimer?.cancel();
      }
      notifyListeners();
    } on ApiException {
      // Soft fail on polling errors — keep trying
    }
  }

  void reset() {
    _pollTimer?.cancel();
    _draft = ProductDraft();
    _state = UploadState.idle;
    _uploadProgress = 0;
    _productId = null;
    _latestStatus = null;
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }
}
