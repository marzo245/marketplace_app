# Servicios externos

## Backend propio (Render)

- **URL prod**: `https://marketplace-backend-sn06.onrender.com`
- **Stack**: Node.js + Express (ver repo del backend).
- **Hosting**: [Render.com](https://render.com), plan free → tiene **cold start** de ~30-60s tras inactividad. Por eso `api_client.dart` tiene `connectTimeout: 60s` y `receiveTimeout: 3min`.

Endpoints que el cliente consume (definidos en `lib/services/api_client.dart`):

| Método | Path | Uso |
|---|---|---|
| `POST` | `/api/v1/products/create` | Subir fotos y crear job Meshy. |
| `GET`  | `/api/v1/products/{id}/status` | Consultar progreso del modelo 3D. |

Headers requeridos:
- `Authorization: Bearer <Firebase idToken>` — el backend valida el token con el Admin SDK de Firebase para identificar al vendedor.
- `Accept: application/json`

## Meshy AI

Servicio externo que **convierte fotos en modelos 3D** (formatos `.glb` para Android/web y `.usdz` para iOS).

- **El cliente Flutter no habla con Meshy directamente.** Toda la integración está en el backend.
- El backend envía el job y queda esperando un webhook de Meshy con el resultado.
- Tiempo típico: 1-3 minutos por modelo.
- El campo `progress` (0-100) que el cliente lee con `getProductStatus` proviene de la API de progreso de Meshy reflejada por el backend.

## Firebase

**Project ID**: `marketplace-e7d4e`

### Firebase Auth

- Único proveedor habilitado: **Google Sign-In** (`AuthService.signInWithGoogle`).
- El cliente obtiene `idToken` con `user.getIdToken()` en `AuthProvider._syncSession` y lo inyecta como Bearer en el `ApiClient`.
- El stream usado es `idTokenChanges()` (no `authStateChanges`) para refrescar el token cuando expira.

### Firestore

Base de datos principal. Colecciones (detalle en [`firestore-schema.md`](firestore-schema.md)):

- `products` — catálogo público.
- `users/{uid}/favorites` — favoritos por usuario.
- `users/{uid}` — perfil + `fcmTokens`.
- `purchase_intents` — solicitudes de compra (vista por vendedor y comprador).
- `product_inquiries` — solicitudes de "Contactar" del comprador al vendedor.

### Firebase Cloud Messaging (FCM)

- `PushService.registerForUser(uid)` pide permisos, obtiene el token del dispositivo y lo guarda en `users/{uid}.fcmTokens` (array union para soportar múltiples dispositivos).
- En logout limpia el token con `arrayRemove`.
- El backend envía push cuando el modelo 3D queda listo (lee los tokens del seller desde `users/{uid}.fcmTokens`).

### Firebase Storage

> **Nota**: el cliente actualmente no sube ni descarga directamente desde Firebase Storage. Las fotos viajan vía multipart al backend, y los modelos 3D se sirven desde Supabase. Si en el futuro se mueven a Firebase Storage, este apartado debe actualizarse.

## Supabase

Usado por el **backend** para almacenar los archivos `.glb` y `.usdz` que produce Meshy. El cliente solo recibe URLs públicas (`glbUrl`, `usdzUrl`) en la respuesta del API y las consume:

- `glbUrl` → cargado en `ModelViewer` (visor inline) y como `file=` en el deep link de Scene Viewer.
- `usdzUrl` → cargado por AR Quick Look en iOS al abrir el URL directo.

> Si tu backend además usa Supabase para otra cosa (auth, base de datos secundaria, edge functions), agrégalo aquí. Por ahora el cliente solo lo "ve" como un host de archivos estáticos.

## Resumen de credenciales y dónde van

| Credencial / Config | Dónde | Notas |
|---|---|---|
| Firebase project (`google-services.json`, `GoogleService-Info.plist`) | `android/app/`, `ios/Runner/` | Generados con `flutterfire configure`. |
| API base URL | `.env` → `API_BASE_URL` | Si falta, cae a la URL de Render hardcodeada en `api_client.dart`. |
| Meshy API key | **solo backend** | Nunca debe estar en el cliente. |
| Supabase service role | **solo backend** | Las URLs públicas de Storage sí pueden viajar al cliente. |
