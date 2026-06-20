import crypto from 'node:crypto';
import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const scriptDir = path.dirname(fileURLToPath(import.meta.url));
const defaultSourceDir =
  'C:\\Users\\syahr\\Downloads\\781x781 px-20260605T030155Z-3-001\\781x781 px';
const defaultDataPath = path.join(scriptDir, 'firebase', 'firestore_seed.json');
const defaultServiceAccountPath = path.join(
  scriptDir,
  'firebase',
  'serviceAccountKey.json',
);

const args = parseArgs(process.argv.slice(2));
const sourceDir = args.source ?? defaultSourceDir;
const dataPath = args.data ?? defaultDataPath;
const serviceAccountPath = args.serviceAccount ?? defaultServiceAccountPath;
const supabaseUrl = normalizeSupabaseUrl(
  args.supabaseUrl ?? process.env.SUPABASE_URL,
);
const supabaseKey =
  args.supabaseKey ??
  process.env.SUPABASE_PUBLISHABLE_KEY ??
  process.env.SUPABASE_ANON_KEY;
const bucket = args.bucket ?? process.env.SUPABASE_PRODUCT_BUCKET ?? 'product-images';
const skipUpload = Boolean(args.skipUpload);
const importFirestore = Boolean(args.importFirestore);
const dryRun = Boolean(args.dryRun);

const existingSeed = JSON.parse(await fs.readFile(dataPath, 'utf8'));
const catalogFiles = await findCatalogFiles(sourceDir);

if (!supabaseUrl && !dryRun) {
  throw new Error('Isi --supabase-url atau env SUPABASE_URL.');
}

if (!skipUpload && !dryRun && !supabaseKey) {
  throw new Error(
    'Isi --supabase-key atau env SUPABASE_PUBLISHABLE_KEY untuk upload gambar.',
  );
}

const services = [];
for (let index = 0; index < catalogFiles.length; index += 1) {
  const file = catalogFiles[index];
  const fileBytes = await fs.readFile(file.fullPath);
  const hash = crypto.createHash('sha1').update(fileBytes).digest('hex').slice(0, 10);
  const ext = path.extname(file.fullPath).toLowerCase();
  const storagePath =
    `catalog/${slugify(file.category)}/${slugify(file.name)}-${hash}${ext}`;
  const imageUrl = supabaseUrl
    ? publicStorageUrl(supabaseUrl, bucket, storagePath)
    : '';

  if (!skipUpload && !dryRun) {
    await uploadToSupabase({
      supabaseUrl,
      supabaseKey,
      bucket,
      storagePath,
      fileBytes,
      contentType: contentTypeFor(file.fullPath),
    });
  }

  services.push(buildService({
    id: index + 1,
    name: file.name,
    category: file.category,
    imageUrl,
  }));
}

const nextSeed = {
  branches: existingSeed.branches ?? [],
  services,
};

if (dryRun) {
  printPlan({ sourceDir, bucket, services, upload: !skipUpload });
  process.exit(0);
}

await fs.writeFile(dataPath, `${JSON.stringify(nextSeed, null, 2)}\n`, 'utf8');
console.log(`Seed katalog ditulis: ${dataPath}`);
console.log(`Total layanan: ${services.length}`);

if (importFirestore) {
  const serviceAccount = JSON.parse(await fs.readFile(serviceAccountPath, 'utf8'));
  const projectId = args.projectId ?? serviceAccount.project_id;
  if (!projectId) {
    throw new Error('Project ID tidak ditemukan di service account.');
  }

  const accessToken = await getAccessToken(serviceAccount);
  await importCollection({
    projectId,
    accessToken,
    collectionName: 'branches',
    documents: nextSeed.branches,
  });
  await importCollection({
    projectId,
    accessToken,
    collectionName: 'services',
    documents: nextSeed.services,
  });
  console.log('Import Firestore selesai.');
}

async function findCatalogFiles(rootDir) {
  const allowedExt = new Set(['.jpg', '.jpeg', '.png', '.webp']);
  const results = [];

  async function walk(currentDir) {
    const entries = await fs.readdir(currentDir, { withFileTypes: true });
    for (const entry of entries) {
      const fullPath = path.join(currentDir, entry.name);
      if (entry.isDirectory()) {
        await walk(fullPath);
        continue;
      }

      if (!entry.isFile()) continue;
      const ext = path.extname(entry.name).toLowerCase();
      if (!allowedExt.has(ext)) continue;

      const relative = path.relative(rootDir, fullPath);
      const parts = relative.split(path.sep);
      const category = parts.length > 1 ? parts[0] : 'Lainnya';
      const name = titleCase(path.basename(entry.name, ext));
      results.push({ category, name, fullPath });
    }
  }

  await walk(rootDir);
  results.sort((a, b) => {
    const categoryOrder = a.category.localeCompare(b.category);
    return categoryOrder === 0 ? a.name.localeCompare(b.name) : categoryOrder;
  });
  return results;
}

function buildService({ id, name, category, imageUrl }) {
  const priceInfo = priceFor(name, category);
  return {
    id,
    name,
    price: priceInfo.price,
    unit: priceInfo.unit,
    options: optionsFor(name, category),
    description: descriptionFor(name, category),
    isActive: true,
    icon: 'print_outlined',
    imageUrl,
    branchIds: branchIdsFor(category),
  };
}

function priceFor(name, category) {
  const combined = `${category} ${name}`.toLowerCase();

  if (combined.includes('kartu nama')) return { price: 75000, unit: 'box' };
  if (combined.includes('brosur')) return { price: 1500, unit: 'lembar' };
  if (combined.includes('sertifikat')) return { price: 3000, unit: 'lembar' };
  if (combined.includes('undangan')) return { price: 3500, unit: 'pcs' };
  if (combined.includes('poster a0')) return { price: 35000, unit: 'lembar' };
  if (combined.includes('poster')) return { price: 8000, unit: 'lembar' };
  if (combined.includes('spanduk')) return { price: 25000, unit: 'meter' };
  if (combined.includes('baliho')) return { price: 45000, unit: 'meter' };
  if (combined.includes('neon box')) return { price: 350000, unit: 'pcs' };
  if (combined.includes('roll up')) return { price: 250000, unit: 'pcs' };
  if (combined.includes('banner')) return { price: 120000, unit: 'pcs' };
  if (combined.includes('plakat')) return { price: 150000, unit: 'pcs' };
  if (combined.includes('hoodie')) return { price: 125000, unit: 'pcs' };
  if (combined.includes('polo')) return { price: 95000, unit: 'pcs' };
  if (combined.includes('kaos')) return { price: 85000, unit: 'pcs' };
  if (combined.includes('tumbler')) return { price: 65000, unit: 'pcs' };
  if (combined.includes('paper bag')) return { price: 7500, unit: 'pcs' };
  if (combined.includes('label')) return { price: 500, unit: 'pcs' };
  if (combined.includes('standing pouch')) return { price: 8000, unit: 'pcs' };
  if (combined.includes('cup plastik')) return { price: 2500, unit: 'pcs' };
  if (combined.includes('kalender')) return { price: 25000, unit: 'pcs' };
  if (combined.includes('buku') || combined.includes('yasin')) {
    return { price: 25000, unit: 'pcs' };
  }
  if (combined.includes('booklet') || combined.includes('katalog')) {
    return { price: 18000, unit: 'pcs' };
  }

  switch (category.toLowerCase()) {
    case 'digital offset':
      return { price: 15000, unit: 'pcs' };
    case 'display promosi':
      return { price: 150000, unit: 'pcs' };
    case 'large format printing':
      return { price: 30000, unit: 'meter' };
    case 'merchandise':
      return { price: 30000, unit: 'pcs' };
    case 'packaging':
      return { price: 5000, unit: 'pcs' };
    case 'plakat':
      return { price: 150000, unit: 'pcs' };
    case 'sablon kaos & garment':
      return { price: 85000, unit: 'pcs' };
    case 'sublime':
      return { price: 30000, unit: 'pcs' };
    case 'tumbler':
      return { price: 65000, unit: 'pcs' };
    default:
      return { price: 20000, unit: 'pcs' };
  }
}

function optionsFor(name, category) {
  const combined = `${category} ${name}`.toLowerCase();
  if (combined.includes('poster') || combined.includes('sertifikat')) {
    return 'A4,A3,A2,A1,A0';
  }
  if (combined.includes('spanduk') || combined.includes('baliho')) {
    return 'Indoor,Outdoor';
  }
  if (combined.includes('kaos') || combined.includes('hoodie') || combined.includes('polo')) {
    return 'S,M,L,XL,XXL';
  }
  if (combined.includes('tumbler')) return 'Putih,Hitam,Silver';
  if (combined.includes('plakat')) return 'Akrilik,Kayu,Fiber';
  if (combined.includes('label') || combined.includes('sticker')) {
    return 'Glossy,Doff,Transparan';
  }
  if (category.toLowerCase() === 'digital offset') return 'Full Color,BW';
  return '';
}

function descriptionFor(name, category) {
  return `${name} kategori ${category}, cocok untuk kebutuhan cetak custom, promosi, event, dan branding.`;
}

function branchIdsFor(category) {
  const lower = category.toLowerCase();
  if (lower === 'large format printing' || lower === 'display promosi') {
    return [1, 2];
  }
  return [1, 2];
}

async function uploadToSupabase({
  supabaseUrl,
  supabaseKey,
  bucket,
  storagePath,
  fileBytes,
  contentType,
}) {
  const url =
    `${supabaseUrl}/storage/v1/object/${encodeURIComponent(bucket)}/` +
    encodeStoragePath(storagePath);

  const response = await fetch(url, {
    method: 'POST',
    headers: storageHeaders(supabaseKey, contentType),
    body: fileBytes,
  });

  if (response.ok) {
    console.log(`UPLOAD ${storagePath}`);
    return;
  }

  const body = await response.text();
  if (response.status === 400 && body.toLowerCase().includes('exists')) {
    console.log(`SKIP exists ${storagePath}`);
    return;
  }

  throw new Error(`Gagal upload ${storagePath}: ${response.status} ${body}`);
}

function storageHeaders(supabaseKey, contentType) {
  const headers = {
    apikey: supabaseKey,
    'Content-Type': contentType,
    'Cache-Control': '31536000, immutable',
  };

  if (supabaseKey.split('.').length === 3) {
    headers.Authorization = `Bearer ${supabaseKey}`;
  }

  return headers;
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

function toFirestoreFields(document) {
  return Object.fromEntries(
    Object.entries(document).map(([key, value]) => [key, toFirestoreValue(value)]),
  );
}

function toFirestoreValue(value) {
  if (value === null) return { nullValue: 'NULL_VALUE' };
  if (Array.isArray(value)) {
    return {
      arrayValue: {
        values: value.map(toFirestoreValue),
      },
    };
  }
  if (typeof value === 'boolean') return { booleanValue: value };
  if (typeof value === 'number') {
    if (!Number.isFinite(value)) throw new Error(`Angka tidak valid: ${value}`);
    if (Number.isInteger(value)) return { integerValue: String(value) };
    return { doubleValue: value };
  }
  if (typeof value === 'string') return { stringValue: value };
  if (typeof value === 'object') {
    return {
      mapValue: {
        fields: toFirestoreFields(value),
      },
    };
  }
  throw new Error(`Tipe data tidak didukung: ${typeof value}`);
}

function parseArgs(argv) {
  const parsed = {};
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === '--dry-run') {
      parsed.dryRun = true;
    } else if (arg === '--skip-upload') {
      parsed.skipUpload = true;
    } else if (arg === '--import-firestore') {
      parsed.importFirestore = true;
    } else if (arg === '--source') {
      parsed.source = argv[++i];
    } else if (arg === '--data') {
      parsed.data = argv[++i];
    } else if (arg === '--service-account') {
      parsed.serviceAccount = argv[++i];
    } else if (arg === '--project-id') {
      parsed.projectId = argv[++i];
    } else if (arg === '--supabase-url') {
      parsed.supabaseUrl = argv[++i];
    } else if (arg === '--supabase-key') {
      parsed.supabaseKey = argv[++i];
    } else if (arg === '--bucket') {
      parsed.bucket = argv[++i];
    } else {
      throw new Error(`Argumen tidak dikenal: ${arg}`);
    }
  }
  return parsed;
}

function printPlan({ sourceDir, bucket, services, upload }) {
  console.log(`Source: ${sourceDir}`);
  console.log(`Bucket: ${bucket}`);
  console.log(`Upload: ${upload ? 'yes' : 'no'}`);
  console.log(`Services: ${services.length}`);
  for (const service of services) {
    console.log(
      `  - ${service.id}. ${service.name} | Rp ${service.price}/${service.unit}`,
    );
  }
}

function normalizeSupabaseUrl(value) {
  if (!value) return '';
  return value.replace(/\/+$/, '');
}

function publicStorageUrl(supabaseUrl, bucket, storagePath) {
  return `${supabaseUrl}/storage/v1/object/public/${encodeURIComponent(bucket)}/${encodeStoragePath(storagePath)}`;
}

function encodeStoragePath(storagePath) {
  return storagePath.split('/').map(encodeURIComponent).join('/');
}

function contentTypeFor(filePath) {
  const ext = path.extname(filePath).toLowerCase();
  if (ext === '.jpg' || ext === '.jpeg') return 'image/jpeg';
  if (ext === '.png') return 'image/png';
  if (ext === '.webp') return 'image/webp';
  return 'application/octet-stream';
}

function slugify(value) {
  return value
    .toLowerCase()
    .replace(/&/g, ' and ')
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '');
}

function titleCase(value) {
  return value
    .replace(/\s+/g, ' ')
    .trim()
    .split(' ')
    .map((word) => {
      if (word.length <= 3 && word === word.toUpperCase()) return word;
      return word.charAt(0).toUpperCase() + word.slice(1);
    })
    .join(' ');
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
