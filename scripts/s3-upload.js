'use strict';

/**
 * S3-backed image upload for hexo-admin.
 *
 * Intercepts POST {root}admin/api/images/upload and stores the image in MinIO
 * (the storage companion service) instead of the local source volume. The
 * markdown inserted by the editor points at the storage service's public URL,
 * e.g. https://<storage-domain>/blog-images/pasted-123.png
 *
 * Design:
 *  - Registered as a server_middleware filter at priority 0 so it runs BEFORE
 *    hexo-admin's own handler (registered at default priority 10).
 *  - hexo-admin's auth chain (cookie-parser + express-session + connect-auth
 *    gate) is re-applied here FIRST, so the interceptor is protected by the
 *    same login as the rest of /admin/ — no auth bypass.
 *  - When MINIO_ENDPOINT is unset, we call next() and the stock hexo-admin
 *    handler saves the image locally (original behavior preserved).
 *  - On MinIO failure we also fall back to next() so the editor keeps working
 *    (graceful degradation to local save).
 *  - The bucket is created lazily on first upload and set to public-read so
 *    images render in the browser without signed URLs.
 *
 * NOTE: hexo loads files from `scripts/` by wrapping them and executing the
 * body with `hexo` in scope — registration happens at top level here, not via
 * module.exports (that pattern only works for node_modules plugins).
 */

const path = require('path');
const bodyParser = require('body-parser');
const Minio = require('minio');

const PUBLIC_READ_POLICY = (bucket) => JSON.stringify({
  Version: '2012-10-17',
  Statement: [
    {
      Effect: 'Allow',
      Principal: { AWS: ['*'] },
      Action: ['s3:GetObject'],
      Resource: [`arn:aws:s3:::${bucket}/*`],
    },
  ],
});

// module-level caches (per process)
let bucketReady = null; // Promise that resolves once bucket exists + policy applied
let client = null;

function getClient() {
  if (client) return client;
  const endpoint = String(process.env.MINIO_ENDPOINT || '').replace(/\/+$/, '');
  const parsed = new URL(endpoint);
  client = new Minio.Client({
    endPoint: parsed.hostname,
    port: parsed.port ? Number(parsed.port) : parsed.protocol === 'https:' ? 443 : 80,
    useSSL: parsed.protocol === 'https:',
    accessKey: process.env.MINIO_ACCESS_KEY,
    secretKey: process.env.MINIO_SECRET_KEY,
    region: process.env.MINIO_REGION || 'us-east-1',
    pathStyle: true,
  });
  return client;
}

function minioConfigured() {
  return !!(process.env.MINIO_ENDPOINT && process.env.MINIO_ACCESS_KEY && process.env.MINIO_SECRET_KEY);
}

function ensureBucket(client, bucket) {
  if (!bucketReady) {
    bucketReady = (async () => {
      const exists = await client.bucketExists(bucket).catch(() => false);
      if (!exists) {
        await client.makeBucket(bucket, process.env.MINIO_REGION || 'us-east-1');
      }
      // public read so <storage-domain>/<bucket>/<key> renders in the browser
      await client.setBucketPolicy(bucket, PUBLIC_READ_POLICY(bucket)).catch((err) => {
        // policy failure is non-fatal: upload still works, image just won't be public
        console.error('[s3-upload] setBucketPolicy failed:', err.message);
      });
    })().catch((err) => {
      bucketReady = null; // allow retry next upload
      throw err;
    });
  }
  return bucketReady;
}

/** Parse a data URI -> { mime, buffer } */
function parseDataUri(dataUri) {
  const m = /^data:([^;,]+);base64,(.*)$/s.exec(String(dataUri || ''));
  if (!m) return null;
  return { mime: m[1], buffer: Buffer.from(m[2], 'base64') };
}

const MIME_EXT = {
  'image/png': '.png',
  'image/jpeg': '.jpg',
  'image/gif': '.gif',
  'image/webp': '.webp',
  'image/svg+xml': '.svg',
  'image/bmp': '.bmp',
  'image/avif': '.avif',
  'image/tiff': '.tiff',
};

/** Build a safe object key: honor given filename, else pasted-<ts>.<ext> */
function buildKey(filename, mime) {
  const ext = MIME_EXT[mime] || '.png';
  if (filename) {
    let base = path.basename(String(filename)).replace(/[^a-zA-Z0-9._-]/g, '_');
    if (!/\.(png|jpe?g|gif|webp|svg|bmp|avif|tiff)$/i.test(base)) base += ext;
    return base;
  }
  return `pasted-${Date.now()}${ext}`;
}

hexo.extend.filter.register('server_middleware', (app) => {
  const root = hexo.config.root || '/';
  const route = `${root}admin/api/images/upload`;

  // 1) Re-apply hexo-admin's auth chain so this route is login-protected.
  //    hexo-admin's own filter (priority 10) will register it again — express
  //    just runs both in sequence; the second sees an already-authenticated
  //    session and passes through.
  if (hexo.config.admin && hexo.config.admin.username) {
    require('hexo-admin/auth')(app, hexo);
  }

  // 2) Our interceptor. Body must be parsed here because hexo-admin's
  //    bodyParser.json is registered AFTER this filter (priority 10).
  //    NOTE: connect 3.x `app.use(route, fn)` takes only ONE handler arg —
  //    a second callback is silently dropped, so we invoke body-parser
  //    manually inside a single middleware.
  const jsonParser = bodyParser.json({ limit: '50mb' });
  app.use(route, (req, res, next) => {
    jsonParser(req, res, (parseErr) => {
      if (parseErr) return next(parseErr);
      if (req.method !== 'POST') return next();
      if (!minioConfigured()) return next(); // stock local save

      const parsed = parseDataUri(req.body && req.body.data);
      if (!parsed) {
        res.statusCode = 400;
        res.setHeader('Content-type', 'application/json');
        return res.end(JSON.stringify({ src: '', msg: 'Invalid image data' }));
      }

      const bucket = process.env.MINIO_BUCKET || 'blog-images';
      const key = buildKey(req.body.filename, parsed.mime);

      const respond = (payload) => {
        res.setHeader('Content-type', 'application/json');
        res.end(JSON.stringify(payload));
      };

      ensureBucket(getClient(), bucket)
        .then(() => getClient().putObject(bucket, key, parsed.buffer, {
          'Content-Type': parsed.mime,
        }))
        .then(() => {
          const base = String(process.env.MINIO_ENDPOINT).replace(/\/+$/, '');
          hexo.log.info(`[s3-upload] stored ${bucket}/${key} (${parsed.buffer.length} bytes)`);
          respond({ src: `${base}/${bucket}/${key}`, msg: 'upload successful' });
        })
        .catch((err) => {
          hexo.log.error(`[s3-upload] MinIO upload failed, falling back to local save: ${err.message}`);
          next(); // graceful degradation: stock hexo-admin handler saves locally
        });
    });
  });
}, 0);
