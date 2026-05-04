# Troubleshooting

## Firestore: `FAILED_PRECONDITION: The query requires an index`

Combinaste `where` + `orderBy` (o varios `where`) sin tener el índice compuesto. El log incluye un link directo:

```
https://console.firebase.google.com/v1/r/project/marketplace-e7d4e/firestore/indexes?create_composite=...
```

Abrirlo en el navegador y darle "Crear" resuelve.

Alternativamente, **ordena client-side** (es lo que hacemos en `_MyProductsTab` y en `SellerProfileScreen`): quita el `orderBy` y haz `.sort(...)` después.

## Layout: `RenderBox was not laid out` / `Cannot hit test a render box that has never been laid out`

Causa típica en este proyecto: un widget exigía ancho infinito (`Size.fromHeight(N)` que internamente es `Size(double.infinity, N)`) dentro de un padre con ancho ilimitado (cualquier `Row` no envuelto en `Expanded`).

Donde lo arreglamos:
- `lib/theme/app_theme.dart` — el theme global de `FilledButton` ya no usa `Size.fromHeight`; usa `padding` vertical.
- En el header del perfil, el botón "Cerrar sesión" trae su propio `minimumSize: Size(0, 40)`.
- Reemplazamos `SegmentedButton` por chips custom (`_ProfileTabChip`) por el mismo motivo.

Si vuelve a salir:
1. **Hot restart**, no hot reload (`R` mayúscula). Los cambios de theme y de `initState` no aplican con reload.
2. Busca el primer error en el log con `EXCEPTION CAUGHT BY RENDERING LIBRARY` y mira la sección `creator:`. Te dice qué widget fue.
3. Si el `creator` es un `FilledButton` dentro de un `Row`, dale `style: FilledButton.styleFrom(minimumSize: Size(0, 40))` o envuélvelo en `Expanded` / `SizedBox` con ancho explícito.

## "No se pudo cargar el perfil del vendedor"

Era el mismo problema de índice Firestore (combinaba `status + sellerId + createdAt`). Resuelto: la query ya no lleva `orderBy`, ordena client-side.

## Cold start del backend (Render free)

Los logs muestran tiempos altos en la primera request tras inactividad (~30-60s). El cliente lo aguanta porque `api_client.dart` configura `connectTimeout: 60s` y `receiveTimeout: 3min`. Si quieres evitarlo: paga el plan starter de Render o usa un cron pinger.

## AR no se abre en iOS

Verifica que el archivo `.usdz` se sirve con `Content-Type: model/vnd.usdz+zip`. Sin ese header, iOS lo trata como descarga genérica y no abre AR Quick Look.

Test rápido:
```bash
curl -I <usdzUrl>
# busca: Content-Type: model/vnd.usdz+zip
```

Si Supabase Storage está sirviendo `application/octet-stream`, configura el bucket o agrega `Content-Disposition`/`Content-Type` al subir.

## AR no se abre en Android (mensaje "Vista AR no disponible")

El usuario no tiene **Google Play Services for AR** (ARCore). El `SnackBar` que sale ofrece un botón "Instalar ARCore" que abre la Play Store en `com.google.ar.core`.

## Polling del progreso 3D no avanza

1. Confirma en consola las líneas `[ArProcessingChip] <id> status=... progress=...` — si las ves, el polling corre y el problema es UI.
2. Si ves `[ArProcessingChip] poll failed: ...` → el endpoint del backend está rechazando o el cold start tardó más de 60s. Reintenta tras unos segundos.
3. Si **no ves nada**: probablemente no hiciste hot restart después del último cambio. `R` mayúscula.

## Login con Google no funciona

- Verifica `SHA-1` y `SHA-256` del keystore registrados en Firebase Console (Project Settings → tu app Android → SHA certificate fingerprints).
- Para release builds usa el SHA del keystore de producción, no el debug.
- En iOS necesitas el `URL Scheme` reverso del `GoogleService-Info.plist` en el `Info.plist`.

## Push notifications no llegan

- En Android 13+ el usuario debe aceptar el permiso `POST_NOTIFICATIONS` (lo solicitamos en `PushService.registerForUser`).
- En iOS el simulador **no recibe** push reales — prueba en dispositivo físico.
- Verifica que el doc `users/{uid}` tenga el array `fcmTokens` con un valor (lo escribe `PushService` al iniciar sesión).
- El backend tiene que iterar esos tokens y enviarles via FCM HTTP v1 API o el Admin SDK.

## "Inicio de sesión cancelado"

El usuario cerró el diálogo de Google. No es bug — solo muestra el mensaje en `AuthProvider.error`.
