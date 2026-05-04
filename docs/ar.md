# Realidad aumentada

## Estrategia

**No usamos un plugin Flutter de AR.** En vez de eso, lanzamos los visores AR nativos del sistema operativo vía deep link.

| Plataforma | Visor | Disparo |
|---|---|---|
| Android | **Google Scene Viewer** | Intent URI `intent://arvr.google.com/scene-viewer/1.0?file=...` |
| iOS | **AR Quick Look** | URL directa al archivo `.usdz` |

Es la misma estrategia que usan IKEA, Wayfair, Mercado Libre, Amazon. Ventajas:

- Cero código AR propio.
- Detección de planos, anclaje, oclusión, sombras e iluminación gestionados por ARCore/ARKit.
- Los usuarios obtienen la experiencia AR que ya conocen del sistema.
- Cuando Apple/Google mejoran su visor, ganamos sin cambiar nada.

Trade-off: el usuario sale temporalmente de tu app durante la sesión AR y vuelve al cerrar el visor.

## Implementación

`lib/services/ar_service.dart`:

```dart
final result = await arService.launchAR(
  productTitle: product.title,
  glbUrl: product.model3d?.glbUrl,
  usdzUrl: product.model3d?.usdzUrl,
);
```

### Android — Scene Viewer

```
intent://arvr.google.com/scene-viewer/1.0
  ?file=<glbUrl>
  &mode=ar_preferred
  &title=<title>
  &resizable=false
  #Intent;scheme=https;
   action=android.intent.action.VIEW;
   S.browser_fallback_url=<google-play-arcore>;
  end;
```

Si el intent falla, hay un segundo intento con la URL HTTPS directa (`https://arvr.google.com/scene-viewer/1.0?...`) — útil si el dispositivo no enrutó el `intent://` correctamente.

### iOS — Quick Look

`launchUrl(usdzUrl, mode: externalApplication)`. iOS detecta el MIME type `model/vnd.usdz+zip` y abre AR Quick Look automáticamente.

> Importante: el servidor (Supabase Storage en este caso) **debe** entregar el header `Content-Type: model/vnd.usdz+zip` para los `.usdz`. Si entrega `application/octet-stream`, iOS lo trata como descarga genérica y AR Quick Look no se abre.

## Compatibilidad

`ArService.checkCapability()` verifica antes de lanzar:

| Plataforma | Mínimo |
|---|---|
| Android | API 24 (Android 7.0) |
| iOS | iOS 12.0 |

Si no se cumple devuelve `unsupportedDevice`. Si la plataforma no es Android/iOS (ej: web, desktop) devuelve `unsupportedPlatform`.

## Errores y mensajes al usuario

Cuando `launchAR()` devuelve `success: false`, `ArLaunchResult.userMessage` da un mensaje listo para mostrar:

| Razón | Mensaje |
|---|---|
| `unsupportedDevice` | "Tu dispositivo no es compatible con realidad aumentada" |
| `unsupportedPlatform` | "La vista AR solo funciona en Android e iOS" |
| `noModel` | "Este producto aún no tiene modelo 3D listo" |
| `launchFailed` | "Vista AR no disponible. Necesitas instalar Google Play Services for AR (ARCore)." |

Cuando el motivo es `launchFailed` en Android, el `SnackBar` ofrece un botón "Instalar ARCore" que llama `ArService.openArCoreInstaller()` (abre Play Store).

## Visor 3D inline (no es AR)

Independiente de la AR: en el detalle del producto el primer slide del carrusel es un `Product3DViewer` que renderiza el `.glb` con `model_viewer_plus` (un WebView con `<model-viewer>` de Google). Permite rotar y hacer zoom **dentro de la app**, sin salir. Es el preview que el usuario ve antes de tocar "Ver en mi casa".

## `in_app_ar_screen.dart`

Pantalla de fallback con cámara live (`camera` package) para escenarios donde Scene Viewer/Quick Look no estén disponibles. **No** es AR real — es solo cámara + overlay del modelo. Hoy no se navega a ella desde la UI principal; queda como base para futura experiencia AR in-app si decides salir de la estrategia de deep link.
