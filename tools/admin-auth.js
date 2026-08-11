'use strict';
/* Adds or removes the hexo-admin auth block in /app/_config.yml.
   Usage: node tools/admin-auth.js <username> <password>
   - password set   -> inject admin block with bcrypt hash + random cookie secret
   - password empty -> strip any existing admin block (open access) */
const fs = require('fs');
const crypto = require('crypto');
const bcrypt = require('bcryptjs');

const CFG = '/app/_config.yml';
const username = process.argv[2] || 'admin';
const password = process.argv[3] || '';

function stripAdminBlock(cfg) {
  const lines = cfg.split('\n');
  const out = [];
  let skipping = false;
  for (const line of lines) {
    if (/^admin:(\s|$)/.test(line)) { skipping = true; continue; }
    if (skipping) {
      if (/^\S/.test(line) && !/^#/.test(line)) skipping = false;
      else continue;
    }
    out.push(line);
  }
  return out.join('\n');
}

let cfg = fs.readFileSync(CFG, 'utf8');
cfg = stripAdminBlock(cfg);

if (password) {
  const hash = bcrypt.hashSync(password, 10);
  const secret = crypto.randomBytes(24).toString('hex');
  const block = [
    '',
    '# hexo-admin auth - injected by docker-entrypoint.sh',
    'admin:',
    '  username: ' + username,
    '  password_hash: ' + hash,
    '  secret: ' + secret,
    '  deployCommand: "hexo generate"',
    ''
  ].join('\n');
  cfg = cfg.replace(/\s*$/, '') + block;
  console.log('[admin-auth] hexo-admin login enabled for user "' + username + '"');
} else {
  console.log('[admin-auth] ADMIN_PASSWORD unset - /admin/ is OPEN (auth off by default)');
}
fs.writeFileSync(CFG, cfg);