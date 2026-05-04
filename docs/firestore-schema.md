# Esquema Firestore

Project ID: `marketplace-e7d4e`.

## `products/{productId}`

Doc principal por producto. Lo crea el **backend** después del upload (no el cliente directamente).

| Campo | Tipo | Notas |
|---|---|---|
| `title` | string | |
| `description` | string | |
| `price` | number | en COP. |
| `category` | string | slug: `muebles`, `decoracion`, `electro`, `iluminacion`, `otros`. |
| `sellerId` | string | uid del vendedor (Firebase Auth). |
| `sellerName` | string? | snapshot del nombre al publicar. |
| `sellerRating` | number? | reservado para futuro. |
| `photos` | `string[]` | URLs de las fotos originales. |
| `model3d` | map? | ver subdocumento abajo. |
| `status` | string | `published` (visible) / `unpublished` (oculto del catálogo). |
| `createdAt` | timestamp | server timestamp. |

### `model3d` (subdoc)

| Campo | Tipo | Notas |
|---|---|---|
| `status` | string | `queued`, `processing`, `ready`, `failed`. |
| `glbUrl` | string? | URL pública en Supabase Storage. |
| `usdzUrl` | string? | idem para iOS Quick Look. |
| `thumbnailUrl` | string? | preview opcional. |

`ProductListing.hasAr == true` ⟺ `model3d.status == 'ready'` y `glbUrl != null`.

## `users/{uid}`

Doc por usuario (lo escribe `PushService`):

| Campo | Tipo | Notas |
|---|---|---|
| `fcmTokens` | `string[]` | tokens FCM (array union/remove). |
| `updatedAt` | timestamp | server timestamp. |

## `users/{uid}/favorites/{productId}`

Subcolección de favoritos por usuario:

| Campo | Tipo |
|---|---|
| `productId` | string |
| `title` | string |
| `price` | number |
| `photo` | string |
| `sellerId` | string |
| `createdAt` | timestamp |

Snapshot mínimo para mostrar la lista sin tener que leer el doc del producto.

## `purchase_intents/{autoId}`

Solicitudes de compra del comprador al vendedor. Las lee tanto el comprador (Enviadas) como el vendedor (Recibidas).

| Campo | Tipo |
|---|---|
| `type` | `'purchase_intent'` |
| `status` | `'new'` / `'accepted'` / `'rejected'` / `'completed'` |
| `productId` | string |
| `productTitle` | string |
| `productPrice` | number |
| `sellerId` | string |
| `sellerName` | string? |
| `buyerId` | string |
| `buyerName` | string? |
| `buyerEmail` | string? |
| `createdAt` | timestamp |
| `updatedAt` | timestamp |

## `product_inquiries/{autoId}`

Igual estructura que `purchase_intents` pero con `type: 'contact_request'`. Hoy no se lee desde la UI, queda almacenado para futura bandeja de mensajes.

## Índices compuestos requeridos

Cuando una query combina **múltiples `where`** + `orderBy`, Firestore exige un índice compuesto. Los actuales:

| Colección | Campos | Para |
|---|---|---|
| `products` | `status (ASC) + category (ASC) + createdAt (DESC)` | Catálogo filtrado por categoría. |
| `products` | `status (ASC) + model3d.status (ASC) + createdAt (DESC)` | Filtro "Con vista 3D". |

Los queries de **perfil de vendedor** (`status + sellerId + createdAt`) y **mis productos** (`sellerId`) **se ordenan client-side** para evitar índices adicionales.

Cuando una query falla por índice faltante, Firestore loguea un link `https://console.firebase.google.com/.../indexes?create_composite=...`. Abrirlo en el navegador crea el índice con un click.

## Reglas mínimas sugeridas

```js
rules_version = '2';
service cloud.firestore {
  match /databases/{db}/documents {

    match /products/{productId} {
      allow read: if true;
      allow create: if request.auth != null
        && request.resource.data.sellerId == request.auth.uid;
      allow update, delete: if request.auth != null
        && resource.data.sellerId == request.auth.uid;
    }

    match /users/{uid} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.uid == uid;

      match /favorites/{productId} {
        allow read, write: if request.auth != null && request.auth.uid == uid;
      }
    }

    match /purchase_intents/{id} {
      allow read: if request.auth != null
        && (resource.data.buyerId == request.auth.uid
            || resource.data.sellerId == request.auth.uid);
      allow create: if request.auth != null
        && request.resource.data.buyerId == request.auth.uid;
      allow update: if request.auth != null
        && resource.data.sellerId == request.auth.uid;
    }

    match /product_inquiries/{id} {
      allow read, write: if request.auth != null;
    }
  }
}
```

> Ajusta según las decisiones reales de privacidad. Por ejemplo, si quieres que el vendedor pueda leer los datos básicos del comprador para contactar, déjalo así. Si no, restrínjelo más.
