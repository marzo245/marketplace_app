import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/push_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService;
  final ApiClient _apiClient;
  final PushService _pushService;

  StreamSubscription<User?>? _authSubscription;

  User? _user;
  User? get user => _user;

  bool _busy = false;
  bool get busy => _busy;

  String? _error;
  String? get error => _error;

  AuthProvider({
    required AuthService authService,
    required ApiClient apiClient,
    required PushService pushService,
  })  : _authService = authService,
        _apiClient = apiClient,
        _pushService = pushService {
    _user = _authService.currentUser;
    _authSubscription = _authService.authStateChanges().listen(_onAuthChanged);
    if (_user != null) {
      _syncSession(_user!);
    }
  }

  Future<void> signInWithGoogle() async {
    _busy = true;
    _error = null;
    notifyListeners();

    try {
      await _authService.signInWithGoogle();
    } catch (error) {
      final message = error.toString();
      _error = message.contains('sign_in_cancelled')
          ? 'Inicio de sesión cancelado'
          : 'No se pudo iniciar sesión con Google';
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    _busy = true;
    _error = null;
    notifyListeners();

    try {
      try {
        await _pushService.clear();
      } catch (_) {}
      await _authService.signOut();
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> _onAuthChanged(User? user) async {
    _user = user;
    _error = null;

    if (user == null) {
      _apiClient.setAuthToken(null);
      try {
        await _pushService.clear();
      } catch (_) {}
      _busy = false;
      notifyListeners();
      return;
    }

    await _syncSession(user);
  }

  Future<void> _syncSession(User user) async {
    try {
      final token = await user.getIdToken();
      _apiClient.setAuthToken(token);
      await _pushService.registerForUser(user.uid);
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _pushService.clear();
    super.dispose();
  }
}


