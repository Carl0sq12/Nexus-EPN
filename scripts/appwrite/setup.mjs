/**
 * Nexus Campus — Setup completo de Appwrite
 *
 * Crea:
 *  - Database: nexus_campus
 *  - Collections: profiles, trips, trip_requests, vehicles, messages,
 *                 ratings, sos_alerts, emergency_contacts
 *  - Indexes necesarios
 *  - Buckets: avatars, vehicles
 *
 * Auth (verificación de email + recuperar contraseña):
 *  Se configura en la consola (el script imprime la checklist).
 *  La app usará Account.createVerification / createRecovery.
 *
 * Uso:
 *   1. Copia .env.example → .env y pega endpoint, project id y API key
 *   2. npm install
 *   3. npm run setup
 */

import { readFileSync, existsSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  Client,
  Databases,
  Storage,
  Users,
  ID,
  Permission,
  Role,
} from 'node-appwrite';

const __dirname = dirname(fileURLToPath(import.meta.url));

function loadEnv() {
  const envPath = resolve(__dirname, '.env');
  if (!existsSync(envPath)) {
    console.error('❌ Falta scripts/appwrite/.env');
    console.error('   Copia .env.example → .env y completa APPWRITE_*');
    process.exit(1);
  }
  const text = readFileSync(envPath, 'utf8');
  for (const line of text.split(/\r?\n/)) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) continue;
    const eq = trimmed.indexOf('=');
    if (eq === -1) continue;
    const key = trimmed.slice(0, eq).trim();
    const value = trimmed.slice(eq + 1).trim();
    if (!process.env[key]) process.env[key] = value;
  }
}

loadEnv();

const ENDPOINT = process.env.APPWRITE_ENDPOINT;
const PROJECT_ID = process.env.APPWRITE_PROJECT_ID;
const API_KEY = process.env.APPWRITE_API_KEY;
const DATABASE_ID = process.env.APPWRITE_DATABASE_ID || 'nexus_campus';

if (!ENDPOINT || !PROJECT_ID || !API_KEY) {
  console.error('❌ APPWRITE_ENDPOINT, APPWRITE_PROJECT_ID y APPWRITE_API_KEY son obligatorios');
  process.exit(1);
}

const client = new Client()
  .setEndpoint(ENDPOINT)
  .setProject(PROJECT_ID)
  .setKey(API_KEY);

const databases = new Databases(client);
const storage = new Storage(client);
const users = new Users(client);

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function waitUntil(fn, { label, attempts = 40, delayMs = 1500 } = {}) {
  let lastError;
  for (let i = 0; i < attempts; i++) {
    try {
      return await fn();
    } catch (e) {
      lastError = e;
      process.stdout.write(`   … esperando ${label} (${i + 1}/${attempts})\r`);
      await sleep(delayMs);
    }
  }
  throw lastError ?? new Error(`Timeout esperando: ${label}`);
}

function isAlreadyExists(error) {
  const code = error?.code ?? error?.response?.code;
  const type = error?.type ?? '';
  return code === 409 || String(type).includes('already_exists');
}

async function ensureDatabase() {
  try {
    await databases.get(DATABASE_ID);
    console.log(`✓ Database ya existe: ${DATABASE_ID}`);
  } catch {
    await databases.create(DATABASE_ID, 'Nexus Campus');
    console.log(`✓ Database creada: ${DATABASE_ID}`);
  }
}

async function ensureCollection({
  id,
  name,
  documentSecurity = true,
  permissions = [
    Permission.read(Role.any()),
    Permission.create(Role.users()),
    Permission.update(Role.users()),
    Permission.delete(Role.users()),
  ],
}) {
  try {
    await databases.getCollection(DATABASE_ID, id);
    console.log(`✓ Collection ya existe: ${id}`);
  } catch {
    await databases.createCollection(
      DATABASE_ID,
      id,
      name,
      permissions,
      documentSecurity,
    );
    console.log(`✓ Collection creada: ${id}`);
  }
}

async function ensureAttribute(collectionId, def) {
  const { key, type } = def;
  try {
    // Si ya existe, getAttributes y buscar
    const attrs = await databases.listAttributes(DATABASE_ID, collectionId);
    if (attrs.attributes.some((a) => a.key === key)) {
      return;
    }
  } catch {
    // continuar a crear
  }

  try {
    switch (type) {
      case 'string':
        await databases.createStringAttribute(
          DATABASE_ID,
          collectionId,
          key,
          def.size ?? 255,
          def.required ?? false,
          def.defaultValue,
          def.array ?? false,
        );
        break;
      case 'integer':
        await databases.createIntegerAttribute(
          DATABASE_ID,
          collectionId,
          key,
          def.required ?? false,
          def.min,
          def.max,
          def.defaultValue,
          def.array ?? false,
        );
        break;
      case 'float':
        await databases.createFloatAttribute(
          DATABASE_ID,
          collectionId,
          key,
          def.required ?? false,
          def.min,
          def.max,
          def.defaultValue,
          def.array ?? false,
        );
        break;
      case 'boolean':
        await databases.createBooleanAttribute(
          DATABASE_ID,
          collectionId,
          key,
          def.required ?? false,
          def.defaultValue,
          def.array ?? false,
        );
        break;
      case 'datetime':
        await databases.createDatetimeAttribute(
          DATABASE_ID,
          collectionId,
          key,
          def.required ?? false,
          def.defaultValue,
          def.array ?? false,
        );
        break;
      case 'email':
        await databases.createEmailAttribute(
          DATABASE_ID,
          collectionId,
          key,
          def.required ?? false,
          def.defaultValue,
          def.array ?? false,
        );
        break;
      case 'enum':
        await databases.createEnumAttribute(
          DATABASE_ID,
          collectionId,
          key,
          def.elements,
          def.required ?? false,
          def.defaultValue,
          def.array ?? false,
        );
        break;
      default:
        throw new Error(`Tipo de atributo no soportado: ${type}`);
    }
    console.log(`  + attribute ${collectionId}.${key} (${type})`);
  } catch (e) {
    if (isAlreadyExists(e)) {
      console.log(`  · attribute ${collectionId}.${key} ya existe`);
      return;
    }
    throw e;
  }
}

async function waitAttributesAvailable(collectionId, keys) {
  await waitUntil(
    async () => {
      const attrs = await databases.listAttributes(DATABASE_ID, collectionId);
      const byKey = Object.fromEntries(attrs.attributes.map((a) => [a.key, a]));
      for (const key of keys) {
        const attr = byKey[key];
        if (!attr || attr.status !== 'available') {
          throw new Error(`${key} status=${attr?.status ?? 'missing'}`);
        }
      }
      return true;
    },
    { label: `attrs ${collectionId}` },
  );
  console.log(`  ✓ attributes ready: ${collectionId}`);
}

async function ensureIndex(collectionId, key, type, attributes, orders) {
  try {
    await databases.createIndex(
      DATABASE_ID,
      collectionId,
      key,
      type,
      attributes,
      orders,
    );
    console.log(`  + index ${collectionId}.${key}`);
  } catch (e) {
    if (isAlreadyExists(e)) {
      console.log(`  · index ${collectionId}.${key} ya existe`);
      return;
    }
    throw e;
  }
}

async function ensureBucket({
  id,
  name,
  permissions = [
    Permission.read(Role.any()),
    Permission.create(Role.users()),
    Permission.update(Role.users()),
    Permission.delete(Role.users()),
  ],
  fileSecurity = true,
  maximumFileSize = 10 * 1024 * 1024,
  allowedExtensions = ['jpg', 'jpeg', 'png', 'webp', 'heic'],
}) {
  try {
    await storage.getBucket(id);
    console.log(`✓ Bucket ya existe: ${id}`);
  } catch {
    await storage.createBucket(
      id,
      name,
      permissions,
      fileSecurity,
      true, // enabled
      maximumFileSize,
      allowedExtensions,
      undefined,
      true, // compression
      false, // encryption
      true, // antivirus
    );
    console.log(`✓ Bucket creado: ${id}`);
  }
}

/** Definición de collections = tablas de Supabase */
const COLLECTIONS = [
  {
    id: 'profiles',
    name: 'Profiles',
    // document id = user.$id
    attributes: [
      { key: 'email', type: 'email', required: false },
      { key: 'full_name', type: 'string', size: 200, required: false },
      {
        key: 'role',
        type: 'enum',
        elements: ['passenger', 'driver'],
        required: true,
        defaultValue: 'passenger',
      },
      { key: 'avatar_url', type: 'string', size: 2048, required: false },
      { key: 'phone', type: 'string', size: 40, required: false },
      { key: 'cedula', type: 'string', size: 10, required: false },
    ],
    indexes: [
      { key: 'idx_email', type: 'key', attributes: ['email'] },
      { key: 'idx_role', type: 'key', attributes: ['role'] },
      { key: 'idx_phone', type: 'key', attributes: ['phone'] },
    ],
  },
  {
    id: 'trips',
    name: 'Trips',
    attributes: [
      { key: 'driver_id', type: 'string', size: 64, required: true },
      { key: 'origin', type: 'string', size: 500, required: true },
      { key: 'destination', type: 'string', size: 500, required: true },
      { key: 'departure_time', type: 'datetime', required: true },
      { key: 'total_seats', type: 'integer', required: true, min: 1, max: 4 },
      {
        key: 'available_seats',
        type: 'integer',
        required: true,
        min: 0,
        max: 4,
      },
      { key: 'price_per_seat', type: 'float', required: true, min: 0 },
      {
        key: 'status',
        type: 'enum',
        elements: ['active', 'cancelled', 'full', 'in_progress', 'completed'],
        required: true,
        defaultValue: 'active',
      },
      { key: 'origin_latitude', type: 'float', required: false },
      { key: 'origin_longitude', type: 'float', required: false },
      { key: 'destination_latitude', type: 'float', required: false },
      { key: 'destination_longitude', type: 'float', required: false },
      { key: 'route_distance_meters', type: 'float', required: false },
      { key: 'route_duration_seconds', type: 'float', required: false },
      { key: 'route_points', type: 'string', size: 20000, required: false },
    ],
    indexes: [
      { key: 'idx_driver', type: 'key', attributes: ['driver_id'] },
      { key: 'idx_status', type: 'key', attributes: ['status'] },
      {
        key: 'idx_status_departure',
        type: 'key',
        attributes: ['status', 'departure_time'],
        orders: ['ASC', 'ASC'],
      },
      { key: 'idx_departure', type: 'key', attributes: ['departure_time'] },
    ],
  },
  {
    id: 'trip_requests',
    name: 'Trip Requests',
    attributes: [
      { key: 'trip_id', type: 'string', size: 64, required: true },
      { key: 'passenger_id', type: 'string', size: 64, required: true },
      {
        key: 'status',
        type: 'enum',
        elements: [
          'pending',
          'price_proposed',
          'accepted',
          'rejected',
          'cancelled',
        ],
        required: true,
        defaultValue: 'pending',
      },
      {
        key: 'passenger_count',
        type: 'integer',
        required: true,
        min: 1,
        max: 20,
        defaultValue: 1,
      },
      { key: 'pickup_note', type: 'string', size: 1000, required: false },
      { key: 'dropoff_note', type: 'string', size: 1000, required: false },
      { key: 'pickup_latitude', type: 'float', required: false },
      { key: 'pickup_longitude', type: 'float', required: false },
      { key: 'dropoff_latitude', type: 'float', required: false },
      { key: 'dropoff_longitude', type: 'float', required: false },
      // JSON serializado (Appwrite no tiene JSONB nativo)
      { key: 'request_stops', type: 'string', size: 10000, required: false, defaultValue: '[]' },
      { key: 'proposed_price', type: 'float', required: false, min: 0 },
      { key: 'price_note', type: 'string', size: 1000, required: false },
    ],
    indexes: [
      { key: 'idx_trip', type: 'key', attributes: ['trip_id'] },
      { key: 'idx_passenger', type: 'key', attributes: ['passenger_id'] },
      { key: 'idx_status', type: 'key', attributes: ['status'] },
      {
        key: 'idx_trip_passenger',
        type: 'key',
        attributes: ['trip_id', 'passenger_id'],
      },
    ],
  },
  {
    id: 'vehicles',
    name: 'Vehicles',
    attributes: [
      { key: 'driver_id', type: 'string', size: 64, required: true },
      { key: 'brand', type: 'string', size: 100, required: true },
      { key: 'model', type: 'string', size: 100, required: true },
      { key: 'color', type: 'string', size: 50, required: true },
      { key: 'plate', type: 'string', size: 30, required: true },
      { key: 'photo_url', type: 'string', size: 2048, required: false },
      { key: 'license_photo_url', type: 'string', size: 2048, required: false },
      {
        key: 'approval_status',
        type: 'enum',
        elements: ['pending', 'approved', 'rejected'],
        required: false,
        defaultValue: 'pending',
      },
    ],
    indexes: [
      { key: 'idx_driver', type: 'key', attributes: ['driver_id'] },
      { key: 'idx_plate', type: 'unique', attributes: ['plate'] },
      { key: 'idx_approval', type: 'key', attributes: ['approval_status'] },
    ],
  },
  {
    id: 'messages',
    name: 'Messages',
    attributes: [
      { key: 'trip_id', type: 'string', size: 64, required: true },
      { key: 'sender_id', type: 'string', size: 64, required: true },
      { key: 'content', type: 'string', size: 4000, required: true },
      { key: 'is_system', type: 'boolean', required: false, defaultValue: false },
    ],
    indexes: [
      { key: 'idx_trip', type: 'key', attributes: ['trip_id'] },
      {
        key: 'idx_trip_created',
        type: 'key',
        attributes: ['trip_id', '$createdAt'],
        orders: ['ASC', 'ASC'],
      },
    ],
  },
  {
    id: 'notifications',
    name: 'Notifications',
    attributes: [
      { key: 'user_id', type: 'string', size: 64, required: true },
      { key: 'title', type: 'string', size: 200, required: true },
      { key: 'body', type: 'string', size: 2000, required: true },
      { key: 'type', type: 'string', size: 50, required: true },
      { key: 'read', type: 'boolean', required: false, defaultValue: false },
      { key: 'related_id', type: 'string', size: 64, required: false },
    ],
    indexes: [
      { key: 'idx_user', type: 'key', attributes: ['user_id'] },
      { key: 'idx_user_created', type: 'key', attributes: ['user_id', '$createdAt'], orders: ['ASC', 'DESC'] },
    ],
  },
  {
    id: 'ratings',
    name: 'Ratings',
    attributes: [
      { key: 'trip_id', type: 'string', size: 64, required: true },
      { key: 'rater_id', type: 'string', size: 64, required: true },
      { key: 'rated_user_id', type: 'string', size: 64, required: true },
      { key: 'score', type: 'integer', required: true, min: 1, max: 5 },
      { key: 'comment', type: 'string', size: 2000, required: false },
    ],
    indexes: [
      { key: 'idx_trip', type: 'key', attributes: ['trip_id'] },
      { key: 'idx_rater', type: 'key', attributes: ['rater_id'] },
      { key: 'idx_rated', type: 'key', attributes: ['rated_user_id'] },
      {
        key: 'uniq_trip_rater_rated',
        type: 'unique',
        attributes: ['trip_id', 'rater_id', 'rated_user_id'],
      },
    ],
  },
  {
    id: 'trip_locations',
    name: 'Trip Locations',
    attributes: [
      { key: 'trip_id', type: 'string', size: 64, required: true },
      { key: 'driver_id', type: 'string', size: 64, required: true },
      { key: 'latitude', type: 'float', required: true },
      { key: 'longitude', type: 'float', required: true },
      { key: 'heading', type: 'float', required: false },
      { key: 'speed', type: 'float', required: false },
      { key: 'updated_at', type: 'datetime', required: true },
    ],
    indexes: [
      { key: 'idx_trip_id', type: 'key', attributes: ['trip_id'] },
      { key: 'idx_driver_id', type: 'key', attributes: ['driver_id'] },
      { key: 'idx_updated_at', type: 'key', attributes: ['updated_at'] },
    ],
  },
  {
    id: 'sos_alerts',
    name: 'SOS Alerts',
    attributes: [
      { key: 'user_id', type: 'string', size: 64, required: true },
      { key: 'latitude', type: 'float', required: true },
      { key: 'longitude', type: 'float', required: true },
      {
        key: 'type',
        type: 'enum',
        elements: ['personal_emergency', 'mechanical_problem'],
        required: true,
        defaultValue: 'personal_emergency',
      },
      { key: 'message', type: 'string', size: 2000, required: false },
    ],
    indexes: [{ key: 'idx_user', type: 'key', attributes: ['user_id'] }],
  },
  {
    id: 'emergency_contacts',
    name: 'Emergency Contacts',
    attributes: [
      { key: 'user_id', type: 'string', size: 64, required: true },
      { key: 'name', type: 'string', size: 200, required: true },
      { key: 'phone', type: 'string', size: 40, required: true },
      { key: 'relationship', type: 'string', size: 100, required: false },
    ],
    indexes: [{ key: 'idx_user', type: 'key', attributes: ['user_id'] }],
  },
];

async function setupCollections() {
  for (const col of COLLECTIONS) {
    console.log(`\n→ ${col.id}`);
    await ensureCollection({ id: col.id, name: col.name });

    for (const attr of col.attributes) {
      await ensureAttribute(col.id, attr);
    }

    await waitAttributesAvailable(
      col.id,
      col.attributes.map((a) => a.key),
    );

    for (const idx of col.indexes ?? []) {
      // Algunos índices con $createdAt pueden fallar según versión; no abortar todo
      try {
        await ensureIndex(
          col.id,
          idx.key,
          idx.type,
          idx.attributes,
          idx.orders,
        );
      } catch (e) {
        console.warn(
          `  ! index ${col.id}.${idx.key} omitido: ${e.message ?? e}`,
        );
      }
    }
  }
}

async function setupBuckets() {
  console.log('\n→ buckets');
  await ensureBucket({ id: 'avatars', name: 'Avatars' });
  await ensureBucket({ id: 'vehicles', name: 'Vehicles' });
}

async function authChecklist() {
  console.log('\n══════════════════════════════════════════════════');
  console.log(' AUTH — Verificación de cuenta y recuperar contraseña');
  console.log('══════════════════════════════════════════════════');
  console.log(`
En Appwrite Console → Auth → Settings:

1) Auth → Settings → Security
   - Email verification: ENABLED
   - Password recovery: ENABLED (por defecto)

2) Auth → Settings → Domains / Redirect URLs
   Agrega (ajusta a tu dominio):
   - https://nexus-five-chi.vercel.app/auth-callback.html
   - https://nexus-five-chi.vercel.app/reset-password.html
   - http://localhost:*/**   (dev)

3) Auth → Templates
   - Verification email
   - Recovery email
   (puedes personalizar el HTML)

4) SMTP (Auth → Settings → SMTP) — recomendado en producción
   Sin SMTP, Appwrite Cloud usa su mailer con límites.

Desde la app Flutter (Account API):
   - Registro: account.create(...)
   - Enviar verificación: account.createVerification(url)
   - Completar verificación (web): account.updateVerification(userId, secret)
   - Recuperar: account.createRecovery(email, url)
   - Nueva clave (web): account.updateRecovery(userId, secret, password, password)

Project ID: ${PROJECT_ID}
Endpoint:   ${ENDPOINT}
Database:   ${DATABASE_ID}
`);

  try {
    const list = await users.list();
    console.log(`✓ API key OK — usuarios actuales: ${list.total}`);
  } catch (e) {
    console.warn(
      '⚠ No se pudo listar usuarios (revisa scopes users.read en la API key):',
      e.message ?? e,
    );
  }
}

async function main() {
  console.log('Nexus Campus → Appwrite setup');
  console.log(`Endpoint: ${ENDPOINT}`);
  console.log(`Project:  ${PROJECT_ID}`);
  console.log(`Database: ${DATABASE_ID}`);

  await ensureDatabase();
  await setupCollections();
  await setupBuckets();
  await authChecklist();

  console.log('\n✅ Setup terminado.');
  console.log('Siguiente: pon en el .env de la app Flutter:');
  console.log(`
APPWRITE_ENDPOINT=${ENDPOINT}
APPWRITE_PROJECT_ID=${PROJECT_ID}
APPWRITE_DATABASE_ID=${DATABASE_ID}
`);
}

main().catch((e) => {
  console.error('\n❌ Setup falló:', e.message ?? e);
  if (e.response) console.error(e.response);
  process.exit(1);
});
