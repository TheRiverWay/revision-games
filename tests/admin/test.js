const { JSDOM } = require('jsdom');
const fs = require('fs');
let html = fs.readFileSync(require('path').join(__dirname,'../../admin/index.html'),'utf8').replace(/<script src="https:[^"]+"><\/script>/,'');
const calls = [];
const overview = [{ id:'p1', email:'mum@example.com', created_at:'2026-11-01', children:[
  { id:'c1', nickname:'Lilly', has_pin:true, focus_topics:['Ratio'], last_check:{id:7, finished_at:'2026-11-09'},
    games:[{ id:1, theme:'restaurant', flavour:'pizza', custom_names:{biz:'Lil Pizza'}, exam_board:'AQA', rank_tier:1, rank_level:2, answered_7d:12, last_played:'2026-11-08' }] }]}];
const q = (data) => { const o = { select:()=>o, neq:()=>o, order:()=>Promise.resolve({data}) }; return o; };
const mock = {
  auth: { getSession: async()=>({data:{session:{user:{email:'joel@x'}}}}), signOut: async()=>({}) },
  from: (t) => q(t==='themes' ? [{id:'restaurant',name:'Kitchen Tycoon',status:'live',custom_name_fields:[{key:'biz',label:'Restaurant name'},{key:'boss',label:'Head chef name'}],tier_names:['Food Van','Market Stall']},{id:'military',name:'Field Command',status:'draft',custom_name_fields:[{key:'squad',label:'Squad name'}],tier_names:['Recruit']}]
     : [{id:'pizza',theme:'restaurant',name:'Pizza',unlock_tier:1},{id:'sushi',theme:'restaurant',name:'Sushi',unlock_tier:3}]),
  rpc: async (fn, args) => { calls.push([fn,args]);
    if (fn==='is_admin') return {data:true}; if (fn==='focus_topic_names') return {data:['Fractions','Ratio','Algebra']};
    if (fn==='admin_overview') return {data:overview};
    if (fn==='assign_game') return {data:{created:false,game_id:1}};
    if (fn==='admin_add_child') return {data:'c2'}; if (fn==='admin_deletion_requests') return {data:[{id:5,email:'gone@x.com',requested_at:'2026-11-09',delete_by:'2026-12-09',children:2,reason:'done with GCSEs'}]}; if (fn==='admin_delete_account') return {error:{message:'Could not find the function public.admin_delete_account'}}; if (fn==='admin_make_tutor') return args.p_email==='x@y.z'?{error:{message:'No account with that email. Ask them to sign up first.'}}:{data:'t1'};
    if (fn==='check_results') return {data:{topics:[{topic:'Ratio',asked:3,correct:1,rating:'gap'}],suggested_focus:['Ratio']}};
    return {data:null}; } };
const dom = new JSDOM(html, { runScripts:'dangerously', url:'https://levelwise.co.uk/admin/', beforeParse(w){ w.__MOCK_DB__ = mock; } });
const w = dom.window, d = w.document, tick = () => new Promise(r=>setTimeout(r,30)), ok=(c,m)=>{ if(!c){console.log('FAIL',m);process.exitCode=1}else console.log('ok',m)};
(async()=>{ await tick(); await tick();
  ok(!d.getElementById('v-admin').classList.contains('hidden'),'admin view shown');
  ok(d.body.textContent.includes('Lil Pizza') && d.body.textContent.includes('Food Van, level 2'),'game row rendered');
  d.querySelector('[data-assign="c1"]').click(); await tick();
  const f = d.getElementById('as-c1');
  ok(f.querySelector('[name=flavour]').options.length===2,'only unlocked venture + let them choose');
  ok(f.querySelector('[name=n_biz]').value==='Lil Pizza','existing names prefilled');
  ok(f.querySelector('input[value=Ratio]').checked,'focus prefilled');
  f.querySelector('[name=board]').value='OCR'; f.querySelector('[name=n_boss]').value='Chef Lil';
  f.dispatchEvent(new w.Event('submit',{cancelable:true})); await tick(); await tick();
  const a = calls.find(c=>c[0]==='assign_game')[1];
  ok(a.p_exam_board==='OCR' && a.p_custom_names.boss==='Chef Lil' && a.p_flavour==='pizza' && a.p_focus_topics[0]==='Ratio','assign_game args '+JSON.stringify(a));
  ok(d.getElementById('topMsg').textContent.includes('/tycoon/?skin=restaurant'),'play link shown: '+d.getElementById('topMsg').textContent);
  d.querySelector('[data-results="7"]').click(); await tick();
  ok(d.getElementById('res-c1').textContent.includes('1 / 3'),'results shown');
  d.querySelector('[data-addchild="p1"]').click(); await tick();
  const af = d.getElementById('addForm-p1'); af.querySelector('[name=nick]').value='Max'; af.querySelector('[name=pin]').value='1234';
  af.dispatchEvent(new w.Event('submit',{cancelable:true})); await tick(); await tick();
  ok(calls.some(c=>c[0]==='admin_add_child'&&c[1].p_nickname==='Max'),'add child called');
  d.getElementById('search').value='nobody'; d.getElementById('search').dispatchEvent(new w.Event('input')); 
  ok(d.body.textContent.includes('No families match'),'search filters');
})();
setTimeout(async()=>{ const d2=dom.window.document; d2.getElementById('tEmail').value='x@y.z'; d2.getElementById('tName').value='Sam';
 d2.getElementById('tutorForm').dispatchEvent(new dom.window.Event('submit',{cancelable:true})); await new Promise(r=>setTimeout(r,30));
 console.log(d2.getElementById('tutorMsg').textContent.includes('sign up')?'ok tutor error shown':'FAIL tutor err');
 d2.getElementById('tEmail').value='sam@tutor.com'; d2.getElementById('tutorForm').dispatchEvent(new dom.window.Event('submit',{cancelable:true})); await new Promise(r=>setTimeout(r,30));
 console.log(d2.getElementById('tutorMsg').textContent.includes('now a tutor')?'ok tutor added':'FAIL tutor add'); },600);
setTimeout(async()=>{ const d2=dom.window.document; const f=d2.querySelector('[data-delreq="5"]');
 console.log(d2.getElementById('delReqs').textContent.includes('gone@x.com')?'ok deletion request listed':'FAIL list');
 f.querySelector('input').value='gone@x.com'; f.dispatchEvent(new dom.window.Event('submit',{cancelable:true,bubbles:true})); await new Promise(r=>setTimeout(r,30));
 console.log(d2.getElementById('delMsg-5').textContent.includes('Run the account deletion SQL')?'ok friendly missing-SQL message':'FAIL msg: '+d2.getElementById('delMsg-5').textContent); },900);
