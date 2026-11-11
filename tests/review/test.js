const { JSDOM } = require('jsdom'); const fs = require('fs');
const html = fs.readFileSync(require('path').join(__dirname,'../../review/index.html'),'utf8').replace(/<script src="https:[^"]+"><\/script>/,'');
let data = JSON.parse(fs.readFileSync(require('path').join(__dirname,'data.json'))); const calls = [];
const mock = { auth:{ getSession: async()=>({data:{session:{user:{email:'sam@x'}}}}), signOut: async()=>({}) },
  rpc: async (fn,a) => { calls.push([fn,a]);
    if (fn==='is_reviewer') return {data:true}; if (fn==='review_overview') return {data:JSON.parse(JSON.stringify(data))};
    if (fn==='review_template') { if (a.p_verdict==='needs_changes' && !a.p_note) return {error:{message:'Add a note saying what needs changing'}};
      data.find(x=>x.id===a.p_template).last_review={verdict:a.p_verdict,note:a.p_note,at:'2026-11-09',by:'Sam'}; return {data:{variants_approved:20}}; }
    if (fn==='review_variant') { data.forEach(t=>t.samples.forEach(s=>{ if(s.id===a.p_variant) s.status=a.p_status; })); return {data:{}}; }
    return {data:null}; } };
const dom = new JSDOM(html,{runScripts:'dangerously',url:'https://levelwise.co.uk/review/',beforeParse(w){w.__MOCK_DB__=mock; w.CSS={escape:(s)=>s};}});
const w=dom.window,d=w.document,tick=()=>new Promise(r=>setTimeout(r,30));
const ok=(c,m)=>{ if(!c){console.log('FAIL',m);process.exitCode=1}else console.log('ok',m)};
(async()=>{ await tick(); await tick();
  d.getElementById('fState').value=''; d.getElementById('fState').dispatchEvent(new w.Event('change'));
  const cards=[...d.querySelectorAll('[data-tpl]')]; ok(cards.length===50,'50 cards');
  const bad=[]; cards.forEach(c=>{ const t=c.querySelector('.main-q')?.textContent||'';
    const samples=[...c.querySelectorAll('.sample span')].map(x=>x.textContent).join(' ');
    const work=c.querySelector('.work')?.textContent||'';
    if (/[{}]/.test(t+samples+work)) bad.push(c.dataset.tpl+': '+(t+' || '+work).slice(0,160));
    if (/NaN|undefined|Infinity/.test(t+samples+work)) bad.push(c.dataset.tpl+' NaN: '+(t+work).slice(0,160)); });
  ok(bad.length===0,'all wording and worked solutions filled'); bad.forEach(b=>console.log('   ',b));
  const fellback = data.filter(t=>{ try { return !t.samples[0] } catch(e){return true} }); ok(fellback.length===0,'every template has samples');
  // count templates whose explain failed (fell back to steps)
  const noWork = cards.filter(c=>{ const t=data.find(x=>x.id===c.dataset.tpl); const li=c.querySelectorAll('.work li').length; return t.explain && li!==t.explain.length; }).map(c=>c.dataset.tpl);
  ok(noWork.length===0,'worked lines render for every template '+noWork.join(','));
  console.log('sample card:', cards[0].querySelector('.main-q').textContent, '|', cards[0].querySelector('.work li').textContent);
  d.getElementById('fState').value='todo'; d.getElementById('fState').dispatchEvent(new w.Event('change'));
  d.querySelector('[data-tpl="ALG-01"] [data-approve]').click(); await tick(); await tick();
  ok(!d.querySelector('[data-tpl="ALG-01"]') && d.getElementById('progText').textContent.startsWith('1 of 50'),'approve removes from to-review, progress 1/50');
  const c2=d.querySelector('[data-tpl="ALG-02"]'); c2.querySelector('[data-flag]').click(); c2.querySelector('[data-sendflag]').click(); await tick();
  ok(c2.querySelector(':scope > .msg').textContent.includes('note'),'note required');
  c2.querySelector('textarea').value='Use smaller numbers'; c2.querySelector('[data-sendflag]').click(); await tick(); await tick();
  ok(d.getElementById('progSub').textContent.startsWith('1 need'),'flag counted');
  d.querySelector('[data-bad]').click(); await tick(); await tick();
  ok(d.querySelector('.sample.rej [data-undo]'),'bad numbers struck through with undo');
})();
