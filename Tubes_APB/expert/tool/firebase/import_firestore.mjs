import crypto from 'node:crypto';
import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const scriptDir = path.dirname(fileURLToPath(import.meta.url));
const defaultServiceAccountPath =
  'C:\\merged_partition_content\\Tubes_APB\\Tubes_APB\\expert\\tool\\firebase\\serviceAccountKey.json';
const defaultDataPath = path.join(scriptDir, 'firestore_seed.json');

const args = parseArgs(process.argv.slice(2));
const dataPath = args.data ?? defaultDataPath;
const serviceAccountPath = args.serviceAccount ?? defaultServiceAccountPath;
const dryRun = Boolean(args.dryRun);

const seedData = JSON.parse(await fs.readFile(dataPath, 'utf8'));

if (dryRun) {
  printPlan(seedData, dataPath);
  process.exit(0);
}

const serviceAccount = JSON.parse(await fs.readFile(serviceAccountPath, 'utf8'));
const projectId = args.projectId ?? serviceAccount.project_id;

if (!projectId) {
  throw new Error('Project ID tidak ditemukan. Isi --project-id atau cek service account key.');
}

const accessToken = await getAccessToken(serviceAccount);
await importCollection({
  projectId,
  accessToken,
  collectionName: 'branches',
  documents: seedData.branches ?? [],
});
await importCollection({
  projectId,
  accessToken,
  collectionName: 'services',
  documents: seedData.services ?? [],
});

console.log('Import selesai.');

function parseArgs(argv) {
  const parsed = {};

  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];

    if (arg === '--dry-run') {
      parsed.dryRun = true;
      continue;
    }

    if (arg === '--data') {
      parsed.data = argv[++i];
      continue;
    }

    if (arg === '--service-account') {
      parsed.serviceAccount = argv[++i];
      continue;
    }

    if (arg === '--project-id') {
      parsed.projectId = argv[++i];
      continue;
    }

    throw new Error(`Argumen tidak dikenal: ${arg}`);
  }

  return parsed;
}

async function getAccessToken(serviceAccount) {
  const now = Math.floor(Date.now() / 1000);
  const header = {
    alg: 'RS256',
    typ: 'JWT',
  };
  const claim = {
    iss: serviceAccount.client_email,
    scope: 'https://www.googleapis.com/auth/datastore',
    aud: 'https://oauth2.googleapis.com/token',
    exp: now + 3600,
    iat: now,
  };

  const unsignedJwt = `${base64UrlJson(header)}.${base64UrlJson(claim)}`;
  const signature = crypto.sign(
    'RSA-SHA256',
    Buffer.from(unsignedJwt),
    serviceAccount.private_key,
  );
  const jwt = `${unsignedJwt}.${base64Url(signature)}`;

  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  });

  const body = await response.json();
  if (!response.ok) {
    throw new Error(`Gagal ambil access token: ${JSON.stringify(body)}`);
  }

  return body.access_token;
}

async function importCollection({ projectId, accessToken, collectionName, documents }) {
  if (!Array.isArray(documents)) {
    throw new Error(`Collection ${collectionName} harus berupa array.`);
  }

  for (const document of documents) {
    if (document.id === undefined || document.id === null) {
      throw new Error(`Document di ${collectionName} wajib punya field id.`);
    }

    const docId = String(document.id);
    const url =
      `https://firestore.googleapis.com/v1/projects/${encodeURIComponent(projectId)}` +
      `/databases/(default)/documents/${collectionName}/${encodeURIComponent(docId)}`;

    const response = await fetch(url, {
      method: 'PATCH',
      headers: {
        Authorization: `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        fields: toFirestoreFields(document),
      }),
    });

    const body = await response.json();
    if (!response.ok) {
      throw new Error(`Gagal import ${collectionName}/${docId}: ${JSON.stringify(body)}`);
    }

    console.log(`OK ${collectionName}/${docId}`);
  }
}

function toFirestoreFields(document) {
  return Object.fromEntries(
    Object.entries(document).map(([key, value]) => [key, toFirestoreValue(value)]),
  );
}

function toFirestoreValue(value) {
  if (value === null) {
    return { nullValue: 'NULL_VALUE' };
  }

  if (Array.isArray(value)) {
    return {
      arrayValue: {
        values: value.map(toFirestoreValue),
      },
    };
  }

  if (typeof value === 'boolean') {
    return { booleanValue: value };
  }

  if (typeof value === 'number') {
    if (!Number.isFinite(value)) {
      throw new Error(`Angka tidak valid: ${value}`);
    }

    if (Number.isInteger(value)) {
      return { integerValue: String(value) };
    }

    return { doubleValue: value };
  }

  if (typeof value === 'string') {
    return { stringValue: value };
  }

  if (typeof value === 'object') {
    return {
      mapValue: {
        fields: toFirestoreFields(value),
      },
    };
  }

  throw new Error(`Tipe data tidak didukung: ${typeof value}`);
}

function printPlan(data, sourcePath) {
  const branches = data.branches ?? [];
  const services = data.services ?? [];

  console.log(`Data file: ${sourcePath}`);
  console.log(`branches: ${branches.length} document(s)`);
  for (const branch of branches) {
    console.log(`  - branches/${branch.id}: ${branch.name}`);
  }

  console.log(`services: ${services.length} document(s)`);
  for (const service of services) {
    console.log(`  - services/${service.id}: ${service.name}`);
  }
}

function base64UrlJson(value) {
  return base64Url(Buffer.from(JSON.stringify(value), 'utf8'));
}

function base64Url(buffer) {
  return buffer
    .toString('base64')
    .replaceAll('+', '-')
    .replaceAll('/', '_')
    .replaceAll('=', '');
}
