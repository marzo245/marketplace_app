# Setup local

## Requisitos

- **Flutter** ≥ 3.22 (`flutter --version`).
- **Android Studio** o **Xcode** según plataforma.
- Cuenta Firebase con proyecto `marketplace-e7d4e` (o uno propio).
- Backend corriendo (local o el deploy en Render).

## Pasos

### 1. Dependencias

```bash
flutter pub get
```

### 2. Variables de entorno

```bash
cp .env.example .env
```

Edita `.env`:

```
FIREBASE_PROJECT_ID=marketplace-e7d4e
API_BASE_URL=http://10.0.2.2:3000     # emulador Android → localhost del host
API_TIMEOUT_SECONDS=30
DEBUG_MODE=true
```

URLs típicas para `API_BASE_URL`:

| Entorno | Valor |
|---|---|
| Emulador Android, backend local | `http://10.0.2.2:3000` |
| Simulador iOS, backend local | `http://localhost:3000` |
| Dispositivo físico, backend en LAN | `http://<IP-LAN>:3000` |
| Producción | `https://marketplace-backend-sn06.onrender.com` |

Si `.env` no existe o `API_BASE_URL` está vacío, el cliente cae al deploy de Render por defecto (ver `lib/services/api_client.dart`).

### 3. Firebase

Necesitas los archivos de config para cada plataforma:

- **Android**: `android/app/google-services.json`
- **iOS**: `ios/Runner/GoogleService-Info.plist`

La forma recomendada es usar **flutterfire**:

```bash
dart pub global activate flutterfire_cli
flutterfire configure --project=marketplace-e7d4e
```

Esto genera además `lib/firebase_options.dart` (ya está en el repo apuntando al proyecto `marketplace-e7d4e`).

### 4. Permisos nativos

Ya configurados en el repo, pero por referencia:

**Android** (`android/app/src/main/AndroidManifest.xml`):
- `INTERNET`
- `CAMERA`
- `READ_MEDIA_IMAGES` / `READ_EXTERNAL_STORAGE`
- `POST_NOTIFICATIONS` (Android 13+)

**iOS** (`ios/Runner/Info.plist`):
- `NSCameraUsageDescription`
- `NSPhotoLibraryUsageDescription`
- `NSPhotoLibraryAddUsageDescription`

### 5. Correr la app

```bash
flutter run                # selecciona dispositivo/emulador
```

Hot reload con `r`, **hot restart con `R`** (necesario cuando cambian providers, themes, o initState).

## Modo demo (sin Firebase)

Si Firebase no inicializa (timeout en `Firebase.initializeApp`), la app entra en `demoMode`:
- Muestra placeholders en Vender y Perfil con texto "Modo demo activo".
- El catálogo se sirve con productos hardcodeados (ver `catalog_screen.dart`).

Útil para revisar UI sin cuenta Firebase configurada.

## Build de producción

```bash
flutter build apk --release         # Android
flutter build appbundle --release   # Android para Play Store
flutter build ios --release         # iOS (luego archive en Xcode)
```

Para iOS recuerda:
- Apple Developer team configurado en Xcode.
- `usdz` requiere que el servidor entregue `Content-Type: model/vnd.usdz+zip` para que AR Quick Look lo abra correctamente. (Tarea del backend / Supabase Storage).
