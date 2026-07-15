# Nexus Campus

Aplicación móvil de **carpooling universitario** para la Escuela Politécnica Nacional (EPN). Conecta estudiantes verificados (`@epn.edu.ec`) para compartir viajes cortos, con mapa en tiempo real, solicitudes de cupo, chat, calificaciones y botón SOS.

**Versión:** 1.2.13+25  
**Stack:** Flutter · Riverpod · GoRouter · Appwrite · OpenStreetMap / OSRM / Nominatim  
**Repositorio:** https://github.com/Carl0sq12/Nexus-EPN

## Requisitos

- Flutter SDK `^3.11.5` ([flutter.dev](https://docs.flutter.dev/get-started/install))
- Cuenta y proyecto en [Appwrite Cloud](https://cloud.appwrite.io) (o instancia self-hosted)
- Node.js 18+ (solo para aprovisionar colecciones/buckets con el script de setup)
- Dispositivo Android / emulador (la distribución actual del prototipo es APK)

```bash
flutter doctor
```

## Instalación

```bash
git clone https://github.com/Carl0sq12/Nexus-EPN.git
cd Nexus-EPN
flutter pub get
```

## Configuración

La app carga variables desde `assets/env/appwrite.env` (incluido en el build). En desarrollo también acepta un `.env` en la raíz.

1. Copia el ejemplo:

```bash
copy .env.example .env
copy .env.example assets\env\appwrite.env
```

2. Completa al menos:

| Variable | Descripción |
|----------|-------------|
| `APPWRITE_ENDPOINT` | URL del API (ej. `https://cloud.appwrite.io/v1`) |
| `APPWRITE_PROJECT_ID` | ID del proyecto Appwrite |
| `APPWRITE_DATABASE_ID` | Por defecto `nexus_campus` |
| `APPWRITE_BUCKET_AVATARS` | Bucket de fotos (por defecto `avatars`) |
| `APPWRITE_BUCKET_VEHICLES` | Puede reutilizar `avatars` en plan gratuito |

3. Aprovisiona backend (colecciones, índices, buckets):

```bash
cd scripts/appwrite
copy .env.example .env
# Edita .env con APPWRITE_ENDPOINT, APPWRITE_PROJECT_ID y APPWRITE_API_KEY
node setup.mjs
# En Windows también: .\setup.ps1
```

La API key del script necesita permisos de databases, collections, attributes, indexes, buckets y files.

## Ejecución

```bash
# Dispositivo / emulador conectado
flutter run

# APK de release
flutter build apk --release
```

El APK queda en `build/app/outputs/flutter-apk/app-release.apk`.

### Verificación rápida

1. Registrar usuario con correo `@epn.edu.ec`
2. Completar onboarding (perfil, contactos de emergencia, vehículo si es conductor)
3. Publicar o solicitar un viaje y revisar documentos en Appwrite (`trips`, `trip_requests`, etc.)

## Estructura del proyecto

```
lib/
  core/           # config Appwrite, tema, utilidades (geo_fare, etc.)
  features/       # auth, trips, requests, map, chat, ratings, sos, ...
scripts/appwrite/ # setup idempotente del backend
assets/env/       # variables de entorno empaquetadas
```

Arquitectura: Clean Architecture por feature (`domain` / `data` / `presentation`).

## Tarifas (app)

Implementadas en `lib/core/utils/geo_fare.dart`:

- Base: **$0.80**
- Por km: **$0.45**
- Mínimo: **$1.00**
- Precio sugerido por asiento = tarifa total / asientos

La comisión del 10 % forma parte del **modelo financiero proyectado**; no se cobra automáticamente en la app actual.

## Documentación del examen

- Documentación de negocio y técnica: `Nexus_Campus_Documentacion` (Word del equipo)
- Pitch deck: `docs/Nexus_Campus_Pitch_Deck.pptx`
- Video promocional: enlace en la documentación / carpeta de entregables del curso

## Licencia

Proyecto académico — EPN · Desarrollo de Aplicaciones Móviles.
