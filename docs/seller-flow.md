# Flujo del vendedor

## Pantallas involucradas

1. `_SellEntry` (en `main.dart`) — entrada al tab "Vender" cuando hay sesión.
2. `SellProductScreen` — formulario de publicación.
3. `ProcessingScreen` — pantalla de progreso tras publicar.
4. Perfil → pestaña "Míos" (`_MyProductsTab` en `main.dart`) — gestión post-publicación.

## Paso a paso

### 1. Login obligatorio

`_SellEntry` muestra el botón "Iniciar sesión con Google" si `AuthProvider.user == null`. Solo después de autenticarse aparece "Empezar publicación".

### 2. Formulario (`SellProductScreen`)

Campos requeridos:

- `title` — mínimo 3 caracteres.
- `price` — > 0.
- `category` — enum `ProductCategory` (Muebles, Decoración, Electrodomésticos, Iluminación, Otros).
- `photos` — entre 2 y 4, desde cámara o galería.
- `description` — opcional.

Toda la validación está en `ProductDraft.validationError`. El estado se mantiene en `SellerProvider`.

### 3. Publicar

Toca **Publicar** → `SellerProvider.submit()`:

```
SellerProvider.submit
 ├─ valida draft
 ├─ POST /api/v1/products/create  (multipart con fotos)
 ├─ guarda productId, productStatus
 ├─ state = waitingForModel
 └─ inicia polling cada 5s a GET /products/{id}/status
```

La UI navega a `ProcessingScreen` que reacciona al `SellerProvider`.

### 4. Polling y progreso

`SellerProvider._checkStatus` actualiza `_latestStatus.progress` (0-100) y `_state`:

- `waitingForModel` mientras Meshy procesa.
- `ready` cuando el endpoint devuelve `status=ready`.
- `failed` si `status=failed`.

`ProcessingSteps` (widget) muestra los 3 pasos con el porcentaje:
1. Subir fotos ✓
2. Publicar producto ✓
3. **Meshy AI procesando... 42%**

Cuando llega a `ready` se cancela el timer y se muestra "Modelo listo, ver producto".

### 5. Mientras tanto, el catálogo

Desde el momento en que `productStatus == 'published'` el producto aparece en el catálogo (sin esperar al modelo 3D). El badge "3D · AR" solo aparece cuando `model3d.status == 'ready'`. Antes de eso, los compradores que abran el detalle ven el chip animado "Generando vista 3D · X%" (ver [`buyer-flow.md`](buyer-flow.md)).

## Gestión post-publicación: pestaña "Míos"

En **Perfil → Míos** el vendedor ve sus productos publicados. Por cada uno hay un menú de tres puntos:

| Acción | Efecto |
|---|---|
| **Ver** | Abre el `ProductDetailScreen`. |
| **Editar** | Diálogo simple para cambiar `title`, `description`, `price`. Escribe directo a `products/{id}` con `update`. |
| **Despublicar** | `update({status: 'unpublished'})`. El producto desaparece del catálogo público (filtra por `status == 'published'`) pero **conserva el modelo 3D** en Supabase. |
| **Republicar** | Reaparece cuando `status != 'published'`. Vuelve a `update({status: 'published'})`. |

La query es `products where sellerId == user.uid` sin `orderBy` (ordena client-side) para no requerir índice compuesto en Firestore.

## Reglas Firestore que el flujo necesita

```js
match /products/{productId} {
  allow read: if true;
  allow create: if request.auth != null && request.resource.data.sellerId == request.auth.uid;
  allow update, delete: if request.auth != null && resource.data.sellerId == request.auth.uid;
}
```

Sin esto, Editar/Despublicar darán `permission-denied`.
