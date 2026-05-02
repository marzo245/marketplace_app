import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class PushService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  StreamSubscription<String>? _tokenRefreshSub;
  String? _registeredUid;
  String? _currentToken;

  Future<void> registerForUser(String uid) async {
    await _messaging.requestPermission(alert: true, badge: true, sound: true);

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    if (_registeredUid != null && _registeredUid != uid && _currentToken != null) {
      await _removeToken(_registeredUid!, _currentToken!);
    }

    await _syncToken(uid);

    await _tokenRefreshSub?.cancel();
    _tokenRefreshSub = _messaging.onTokenRefresh.listen((token) {
      _saveToken(uid, token);
    });
  }

  Future<void> clear() async {
    await _tokenRefreshSub?.cancel();
    _tokenRefreshSub = null;

    if (_registeredUid != null && _currentToken != null) {
      await _removeToken(_registeredUid!, _currentToken!);
    }

    _registeredUid = null;
    _currentToken = null;
  }

  Future<void> _syncToken(String uid) async {
    final token = await _messaging.getToken();
    if (token == null || token.isEmpty) return;

    _registeredUid = uid;
    _currentToken = token;

    await _saveToken(uid, token);
  }

  Future<void> _saveToken(String uid, String token) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).set(
      {
        'fcmTokens': FieldValue.arrayUnion([token]),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> _removeToken(String uid, String token) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).set(
      {
        'fcmTokens': FieldValue.arrayRemove([token]),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }
}

