const fs = require('fs');
const { JSDOM } = require('jsdom');
const D = JSON.parse(fs.readFileSync(require('path').join(__dirname,'data.json'), 'utf8'));
const html = fs.readFileSync(require('path').join(__dirname,'../../tycoon/index.html'), 'utf8');

const st = { children: [{ id: 'c1', nickname: 'Lucy', child_games: [] }], game: null, owned: [], qi: 0, attempts: {}, tierUpNext: false };
const ok = (data) => Promise.resolve({ data, error: null });
const bad = (m) => Promise.resolve({ data: null, error: { message: m } });
const rank = () => { const g = st.game; return { tier: g.rank_tier, level: g.rank_level, tier_name: D.theme.tier_names[g.rank_tier - 1], next_tier_name: D.theme.tier_names[g.rank_tier] || null, level_progress: 0, per_level: 5, max_tier: 9 }; };
const perks = () => ({ coin_bonus: Math.min(8, st.owned.filter((o) => o.equipped_slot).map((o) => D.collectibles.find((c) => c.id === o.collectible_id)).filter((c) => c.kind === 'gear').reduce((a, c) => a + c.perks.coin_bonus, 0)), free_hints: 0, streak_shields: 0 });

function from(table) {
  const f = {}; let op = 'select', payload = null, single = false;
  const b = {
    select() { return b; }, eq(k, v) { f[k] = v; return b; }, in(k, v) { f[k] = v; return b; }, order() { return b; }, limit() { return b; },
    single() { single = true; return b; }, insert(p) { op = 'insert'; payload = p; return b; },
    then(res, rej) { return run().then(res, rej); },
  };
  function run() {
    if (table === 'themes') return ok(D.theme);
    if (table === 'theme_flavours') return ok(D.flavours);
    if (table === 'children') return ok(st.children);
    if (table === 'child_games') {
      if (op === 'insert') { st.game = { id: 'g1', credits: 0, rank_tier: 1, rank_level: 1, rank_xp: 0, flavour: null, ...payload }; st.children[0].child_games = [st.game]; return ok({ id: 'g1' }); }
      return ok({ ...st.game });
    }
    if (table === 'theme_wording') return ok(D.wording.filter((w) => f.theme.includes(w.theme)));
    if (table === 'collectibles') return ok(D.collectibles);
    if (table === 'child_collection') return ok(st.owned.map((o) => ({ ...o })));
    if (table === 'crates') return ok([D.crate]);
    return bad('unknown table ' + table);
  }
  return b;
}
const rpcs = {
  check_child_pin: () => ok(true), is_admin: () => ok(true), rank_info: () => ok(rank()), game_perks: () => ok(perks()),
  choose_venture: ({ p_flavour }) => { const fl = D.flavours.find((x) => x.id === p_flavour); if (!fl) return bad('That venture is not part of this game'); if (fl.unlock_tier > st.game.rank_tier) return bad('You have not unlocked that venture yet'); st.game.flavour = fl.id; return ok({ flavour: fl.id, name: fl.name, words: fl.words }); },
  next_question: ({ p_template }) => { const s = p_template ? D.samples.find((x) => x.template_id === p_template) : D.samples[st.qi++ % D.samples.length]; const id = Math.floor(Math.random() * 1e9); st.attempts[id] = s; return ok({ attempt_id: id, template_id: s.template_id, topic: s.topic, spec_point: s.spec_point, difficulty: s.difficulty, calculator: s.calculator, vars: s.vars, tip: 'A tip' }); },
  dev_answer: () => ok('right'),
  submit_answer: ({ p_attempt, p_given }) => {
    const s = st.attempts[p_attempt], correct = p_given === 'right'; let tier_up = false;
    const bonus = correct ? perks().coin_bonus : 0, award = correct ? 10 + bonus : 0; st.game.credits += award;
    if (correct && st.tierUpNext) { st.game.rank_tier++; st.game.rank_level = 1; tier_up = true; st.tierUpNext = false; }
    return ok({ correct, answer: '42', explain: s.explain, vars: s.vars, steps: ['step'], credits_awarded: award, gear_bonus: bonus, credits: st.game.credits, too_fast: false, levelled_up: false, tier_up, rank: rank() });
  },
  open_crate: () => { st.game.credits -= 100; const items = ['MIL-001', 'MIL-073', 'MIL-040'].map((id) => D.collectibles.find((c) => c.id === id)); items.forEach((it) => { const o = st.owned.find((x) => x.collectible_id === it.id); if (o) o.quantity++; else st.owned.push({ collectible_id: it.id, quantity: 1, equipped_slot: null }); }); return ok({ items, credits: st.game.credits }); },
  equip_item: ({ p_item }) => { const c = D.collectibles.find((x) => x.id === p_item); st.owned.forEach((o) => { if (o.equipped_slot === c.slot) o.equipped_slot = null; }); st.owned.find((o) => o.collectible_id === p_item).equipped_slot = c.slot; return ok(null); },
  unequip_slot: ({ p_slot }) => { st.owned.forEach((o) => { if (o.equipped_slot === p_slot) o.equipped_slot = null; }); return ok(null); },
  dev_add_credits: () => { st.game.credits += 500; return ok(st.game.credits); },
};
const mock = { from, rpc: (n, a) => (rpcs[n] ? rpcs[n](a || {}) : bad('no rpc ' + n)),
  auth: { getSession: () => ok({ session: { user: { email: 'joel@test' } } }), signOut: () => ok(null) } };

const dom = new JSDOM(html.replace('<script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2"></script>', ''), {
  runScripts: 'dangerously', url: 'https://example.com/tycoon/?skin=military', pretendToBeVisual: true,
  beforeParse(w) { w.__MOCK_DB__ = mock; w.scrollTo = () => {}; w.console.warn = (...a) => console.log('WARN', ...a); },
});
const w = dom.window, $ = (id) => w.document.getElementById(id);
const tick = (ms = 30) => new Promise((r) => setTimeout(r, ms));
const visible = () => [...w.document.querySelectorAll('main > section')].find((s) => !s.classList.contains('hidden'))?.id;
const errs = []; w.addEventListener('error', (e) => errs.push(e.message)); process.on('unhandledRejection', (e) => errs.push(String(e)));
let fails = 0; const check = (c, m) => { console.log((c ? 'PASS ' : 'FAIL ') + m); if (!c) fails++; };

(async () => {
  await tick(100);
  check(visible() === 'v-who', 'opens on who is playing');
  check(w.document.title === 'Field Command', 'title from theme: ' + w.document.title);
  w.document.querySelector('[data-child]').click(); await tick();
  $('pinForm').dispatchEvent(new w.Event('submit', { cancelable: true })); await tick(80);
  check(visible() === 'v-setup', 'new kid goes to setup');
  check(/Squad name/.test($('nameFields').textContent) && /Callsign/.test($('nameFields').textContent), 'name labels come from theme');
  check($('setupTitle').textContent === 'Form your squad', 'setup title: ' + $('setupTitle').textContent);
  check($('setupHelp').textContent === 'Pick your names.', 'setup help has no venture line: ' + $('setupHelp').textContent);
  check($('nf-callsign').value === 'Lucy', 'callsign prefilled with nickname');
  $('nf-squad').value = 'Thunder Owls'; $('nf-callsign').value = 'Echo';
  $('setupForm').dispatchEvent(new w.Event('submit', { cancelable: true })); await tick(80);
  check(visible() === 'v-hub', 'no flavours, so straight to hub');
  check($('ventureBtn').hidden, 'venture button hidden');
  check(/Thunder Owls/.test($('board').textContent) && /Callsign: Echo/.test($('board').textContent) && /0 supply points/.test($('board').textContent), 'board: ' + $('board').textContent.replace(/\s+/g, ' ').slice(0, 120));
  check(/Recruit, level 1/.test($('board').textContent) && /Next: Private/.test($('board').textContent), 'rank ladder uses tier names');
  check($('crateName').textContent === 'Supply Drop' && /100 supply points for 3 items/.test($('packCost').textContent), 'crate button: ' + $('packCost').textContent);

  $('v-hub').querySelector('[data-go="play"]').click(); await tick(80);
  const q1 = $('qText').textContent;
  check(visible() === 'v-play' && !/[{}]/.test(q1), 'question renders: ' + q1);
  $('answerIn').value = 'right'; $('answerForm').dispatchEvent(new w.Event('submit', { cancelable: true })); await tick(80);
  check(/Right! \+10 supply points/.test($('qResult').textContent), 'right answer pays 10 supply points');
  check(w.document.querySelectorAll('.working li').length > 0, 'working shown');

  st.game.credits = 500;
  $('v-play').querySelector('[data-go="hub"]').click(); await tick(120);
  $('v-hub').querySelector('[data-go="pack"]').click(); await tick(40);
  check($('packTitle').textContent === 'Supply Drop', 'crate named');
  $('openBtn').click(); await tick(900);
  check(w.document.querySelectorAll('.reveal .card').length === 3 && /Orbital Uplink Dish/.test($('packMsg').textContent), 'crate reveals 3: ' + $('packMsg').textContent);
  check(![...w.document.querySelectorAll('.reveal .card .icon')].some((i) => i.textContent.trim() === '★'), 'slot icons present on reveal');
  w.document.querySelector('#packButtons [data-go="kit"]').click(); await tick(40);
  check(w.document.querySelectorAll('#slots .slot').length === 6, 'six slots');
  check(![...w.document.querySelectorAll('#slots .empty')].some((e) => e.textContent.includes('★')), 'empty slot icons present');
  w.document.querySelector('[data-item="MIL-040"]').click(); await tick(80);
  w.document.querySelector('[data-item="MIL-001"]').click(); await tick(80);
  check(/\+5 supply points/.test($('kitBonus').textContent), 'gear bonus 4+1: ' + $('kitBonus').textContent);
  w.document.querySelector('[data-item="MIL-073"]').click(); await tick(80);
  check(w.document.querySelectorAll('#slots .card.equipped').length === 3 && /\+5 supply points/.test($('kitBonus').textContent), 'badge equips, no bonus change');

  // every question, kid names in place: no leftovers
  const leftovers = [], shown = [];
  for (const s of D.samples) { const t = w.eval(`fill(S.wording[${JSON.stringify(s.template_id + '|theme')}] || 'MISSING', ${JSON.stringify(s.vars)})`); shown.push(s.template_id + ': ' + t); if (/[{}]|MISSING/.test(t)) leftovers.push(s.template_id + ': ' + t); }
  check(leftovers.length === 0, `all ${D.samples.length} questions fill cleanly` + (leftovers.length ? '\n' + leftovers.join('\n') : ''));
  // and the worked explanation evaluates for each sample
  const badWork = D.samples.filter((s) => !w.eval(`workedLines(${JSON.stringify(s.explain)}, ${JSON.stringify(s.vars)})`)).map((s) => s.template_id);
  check(badWork.length === 0, 'worked explanations evaluate ' + badWork.join());
  require('fs').writeFileSync(require('path').join(__dirname,'rendered.txt'), shown.join('\n'));
  // player list shows squad name
  w.eval('openWho()'); await tick(80);
  check(/Thunder Owls/.test($('players').textContent), 'player list shows squad name: ' + $('players').textContent.trim());
  check(errs.length === 0, 'no page errors ' + errs.join(' | '));
  console.log(fails ? `${fails} FAILED` : 'ALL PASSED');
  process.exit(fails ? 1 : 0);
})();
