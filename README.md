# Marketplace 3D — App Flutter completa

App e-commerce móvil con dos flujos completos:

**Vendedor:** publica un producto tomando fotos → backend genera modelo 3D con Meshy AI.
**Comprador:** navega catálogo → ve producto en 3D → lo visualiza con realidad aumentada en su espacio real.

## Estructura

```
lib/
├── main.dart                             punto de entrada + bottom nav
├── theme/
│   └── app_theme.dart                    Material 3, purple seed
├── models/
│   ├── product.dart                      ProductDraft (vendedor), ProductStatus
│   └── product_listing.dart              ProductListing, Model3D (comprador)
├── services/
│   ├── api_client.dart                   habla con el backend Meshy worker
│   ├── photo_service.dart                cámara + galería + permisos
│   └── ar_service.dart                   lanza Scene Viewer y Quick Look
├── providers/
│   └── seller_provider.dart              estado del vendedor con polling
├── widgets/
│   ├── photo_grid.dart                   grid de fotos del vendedor
│   ├── processing_steps.dart             indicador de 3 pasos
│   └── product_3d_viewer.dart            visor 3D inline + carrusel media
└── screens/
    ├── catalog_screen.dart               catálogo con filtro "Con vista 3D"
    ├── product_detail_screen.dart        detalle con 3D + botón AR
    ├── sell_product_screen.dart          formulario del vendedor
    └── processing_screen.dart            progreso de publicación
```

## Flujo AR — decisión de arquitectura

**No usamos `ar_flutter_plugin`** (el que más aparece en tutoriales). Razones:

1. Requiere manejar manualmente detección de planos, anchors, gestos, iluminación, escalado
2. Mantenimiento inconsistente, varios forks abandonados
3. Produce una experiencia AR inferior a la nativa del sistema operativo

**En su lugar usamos deep links a los visores AR nativos**:

- **Android:** Intent URI que abre **Google Scene Viewer**
  ```
  intent://arvr.google.com/scene-viewer/1.0?file=URL.glb&mode=ar_preferred...
  ```
- **iOS:** URL directa al archivo **`.usdz`** que abre **AR Quick Look**

Esta es la misma estrategia que usan Amazon, IKEA, Wayfair y Mercado Libre. Ventajas:

- Cero código AR propio, cero mantenimiento
- El usuario obtiene la experiencia AR que ya conoce de otras apps
- Funciona con detección de planos, oclusión, iluminación y sombras optimizadas por Google/Apple
- Actualizaciones automáticas cuando mejoran ARCore/ARKit

**Trade-off:** el usuario sale temporalmente de tu app durante la sesión AR. Vuelve al cerrar el visor.

## Visor 3D inline

Para la pantalla de detalle usamos **`model_viewer_plus`**, que renderiza `<model-viewer>` de Google en un WebView interno. Soporta:

- Rotación automática del modelo al ver el producto
- Gestos de rotación y zoom manual
- Sombras realistas
- Carga progresiva

El carrusel `MediaCarousel` muestra primero el modelo 3D (si existe) y luego las fotos originales con indicadores de página.

## Firebase Firestore como fuente de verdad

El catálogo lee con `StreamBuilder` de Firestore para tener actualizaciones en tiempo real:
- Cuando Meshy termina un modelo, el backend actualiza el doc
- El catálogo refleja el cambio al instante sin recargar

La query base:
```dart
collection('products')
  .where('status', isEqualTo: 'published')
  .where('model3d.status', isEqualTo: 'ready')  // si filtro = AR
  .orderBy('createdAt', descending: true)
  .limit(30)
```

Necesitarás crear índices compuestos en Firestore para que estas queries funcionen. Firebase te los sugiere automáticamente en la consola cuando las ejecutas por primera vez.

## Compatibilidad AR

### Android
- Requiere **Google Play Services for AR** instalado (app gratis de Google)
- Dispositivos compatibles: [lista oficial ARCore](https://developers.google.com/ar/devices)
- Android 7.0 (API 24) mínimo

### iOS
- iOS 12 o superior
- iPhone 6s o posterior
- Quick Look viene incluido en el sistema, no requiere instalación

El `ArService.checkCapability()` verifica esto antes de lanzar, y si falla muestra un diálogo con instrucciones claras al usuario.

## Setup

```bash
flutter create . --project-name marketplace_3d --platforms android,ios --overwrite
cp .env.example .env
# editar .env con URL del backend
flutter pub get

# Firebase: bajar google-services.json y GoogleService-Info.plist
# y ponerlos en android/app/ e ios/Runner/ respectivamente

flutter run
```

## Dependencias clave

```yaml
model_viewer_plus: ^1.9.3      # visor 3D inline
url_launcher: ^6.3.0           # deep links a Scene Viewer / Quick Look
device_info_plus: ^10.1.2      # check de compatibilidad AR
cloud_firestore: ^5.4.3        # catálogo en tiempo real
firebase_core: ^3.6.0
image_picker: ^1.1.2
dio: ^5.7.0
provider: ^6.1.2
```

## Flujo completo end-to-end

1. **Vendedor** abre app → tab Vender → sube 2-4 fotos → llena datos → toca Publicar
2. App manda multipart al backend, recibe `productId`, muestra `ProcessingScreen`
3. Backend encola job, llama a Meshy, Meshy procesa 1-3 min, envía webhook
4. Backend descarga `.glb` + `.usdz`, guarda en Storage, actualiza Firestore status=`ready`
5. **Comprador** entra al catálogo → ve el producto con badge "3D · AR"
6. Entra al detalle → gira el modelo 3D con los dedos
7. Toca "Ver en mi casa" → sale de la app hacia Scene Viewer / Quick Look
8. Coloca el producto en su piso real con la cámara → decide comprar

## Puntos pendientes para producción

- Auth real con Firebase Auth (ahora usa `demo_seller_001` hardcodeado)
- Paginación en el catálogo (ahora trae 30 fijos)
- Chat entre comprador y vendedor (crear colección `chats`)
- Carrito y checkout (Stripe o Wompi para Colombia)
- Push notifications con FCM cuando el modelo 3D queda listo
- Analytics de qué productos se visualizan más en AR
- Cache de modelos 3D descargados con `flutter_cache_manager`
