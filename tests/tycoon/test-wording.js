// How theme wording is filled: defaults, then venture, then the kid's names; blanks never leave a raw {slot}.
const fs = require('fs'); const path = require('path');
const html = fs.readFileSync(path.join(__dirname, '../../tycoon/index.html'), 'utf8');
const grab = (re, what) => { const m = html.match(re); if (!m) { console.log('FAIL', what, 'not found'); process.exit(1); } return m[0]; };
const code = grab(/function words\(\) \{[\s\S]*?\n\}/, 'words()') + '\n' + grab(/function fill\(text, vars\) \{[\s\S]*?\n\}/, 'fill()');
const make = (S) => new Function('S', 'flavour', 'names', code + '; return fill;')(S, () => S.flavour, () => S.game.custom_names);
const base = { theme: { default_words: { biz: 'your restaurant', items: 'burgers', sides: 'fries' } }, flavour: { words: { items: 'ice creams' } } };
let fails = 0; const ok = (c, m) => { console.log(c ? 'ok' : 'FAIL', m); if (!c) fails++; };
const tpl = '{biz} took £{A} in sales this week. The ordering app keeps {B}% of it.';
let fill = make({ ...base, game: { custom_names: { biz: 'Burger Slop' } } });
ok(fill(tpl, { A: 1000, B: 25 }) === 'Burger Slop took £1,000 in sales this week. The ordering app keeps 25% of it.', 'kid name and numbers fill');
fill = make({ ...base, game: { custom_names: { biz: '   ' } } });
ok(fill(tpl, { A: 1000, B: 25 }).startsWith('Your restaurant took £1,000'), 'blank name falls back to the theme default, capitalised');
ok(!/\{\w+\}/.test(fill('{items} and {sides}', {})), 'no raw slots left');
ok(fill('{items} and {sides}', {}) === 'Ice creams and fries', 'venture words beat theme defaults');
ok(fill('£{C} for {Q} kg', { C: 17.3, Q: 3 }) === '£17.30 for 3 kg', 'money shows 2 decimal places');
console.log(fails ? fails + ' FAILED' : 'ALL PASSED'); process.exit(fails ? 1 : 0);
