import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class ArService {
  static const int minAndroidSdk = 24;
  static const double minIosVersion = 12.0;
  static const String _arCorePackage = 'com.google.ar.core';

  Future<bool> openArCoreInstaller() async {
    final marketUri = Uri.parse('market://details?id=$_arCorePackage');
    if (await canLaunchUrl(marketUri)) {
      return launchUrl(marketUri, mode: LaunchMode.externalApplication);
    }
    final webUri = Uri.parse(
      'https://play.google.com/store/apps/details?id=$_arCorePackage',
    );
    return launchUrl(webUri, mode: LaunchMode.externalApplication);
  }

  Future<ArCapability> checkCapability() async {
    if (Platform.isAndroid) {
      final info = await DeviceInfoPlugin().androidInfo;
      if (info.version.sdkInt < minAndroidSdk) {
        return ArCapability.unsupportedDevice;
      }
      return ArCapability.supported;
    }

    if (Platform.isIOS) {
      final info = await DeviceInfoPlugin().iosInfo;
      final versionStr = info.systemVersion;
      final majorVersion = double.tryParse(versionStr.split('.').first) ?? 0;
      if (majorVersion < minIosVersion) {
        return ArCapability.unsupportedDevice;
      }
      return ArCapability.supported;
    }

    return ArCapability.unsupportedPlatform;
  }

  Future<ArLaunchResult> launchAR({
    required String productTitle,
    required String? glbUrl,
    required String? usdzUrl,
    String? fallbackLink,
  }) async {
    final capability = await checkCapability();
    if (capability != ArCapability.supported) {
      return ArLaunchResult(success: false, reason: capability);
    }

    try {
      if (Platform.isAndroid) {
        return await _launchSceneViewer(
          glbUrl: glbUrl,
          productTitle: productTitle,
          fallbackLink: fallbackLink,
        );
      }
      if (Platform.isIOS) {
        return await _launchQuickLook(
          usdzUrl: usdzUrl,
          glbUrl: glbUrl,
        );
      }
      return ArLaunchResult(
        success: false,
        reason: ArCapability.unsupportedPlatform,
      );
    } catch (e) {
      return ArLaunchResult(
        success: false,
        reason: ArCapability.launchFailed,
        errorDetail: e.toString(),
      );
    }
  }

  Future<ArLaunchResult> _launchSceneViewer({
    required String? glbUrl,
    required String productTitle,
    String? fallbackLink,
  }) async {
    if (glbUrl == null) {
      return ArLaunchResult(success: false, reason: ArCapability.noModel);
    }

    final intent = Uri.parse(
      'intent://arvr.google.com/scene-viewer/1.0'
      '?file=${Uri.encodeComponent(glbUrl)}'
      '&mode=ar_preferred'
      '&title=${Uri.encodeComponent(productTitle)}'
      '&resizable=false'
      '${fallbackLink != null ? '&link=${Uri.encodeComponent(fallbackLink)}' : ''}'
      '#Intent;scheme=https;package=com.google.android.googlequicksearchbox;'
      'action=android.intent.action.VIEW;'
      'S.browser_fallback_url=${Uri.encodeComponent(
        'https://play.google.com/store/apps/details?id=$_arCorePackage',
      )};end;',
    );

    final ok = await launchUrl(intent, mode: LaunchMode.externalApplication);
    return ArLaunchResult(success: ok);
  }

  Future<ArLaunchResult> _launchQuickLook({
    required String? usdzUrl,
    required String? glbUrl,
  }) async {
    final url = usdzUrl ?? glbUrl;
    if (url == null) {
      return ArLaunchResult(success: false, reason: ArCapability.noModel);
    }

    final uri = Uri.parse(url);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    return ArLaunchResult(success: ok);
  }
}

enum ArCapability {
  supported,
  unsupportedDevice,
  unsupportedPlatform,
  noModel,
  launchFailed,
}

class ArLaunchResult {
  final bool success;
  final ArCapability? reason;
  final String? errorDetail;

  ArLaunchResult({
    required this.success,
    this.reason,
    this.errorDetail,
  });

  String get userMessage => switch (reason) {
    ArCapability.unsupportedDevice =>
      'Tu dispositivo no es compatible con realidad aumentada',
    ArCapability.unsupportedPlatform =>
      'La vista AR solo funciona en Android e iOS',
    ArCapability.noModel =>
      'Este producto aún no tiene modelo 3D listo',
    ArCapability.launchFailed =>
      'Vista AR no disponible. Necesitas instalar Google Play Services for AR (ARCore).',
    _ => 'No se pudo iniciar la vista AR',
  };
}
