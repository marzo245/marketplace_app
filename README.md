# VisuBuy

App móvil Flutter para un marketplace donde los vendedores publican productos con fotos y se genera automáticamente un modelo 3D que los compradores pueden ver con realidad aumentada en su propio espacio.

## Stack en una línea

**Flutter (cliente)** ↔ **Backend Node/Express en Render** ↔ **Meshy AI (3D)** + **Firebase (Firestore, Auth, FCM, Storage)** + **Supabase (almacenamiento de modelos `.glb`/`.usdz`)**.

## Quickstart

```bash
flutter pub get
cp .env.example .env        # ajusta API_BASE_URL si hace falta
flutter run
```

Necesitas además:
- `android/app/google-services.json` (Firebase Android)
- `ios/Runner/GoogleService-Info.plist` (Firebase iOS)
- Backend corriendo (por defecto el `.env.example` apunta a `http://10.0.2.2:3000` para emulador Android; el binario por defecto del cliente apunta al deploy en Render).

Detalles completos en [`docs/setup.md`](docs/setup.md).

## Documentación (wiki)

| Documento | Contenido |
|---|---|
| [`docs/architecture.md`](docs/architecture.md) | Diagrama general, responsabilidades por capa, flujo de datos. |
| [`docs/services.md`](docs/services.md) | Qué hace cada proveedor externo (Meshy, Firebase, Render, Supabase). |
| [`docs/setup.md`](docs/setup.md) | Instalación local, variables de entorno, Firebase, permisos. |
| [`docs/seller-flow.md`](docs/seller-flow.md) | Flujo del vendedor: publicar, generación 3D, polling de progreso. |
| [`docs/buyer-flow.md`](docs/buyer-flow.md) | Flujo del comprador: catálogo, detalle, favoritos, contacto, compra, AR. |
| [`docs/profile.md`](docs/profile.md) | Perfil propio, "Mis productos" (editar/despublicar), perfiles de vendedor. |
| [`docs/firestore-schema.md`](docs/firestore-schema.md) | Colecciones, campos, índices. |
| [`docs/ar.md`](docs/ar.md) | Estrategia AR (Scene Viewer / Quick Look) y compatibilidad. |
| [`docs/troubleshooting.md`](docs/troubleshooting.md) | Errores comunes (índices Firestore, layout, AR, polling). |

## Estructura del cliente

```
lib/
├── main.dart                     entrypoint, MultiProvider, RootShell con tabs
├── firebase_options.dart         generado por flutterfire (no se edita a mano)
├── theme/app_theme.dart          tema Material 3
├── models/
│   ├── product.dart              ProductDraft, ProductStatus, Model3DStatus, UploadResult
│   └── product_listing.dart      ProductListing + Model3D (lectura)
├── services/
│   ├── api_client.dart           Dio + base URL + Bearer token Firebase
│   ├── auth_service.dart         FirebaseAuth + Google Sign-In
│   ├── push_service.dart         FCM token sync en users/{uid}.fcmTokens
│   ├── photo_service.dart        cámara + galería + permisos
│   └── ar_service.dart           Scene Viewer (Android) / Quick Look (iOS)
├── providers/
│   ├── auth_provider.dart        sesión, busy/error, sync token al backend
│   └── seller_provider.dart      borrador, upload, polling de modelo 3D
├── widgets/
│   ├── photo_grid.dart           grid 2-4 fotos del vendedor
│   ├── processing_steps.dart     indicador 3 pasos durante generación
│   └── product_3d_viewer.dart    ModelViewer + carrusel multimedia
└── screens/
    ├── catalog_screen.dart       catálogo Firestore con filtros y paginación
    ├── product_detail_screen.dart detalle, favoritos, contactar, comprar, AR
    ├── sell_product_screen.dart  formulario del vendedor
    ├── processing_screen.dart    progreso (sigue el SellerProvider)
    └── in_app_ar_screen.dart     fallback AR in-app si el visor del SO falla
```
