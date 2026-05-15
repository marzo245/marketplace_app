# VisuBuy

App móvil Flutter para un marketplace donde los vendedores publican productos con fotos y se genera automáticamente un modelo 3D que los compradores pueden ver con realidad aumentada en su propio espacio.

### Tecnologías

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)
![Material 3](https://img.shields.io/badge/Material%203-757575?style=for-the-badge&logo=materialdesign&logoColor=white)
![Kotlin](https://img.shields.io/badge/Kotlin-7F52FF?style=for-the-badge&logo=kotlin&logoColor=white)
![Swift](https://img.shields.io/badge/Swift-F05138?style=for-the-badge&logo=swift&logoColor=white)
![Node.js](https://img.shields.io/badge/Node.js-339933?style=for-the-badge&logo=nodedotjs&logoColor=white)
![Express](https://img.shields.io/badge/Express-000000?style=for-the-badge&logo=express&logoColor=white)
![Gradle](https://img.shields.io/badge/Gradle-02303A?style=for-the-badge&logo=gradle&logoColor=white)
![Git](https://img.shields.io/badge/Git-F05032?style=for-the-badge&logo=git&logoColor=white)

### Servicios cloud

![Firebase](https://img.shields.io/badge/Firebase-FFCA28?style=for-the-badge&logo=firebase&logoColor=black)
![Firestore](https://img.shields.io/badge/Cloud%20Firestore-FFA000?style=for-the-badge&logo=firebase&logoColor=white)
![Firebase Auth](https://img.shields.io/badge/Firebase%20Auth-FFCA28?style=for-the-badge&logo=firebase&logoColor=black)
![FCM](https://img.shields.io/badge/Cloud%20Messaging-FFA000?style=for-the-badge&logo=firebase&logoColor=white)
![Supabase](https://img.shields.io/badge/Supabase-3FCF8E?style=for-the-badge&logo=supabase&logoColor=white)
![Render](https://img.shields.io/badge/Render-46E3B7?style=for-the-badge&logo=render&logoColor=white)
![Meshy AI](https://img.shields.io/badge/Meshy%20AI-7C3AED?style=for-the-badge&logo=sparkfun&logoColor=white)
![Google Sign-In](https://img.shields.io/badge/Google%20Sign--In-4285F4?style=for-the-badge&logo=google&logoColor=white)
![ARCore](https://img.shields.io/badge/ARCore%20%2F%20Scene%20Viewer-4285F4?style=for-the-badge&logo=google&logoColor=white)
![ARKit](https://img.shields.io/badge/ARKit%20%2F%20Quick%20Look-000000?style=for-the-badge&logo=apple&logoColor=white)

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

## Criterios de calidad

Estos son los atributos que se consideraron al diseñar la app y que guiaron las decisiones técnicas. Cada uno tiene una manifestación concreta en el código o la infraestructura.

### Seguridad

- **Tokens, no contraseñas.** El cliente nunca maneja credenciales: Firebase Auth emite un `idToken` JWT que el backend valida con `firebase-admin`. Si el token se filtra, expira en 1 hora.
- **Reglas en el servidor.** `firestore.rules` valida `request.auth.uid` para cada lectura/escritura — un cliente modificado no puede leer favoritos ajenos ni publicar productos como otro usuario.
- **Secretos solo en el backend.** Las API keys de Meshy y la service-role de Supabase nunca salen del servidor. El cliente solo ve URLs públicas.
- **Sin endpoints triviales.** Cada endpoint del backend hace algo que requiere privilegios de servidor; no exponemos CRUDs genéricos sobre Firestore.

### Rendimiento

- **Tiempo real sin polling propio.** Catálogo, favoritos y estado del modelo 3D usan `snapshots()` de Firestore; la UI se actualiza por push del servidor, no por refrescos manuales.
- **Paginación en catálogo** (`limit + startAfterDocument`) para no descargar la colección entera.
- **Lazy carga 3D.** El `ModelViewer` se monta solo cuando el modelo está `ready`; mientras tanto se muestra el carrusel de fotos.
- **Polling acotado.** El único polling que hace el cliente (estado del modelo 3D) corre cada 5 s y se detiene en cuanto el estado es `ready` o `failed`.

### Disponibilidad / resiliencia

- **Cold start tolerado.** El backend en Render free tier puede tardar 30–60 s en despertar; `api_client.dart` tiene `connectTimeout: 60s` y `receiveTimeout: 3min` para no fallar en ese arranque.
- **Webhook en lugar de polling al proveedor.** Meshy nos avisa cuando termina, evitando timeouts y desperdicio de requests.
- **Múltiples dispositivos por usuario.** `users/{uid}.fcmTokens` es un array; un push llega a todos los dispositivos activos del vendedor.
- **`demoMode` si Firebase no inicializa.** La app no crashea si falta `google-services.json`: degrada a un modo de solo lectura para desarrollo.

### Mantenibilidad

- **Separación por capas estricta**: `services/` (clientes a APIs), `providers/` (estado), `screens/` + `widgets/` (UI), `models/` (DTOs). Una capa solo conoce a la inmediatamente inferior.
- **Una sola base de código** para Android e iOS (Flutter) — no hay que portar features dos veces.
- **Tipado fuerte** en DTOs (`Product`, `ProductListing`, `Model3DStatus`) para que el compilador atrape cambios de contrato con el backend.
- **Documentación viva** en `docs/` por flujo, no por capa, para que un dev nuevo lea solo lo que necesita.

### Usabilidad / UX

- **Material 3** con tema unificado en `theme/app_theme.dart`.
- **AR nativo del sistema operativo** (Scene Viewer / Quick Look) en vez de un visor propio: mejor calidad, gestos familiares, menos bugs.
- **Feedback de progreso continuo** durante la generación 3D: barra de progreso (0–100 %) + tres pasos visibles, en vez de un spinner ciego durante 3 minutos.
- **Estado vacío y errores con acción**, no solo mensajes (botones de reintento, recarga, login).

### Escalabilidad / costo

- **Free tier first.** Firestore, Render, Supabase y Firebase Auth corren en planes gratuitos; el único costo variable hoy es Meshy.
- **Pago donde duele primero.** Si crece el tráfico, el primer cuello es el cold start de Render → upgrade a plan pago sin tocar código. El esquema de Firestore ya está pensado para escalar horizontalmente (sin joins, queries por índice).
- **Egreso de modelos 3D en Supabase**, no en Firebase Storage, porque Supabase tiene egreso más barato para archivos binarios.

### Portabilidad

- Cliente Flutter compila a Android, iOS y (con ajustes menores) web — el visor `ModelViewer` ya es WebGL.
- Backend desacoplado del cliente: si se cambia Render por Railway/Fly.io, solo cambia `API_BASE_URL` en `.env`.
- Los modelos 3D viven en un bucket externo (Supabase); migrar a otro CDN es cambiar el host en el backend, no en la app.

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
