// Runs every page test suite (tests/<page>/*.js) in its own Node process.
// Each suite loads the real page into jsdom with a mock Supabase client and exits non-zero on failure.
const { readdirSync, statSync } = require('fs');
const { join } = require('path');
const { spawnSync } = require('child_process');

const root = __dirname;
let failed = 0;
for (const dir of readdirSync(root).sort()) {
  const full = join(root, dir);
  if (!statSync(full).isDirectory()) continue;
  for (const file of readdirSync(full).filter(f => f.endsWith('.js')).sort()) {
    const r = spawnSync(process.execPath, [join(full, file)], { encoding: 'utf8' });
    const out = r.stdout || '';
    // A suite fails on a non-zero exit, on any line starting with FAIL, or if it stopped before its last check.
    const lastLine = out.trim().split('\n').pop() || '';
    const ok = r.status === 0 && !/^FAIL/m.test(out) && /^(ALL PASSED|ok )/.test(lastLine);
    if (!ok) failed++;
    const last = (r.stdout || '').trim().split('\n').pop();
    console.log(`${ok ? 'PASS' : 'FAIL'}  ${dir}/${file}  ${last || ''}`);
    if (!ok) console.log((r.stdout || '') + (r.stderr || ''));
  }
}
console.log(failed ? `\n${failed} suite(s) failed` : '\nAll suites passed');
process.exit(failed ? 1 : 0);
