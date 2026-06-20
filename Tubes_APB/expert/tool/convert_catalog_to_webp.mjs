import fs from 'node:fs/promises';
import path from 'node:path';
import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const scriptDir = path.dirname(fileURLToPath(import.meta.url));
const defaultSourceDir =
  'C:\\Users\\syahr\\Downloads\\781x781 px-20260605T030155Z-3-001\\781x781 px';
const defaultOutputDir = path.join(scriptDir, 'generated', 'catalog-webp');
const pythonWebpConverterCode = String.raw`
from PIL import Image
from PIL import ImageOps
import sys

input_path, output_path, quality, target_size = (
    sys.argv[1],
    sys.argv[2],
    int(sys.argv[3]),
    int(sys.argv[4]),
)

with Image.open(input_path) as image:
    image.load()
    if target_size > 0:
        image = ImageOps.fit(
            image,
            (target_size, target_size),
            method=Image.Resampling.LANCZOS,
            centering=(0.5, 0.5),
        )
    if image.mode not in ("RGB", "RGBA"):
        image = image.convert("RGBA" if "A" in image.getbands() else "RGB")
    image.save(output_path, "WEBP", quality=quality, method=6)
`;

const args = parseArgs(process.argv.slice(2));
const sourceDir = args.source ?? defaultSourceDir;
const outputDir = args.out ?? defaultOutputDir;
const quality = Number(args.quality ?? 75);
const targetSize = Number(args.size ?? 781);
const dryRun = Boolean(args.dryRun);
const force = Boolean(args.force);
const requestedConverter = args.converter;
const requestedPython = args.python;

if (!Number.isInteger(quality) || quality < 1 || quality > 100) {
  throw new Error('--quality harus angka 1 sampai 100.');
}

if (!Number.isInteger(targetSize) || targetSize < 0) {
  throw new Error('--size harus angka 0 atau lebih. Pakai 0 untuk mempertahankan dimensi asli.');
}

if (args.help) {
  printHelp();
  process.exit(0);
}

const catalogFiles = await findCatalogFiles(sourceDir);
if (catalogFiles.length === 0) {
  throw new Error(`Tidak ada file gambar di: ${sourceDir}`);
}

const plan = catalogFiles.map((file) => {
  const relativeDir = path.dirname(path.relative(sourceDir, file.fullPath));
  const outputName = `${path.basename(file.fullPath, path.extname(file.fullPath))}.webp`;
  const outputPath = path.join(outputDir, relativeDir, outputName);
  return { ...file, outputPath };
});

if (dryRun) {
  printPlan({ sourceDir, outputDir, quality, targetSize, plan });
  process.exit(0);
}

const converter = requestedConverter
  ? await validateConverter(requestedConverter, requestedPython)
  : await detectConverter();

if (!converter) {
  throw new Error(
    [
      'Converter WebP tidak ditemukan.',
      'Install salah satu tool berikut lalu jalankan ulang script:',
      '  1. cwebp/libwebp, atau',
      '  2. ImageMagick dengan command magick, atau',
      '  3. ffmpeg, atau',
      '  4. Python + Pillow yang support WebP.',
      '',
      'Setelah itu jalankan:',
      'node tool/convert_catalog_to_webp.mjs --quality 75 --force',
    ].join('\n'),
  );
}

console.log(`Converter: ${converter.name}`);
console.log(`Source: ${sourceDir}`);
console.log(`Output: ${outputDir}`);
console.log(`Quality: ${quality}`);
console.log(`Size: ${targetSize === 0 ? 'original' : `${targetSize}x${targetSize}`}`);
console.log(`Images: ${plan.length}`);

let converted = 0;
let skipped = 0;
let originalBytes = 0;
let webpBytes = 0;

for (const item of plan) {
  await fs.mkdir(path.dirname(item.outputPath), { recursive: true });

  const inputStats = await fs.stat(item.fullPath);
  originalBytes += inputStats.size;

  if (!force && (await existsAndIsNewer(item.outputPath, item.fullPath))) {
    const outputStats = await fs.stat(item.outputPath);
    webpBytes += outputStats.size;
    skipped += 1;
    console.log(`SKIP ${path.relative(outputDir, item.outputPath)}`);
    continue;
  }

  await convertImage({
    converter,
    inputPath: item.fullPath,
    outputPath: item.outputPath,
    quality,
    targetSize,
  });

  const outputStats = await fs.stat(item.outputPath);
  webpBytes += outputStats.size;
  converted += 1;
  console.log(
    `WEBP ${path.relative(outputDir, item.outputPath)} ` +
      `${formatBytes(inputStats.size)} -> ${formatBytes(outputStats.size)}`,
  );
}

await writeManifest({
  outputDir,
  sourceDir,
  quality,
  targetSize,
  converter: converter.name,
  convertedAt: new Date().toISOString(),
  items: await Promise.all(
    plan.map(async (item) => {
      const inputStats = await fs.stat(item.fullPath);
      const outputStats = await fs.stat(item.outputPath);
      return {
        source: item.fullPath,
        output: item.outputPath,
        category: item.category,
        name: item.name,
        sourceBytes: inputStats.size,
        webpBytes: outputStats.size,
      };
    }),
  ),
});

const saved = originalBytes - webpBytes;
const savedPercent = originalBytes === 0 ? 0 : (saved / originalBytes) * 100;
console.log('');
console.log(`Selesai. Converted: ${converted}, skipped: ${skipped}`);
console.log(
  `Total: ${formatBytes(originalBytes)} -> ${formatBytes(webpBytes)} ` +
    `(${savedPercent.toFixed(1)}% lebih kecil)`,
);
console.log('');
console.log('Langkah berikutnya, upload dan update Firestore:');
console.log(
  'node tool/import_product_catalog.mjs ' +
    '--source tool/generated/catalog-webp ' +
    '--supabase-url <SUPABASE_URL> ' +
    '--supabase-key <SUPABASE_PUBLISHABLE_KEY> ' +
    '--bucket product-images ' +
    '--import-firestore',
);

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
      const name = path.basename(entry.name, ext);
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

async function detectConverter() {
  for (const name of ['cwebp', 'magick', 'ffmpeg']) {
    const converter = await validateConverter(name);
    if (converter) return converter;
  }

  for (const python of pythonCandidates()) {
    const converter = await validatePythonPillow(python);
    if (converter) return converter;
  }

  return null;
}

async function validateConverter(name, pythonPath) {
  try {
    if (name === 'cwebp') {
      await runProcess('cwebp', ['-version'], { quiet: true });
      return { name };
    }
    if (name === 'magick') {
      await runProcess('magick', ['-version'], { quiet: true });
      return { name };
    }
    if (name === 'ffmpeg') {
      await runProcess('ffmpeg', ['-version'], { quiet: true });
      return { name };
    }
    if (name === 'python' || name === 'pillow' || name === 'python-pillow') {
      if (pythonPath) {
        return validatePythonPillow({ command: pythonPath, args: [] });
      }

      for (const python of pythonCandidates()) {
        const converter = await validatePythonPillow(python);
        if (converter) return converter;
      }
      return null;
    }
  } catch (_) {
    return null;
  }

  throw new Error(`Converter tidak didukung: ${name}`);
}

async function convertImage({ converter, inputPath, outputPath, quality, targetSize }) {
  if (converter.name === 'cwebp') {
    const args = ['-quiet', '-q', String(quality)];
    if (targetSize > 0) {
      args.push('-resize', String(targetSize), String(targetSize));
    }
    args.push(inputPath, '-o', outputPath);
    await runProcess('cwebp', args);
    return;
  }

  if (converter.name === 'magick') {
    const args = [inputPath];
    if (targetSize > 0) {
      args.push(
        '-resize',
        `${targetSize}x${targetSize}^`,
        '-gravity',
        'center',
        '-extent',
        `${targetSize}x${targetSize}`,
      );
    }
    args.push('-strip', '-quality', String(quality), outputPath);
    await runProcess('magick', args);
    return;
  }

  if (converter.name === 'ffmpeg') {
    await runProcess('ffmpeg', [
      '-y',
      '-hide_banner',
      '-loglevel',
      'error',
      '-i',
      inputPath,
      '-q:v',
      String(quality),
      ...(targetSize > 0
        ? [
            '-vf',
            `scale=${targetSize}:${targetSize}:force_original_aspect_ratio=increase,crop=${targetSize}:${targetSize}`,
          ]
        : []),
      outputPath,
    ]);
    return;
  }

  if (converter.name === 'python-pillow') {
    await runProcess(converter.command, [
      ...converter.args,
      '-c',
      pythonWebpConverterCode,
      inputPath,
      outputPath,
      String(quality),
      String(targetSize),
    ]);
    return;
  }

  throw new Error(`Converter tidak didukung: ${converter.name}`);
}

function pythonCandidates() {
  const candidates = [];
  if (requestedPython) {
    candidates.push({ command: requestedPython, args: [] });
  }
  if (process.env.PYTHON) {
    candidates.push({ command: process.env.PYTHON, args: [] });
  }
  candidates.push({ command: 'python', args: [] });
  candidates.push({ command: 'py', args: ['-3'] });

  const userProfile = process.env.USERPROFILE;
  if (userProfile) {
    candidates.push({
      command: path.join(
        userProfile,
        '.cache',
        'codex-runtimes',
        'codex-primary-runtime',
        'dependencies',
        'python',
        'python.exe',
      ),
      args: [],
    });
  }

  return candidates;
}

async function validatePythonPillow(candidate) {
  try {
    await runProcess(
      candidate.command,
      [
        ...candidate.args,
        '-c',
        "from PIL import Image, features; import sys; sys.exit(0 if features.check('webp') else 1)",
      ],
      { quiet: true },
    );
    return { name: 'python-pillow', ...candidate };
  } catch (_) {
    return null;
  }
}

async function runProcess(command, args, { quiet = false } = {}) {
  await new Promise((resolve, reject) => {
    const child = spawn(command, args, {
      stdio: quiet ? 'ignore' : ['ignore', 'inherit', 'inherit'],
      windowsHide: true,
    });

    child.on('error', reject);
    child.on('exit', (code) => {
      if (code === 0) {
        resolve();
        return;
      }
      reject(new Error(`${command} exit code ${code}`));
    });
  });
}

async function existsAndIsNewer(outputPath, inputPath) {
  try {
    const [outputStats, inputStats] = await Promise.all([
      fs.stat(outputPath),
      fs.stat(inputPath),
    ]);
    return outputStats.mtimeMs >= inputStats.mtimeMs;
  } catch (_) {
    return false;
  }
}

async function writeManifest({ outputDir, ...manifest }) {
  await fs.mkdir(outputDir, { recursive: true });
  const manifestPath = path.join(outputDir, 'manifest.json');
  await fs.writeFile(manifestPath, `${JSON.stringify(manifest, null, 2)}\n`, 'utf8');
  console.log(`Manifest: ${manifestPath}`);
}

function parseArgs(argv) {
  const parsed = {};
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === '--help' || arg === '-h') {
      parsed.help = true;
    } else if (arg === '--dry-run') {
      parsed.dryRun = true;
    } else if (arg === '--force') {
      parsed.force = true;
    } else if (arg === '--source') {
      parsed.source = argv[++i];
    } else if (arg === '--out') {
      parsed.out = argv[++i];
    } else if (arg === '--quality') {
      parsed.quality = argv[++i];
    } else if (arg === '--size') {
      parsed.size = argv[++i];
    } else if (arg === '--converter') {
      parsed.converter = argv[++i];
    } else if (arg === '--python') {
      parsed.python = argv[++i];
    } else {
      throw new Error(`Argumen tidak dikenal: ${arg}`);
    }
  }
  return parsed;
}

function printPlan({ sourceDir, outputDir, quality, targetSize, plan }) {
  console.log(`Source: ${sourceDir}`);
  console.log(`Output: ${outputDir}`);
  console.log(`Quality: ${quality}`);
  console.log(`Size: ${targetSize === 0 ? 'original' : `${targetSize}x${targetSize}`}`);
  console.log(`Images: ${plan.length}`);
  for (const item of plan.slice(0, 12)) {
    console.log(`  - ${item.category}/${path.basename(item.outputPath)}`);
  }
  if (plan.length > 12) {
    console.log(`  ... ${plan.length - 12} lainnya`);
  }
}

function printHelp() {
  console.log(`Convert katalog produk ke WebP.

Usage:
  node tool/convert_catalog_to_webp.mjs [options]

Options:
  --source <path>        Folder katalog sumber.
  --out <path>           Folder output WebP. Default: tool/generated/catalog-webp
  --quality <1-100>      Kualitas WebP. Default: 75
  --size <pixels>        Resize square output. Default: 781. Pakai 0 untuk original.
  --converter <name>     Paksa converter: cwebp, magick, ffmpeg, atau python
  --python <path>        Path python.exe kalau memakai --converter python
  --force                Convert ulang walau output sudah ada
  --dry-run              Cek file tanpa convert
  --help                 Tampilkan bantuan
`);
}

function formatBytes(bytes) {
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  return `${(bytes / 1024 / 1024).toFixed(2)} MB`;
}
