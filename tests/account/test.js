const { JSDOM } = require('jsdom'); const fs = require('fs');
const html = fs.readFileSync(require('path').join(__dirname,'../../account/index.html'),'utf8').replace(/<script src="\/vendor[^"]+"><\/script>/,'');
function run(opts){ const calls=[]; let session = opts.session; let deletion=null; let authCb;
 const mock={ auth:{ getSession:async()=>({data:{session}}), onAuthStateChange:(cb)=>{authCb=cb;},
   signInWithPassword:async({password})=> password==='bad'?{error:{message:'Invalid login credentials'}}:(session={user:{}}, {data:{user:{}}}),
   resetPasswordForEmail:async(e,o)=>{calls.push(['reset',e,o]);return {}}, updateUser:async(u)=>{calls.push(['update',u]);return {}}, signOut:async()=>{session=null;return {}} },
  rpc:async(fn,a)=>{calls.push([fn,a]);
   if(fn==='my_account') return {data:{email:'mum@x.com',children:[{nickname:'Lilly',games:1},{nickname:'Lucy',games:0}],deletion}};
   if(fn==='request_account_deletion'){deletion={requested_at:'2026-11-09',delete_by:'2026-12-09'};return {data:{}}}
   if(fn==='cancel_account_deletion'){deletion=null;return {data:true}} return {data:null}} };
 const dom=new JSDOM(html,{runScripts:'dangerously',url:'https://levelwise.co.uk/account/'+(opts.hash||''),beforeParse(w){w.__MOCK_DB__=mock;}});
 return {dom,calls,fire:(e)=>authCb&&authCb(e)}; }
const tick=()=>new Promise(r=>setTimeout(r,30)); let fail=0; const ok=(c,m)=>{console.log(c?'ok':'FAIL',m); if(!c) fail=1;};
const vis=(d,id)=>!d.getElementById(id).classList.contains('hidden');
const submit=(w,el)=>el.dispatchEvent(new w.Event('submit',{cancelable:true}));
(async()=>{
 let {dom,calls}=run({}); let w=dom.window,d=w.document; await tick();
 ok(vis(d,'v-signin'),'signed out shows sign in');
 d.getElementById('toForgot').click(); ok(vis(d,'v-forgot'),'forgot link');
 d.getElementById('fEmail').value='mum@x.com'; submit(w,d.getElementById('forgotForm')); await tick();
 const r=calls.find(c=>c[0]==='reset'); ok(r&&r[2].redirectTo==='https://levelwise.co.uk/account/','reset email with redirect');
 ok(d.getElementById('forgotMsg').textContent.includes('If that email'),'neutral message');
 ({dom,calls}=run({session:{user:{}}})); w=dom.window; d=w.document; await tick(); await tick();
 ok(vis(d,'v-account') && d.getElementById('kids').textContent.includes('Lucy (no game yet)'),'account view with kids');
 d.getElementById('nPass').value='short'; d.getElementById('nPass2').value='short'; submit(w,d.getElementById('passForm')); await tick();
 ok(d.getElementById('passMsg').textContent.includes('8'),'min length');
 d.getElementById('nPass').value='longenough1'; d.getElementById('nPass2').value='different1'; submit(w,d.getElementById('passForm')); await tick();
 ok(d.getElementById('passMsg').textContent.includes('match'),'mismatch');
 d.getElementById('nPass2').value='longenough1'; submit(w,d.getElementById('passForm')); await tick();
 ok(calls.some(c=>c[0]==='update'&&c[1].password==='longenough1'),'password updated');
 ok(d.getElementById('delBtn').disabled,'delete disabled until DELETE typed');
 d.getElementById('delConfirm').value='delete'; d.getElementById('delConfirm').dispatchEvent(new w.Event('input'));
 ok(!d.getElementById('delBtn').disabled,'enabled after typing');
 submit(w,d.getElementById('delForm')); await tick(); await tick();
 ok(vis(d,'delPending') && d.getElementById('delBy').textContent.includes('December'),'pending shown with date');
 d.getElementById('delCancel').click(); await tick(); await tick();
 ok(!vis(d,'delPending') && vis(d,'delForm'),'cancel restores');
 const x=run({session:{user:{}},hash:'#access_token=abc&type=recovery'}); w=x.dom.window; d=w.document; await tick(); await tick();
 ok(vis(d,'v-recover'),'recovery link shows new password form');
 d.getElementById('rPass').value='newpass123'; d.getElementById('rPass2').value='newpass123'; submit(w,d.getElementById('recoverForm')); await tick(); await tick();
 ok(x.calls.some(c=>c[0]==='update') && vis(d,'v-account'),'recovery saves and signs in');
 process.exitCode=fail;
})();
