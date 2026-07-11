# Setup Appwrite — Nexus Campus

Script que crea en tu proyecto Appwrite todo lo que antes estaba en Supabase:

| Recurso | IDs |
|---------|-----|
| Database | `nexus_campus` |
| Collections | `profiles`, `trips`, `trip_requests`, `vehicles`, `messages`, `ratings`, `sos_alerts`, `emergency_contacts` |
| Buckets | `avatars`, `vehicles` |

También imprime la checklist de **verificación de email** y **recuperar contraseña**.

Colecciones: `profiles`, `trips`, `trip_requests`, `vehicles` (con `approval_status`, `license_photo_url`), `messages` (`is_system`), `notifications`, `ratings`, `sos_alerts`, `emergency_contacts`.

## 1. Crear API Key en Appwrite

Console → **Overview** → **API Keys** → Create:

Scopes recomendados:
- `databases.read`, `databases.write`
- `collections.read`, `collections.write`
- `attributes.read`, `attributes.write`
- `indexes.read`, `indexes.write`
- `buckets.read`, `buckets.write`
- `files.read`, `files.write`
- `users.read` (solo para validar la key)

## 2. Configurar `.env` del script

```bash
cd scripts/appwrite
copy .env.example .env
```

Edita `.env`:

```
APPWRITE_ENDPOINT=https://cloud.appwrite.io/v1
APPWRITE_PROJECT_ID=xxxxx
APPWRITE_API_KEY=xxxxx
APPWRITE_DATABASE_ID=nexus_campus
```

> Si usas Appwrite self-hosted, cambia el endpoint (ej. `https://tu-servidor/v1`).

## 3. Ejecutar

### Opción A — PowerShell (recomendado en Windows, no necesita Node)

```powershell
cd scripts\appwrite
.\setup.ps1
```

### Opción B — Node.js

```bash
npm install
npm run setup
```

El script es **idempotente**: si vuelves a correrlo, no duplica resources (omite lo que ya existe).

## 4. Auth (confirmación + reset)

En Console → **Auth** → **Settings**:

1. Activar **Email verification**
2. Agregar redirect URLs:
   - `https://nexus-five-chi.vercel.app/auth-callback.html`
   - `https://nexus-five-chi.vercel.app/reset-password.html`
3. (Opcional) Configurar SMTP

La app usará:
- `Account.createVerification(url)` al registrarse
- `Account.createRecovery(email, url)` en “olvidé mi contraseña”
- Las páginas web `auth-callback.html` / `reset-password.html` completan el flujo con `userId` + `secret`

### Borrar un usuario de prueba

Borrar el documento en **Databases → profiles** NO elimina la cuenta.
Hay que borrarla en **Auth → Users**, o con:

```powershell
cd scripts\appwrite
.\delete-user.ps1 -Email "usuario@epn.edu.ec"
```

(La API key del `.env` necesita scope `users.write`.)

## 5. Variables para la app Flutter

Después del setup, el `.env` de la raíz del proyecto debe tener:

```
APPWRITE_ENDPOINT=https://cloud.appwrite.io/v1
APPWRITE_PROJECT_ID=xxxxx
APPWRITE_DATABASE_ID=nexus_campus
```

(No pongas la API key en la app móvil; solo endpoint + project id.)
