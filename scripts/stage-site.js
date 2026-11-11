// Copies only the files the live site serves into dist/ (used by Netlify and by build-deploy.sh).
// Tests, database schema, drafts, scripts and the README never get published.
const fs = require('fs');
const path = require('path');
const root = path.join(__dirname, '..');
const out = path.join(root, 'dist');
const SITE = ['index.html', 'tycoon', 'check', 'account', 'review', 'admin', 'football', 'fonts', 'vendor', 'brand', 'audio'];
fs.rmSync(out, { recursive: true, force: true });
fs.mkdirSync(out);
for (const item of SITE) fs.cpSync(path.join(root, item), path.join(out, item), { recursive: true });
let n = 0;
(function count(d) { for (const e of fs.readdirSync(d, { withFileTypes: true })) e.isDirectory() ? count(path.join(d, e.name)) : n++; })(out);
console.log(`Staged ${n} files in dist/`);
