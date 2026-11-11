const fs = require('fs');
const { JSDOM } = require('jsdom');
const D = JSON.parse(fs.readFileSync(require('path').join(__dirname,'data.json'), 'utf8'));
const html = fs.readFileSync(require('path').join(__dirname,'../../tycoon/index.html'), 'utf8');

const st = { children: [{ id: 'c1', nickname: 'Lucy', child_games: [] }], game: null, owned: [], qi: 0, attempts: {}, tierUpNext: false };
const ok = (data) => Promise.resolve({ data, error: null });
const bad = (m) => Promise.resolve({ data: null, error: { message: m } });
const rank = () => { const g = st.game; return { tier: g.rank_tier, level: g.rank_level, tier_name: D.theme.tier_names[g.rank_tier - 1], next_tier_name: D.theme.tier_names[g.rank_tier] || null, level_progress: 0, per_level: 5, max_tier: 6 }; };
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
  open_crate: () => { st.game.credits -= 100; const items = ['RST-001', 'RST-061', 'RST-060'].map((id) => D.collectibles.find((c) => c.id === id)); items.forEach((it) => { const o = st.owned.find((x) => x.collectible_id === it.id); if (o) o.quantity++; else st.owned.push({ collectible_id: it.id, quantity: 1, equipped_slot: null }); }); return ok({ items, credits: st.game.credits }); },
  equip_item: ({ p_item }) => { const c = D.collectibles.find((x) => x.id === p_item); st.owned.forEach((o) => { if (o.equipped_slot === c.slot) o.equipped_slot = null; }); st.owned.find((o) => o.collectible_id === p_item).equipped_slot = c.slot; return ok(null); },
  unequip_slot: ({ p_slot }) => { st.owned.forEach((o) => { if (o.equipped_slot === p_slot) o.equipped_slot = null; }); return ok(null); },
  dev_add_credits: () => { st.game.credits += 500; return ok(st.game.credits); },
};
const mock = { from, rpc: (n, a) => (rpcs[n] ? rpcs[n](a || {}) : bad('no rpc ' + n)),
  auth: { getSession: () => ok({ session: { user: { email: 'joel@test' } } }), signOut: () => ok(null) } };

const dom = new JSDOM(html.replace('<script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2"></script>', ''), {
  runScripts: 'dangerously', url: 'https://example.com/tycoon/', pretendToBeVisual: true,
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
  check(w.document.title === 'Kitchen Tycoon', 'title from theme: ' + w.document.title);
  w.document.querySelector('[data-child]').click(); await tick();
  $('pinForm').dispatchEvent(new w.Event('submit', { cancelable: true })); await tick(80);
  check(visible() === 'v-setup', 'new kid goes to setup');
  check($('tabs').hidden, 'no tab bar during setup');
  check(/Restaurant name/.test($('nameFields').textContent) && /Head chef name/.test($('nameFields').textContent), 'name labels come from theme');
  check($('setupTitle').textContent === 'Start your food van', 'setup title: ' + $('setupTitle').textContent);
  $('nf-biz').value = "Lucy's Diner"; $('nf-boss').value = 'Lucy';
  $('setupForm').dispatchEvent(new w.Event('submit', { cancelable: true })); await tick(80);
  check(visible() === 'v-venture', 'then picks first venture');
  const enabled = [...w.document.querySelectorAll('.venture:not([disabled])')].map((b) => b.dataset.f);
  check(enabled.join() === 'rest-smashburger,rest-hotdog,rest-icecream', 'only Food Van ventures unlocked: ' + enabled.join());
  check($('ventureBack').hidden, 'no back button on first pick');
  w.document.querySelector('[data-f="rest-pizza"]').click(); await tick();
  check(st.game.flavour === null, 'locked button does nothing');
  w.document.querySelector('[data-f="rest-hotdog"]').click(); await tick(80);
  check(visible() === 'v-hub', 'lands on hub');
  check(!$('tabs').hidden && $('tabs').querySelector('[aria-current]')?.dataset.tab === 'hub', 'tab bar shows, Home active');
  check($('board').querySelector('.scene svg') && $('board').querySelector('.sign'), 'home has the scene and sign');
  check(/Lucy's Diner/.test($('board').textContent) && /Hot Dog Van/.test($('board').textContent) && /£0/.test($('board').textContent), 'board shows name, venture, cash');
  check(/Taco Stall/.test($('hubSide').textContent), 'hub teases next unlocks');

  // questions
  $('v-hub').querySelector('[data-go="play"]').click(); await tick(80);
  const q1 = $('qText').textContent;
  check($('tabs').hidden, 'tab bar steps aside during a question');
  check($('playStrip').querySelector('svg') && /Lv/.test($('playRank').textContent), 'play screen has scene strip and mini rank');
  for (const k of ['1','2','del','3',':','4']) $('pad').querySelector(`[data-k="${k}"]`).click();
  check($('answerIn').value === '13:4', 'number pad types and deletes: ' + $('answerIn').value);
  $('answerIn').value = '';
  check(visible() === 'v-play' && !/[{}]/.test(q1), 'question renders: ' + q1);
  $('answerIn').value = 'right'; $('answerForm').dispatchEvent(new w.Event('submit', { cancelable: true })); await tick(80);
  check(/Right! \+£10/.test($('qResult').textContent), 'right answer pays £10');
  check(/\+£10/.test($('playStrip').querySelector('.reward')?.textContent || ''), 'reward pops on the strip');
  check($('pad').hidden, 'pad hides while showing the result');
  check(w.document.querySelectorAll('.working li').length > 0, 'working shown');
  $('nextBtn').click(); await tick(80);
  $('answerIn').value = 'nope'; $('answerForm').dispatchEvent(new w.Event('submit', { cancelable: true })); await tick(80);
  check(/Not this time/.test($('qResult').textContent), 'wrong answer handled');

  $('nextBtn').click(); await tick(80);
  check(!$('pad').hidden && !$('answerBtn').disabled, 'pad back for next question');
  $('answerIn').value = 'right'; $('answerBtn').click(); await tick(80);
  check(/Right!/.test($('qResult').textContent), 'Check button submits');
  $('tabs').querySelector('[data-tab="kit"]').click(); await tick(60);
  check(visible() === 'v-kit' && $('tabs').querySelector('[aria-current]')?.dataset.tab === 'kit', 'Collection tab opens kit');
  $('tabs').querySelector('[data-tab="pack"]').click(); await tick(60);
  check(visible() === 'v-pack', 'Crates tab opens crates');
  $('tabs').querySelector('[data-tab="hub"]').click(); await tick(80);
  check(visible() === 'v-hub', 'Home tab goes home');
  check($('musicToggle').getAttribute('aria-pressed') === 'true' && $('fxToggle').getAttribute('aria-pressed') === 'true', 'music and effects on by default');
  $('musicToggle').click(); await tick(10);
  check($('musicToggle').getAttribute('aria-pressed') === 'false' && $('playMute').getAttribute('aria-pressed') === 'false' && w.localStorage.getItem('lw.music') === '0', 'music switch turns off, remembered, play-screen button follows');
  $('playMute').click(); await tick(10);
  check($('musicToggle').getAttribute('aria-pressed') === 'true', 'play-screen music button turns it back on');
  // crate + kit
  st.game.credits = 500;
  $('v-play').querySelector('[data-go="hub"]').click(); await tick(120);
  check(/£500/.test($('board').textContent), 'cash refreshed to £500');
  $('v-hub').querySelector('[data-go="pack"]').click(); await tick(40);
  check($('packTitle').textContent === 'Supply Crate', 'crate named');
  $('openBtn').click(); await tick(900);
  check(w.document.querySelectorAll('.reveal .card').length === 3 && /Delivery Drone Fleet/.test($('packMsg').textContent), 'crate reveals 3, best legendary: ' + $('packMsg').textContent);
  check(/guaranteed within/.test($('odds').textContent), 'crate screen shows the guarantees');
  await tick(1000);
  const big = w.document.querySelector('.big-reveal');
  check(big && /LEGENDARY!/.test(big.textContent) && /Delivery Drone Fleet/.test(big.textContent), 'legendary gets the big reveal');
  big?.querySelector('[data-done]').click(); await tick(10);
  check(!w.document.querySelector('.big-reveal'), 'Collect closes the reveal');
  w.document.querySelector('#packButtons [data-go="kit"]').click(); await tick(40);
  check(w.document.querySelectorAll('#slots .slot').length === 6, 'six slots');
  check(w.document.querySelector('#collection .set-head') && /set/.test(w.document.querySelector('#collection .set-head').textContent), 'collection grouped into venture sets: ' + (w.document.querySelector('#collection .set-head')?.textContent || 'none'));
  // new kit went straight on: stove (oven, +£1), drone fleet (delivery, +£4) and the cosmetic
  check(/\+£5/.test($('kitBonus').textContent), 'crate kit auto-equipped, bonus 4+1 = £5: ' + $('kitBonus').textContent);
  check(w.document.querySelectorAll('#slots .card.equipped').length === 3, 'three slots filled automatically');
  // tapping a slot opens its picker
  w.document.querySelector('[data-slot="oven"]').click(); await tick(40);
  check(!$('picker').hidden && /Rusty Camping Stove/.test($('picker').textContent), 'oven slot opens a picker with the stove');
  $('picker').querySelector('[data-unequip="oven"]').click(); await tick(80);
  check(/\+£4/.test($('kitBonus').textContent) && $('picker').hidden, 'Take it off from the picker drops bonus to £4');
  w.document.querySelector('[data-slot="oven"]').click(); await tick(40);
  $('picker').querySelector('[data-item="RST-001"]').click(); await tick(80);
  check(/\+£5/.test($('kitBonus').textContent), 'choosing in the picker puts it back on');
  w.document.querySelector('[data-slot="fryer"]').click(); await tick(40);
  check(/haven't found a fryer/i.test($('picker').textContent) && $('picker').querySelector('[data-go="pack"]'), 'empty slot with nothing owned points to crates');
  $('picker').querySelector('[data-close]').click(); await tick(20);
  check($('picker').hidden, 'picker closes');
  w.document.querySelector('[data-slot="oven"]').click(); await tick(40);
  $('picker').querySelector('[data-unequip="oven"]').click(); await tick(80);
  check(/\+£4/.test($('kitBonus').textContent), 'unequip drops bonus to £4');

  // tier up -> venture picker
  st.tierUpNext = true;
  $('v-kit').querySelector('[data-go="hub"]').click(); await tick(80);
  $('v-hub').querySelector('[data-go="play"]').click(); await tick(80);
  $('answerIn').value = 'right'; $('answerForm').dispatchEvent(new w.Event('submit', { cancelable: true })); await tick(80);
  check(/grown into a Market Stall/.test($('qResult').textContent) && $('ventureNow'), 'tier up offers new venture');
  check(/\+£4 from your gear/.test($('qResult').textContent), 'gear bonus shown on answer');
  $('ventureNow').click(); await tick(40);
  check(/Market Stall/.test($('ventureTitle').textContent), 'picker title: ' + $('ventureTitle').textContent);
  check(w.document.querySelectorAll('.venture.new').length === 3 && !w.document.querySelector('[data-f="rest-taco"]').disabled, 'stall ventures highlighted and unlocked');
  w.document.querySelector('[data-f="rest-taco"]').click(); await tick(80);
  check(st.game.flavour === 'rest-taco' && /Taco Stall/.test($('board').textContent), 'switched to Taco Stall');
  $('v-hub').querySelector('[data-go="play"]').click(); await tick(80);
  console.log('   taco question:', $('qText').textContent);

  // every question x every venture: no leftover placeholders
  const leftovers = [];
  for (const fl of D.flavours) { st.game.flavour = fl.id; w.eval(`S.game.flavour = ${JSON.stringify(fl.id)}`);
    for (const s of D.samples) { const t = w.eval(`fill(S.wording[${JSON.stringify(s.template_id + '|theme')}] || 'MISSING', ${JSON.stringify(s.vars)})`); if (/[{}]|MISSING/.test(t)) leftovers.push(fl.id + ' ' + s.template_id + ': ' + t); } }
  check(leftovers.length === 0, `all ${D.flavours.length * D.samples.length} venture/question combos fill cleanly` + (leftovers.length ? '\n' + leftovers.slice(0, 5).join('\n') : ''));
  for (const [fl, id] of [['rest-pancake', 'AVG-04'], ['rest-seafood', 'AVG-04'], ['rest-greek', 'RAT-01'], ['rest-icecream', 'DEC-01'], ['rest-finedining', 'PCT-03']]) {
    w.eval(`S.game.flavour = ${JSON.stringify(fl)}`); const s = D.samples.find((x) => x.template_id === id);
    console.log('   ' + fl + ': ' + w.eval(`fill(S.wording['${id}|theme'], ${JSON.stringify(s.vars)})`));
  }
  check(errs.length === 0, 'no page errors ' + errs.join(' | '));
  console.log(fails ? `${fails} FAILED` : 'ALL PASSED');
  process.exit(fails ? 1 : 0);
})();
