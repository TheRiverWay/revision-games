// Database errors must never reach the screen raw (a parent saw a row-level security message on 10 Nov).
const fs = require('fs'); const path = require('path');
const html = fs.readFileSync(path.join(__dirname, '../../tycoon/index.html'), 'utf8');
const src = html.match(/const nice = \(e\) => \{[\s\S]*?\n\};/);
if (!src) { console.log('FAIL nice() not found'); process.exit(1); }
const nice = new Function(src[0] + '; return nice;')();
let fails = 0; const ok = (c, m) => { console.log(c ? 'ok' : 'FAIL', m); if (!c) fails++; };
ok(!/row-level/i.test(nice({ message: 'new row violates row-level security policy for table "child_games"' })), 'RLS error is replaced');
ok(/hello@levelwise\.co\.uk/.test(nice({ message: 'duplicate key value violates unique constraint "x"' })), 'constraint error points to support');
ok(nice({ message: 'P0001: You have not unlocked that venture yet' }) === 'You have not unlocked that venture yet', 'our own messages still show');
ok(nice(null) === 'Something went wrong. Try again.', 'empty error has a fallback');
console.log(fails ? fails + ' FAILED' : 'ALL PASSED'); process.exit(fails ? 1 : 0);
