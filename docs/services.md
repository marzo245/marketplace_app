# Servicios externos

## Backend propio

- **URL prod**: `https://marketplace-backend-sn06.onrender.com`
- **Stack**: Node.js + Express
- **Codigo presente en este proyecto**: `meshy-worker/`

Aunque la app Flutter solo "ve" una API HTTP, internamente el backend usa:

- **BullMQ** para la cola de generacion 3D
- **Redis** como backend de la cola
- **Worker** separado para procesar jobs

Endpoints que el cliente consume:

| Metodo | Path | Uso |
|---|---|---|
| `POST` | `/api/v1/products/create` | Subir fotos, crear producto y encolar job Meshy |
| `GET` | `/api/v1/products/{id}/status` | Consultar progreso y resultado del modelo 3D |

Headers:

- `Accept: application/json`
- `Authorization: Bearer <Firebase idToken>` para publicar

Nota importante:

- El cliente hoy envia el Bearer token en general cuando hay sesion.
- El backend **si exige auth** en `POST /api/v1/products/create`.
- El backend **no exige auth hoy** en `GET /api/v1/products/{id}/status`.

## BullMQ + Redis

Arquitectura real del procesamiento:

1. La API recibe fotos y metadata del producto.
2. Sube fotos a Cloudinary.
3. Crea el documento en Firestore con `model3d.status = queued`.
4. Encola un job BullMQ en `3d-generation`.
5. Un worker consume el job desde Redis.
6. El worker reserva creditos, crea la tarea en Meshy y guarda `meshyTaskId`.
7. Meshy llama al webhook cuando termina.
8. El backend descarga y guarda `.glb` y `.usdz`, actualiza Firestore y envia FCM.

Configuracion visible hoy:

- reintentos: `attempts = 3`
- backoff exponencial: `delay = 15000`
- concurrencia del worker: `2`
- rate limit del worker: `10 jobs / minuto`

## Meshy AI

Servicio externo que convierte fotos en modelos 3D.

- El cliente Flutter no habla con Meshy directamente.
- La API encola el trabajo.
- El worker crea la tarea remota en Meshy.
- El backend recibe el resultado via webhook.
- Durante `/status`, el backend puede refrescar progreso consultando Meshy si el modelo sigue `queued` o `processing`.

## Firebase

**Project ID**: `marketplace-e7d4e`

### Firebase Auth

- proveedor principal: Google Sign-In
- el cliente obtiene `idToken` y lo inyecta en el `ApiClient`
- el backend valida el token con `firebase-admin` cuando la ruta lo requiere

### Firestore

Base de datos principal.

- `products`
- `users/{uid}`
- `users/{uid}/favorites`
- `purchase_intents`
- `product_inquiries`

Tambien guarda el estado del flujo 3D:

- `model3d.status`
- `model3d.progress`
- `model3d.meshyTaskId`
- `model3d.glbUrl`
- `model3d.usdzUrl`
- `model3d.error`

### Firebase Cloud Messaging

- el cliente registra `fcmTokens` en `users/{uid}`
- el backend lee esos tokens y envia push cuando el modelo queda listo

### Firebase Storage

No es el storage primario documentado para modelos, pero **si existe como fallback real** en backend.

Se usa cuando no estan configuradas las variables de Supabase Storage.

## Cloudinary

Cloudinary se usa para las **fotos del producto** subidas desde el formulario multipart.

- el cliente no sube directo a Cloudinary
- la API recibe las fotos
- luego las sube a `marketplace/products/{productId}/photos`

## Storage de modelos 3D

Hoy hay dos caminos posibles:

### Supabase Storage

Se usa si existen:

- `SUPABASE_URL`
- `SUPABASE_SECRET_KEY`
- `SUPABASE_STORAGE_BUCKET`

En ese caso, el backend sube `model.glb` y `model.usdz` y devuelve URLs publicas.

### Firebase Storage fallback

Si la configuracion de Supabase no existe, el backend guarda los modelos en Firebase Storage y genera una URL con token de descarga.

Eso significa que la documentacion no debe asumir que todos los despliegues usan siempre Supabase.

## Hosting

La URL productiva documentada apunta a Render y el cliente tiene timeouts largos por cold start. Pero el repo tambien tiene señales de despliegue para otros escenarios:

- `docker-compose.yml` para local con `api`, `worker` y `redis`
- `railway.toml` en `meshy-worker/`

## Resumen de credenciales

| Credencial / Config | Donde | Notas |
|---|---|---|
| Firebase app config | `android/app/`, `ios/Runner/` | Generados con `flutterfire configure` |
| API base URL | `.env` -> `API_BASE_URL` | Si falta, cae a la URL de Render hardcodeada |
| Firebase idToken | Cliente | Se manda como Bearer al backend |
| Meshy API key | Solo backend | Nunca debe vivir en cliente |
| REDIS_URL | Solo backend | Necesaria para BullMQ |
| Cloudinary creds | Solo backend | Para fotos |
| Supabase service role | Solo backend | Solo si se usa Supabase Storage |
