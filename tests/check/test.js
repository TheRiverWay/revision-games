const fs = require('fs');
const { JSDOM } = require('jsdom');
const SAMPLES = JSON.parse(fs.readFileSync(require('path').join(__dirname,'samples.json'), 'utf8'));
const html = fs.readFileSync(require('path').join(__dirname,'../../check/index.html'), 'utf8');

// Mock server: serves all 50 templates so every generic wording goes through the real page.
const st = { served: [], answers: {}, finished: false, startCalls: 0 };
const ok = (data) => Promise.resolve({ data, error: null });
const bad = (m) => Promise.resolve({ data: null, error: { message: m } });
function results() {
  const by = {};
  Object.values(st.answers).forEach((a) => { const t = by[a.topic] || (by[a.topic] = { topic: a.topic, asked: 0, correct: 0 }); t.asked++; if (a.correct) t.correct++; });
  const topics = Object.values(by).sort((a, b) => a.topic.localeCompare(b.topic)).map((t) => {
    const percent = Math.round((100 * t.correct) / t.asked);
    return { ...t, percent, rating: percent >= 75 ? 'secure' : percent >= 40 ? 'shaky' : 'gap' };
  });
  return { session_id: 1, finished: st.finished, total: SAMPLES.length, answered: Object.keys(st.answers).length,
    correct: Object.values(st.answers).filter((a) => a.correct).length, topics,
    suggested_focus: topics.filter((t) => t.rating === 'gap').map((t) => t.topic), focus_topics: [] };
}
const rpcs = {
  check_child_pin: ({ p_pin }) => ok(p_pin !== '9999'),
  is_admin: () => ok(true),
  start_check: () => { st.startCalls++; return ok({ session_id: 1, total: SAMPLES.length, answered: 0, resumed: false }); },
  next_check_question: () => {
    const n = st.served.length;
    if (n >= SAMPLES.length) return ok({ done: true });
    const s = SAMPLES[n]; st.served.push(s);
    return ok({ done: false, attempt_id: 1000 + n, template_id: s.template_id, topic: s.topic, difficulty: s.difficulty,
      calculator: s.calculator, vars: s.vars, number: n + 1, total: SAMPLES.length, wording: s.wording });
  },
  submit_check_answer: ({ p_attempt, p_given }) => {
    if (st.answers[p_attempt]) return bad('Already answered');
    const s = st.served[p_attempt - 1000];
    // right for the first template of each topic only, so we get a mix of secure/shaky/gap
    const correct = p_given === 'right';
    st.answers[p_attempt] = { topic: s.topic, correct };
    const n = Object.keys(st.answers).length, done = n >= SAMPLES.length;
    if (done) st.finished = true;
    return ok({ correct, done, number: n, total: SAMPLES.length });
  },
  check_results: () => ok(results()),
  dev_answer: () => ok('right'),
};
function from(table) {
  const b = { select() { return b; }, order() { return b; }, eq() { return b; },
    then(res, rej) { return (table === 'children' ? ok([{ id: 'c1', nickname: 'Lilly' }, { id: 'c2', nickname: 'Lucy' }]) : bad('no table ' + table)).then(res, rej); } };
  return b;
}
const mock = { from, rpc: (n, a) => (rpcs[n] ? rpcs[n](a || {}) : bad('no rpc ' + n)),
  auth: { getSession: () => ok({ session: null }), signInWithPassword: () => ok({ user: { email: 'joel@test' }, session: {} }), signOut: () => ok(null) } };

const dom = new JSDOM(html.replace('<script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2"></script>', ''), {
  runScripts: 'dangerously', url: 'https://example.com/check/', pretendToBeVisual: true,
  beforeParse(w) { w.__MOCK_DB__ = mock; w.scrollTo = () => {}; },
});
const w = dom.window, $ = (id) => w.document.getElementById(id);
const tick = (ms = 20) => new Promise((r) => setTimeout(r, ms));
const visible = () => [...w.document.querySelectorAll('main > section')].find((s) => !s.classList.contains('hidden'))?.id;
const errs = []; w.addEventListener('error', (e) => errs.push(e.message)); process.on('unhandledRejection', (e) => errs.push(String(e)));
const origErr = w.console.error; w.console.error = (...a) => { errs.push(a.join(' ')); };
let fails = 0; const check = (c, m) => { console.log((c ? 'PASS ' : 'FAIL ') + m); if (!c) fails++; };
const submit = (id) => $(id).dispatchEvent(new w.Event('submit', { cancelable: true }));

(async () => {
  await tick(50);
  check(visible() === 'v-auth', 'starts on sign in');
  $('email').value = 'joel@test'; $('password').value = 'password1'; submit('authForm'); await tick(50);
  check(visible() === 'v-who', 'then who is taking the check');
  check(w.document.querySelectorAll('[data-child]').length === 2, 'lists children');
  w.document.querySelector('[data-child="c1"]').click(); await tick();
  $('pinIn').value = '9999'; submit('pinForm'); await tick();
  check(/isn't right/.test($('pinMsg').textContent) && visible() === 'v-who', 'wrong PIN refused');
  $('pinIn').value = '1234'; submit('pinForm'); await tick(50);
  check(visible() === 'v-intro', 'intro after PIN');
  check(/About 25 questions, around 20 minutes\. No timer, no hints, answers aren't shown/.test($('v-intro').textContent), 'intro copy');
  check(st.startCalls === 1 && $('resumeNote').hidden, 'session started, no resume note');
  $('startBtn').click(); await tick(40);
  check(visible() === 'v-q', 'question view');
  check($('qCount').textContent === `Question 1 of ${SAMPLES.length}`, 'progress label: ' + $('qCount').textContent);
  // empty answer is not sent
  $('answerIn').value = ''; submit('answerForm'); await tick();
  check(/Type an answer/.test($('qMsg').textContent) && Object.keys(st.answers).length === 0, 'empty answer blocked');

  const leftovers = [], rendered = {};
  for (let i = 0; i < SAMPLES.length; i++) {
    const s = SAMPLES[i], text = $('qText').textContent;
    rendered[s.template_id] = text;
    if (/[{}]/.test(text)) leftovers.push(`${s.template_id}: ${text}`);
    if ($('qCount').textContent !== `Question ${i + 1} of ${SAMPLES.length}`) leftovers.push('bad count at ' + i);
    const tag = $('qTags').textContent;
    const wantTag = s.calculator === 'calculator' ? 'Calculator allowed' : s.calculator === 'non-calculator' ? 'No calculator' : 'Calculator optional';
    if (tag !== wantTag) leftovers.push(`${s.template_id} tag ${tag}`);
    // first template of each topic right, the rest wrong
    const firstOfTopic = SAMPLES.findIndex((x) => x.topic === s.topic) === i;
    const secondOfTopic = SAMPLES.filter((x, j) => x.topic === s.topic && j < i).length === 1;
    $('answerIn').value = firstOfTopic || (secondOfTopic && s.topic === 'Ratio') ? 'right' : 'nope';
    submit('answerForm'); await tick(25);
  }
  check(leftovers.length === 0, 'all 50 wordings filled, counts and calc tags right' + (leftovers.length ? ': ' + leftovers.join(' | ') : ''));
  check(Object.keys(rendered).length === 50, 'rendered 50 templates');
  check(rendered['DEC-01'] === 'Work out £30.60 + £11.29 − £6.09.', 'money formatting: ' + rendered['DEC-01']);
  check(rendered['AVG-01'] === 'Find the mean of: 5, 4, 5, 5, 4, 2.', 'arrays joined: ' + rendered['AVG-01']);
  check(rendered['NUM-04'] === 'Round 78,736 to the nearest 1,000.', 'number formatting: ' + rendered['NUM-04']);
  check(rendered['PCT-01'] === 'Find 25% of £1,000.', 'whole pounds: ' + rendered['PCT-01']);
  check(rendered['CMP-04'] === '3 kg costs £17.31. What is the cost per kg?', 'leading placeholder: ' + rendered['CMP-04']);

  check(visible() === 'v-results', 'results after last question');
  const rows = [...w.document.querySelectorAll('#rList li')];
  check(rows.length === 14, '14 topic rows: ' + rows.length);
  const rowText = (t) => rows.find((r) => r.querySelector('.t').textContent.startsWith(t))?.querySelector('.rate').textContent;
  check(rowText('Volume') === '50% Shaky', 'Volume 1/2 shaky in words: ' + rowText('Volume'));
  check(rowText('Ratio') === '50% Shaky', 'Ratio 2/4 shaky: ' + rowText('Ratio'));
  check(rowText('Algebra') === '25% Gap', 'Algebra 1/4 gap: ' + rowText('Algebra'));
  check(rows.every((r) => /(Secure|Shaky|Gap)$/.test(r.querySelector('.rate').textContent)), 'every row has a rating word');
  check(rows.every((r) => /^\d+%$/.test(r.querySelector('.bar > div').style.width)), 'every row has a bar');
  const focus = [...w.document.querySelectorAll('#rFocus li')].map((l) => l.textContent);
  check(focus.length === 11 && !focus.includes('Pythagoras') && !focus.includes('Volume') && !focus.includes('Ratio'), 'suggested focus = gap topics: ' + focus.join(', '));
  check(/tutor can change them/.test($('v-results').textContent), 'tutor note present');
  const visibleText = [...w.document.querySelectorAll('main > section:not(.hidden)')].map((s) => s.textContent).join(' ');
  check(!/[{}]/.test(visibleText), 'no leftover braces on results screen');
  check(errs.length === 0, 'no page errors' + (errs.length ? ': ' + errs.join(' | ') : ''));
  console.log(fails ? `${fails} FAILED` : 'ALL PASSED');
  process.exit(fails ? 1 : 0);
})();
