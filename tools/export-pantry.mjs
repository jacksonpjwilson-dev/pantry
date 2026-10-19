#!/usr/bin/env node
/* Nightly pantry export for Sally (path B). READ-ONLY: this script only calls get()/listDocuments().
   It never writes to Firestore. It writes one local file: /home/box/shared/crew/pantry.json.

   Usage:
     PANTRY_SA_KEY_FILE=/path/to/key.json node tools/export-pantry.mjs [--uid <uid>] [--out <file>] [--log-run] [--no-logbook]
     node tools/export-pantry.mjs --fake test-cloud.json      (testing without Firebase)

   Key: PANTRY_SA_KEY_FILE (or GOOGLE_APPLICATION_CREDENTIALS), default ~/.config/pantry/service-account.json.
   Never commit the key (see .gitignore). UID: --uid or PANTRY_UID; if omitted and exactly one pantry exists, that one is used.

   qty in the output = what the app has saved, minus linked foods logged in Logbook v2 that the app hasn't
   processed yet (so it's right even if Jackson hasn't opened the pantry app today). storedQty is shown when they differ. */
import fs from 'node:fs';import path from 'node:path';import os from 'node:os';import {createRequire} from 'node:module';import {fileURLToPath} from 'node:url';
const require=createRequire(import.meta.url),here=path.dirname(fileURLToPath(import.meta.url));const PE=require(path.join(here,'..','engine.js'));
const args=process.argv.slice(2),opt=k=>{const i=args.indexOf(k);return i>=0?args[i+1]:null},flag=k=>args.includes(k);
const OUT=opt('--out')||process.env.PANTRY_OUT||'/home/box/shared/crew/pantry.json',RUNS='/home/box/shared/crew/runs.jsonl';
function logRun(status,note){if(!flag('--log-run'))return;fs.appendFileSync(RUNS,JSON.stringify({ts:PE.ontario(Date.now()),bot:'Felix',routine:'pantry-export',status,note})+'\n')}
/* tiny read-only adapter so tests can run against a JSON snapshot instead of Firestore */
function fakeDb(file){const docs=JSON.parse(fs.readFileSync(file,'utf8')).docs||{};const snap=p=>({id:p.split('/').pop(),exists:docs[p]!==undefined,data:()=>docs[p]});
 const doc=p=>({id:p.split('/').pop(),get:async()=>snap(p),collection:c=>col(p+'/'+c)});
 const col=p=>({doc:id=>doc(p+'/'+id),get:async()=>{const ds=Object.keys(docs).filter(k=>k.startsWith(p+'/')&&!k.slice(p.length+1).includes('/')).map(snap);return {docs:ds,forEach:f=>ds.forEach(f)}},
  listDocuments:async()=>[...new Set(Object.keys(docs).filter(k=>k.startsWith(p+'/')).map(k=>k.slice(p.length+1).split('/')[0]))].map(id=>doc(p+'/'+id))});
 return {collection:col}}
async function realDb(){const keyFile=process.env.PANTRY_SA_KEY_FILE||process.env.GOOGLE_APPLICATION_CREDENTIALS||path.join(os.homedir(),'.config/pantry/service-account.json');
 if(!fs.existsSync(keyFile))throw new Error(`No service-account key at ${keyFile}. Set PANTRY_SA_KEY_FILE (see pantry-key-setup.md).`);
 const admin=(await import('firebase-admin')).default;const cred=JSON.parse(fs.readFileSync(keyFile,'utf8'));
 if(cred.project_id&&cred.project_id!=='logbook-e784a')throw new Error('Key is for project '+cred.project_id+', expected logbook-e784a');
 admin.initializeApp({credential:admin.credential.cert(cred),projectId:'logbook-e784a'});return admin.firestore()}
async function main(){const db=opt('--fake')?fakeDb(opt('--fake')):await realDb();
 let uid=opt('--uid')||process.env.PANTRY_UID;
 if(!uid){const refs=await db.collection('pantry').listDocuments();if(refs.length!==1)throw new Error(refs.length?`Found ${refs.length} pantries; pass --uid or PANTRY_UID.`:'No pantry found yet (open the app and sign in once).');uid=refs[0].id}
 const root=db.collection('pantry').doc(uid),get=async c=>{const s=await root.collection(c).get(),o={};s.forEach(d=>{o[d.id]=Object.assign({id:d.id},d.data())});return o};
 const [items,ledger,meta]=await Promise.all([get('items'),get('ledger'),get('meta')]);
 const st={items,ledger:Object.values(ledger),links:(meta.links||{}),ignored:(meta.ignored||{}),inbox:(meta.inbox||{}),startDate:(meta.state||{}).startDate,lastProcessed:(meta.state||{}).lastProcessed||0};
 ['links','ignored','inbox'].forEach(k=>{if(st[k])delete st[k].id});
 /* projection: what the app would take off if it were opened now (computed in memory only, nothing is written) */
 const pending={};let pendingCount=0,logbook='skipped';
 if(!flag('--no-logbook')){const s=await db.collection('logbookV2').doc(uid).get();if(s.exists){const v2=PE.readV2Cloud(s.data()),{ops}=PE.plan(v2,st);
   ops.forEach(o=>{if(o.t==='adjust'){pending[o.itemId]=(pending[o.itemId]||0)+o.delta;pendingCount++}});logbook=v2.at?PE.ontario(v2.at):'read'}else logbook='no Logbook v2 data'}
 const out=Object.values(items).sort((a,b)=>(a.name||'').localeCompare(b.name||'')).map(it=>{const stored=+it.qty||0,qty=PE.r3(Math.max(0,stored+(pending[it.id]||0))),cur=Object.assign({},it,{qty});
  const o={name:it.name,qty,unit:it.unit,lowAt:it.lowAt??null,low:PE.status(cur)!=='ok',status:PE.status(cur),category:it.category||'Other',updatedAt:it.updatedAt?PE.ontario(it.updatedAt):null};
  if(qty!==stored){o.storedQty=stored;o.pendingEaten=PE.r3(stored-qty)}return o});
 const doc={generatedAt:PE.ontario(Date.now()),source:'Pantry app (Firestore pantry/{uid}), read-only export',logbookLastSync:logbook,pendingLogbookEntries:pendingCount,
  itemCount:out.length,lowItems:out.filter(x=>x.low).map(x=>x.name),items:out,
  notes:'qty includes linked foods logged in Logbook v2 that the app has not processed yet. low = at or below lowAt, or out. Unlinked foods are not counted.'};
 fs.mkdirSync(path.dirname(OUT),{recursive:true});const tmp=OUT+'.tmp-'+process.pid;fs.writeFileSync(tmp,JSON.stringify(doc,null,1)+'\n');fs.renameSync(tmp,OUT);
 const note=`${out.length} items, ${doc.lowItems.length} low, ${pendingCount} pending Logbook entries`;console.log('Wrote',OUT,'-',note);logRun('ok',note)}
main().then(()=>process.exit(0)).catch(e=>{console.error('pantry export failed:',e.message);try{logRun('fail',String(e.message).slice(0,160))}catch(x){}process.exit(1)});
