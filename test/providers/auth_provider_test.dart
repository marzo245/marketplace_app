import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:marketplace_3d/providers/auth_provider.dart';
import 'package:marketplace_3d/services/api_client.dart';
import 'package:marketplace_3d/services/auth_service.dart';
import 'package:marketplace_3d/services/push_service.dart';

class _MockAuthService extends Mock implements AuthService {}

class _MockApiClient extends Mock implements ApiClient {}

class _MockPushService extends Mock implements PushService {}

class _MockUser extends Mock implements User {}

void main() {
  late _MockAuthService mockAuthService;
  late _MockApiClient mockApiClient;
  late _MockPushService mockPushService;

  setUp(() {
    mockAuthService = _MockAuthService();
    mockApiClient = _MockApiClient();
    mockPushService = _MockPushService();
  });

  /// Builds an [AuthProvider] using the current mocks.
  AuthProvider buildProvider() => AuthProvider(
        authService: mockAuthService,
        apiClient: mockApiClient,
        pushService: mockPushService,
      );

  // ---------------------------------------------------------------------------
  // Initial state — no signed-in user
  // ---------------------------------------------------------------------------
  group('initial state with no user', () {
    setUp(() {
      when(() => mockAuthService.currentUser).thenReturn(null);
      when(() => mockAuthService.authStateChanges())
          .thenAnswer((_) => const Stream.empty());
    });

    test('user is null', () {
      final provider = buildProvider();
      addTearDown(provider.dispose);
      expect(provider.user, isNull);
    });

    test('busy is false', () {
      final provider = buildProvider();
      addTearDown(provider.dispose);
      expect(provider.busy, isFalse);
    });

    test('error is null', () {
      final provider = buildProvider();
      addTearDown(provider.dispose);
      expect(provider.error, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // Initial state — already signed in
  // ---------------------------------------------------------------------------
  group('initial state with existing user', () {
    late _MockUser mockUser;
    late StreamController<User?> authController;

    setUp(() {
      mockUser = _MockUser();
      authController = StreamController<User?>();

      when(() => mockUser.uid).thenReturn('user_123');
      when(() => mockUser.getIdToken()).thenAnswer((_) async => 'id_token');
      when(() => mockAuthService.currentUser).thenReturn(mockUser);
      when(() => mockAuthService.authStateChanges())
          .thenAnswer((_) => authController.stream);
      when(() => mockApiClient.setAuthToken(any())).thenReturn(null);
      when(() => mockPushService.registerForUser(any())).thenAnswer((_) async {});
      when(() => mockPushService.clear()).thenAnswer((_) async {});
    });

    tearDown(() => authController.close());

    test('user is populated from currentUser', () {
      final provider = buildProvider();
      addTearDown(provider.dispose);
      expect(provider.user, mockUser);
    });

    test('syncSession sets auth token on ApiClient', () async {
      final provider = buildProvider();
      addTearDown(provider.dispose);
      // Give the async _syncSession a chance to run
      await Future<void>.value();
      verify(() => mockApiClient.setAuthToken('id_token')).called(greaterThan(0));
    });

    test('syncSession registers push notification for user uid', () async {
      final provider = buildProvider();
      addTearDown(provider.dispose);
      await Future<void>.value();
      verify(() => mockPushService.registerForUser('user_123'))
          .called(greaterThan(0));
    });
  });

  // ---------------------------------------------------------------------------
  // signInWithGoogle
  // ---------------------------------------------------------------------------
  group('signInWithGoogle', () {
    late StreamController<User?> authController;

    setUp(() {
      authController = StreamController<User?>();
      when(() => mockAuthService.currentUser).thenReturn(null);
      when(() => mockAuthService.authStateChanges())
          .thenAnswer((_) => authController.stream);
    });

    tearDown(() => authController.close());

    test('sets busy to true before the sign-in attempt completes', () async {
      final completer = Completer<void>();
      when(() => mockAuthService.signInWithGoogle())
          .thenAnswer((_) => completer.future);

      final provider = buildProvider();
      addTearDown(provider.dispose);

      final future = provider.signInWithGoogle();
      expect(provider.busy, isTrue);
      expect(provider.error, isNull);

      completer.complete();
      await future;
    });

    test('sets cancelled error when sign_in_cancelled is thrown', () async {
      when(() => mockAuthService.signInWithGoogle())
          .thenThrow(Exception('sign_in_cancelled'));

      final provider = buildProvider();
      addTearDown(provider.dispose);

      await provider.signInWithGoogle();

      expect(provider.error, 'Inicio de sesión cancelado');
      expect(provider.busy, isFalse);
    });

    test('sets generic error for other exceptions', () async {
      when(() => mockAuthService.signInWithGoogle())
          .thenThrow(Exception('network_error'));

      final provider = buildProvider();
      addTearDown(provider.dispose);

      await provider.signInWithGoogle();

      expect(provider.error, 'No se pudo iniciar sesión con Google');
      expect(provider.busy, isFalse);
    });

    test('clears previous error before a new attempt', () async {
      when(() => mockAuthService.signInWithGoogle())
          .thenThrow(Exception('first_error'));

      final provider = buildProvider();
      addTearDown(provider.dispose);

      await provider.signInWithGoogle();
      expect(provider.error, isNotNull);

      // Second attempt — also fails, but error must be cleared at start
      final completer = Completer<void>();
      when(() => mockAuthService.signInWithGoogle())
          .thenAnswer((_) => completer.future);

      final future = provider.signInWithGoogle();
      expect(provider.error, isNull); // cleared on second attempt

      completer.completeError(Exception('second_error'));
      await future;
    });
  });

  // ---------------------------------------------------------------------------
  // signOut
  // ---------------------------------------------------------------------------
  group('signOut', () {
    late StreamController<User?> authController;

    setUp(() {
      authController = StreamController<User?>();
      when(() => mockAuthService.currentUser).thenReturn(null);
      when(() => mockAuthService.authStateChanges())
          .thenAnswer((_) => authController.stream);
      when(() => mockPushService.clear()).thenAnswer((_) async {});
      when(() => mockAuthService.signOut()).thenAnswer((_) async {});
    });

    tearDown(() => authController.close());

    test('calls authService.signOut', () async {
      final provider = buildProvider();
      addTearDown(provider.dispose);

      await provider.signOut();

      verify(() => mockAuthService.signOut()).called(1);
    });

    test('busy is false after sign-out completes', () async {
      final provider = buildProvider();
      addTearDown(provider.dispose);

      await provider.signOut();

      expect(provider.busy, isFalse);
    });

    test('pushService.clear is called during sign-out', () async {
      final provider = buildProvider();
      addTearDown(provider.dispose);

      await provider.signOut();

      verify(() => mockPushService.clear()).called(greaterThanOrEqualTo(1));
    });

    test('busy is false even when pushService.clear throws', () async {
      when(() => mockPushService.clear()).thenThrow(Exception('fcm error'));

      final provider = buildProvider();
      addTearDown(provider.dispose);

      await provider.signOut();

      expect(provider.busy, isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // Auth state changes
  // ---------------------------------------------------------------------------
  group('auth state changes', () {
    late StreamController<User?> authController;

    setUp(() {
      authController = StreamController<User?>();
      when(() => mockAuthService.currentUser).thenReturn(null);
      when(() => mockAuthService.authStateChanges())
          .thenAnswer((_) => authController.stream);
      when(() => mockApiClient.setAuthToken(any())).thenReturn(null);
      when(() => mockPushService.clear()).thenAnswer((_) async {});
    });

    tearDown(() => authController.close());

    test('user becomes null when auth stream emits null', () async {
      final provider = buildProvider();
      addTearDown(provider.dispose);

      authController.add(null);
      await Future<void>.value();

      expect(provider.user, isNull);
    });

    test('clears auth token when user signs out via auth stream', () async {
      final provider = buildProvider();
      addTearDown(provider.dispose);

      authController.add(null);
      await Future<void>.value();

      verify(() => mockApiClient.setAuthToken(null)).called(greaterThan(0));
    });

    test('user is updated when auth stream emits a new user', () async {
      final mockUser = _MockUser();
      when(() => mockUser.uid).thenReturn('new_uid');
      when(() => mockUser.getIdToken()).thenAnswer((_) async => 'new_token');
      when(() => mockPushService.registerForUser(any())).thenAnswer((_) async {});

      final provider = buildProvider();
      addTearDown(provider.dispose);

      authController.add(mockUser);
      await Future<void>.value();

      expect(provider.user, mockUser);
    });
  });
}
