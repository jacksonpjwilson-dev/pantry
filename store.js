/* Pantry storage. Two backends with the same API:
   - Local: this device only (localStorage), used for "Continue without account".
   - Cloud: Firestore pantry/{uid} with subcollections items, ledger and meta (docs: state, links, inbox, ignored).
   Logbook v2 data (logbookV2/{uid}) is only ever read with get(); users/{uid} is never touched. */
(function(){
const CFG={apiKey:"AIzaSyAe50ZOlninoeHPIrxq9aylnLROi3SFekY",authDomain:"logbook-e784a.firebaseapp.com",projectId:"logbook-e784a",storageBucket:"logbook-e784a.firebasestorage.app",messagingSenderId:"901165633464",appId:"1:901165633464:web:f201b53121ccf05f04c94d"};
const SDK='https://www.gstatic.com/firebasejs/10.13.2/',LKEY='pantry:local',V2LOCAL='lb2w:data9',META=['state','links','inbox','ignored'];
const r3=v=>Math.round(v*1000)/1000,now=()=>Date.now();
const blank=()=>({items:{},ledger:{},meta:{state:{},links:{},inbox:{},ignored:{}}});
function mkEntry(op,item,before,after){return {id:op.id,itemId:item.id,itemName:item.name,unit:item.unit,delta:r3(after-before),qtyBefore:before,qtyAfter:after,reason:op.reason,source:op.source||null,note:op.note||'',ts:now(),undone:false}}
/* ---------- local ---------- */
function Local(){let d;try{d=JSON.parse(localStorage.getItem(LKEY))||blank()}catch(e){d=blank()}META.forEach(k=>d.meta[k]=d.meta[k]||{});
 const save=()=>localStorage.setItem(LKEY,JSON.stringify(d));
 return {kind:'local',data:()=>d,async load(){return d},
  async putItem(it){d.items[it.id]=Object.assign({},d.items[it.id],it,{updatedAt:now(),updatedBy:'manual'});save()},
  async delItem(id){delete d.items[id];save()},
  async adjust(op){if(d.ledger[op.id])return false;const it=d.items[op.itemId];if(!it)return false;const b=+it.qty||0,a=r3(op.setTo!=null?Math.max(0,+op.setTo):Math.max(0,b+op.delta));
   d.ledger[op.id]=mkEntry(op,it,b,a);it.qty=a;it.updatedAt=now();it.updatedBy=op.reason==='eaten'||op.reason==='correction'?'auto':'manual';save();return true},
  async undo(lid){const l=d.ledger[lid],uid='u_'+lid;if(!l||l.undone||d.ledger[uid])return false;const it=d.items[l.itemId];if(!it)return false;const b=+it.qty||0,a=r3(Math.max(0,b-l.delta));
   d.ledger[uid]=Object.assign(mkEntry({id:uid,reason:'undo',source:{of:lid},note:'Undid: '+(l.note||l.reason)},it,b,a));l.undone=true;it.qty=a;it.updatedAt=now();it.updatedBy='manual';save();return true},
  async setMeta(name,val){d.meta[name]=val;save()},
  readV2:async()=>{const s=localStorage.getItem(V2LOCAL);if(!s)return null;return PE.readV2Local(JSON.parse(s))},
  wipe(){localStorage.removeItem(LKEY);d=blank()}}}
/* ---------- cloud ---------- */
let fb=null;
function load(src){return new Promise((res,rej)=>{const s=document.createElement('script');s.src=SDK+src;s.onload=res;s.onerror=()=>rej(new Error('Could not load Firebase (offline?)'));document.head.appendChild(s)})}
async function init(){if(fb)return fb;if(!window.firebase){await load('firebase-app-compat.js');await load('firebase-auth-compat.js');await load('firebase-firestore-compat.js')}
 if(!(firebase.apps&&firebase.apps.length))firebase.initializeApp(CFG);fb={auth:firebase.auth(),db:firebase.firestore()};fb.auth.getRedirectResult().catch(e=>console.warn('redirect result',e));return fb} /* not awaited: a Google tap must open its popup immediately */
/* resolves once Firebase has restored (or not) the saved sign-in, so we never decide "signed out" too early */
function whenAuthReady(){return init().then(f=>new Promise(res=>{const off=f.auth.onAuthStateChanged(u=>{off&&off();res(u)})}))}
function Cloud(user){const uid=user.uid,root=()=>fb.db.collection('pantry').doc(uid),col=c=>root().collection(c);let d=blank();
 return {kind:'cloud',user,data:()=>d,
  async load(){const [is,ls,...ms]=await Promise.all([col('items').get(),col('ledger').orderBy('ts','desc').limit(500).get(),...META.map(m=>col('meta').doc(m).get())]);
   d=blank();is.forEach(s=>{d.items[s.id]=Object.assign({id:s.id},s.data())});ls.forEach(s=>{d.ledger[s.id]=Object.assign({id:s.id},s.data())});META.forEach((m,i)=>{d.meta[m]=ms[i].exists?ms[i].data():{}});
   if(!d.meta.state.createdAt){await root().set({owner:uid,app:'pantry',updatedAt:now()},{merge:true})}return d},
  async putItem(it){const v=Object.assign({},d.items[it.id],it,{updatedAt:now(),updatedBy:'manual'});delete v.id;await col('items').doc(it.id).set(v);d.items[it.id]=Object.assign({id:it.id},v);root().set({updatedAt:now()},{merge:true}).catch(()=>{})},
  async delItem(id){await col('items').doc(id).delete();delete d.items[id]},
  async adjust(op){const lr=col('ledger').doc(op.id),ir=col('items').doc(op.itemId);let ent=null,it2=null;
   await fb.db.runTransaction(async tx=>{ent=null;const ls=await tx.get(lr);if(ls.exists)return;const is=await tx.get(ir);if(!is.exists)return;const it=Object.assign({id:op.itemId},is.data()),b=+it.qty||0,a=r3(op.setTo!=null?Math.max(0,+op.setTo):Math.max(0,b+op.delta));
    ent=mkEntry(op,it,b,a);const by=op.reason==='eaten'||op.reason==='correction'?'auto':'manual';tx.set(lr,ent);tx.update(ir,{qty:a,updatedAt:now(),updatedBy:by});it2=Object.assign(it,{qty:a,updatedAt:now(),updatedBy:by})});
   if(!ent)return false;d.ledger[op.id]=ent;d.items[op.itemId]=it2;return true},
  async undo(lid){const uidr='u_'+lid,lr=col('ledger').doc(lid),ur=col('ledger').doc(uidr);let ent=null,it2=null;
   await fb.db.runTransaction(async tx=>{ent=null;const [ls,us]=[await tx.get(lr),await tx.get(ur)];if(!ls.exists||us.exists)return;const l=ls.data();if(l.undone)return;const ir=col('items').doc(l.itemId),is=await tx.get(ir);if(!is.exists)return;
    const it=Object.assign({id:l.itemId},is.data()),b=+it.qty||0,a=r3(Math.max(0,b-l.delta));ent=mkEntry({id:uidr,reason:'undo',source:{of:lid},note:'Undid: '+(l.note||l.reason)},it,b,a);
    tx.set(ur,ent);tx.update(lr,{undone:true});tx.update(ir,{qty:a,updatedAt:now(),updatedBy:'manual'});it2=Object.assign(it,{qty:a})});
   if(!ent)return false;d.ledger[uidr]=ent;if(d.ledger[lid])d.ledger[lid].undone=true;d.items[it2.id]=it2;return true},
  async setMeta(name,val){await col('meta').doc(name).set(val);d.meta[name]=val},
  async readV2(){const s=await fb.db.collection('logbookV2').doc(uid).get();return s.exists?PE.readV2Cloud(s.data()):null}}}
const errMsg=e=>{const c=e&&e.code||'';return /permission/.test(c)?'Cloud access denied. The Firestore rules need the pantry rule (see Settings).':/unavailable|network/.test(c)?'You look offline. Try again when you have a connection.':/wrong-password|invalid-credential|user-not-found|invalid-login/.test(c)?'That email and password don’t match. If you signed up with Google, close this and tap Sign in with Google. Or tap Forgot password.':/not-ready/.test(c)?'Getting Google ready, tap again':/popup-blocked/.test(c)?'Your browser blocked the Google window. Tap Sign in with Google again.':/email-already/.test(c)?'That email already has an account. Sign in instead.':/weak-password/.test(c)?'Use at least 6 characters.':/invalid-email/.test(c)?'That email doesn’t look right.':/popup-closed|cancelled-popup/.test(c)?'Sign-in was cancelled.':(e&&e.message)||String(e)};
let prepP=null;function prepare(){if(fb)return Promise.resolve(fb);if(!prepP)prepP=init().catch(e=>{prepP=null;console.warn('preload',e)});return prepP} /* load SDKs + auth before any Google tap */
window.STORE={Local,Cloud,init,whenAuthReady,errMsg,
 google(){ /* popup opened inside the tap; never a redirect on iPhone/iPad (Safari blocks the cross-site storage a redirect needs, so you land back signed out) */
  const ios=/iP(hone|ad|od)/.test(navigator.userAgent)||(navigator.platform==='MacIntel'&&navigator.maxTouchPoints>1);
  const go=()=>{const p=new firebase.auth.GoogleAuthProvider();p.setCustomParameters({prompt:'select_account'});return fb.auth.signInWithPopup(p).catch(e=>{if(/popup-blocked|operation-not-supported/.test(e.code||'')&&!ios)return fb.auth.signInWithRedirect(p);throw e})};
  if(fb)return go(); /* fb ready: popup opens synchronously inside the tap */
  prepare();const e=new Error('Getting Google ready, tap again');e.code='app/not-ready';return Promise.reject(e)}, /* never open the popup after an async load: iOS Safari blocks it (Bugsy) */
 prepare,
 async email(email,pass,create){await init();return create?fb.auth.createUserWithEmailAndPassword(email,pass):fb.auth.signInWithEmailAndPassword(email,pass)},
 async reset(email){await init();return fb.auth.sendPasswordResetEmail(email)},
 async signOut(){if(fb)await fb.auth.signOut()},
 current:()=>fb&&fb.auth.currentUser};
})();
