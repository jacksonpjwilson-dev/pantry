/* Pantry app (p1). Widget-home style matching Logbook v2. */
(function(){
const VERSION='p1',LOGBOOK_URL='https://jacksonpjwilson-dev.github.io/logbook-v2/preview-widget/';
const $=s=>document.querySelector(s),esc=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const uid=()=>Date.now().toString(36)+Math.random().toString(36).slice(2,7);
const iso=d=>{const x=new Date(d);x.setMinutes(x.getMinutes()-x.getTimezoneOffset());return x.toISOString().slice(0,10)};
const CW={
0:{n:"Neutral greyscale",fh:"-apple-system,system-ui,sans-serif",fb:"-apple-system,system-ui,sans-serif",pair:"System",L:{bg:"#f2f2f2",card:"#fff",fg:"#111",mut:"#777",line:"#ddd",a:"#333",a2:"#777",a3:"#aaa",on:"#fff"},Dk:{bg:"#111",card:"#1e1e1e",fg:"#eee",mut:"#888",line:"#333",a:"#ddd",a2:"#999",a3:"#666",on:"#111"}},
1:{n:"Midnight Navy & Gold",fh:"'Playfair Display',Georgia,serif",fb:"'Inter',-apple-system,sans-serif",pair:"Playfair Display + Inter",L:{bg:"#f6f3ea",card:"#fff",fg:"#0f1b33",mut:"#6b7280",line:"#e6dfcc",a:"#0f1b33",a2:"#c9a227",a3:"#8aa0c8",on:"#f6e7b0"},Dk:{bg:"#0a1326",card:"#13203d",fg:"#f3ead2",mut:"#8d97ad",line:"#22325a",a:"#d4af37",a2:"#8aa0c8",a3:"#f3ead2",on:"#0a1326"}},
2:{n:"Forest & Cream",fh:"'Fraunces',Georgia,serif",fb:"'Source Sans 3',-apple-system,sans-serif",pair:"Fraunces + Source Sans 3",L:{bg:"#f4efe3",card:"#fbf8f0",fg:"#1f3a2b",mut:"#7a7a68",line:"#e2dac6",a:"#2f5d43",a2:"#a3b18a",a3:"#d9a441",on:"#f4efe3"},Dk:{bg:"#13221a",card:"#1c3126",fg:"#efe8d6",mut:"#93a08f",line:"#2c4436",a:"#a3c49a",a2:"#d9a441",a3:"#efe8d6",on:"#13221a"}},
3:{n:"Sunset Coral",fh:"'Poppins',-apple-system,sans-serif",fb:"'Poppins',-apple-system,sans-serif",pair:"Poppins (600/400)",L:{bg:"#fff5f0",card:"#fff",fg:"#3b1f1a",mut:"#9a7268",line:"#fbd9cc",a:"#ff6b57",a2:"#ffb347",a3:"#c2549c",on:"#fff"},Dk:{bg:"#24120f",card:"#341c17",fg:"#ffe9e1",mut:"#b88a7e",line:"#4a2a22",a:"#ff7a66",a2:"#ffb347",a3:"#e077b6",on:"#24120f"}},
4:{n:"Mono + Red",fh:"'Helvetica Neue',Helvetica,Arial,sans-serif",fb:"'Helvetica Neue',Helvetica,Arial,sans-serif",pair:"Helvetica Neue / Inter Tight",L:{bg:"#fff",card:"#fff",fg:"#000",mut:"#666",line:"#000",a:"#e10600",a2:"#000",a3:"#999",on:"#fff"},Dk:{bg:"#000",card:"#000",fg:"#fff",mut:"#999",line:"#fff",a:"#ff2a1f",a2:"#fff",a3:"#666",on:"#000"}},
5:{n:"Arctic",fh:"'Manrope',-apple-system,sans-serif",fb:"'Manrope',-apple-system,sans-serif",pair:"Manrope",L:{bg:"#eef6fb",card:"#fff",fg:"#0d2a3d",mut:"#6c8799",line:"#d4e6f1",a:"#2b8fd6",a2:"#7cc8f0",a3:"#b6dcf2",on:"#fff"},Dk:{bg:"#0a1a26",card:"#11283a",fg:"#e6f4fc",mut:"#7e9db0",line:"#1e3c52",a:"#6cc4f5",a2:"#b6e3fa",a3:"#3a7fae",on:"#0a1a26"}},
6:{n:"Sand & Terracotta",fh:"'DM Serif Display',Georgia,serif",fb:"'DM Sans',-apple-system,sans-serif",pair:"DM Serif Display + DM Sans",L:{bg:"#f3ebdf",card:"#faf5ec",fg:"#3d2a20",mut:"#93806f",line:"#e3d6c2",a:"#c4643f",a2:"#d9a87e",a3:"#7f8f6a",on:"#fff"},Dk:{bg:"#221812",card:"#33241b",fg:"#f3e6d6",mut:"#a8927e",line:"#46342a",a:"#e07b52",a2:"#d9a87e",a3:"#9fb087",on:"#221812"}},
7:{n:"Electric Violet",fh:"'Space Grotesk',-apple-system,sans-serif",fb:"'Inter',-apple-system,sans-serif",pair:"Space Grotesk + Inter",L:{bg:"#f5f2ff",card:"#fff",fg:"#1a1033",mut:"#7a6f99",line:"#e4dcff",a:"#7c3aed",a2:"#22d3ee",a3:"#f472b6",on:"#fff"},Dk:{bg:"#0e0820",card:"#1a1236",fg:"#efeaff",mut:"#9a8fc0",line:"#2c2257",a:"#a26bff",a2:"#22d3ee",a3:"#f472b6",on:"#0e0820"}},
8:{n:"Graphite & Mint",fh:"'IBM Plex Sans',-apple-system,sans-serif",fb:"'IBM Plex Sans',-apple-system,sans-serif",pair:"IBM Plex Sans + Plex Mono numerals",L:{bg:"#eceeee",card:"#fff",fg:"#1f2326",mut:"#6d7579",line:"#d8dcdd",a:"#12b886",a2:"#3a4045",a3:"#9ad9c3",on:"#fff"},Dk:{bg:"#16191b",card:"#22272a",fg:"#e8eceb",mut:"#8a9397",line:"#33393d",a:"#3ee6b0",a2:"#9aa4a8",a3:"#1f7a5e",on:"#16191b"}},
9:{n:"Aviator",fh:"'Barlow Condensed','Arial Narrow',sans-serif",fb:"'Barlow',-apple-system,sans-serif",pair:"Barlow Condensed + Barlow",L:{bg:"#f2f4f7",card:"#fff",fg:"#0b1f3a",mut:"#5d6b80",line:"#d9dfe7",a:"#ff6a13",a2:"#0b1f3a",a3:"#7f93ad",on:"#fff"},Dk:{bg:"#07142a",card:"#0e2140",fg:"#f4f6fa",mut:"#8796ad",line:"#1d3560",a:"#ff7a26",a2:"#f4f6fa",a3:"#4f6d99",on:"#07142a"}},
10:{n:"Rose & Charcoal",fh:"'Cormorant Garamond',Georgia,serif",fb:"'Lato',-apple-system,sans-serif",pair:"Cormorant Garamond + Lato",L:{bg:"#f7eeee",card:"#fff",fg:"#2b2b2e",mut:"#8a7f80",line:"#ead8d8",a:"#c0687a",a2:"#2b2b2e",a3:"#e3b3bc",on:"#fff"},Dk:{bg:"#1c1c1f",card:"#2a2a2e",fg:"#f2e6e7",mut:"#9a9093",line:"#3a3a3f",a:"#e48a9c",a2:"#f2e6e7",a3:"#7d4b56",on:"#1c1c1f"}}};
CW.teal={n:'Logbook Teal',fh:'-apple-system,system-ui,sans-serif',fb:'-apple-system,system-ui,sans-serif',L:{bg:'#f6f7fb',card:'#fff',fg:'#0f172a',mut:'#64748b',line:'#e2e8f0',a:'#0d9488',a2:'#6366f1',a3:'#ec4899',on:'#fff'},Dk:{bg:'#0b0d12',card:'#151922',fg:'#f1f5f9',mut:'#94a3b8',line:'#263041',a:'#2dd4bf',a2:'#818cf8',a3:'#f472b6',on:'#042f2e'}};
CW.grey=Object.assign({},CW[0],{n:'Grey'});delete CW[0];
const CW_ORDER=['teal',1,2,3,4,5,6,7,8,9,10,'grey'].map(String),TH_KEY='pantry:theme';
const TH=Object.assign({cw:'teal',mode:'auto'},JSON.parse(localStorage.getItem(TH_KEY)||'{}'));
function applyTheme(){const dark=TH.mode==='dark'||(TH.mode==='auto'&&matchMedia('(prefers-color-scheme: dark)').matches);const c=CW[TH.cw]||CW.teal,v=dark?c.Dk:c.L,r=document.documentElement;
 r.dataset.theme=dark?'dark':'light';const mix=(a,b,p)=>`color-mix(in srgb,${a} ${p}%,${b})`;
 const set={'--bg':v.bg,'--card':v.card,'--card2':mix(v.line,v.card,55),'--text':v.fg,'--muted':v.mut,'--line':v.line,'--accent':v.a,'--accent2':v.a2,'--accent3':v.a3,'--on':v.on,'--accentSoft':mix(v.a,v.card,22),'--fh':c.fh,'--fb':c.fb};
 for(const k in set)r.style.setProperty(k,set[k]);document.querySelectorAll('meta[name=theme-color]').forEach(x=>x.setAttribute('content',v.bg))}
function saveTheme(){localStorage.setItem(TH_KEY,JSON.stringify(TH));applyTheme()}
matchMedia('(prefers-color-scheme: dark)').addEventListener('change',()=>{if(TH.mode==='auto')applyTheme()});
const sv=p=>`<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round">${p}</svg>`;
const IC={items:sv('<path d="M7 3h10M8 3v3l-2 3v11a1 1 0 0 0 1 1h10a1 1 0 0 0 1-1V9l-2-3V3"/><path d="M6 12h12"/>'),
 inbox:sv('<path d="M10 14a3.5 3.5 0 0 0 5 0l3-3a3.5 3.5 0 0 0-5-5l-1 1"/><path d="M14 10a3.5 3.5 0 0 0-5 0l-3 3a3.5 3.5 0 0 0 5 5l1-1"/>'),
 bought:sv('<path d="M5 8h14l-1 12H6z"/><path d="M9 8V6a3 3 0 0 1 6 0v2"/><path d="M12 12v5M9.5 14.5h5"/>'),
 history:sv('<path d="M3 12a9 9 0 1 0 3-6.7L3 8"/><path d="M3 3v5h5"/><path d="M12 7v5l3 2"/>'),
 settings:sv('<circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.7 1.7 0 0 0 .3 1.8l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.7 1.7 0 0 0-1.8-.3 1.7 1.7 0 0 0-1 1.5V21a2 2 0 1 1-4 0v-.1a1.7 1.7 0 0 0-1.1-1.5 1.7 1.7 0 0 0-1.8.3l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1a1.7 1.7 0 0 0 .3-1.8 1.7 1.7 0 0 0-1.5-1H3a2 2 0 1 1 0-4h.1a1.7 1.7 0 0 0 1.5-1.1 1.7 1.7 0 0 0-.3-1.8l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1a1.7 1.7 0 0 0 1.8.3H9a1.7 1.7 0 0 0 1-1.5V3a2 2 0 1 1 4 0v.1a1.7 1.7 0 0 0 1 1.5 1.7 1.7 0 0 0 1.8-.3l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.7 1.7 0 0 0-.3 1.8V9a1.7 1.7 0 0 0 1.5 1H21a2 2 0 1 1 0 4h-.1a1.7 1.7 0 0 0-1.5 1z"/>'),
 low:sv('<path d="M12 3 2 20h20z"/><path d="M12 10v4M12 17h.01"/>'),eat:sv('<path d="M4 11h16a8 8 0 0 1-16 0zM8 7c0-2 2-2 2-4M12 7c0-2 2-2 2-4"/>'),
 plus:sv('<path d="M12 5v14M5 12h14"/>'),google:'<svg viewBox="0 0 24 24"><path fill="#4285F4" d="M22.6 12.2c0-.8-.1-1.5-.2-2.2H12v4.2h5.9a5 5 0 0 1-2.2 3.3v2.7h3.6c2.1-1.9 3.3-4.8 3.3-8z"/><path fill="#34A853" d="M12 23c3 0 5.5-1 7.3-2.7l-3.6-2.8c-1 .7-2.2 1.1-3.7 1.1-2.9 0-5.3-1.9-6.2-4.5H2.1v2.8A11 11 0 0 0 12 23z"/><path fill="#FBBC05" d="M5.8 14.1a6.6 6.6 0 0 1 0-4.2V7.1H2.1a11 11 0 0 0 0 9.8z"/><path fill="#EA4335" d="M12 5.4c1.6 0 3.1.6 4.2 1.7l3.2-3.2A11 11 0 0 0 2.1 7.1l3.7 2.8C6.7 7.3 9.1 5.4 12 5.4z"/></svg>',
 mail:sv('<rect x="3" y="5" width="18" height="14" rx="2"/><path d="m3 7 9 6 9-6"/>'),phone:sv('<rect x="7" y="2" width="10" height="20" rx="2"/><path d="M11 18h2"/>'),sync:sv('<path d="M21 12a9 9 0 0 1-15 6.7L3 16M3 12a9 9 0 0 1 15-6.7L21 8"/><path d="M21 3v5h-5M3 21v-5h5"/>')};
/* themed illustration: shelves with jars, gently bobbing */
const ART=(cls)=>`<svg class="${cls||'art'}" viewBox="0 0 240 200" aria-hidden="true"><defs><linearGradient id="gj" x1="0" x2="0" y1="0" y2="1"><stop offset="0" stop-color="var(--accent)" stop-opacity=".9"/><stop offset="1" stop-color="var(--accent)" stop-opacity=".55"/></linearGradient></defs>
 <circle cx="120" cy="100" r="92" fill="var(--accentSoft)" opacity=".7"/><rect x="28" y="128" width="184" height="8" rx="4" fill="var(--line)"/><rect x="40" y="74" width="160" height="7" rx="3.5" fill="var(--line)"/>
 <g class="bob"><rect x="56" y="34" width="34" height="40" rx="8" fill="var(--card)" stroke="var(--accent)" stroke-width="3"/><rect x="58" y="50" width="30" height="22" rx="6" fill="url(#gj)"/><rect x="60" y="28" width="26" height="8" rx="3" fill="var(--accent2)"/></g>
 <g class="bob" style="animation-delay:-1.3s"><rect x="104" y="40" width="30" height="34" rx="7" fill="var(--card)" stroke="var(--accent2)" stroke-width="3"/><rect x="106" y="58" width="26" height="14" rx="5" fill="var(--accent2)" opacity=".7"/><rect x="108" y="34" width="22" height="7" rx="3" fill="var(--accent3)"/></g>
 <g class="bob" style="animation-delay:-2.4s"><rect x="148" y="28" width="38" height="46" rx="9" fill="var(--card)" stroke="var(--accent3)" stroke-width="3"/><rect x="150" y="56" width="34" height="16" rx="6" fill="var(--accent3)" opacity=".6"/><rect x="152" y="22" width="30" height="8" rx="3" fill="var(--accent)"/></g>
 <g class="bob" style="animation-delay:-.7s"><rect x="62" y="92" width="44" height="36" rx="6" fill="var(--accent)" opacity=".85"/><rect x="70" y="100" width="28" height="10" rx="3" fill="var(--card)" opacity=".85"/></g>
 <g class="bob" style="animation-delay:-1.9s"><rect x="118" y="86" width="26" height="42" rx="11" fill="var(--accent2)" opacity=".85"/><rect x="124" y="80" width="14" height="8" rx="3" fill="var(--accent2)"/></g>
 <g class="bob" style="animation-delay:-3s"><circle cx="172" cy="112" r="16" fill="var(--accent3)" opacity=".8"/><path d="M172 96c2-6 8-8 12-7" stroke="var(--accent)" stroke-width="3" fill="none" stroke-linecap="round"/></g></svg>`;
/* ---------- state ---------- */
const S={store:null,v2:null,v2s:{ok:null,msg:'Not checked yet'},syncing:false,stack:[],signedOutNote:false,lastSync:0};
const D=()=>S.store.data(),M=()=>D().meta;
const items=()=>Object.values(D().items).sort((a,b)=>(a.name||'').localeCompare(b.name||''));
const ledger=()=>Object.values(D().ledger).sort((a,b)=>(b.ts||0)-(a.ts||0));
const nfmt=(v,u)=>{v=+v||0;const a=Math.abs(v);return (u==='g'||u==='ml')&&a>=10?String(Math.round(v)):String(Math.round(v*100)/100)};
const fq=(v,u)=>u==='count'?nfmt(v,u):`${nfmt(v,u)} ${u}`;
const fqItem=it=>fq(it.qty,it.unit)+(it.unit==='count'?' left':'');
const STEP={count:1,g:100,kg:.5,oz:4,lb:.5,ml:100,L:.5,'fl oz':4,cup:1,tbsp:1,tsp:1};
const CATS=['Fridge','Freezer','Pantry','Produce','Spices','Snacks','Drinks','Other'];
const PL={ok:'In stock',low:'Low',out:'Out'};
const pill=it=>{const s=PE.status(it);return `<span class="pill ${s}">${PL[s]}</span>`};
const when=ms=>{if(!ms)return '';const d=new Date(ms),t=d.toLocaleTimeString([], {hour:'2-digit',minute:'2-digit',hourCycle:'h23'});return iso(d)===iso(new Date())?t:d.toLocaleDateString(undefined,{month:'short',day:'numeric'})+' '+t};
const prettyDate=d=>new Date(d+'T12:00').toLocaleDateString(undefined,{weekday:'short',month:'short',day:'numeric'});
const linksFor=id=>Object.entries(M().links||{}).filter(([,l])=>l.itemId===id);
const inboxGroups=()=>{const g={};Object.entries(M().inbox||{}).forEach(([k,e])=>{(g[e.fid]=g[e.fid]||{fid:e.fid,name:e.food,list:[]}).list.push(Object.assign({key:k},e))});return Object.values(g).sort((a,b)=>b.list.length-a.list.length)};
/* ---------- ui primitives ---------- */
let tT;function toast(m){const t=$('#toast');t.textContent=m;t.classList.add('on');clearTimeout(tT);tT=setTimeout(()=>t.classList.remove('on'),2600)}
function sheet(html,bind){closeSheet(true);const bg=document.createElement('div');bg.className='sheet-bg';bg.innerHTML=`<div class="sheet" role="dialog" aria-modal="true"><div class="grab"></div>${html}</div>`;
 bg.addEventListener('click',e=>{if(e.target===bg)closeSheet()});$('#sheet-root').appendChild(bg);bind&&bind(bg.querySelector('.sheet'));const f=bg.querySelector('[autofocus]');if(f&&matchMedia('(pointer:fine)').matches)f.focus()}
function closeSheet(){$('#sheet-root').querySelectorAll('.sheet-bg').forEach(x=>x.remove())}
/* themed pop-up instead of the browser's alert/confirm */
function pop({title,msg,ok='OK',cancel='Cancel',danger=false}){return new Promise(res=>{const bg=document.createElement('div');bg.className='pop-bg';
 bg.innerHTML=`<div class="pop" role="alertdialog" aria-modal="true"><h3>${esc(title)}</h3>${msg?`<p>${msg}</p>`:''}<div class="btns">${cancel?`<button class="btn ghost" data-r="0">${esc(cancel)}</button>`:''}<button class="btn ${danger?'dangerfill':''}" data-r="1">${esc(ok)}</button></div></div>`;
 bg.addEventListener('click',e=>{const b=e.target.closest('[data-r]');if(b||e.target===bg){bg.remove();res(b?b.dataset.r==='1':false)}});document.body.appendChild(bg)})}
async function guard(fn,okMsg){try{const r=await fn();if(okMsg)toast(okMsg);return r}catch(e){console.warn(e);pop({title:'Couldn’t save that',msg:esc(STORE.errMsg(e)),cancel:null});return false}finally{render()}}
/* ---------- applying changes ---------- */
async function applyOps(ops){const inbox=Object.assign({},M().inbox);let inboxChanged=false,eaten=0,fixed=0,added=0;
 for(const op of ops){if(op.t==='adjust'){if(await S.store.adjust(op)){if(op.reason==='eaten')eaten++;else if(op.reason==='correction')fixed++}}
  else if(op.t==='inbox'){if(!inbox[op.key]){inbox[op.key]=op.entry;inboxChanged=true;added++}}
  else if(op.t==='uninbox'){if(inbox[op.key]){delete inbox[op.key];inboxChanged=true}}}
 if(inboxChanged)await S.store.setMeta('inbox',inbox);return {eaten,fixed,added}}
const stateFor=()=>{const st=M().state||{};return {items:D().items,ledger:Object.values(D().ledger),links:M().links||{},ignored:M().ignored||{},inbox:M().inbox||{},startDate:st.startDate,lastProcessed:st.lastProcessed||0}};
async function runSync(manual){if(S.syncing||!S.store)return;S.syncing=true;if(manual)render();
 try{const v2=await S.store.readV2();S.v2=v2;
  if(!v2){S.v2s={ok:false,msg:S.store.kind==='cloud'?'No Logbook v2 data in this account yet. Turn on sync in Logbook v2 (Settings › Sign in).':'No Logbook v2 data on this device yet.'}}
  else{const {ops,cursor}=PE.plan(v2,stateFor()),r=await applyOps(ops);const st=Object.assign({},M().state,{lastProcessed:cursor,lastCheck:Date.now()});await S.store.setMeta('state',st);
   S.v2s={ok:true,msg:'Up to date'};const bits=[];if(r.eaten)bits.push(`${r.eaten} eaten food${r.eaten>1?'s':''} taken off stock`);if(r.fixed)bits.push(`${r.fixed} correction${r.fixed>1?'s':''}`);if(r.added)bits.push(`${r.added} new to link`);
   if(bits.length)toast(bits.join(' · '));else if(manual)toast('Pantry is up to date with Logbook')}}
 catch(e){console.warn('sync',e);S.v2s={ok:false,msg:STORE.errMsg(e)}}
 S.syncing=false;S.lastSync=Date.now();render()}
document.addEventListener('visibilitychange',()=>{if(document.visibilityState==='visible'&&S.store&&Date.now()-S.lastSync>60000)runSync()});
/* ---------- home ---------- */
const ghost=`<div class="ghostlines"><i></i><i></i><i></i></div>`;
function wSummary(){const it=items(),low=it.filter(x=>PE.status(x)==='low').length,out=it.filter(x=>PE.status(x)==='out').length,st=M().state||{};
 if(!it.length)return `<button class="w L" data-open="items" data-wid="summary"><div class="wl">${IC.items.replace('<svg','<svg width="14" height="14"')} Pantry</div><div class="wt">Your pantry is empty</div>
  <div class="row" style="margin:10px 0"><div class="ghostring"></div><div class="grow">${ghost}</div></div><span class="wcta" data-add="1">Add your first item ›</span></button>`;
 const chk=S.syncing?'Checking Logbook…':S.v2s.ok===false?'Logbook: '+esc(S.v2s.msg):st.lastCheck?'Logbook checked '+when(st.lastCheck):'Logbook not checked yet';
 return `<button class="w L" data-open="items" data-wid="summary"><div class="wl">Pantry</div><div class="statrow"><div class="stat"><b>${it.length}</b><span>Items</span></div><div class="stat"><b>${low}</b><span>Low</span></div><div class="stat"><b>${out}</b><span>Out</span></div></div><small style="margin-top:10px">${chk}</small></button>`}
function wLow(){const it=items(),l=it.filter(x=>PE.status(x)!=='ok').sort((a,b)=>(PE.status(a)==='out'?0:1)-(PE.status(b)==='out'?0:1));
 if(!it.length)return `<button class="w L" data-open="items" data-wid="low"><div class="wl">Low stock</div><div class="wt">Nothing to watch yet</div><div class="ghostchips"><i></i><i></i><i></i></div><small>Set a “low at” amount on items and they show up here.</small></button>`;
 if(!l.length)return `<button class="w L" data-open="items" data-wid="low"><div class="wl">Low stock</div><div class="wt">Nothing running low</div><div class="ghostchips"><i></i><i></i></div><small>All ${it.length} item${it.length>1?'s are':' is'} above their low level.</small></button>`;
 return `<button class="w L" data-open="items" data-arg="low" data-wid="low"><div class="wl">Low stock · ${l.length}</div><div class="wlist">${l.slice(0,4).map(x=>`<div><span>${esc(x.name)}</span><span class="row" style="gap:6px"><b>${esc(fq(x.qty,x.unit))}</b>${pill(x)}</span></div>`).join('')}</div>${l.length>4?`<small style="margin-top:6px">+${l.length-4} more</small>`:''}<span class="wcta" data-bought="1" style="margin-top:10px">Bought something ›</span></button>`}
function wEaten(){const e=ledger().filter(l=>l.reason==='eaten'&&!l.undone).slice(0,3);
 if(!e.length)return `<button class="w" data-open="history" data-wid="eaten"><div class="wl">Recently eaten</div><div class="wt">Nothing yet</div>${ghost}<small>Linked foods you log in Logbook v2 come off stock here.</small></button>`;
 return `<button class="w" data-open="history" data-wid="eaten"><div class="wl">Recently eaten</div><div class="wlist">${e.map(l=>`<div><span>${esc(l.itemName)}</span><b>${esc(fq(l.delta,l.unit))}</b></div>`).join('')}</div><small style="margin-top:auto">${when(e[0].ts)}</small></button>`}
function wInbox(){const g=inboxGroups();
 if(!g.length)return `<button class="w" data-open="inbox" data-wid="inbox"><div class="wl">Link inbox</div><div class="wt">All linked</div><div class="row" style="margin:10px 0"><div class="ghostring"></div></div><small>New foods from Logbook wait here.</small></button>`;
 return `<button class="w" data-open="inbox" data-wid="inbox"><div class="wl">Link inbox</div><div class="wcount"><span class="big">${g.length}</span><small>food${g.length>1?'s':''}</small></div><small style="margin-top:4px">${esc(g.slice(0,2).map(x=>x.name).join(', '))}${g.length>2?'…':''}</small><span class="wcta">Link to pantry ›</span></button>`}
function wBought(){return `<button class="w" data-bought="1" data-wid="bought"><div class="wl">Bought</div><div class="wt">Just shopped?</div><small>Add what you bought in a couple of taps.</small><span class="wcta">Add to stock ›</span></button>`}
function wLast(){const l=ledger()[0];
 if(!l)return `<button class="w" data-open="history" data-wid="last"><div class="wl">History</div><div class="wt">No changes yet</div>${ghost}<small>Every change can be undone.</small></button>`;
 return `<button class="w" data-open="history" data-wid="last"><div class="wl">History</div><div class="wt">${esc(l.itemName)}</div><small>${esc(REASON[l.reason]||l.reason)} · <b>${l.delta>0?'+':''}${esc(fq(l.delta,l.unit))}</b></small><small style="margin-top:auto">${when(l.ts)}</small></button>`}
const REASON={eaten:'Eaten',bought:'Bought',manual:'Edited',correction:'Logbook change',undo:'Undo'};
function homeHtml(){const u=S.store.user,nm=u&&(u.displayName||u.email)||'';const d=new Date().toLocaleDateString(undefined,{weekday:'long',month:'long',day:'numeric'});
 const nb=inboxGroups().length;
 return `<div class="sb" id="home"><div class="pin"><div class="top"><div><div class="sub">${esc(d)}</div><h1>Pantry</h1></div><button class="avatar" data-open="settings" aria-label="Settings">${esc((nm[0]||'P').toUpperCase())}</button></div>
 <div class="wgrid">${wSummary()}${wLow()}${wEaten()}${wInbox()}${wBought()}${wLast()}</div></div></div>
 <div class="dockwrap"><nav class="dock">${[['items','Items'],['inbox','Inbox'],['bought','Bought'],['history','History'],['settings','Settings']].map(([k,n])=>`<button data-${k==='bought'?'bought':'open'}="${k}" data-app="${k}"><span class="aico">${IC[k]}</span><span>${n}</span>${k==='inbox'&&nb?`<span class="badge">${nb}</span>`:''}</button>`).join('')}</nav></div>`}
/* ---------- full-screen pages ---------- */
function openOv(name,arg){S.stack.push({name,arg});render(true)}
function back(){S.stack.pop();const ov=$('#ov');if(ov&&!S.stack.length){ov.classList.add('out');setTimeout(()=>render(),190)}else render()}
const V={};
V.items=arg=>{if(!S.filterSet)S.filter=arg||'all';const f=S.filter||'all';S.filterSet=true;const q=(S.q||'').toLowerCase();let it=items();
 const counts={all:it.length,low:it.filter(x=>PE.status(x)==='low').length,out:it.filter(x=>PE.status(x)==='out').length};
 if(f!=='all')it=it.filter(x=>PE.status(x)===f);if(q)it=it.filter(x=>(x.name+' '+(x.category||'')).toLowerCase().includes(q));
 const by={};it.forEach(x=>(by[x.category||'Other']=by[x.category||'Other']||[]).push(x));
 const body=!counts.all?`<div class="empty">${ART()}<b>No items yet</b><p>Add what’s in your kitchen. Link items to Logbook foods and they’ll go down as you eat.</p><button class="btn" data-add="1">${IC.plus} Add item</button></div>`
  :`<input class="search" id="q" placeholder="Search items" value="${esc(S.q||'')}"><div class="seg">${['all','low','out'].map(k=>`<button data-f="${k}" class="${f===k?'on':''}">${k==='all'?'All':PL[k]} ${counts[k]}</button>`).join('')}</div>
   ${Object.keys(by).sort().map(c=>`<div class="gcat">${esc(c)}</div><div class="card" style="padding:0 14px"><div class="list">${by[c].map(x=>`<button class="item" data-item="${esc(x.id)}"><div class="ico">${IC.items.replace('<svg','<svg width="20" height="20"')}</div><div class="grow"><div class="t">${esc(x.name)}</div><div class="s">${linksFor(x.id).length?'Linked to Logbook':'Not linked'}${x.lowAt?` · low at ${esc(fq(x.lowAt,x.unit))}`:''}</div></div><div><div class="q">${esc(fq(x.qty,x.unit))}</div><div style="text-align:right;margin-top:3px">${pill(x)}</div></div></button>`).join('')}</div></div>`).join('')||'<div class="empty"><b>No matches</b></div>'}`;
 return {title:'Items',act:`<button class="act" data-add="1">Add</button>`,body}};
V.item=id=>{const it=D().items[id];if(!it)return {title:'Item',body:'<div class="empty"><b>This item was removed</b></div>'};
 const lg=ledger().filter(l=>l.itemId===id),lk=linksFor(id),st=STEP[it.unit]||1;
 return {title:it.name,act:`<button class="act" data-edit="${esc(id)}">Edit</button>`,body:`<div class="card"><div class="hero"><div class="big">${esc(nfmt(it.qty,it.unit))}</div><div class="u">${it.unit==='count'?'left':esc(it.unit)} · ${pill(it)}</div></div>
  <div class="stepper"><button class="icon-btn" data-step="-${st}" aria-label="Use ${st}">−</button><span class="muted">${esc(fq(st,it.unit))}</span><button class="icon-btn" data-step="${st}" aria-label="Add ${st}">＋</button></div>
  <div class="row" style="margin-top:12px"><button class="btn grow" data-bought="${esc(id)}">${IC.bought} Bought</button><button class="btn ghost grow" data-set="${esc(id)}">Set amount</button></div></div>
  <div class="card"><div class="kv"><span>Low at</span><b>${it.lowAt?esc(fq(it.lowAt,it.unit)):'Not set'}</b></div><div class="kv"><span>Category</span><b>${esc(it.category||'Other')}</b></div><div class="kv"><span>Last change</span><b>${it.updatedAt?when(it.updatedAt)+(it.updatedBy==='auto'?' · auto':''):'—'}</b></div></div>
  <div class="card"><h2>Linked Logbook foods <small>${lk.length}</small></h2>${lk.length?`<div class="list">${lk.map(([fid,l])=>`<div class="item" style="cursor:default"><div class="grow"><div class="t">${esc(foodNm(fid))}</div><div class="s">${l.mode==='per'?`Each serving uses ${esc(fq(l.per||1,it.unit))}`:'Uses the amount you log, converted'}</div></div><button class="undo" data-unlink="${esc(fid)}">Unlink</button></div>`).join('')}</div>`:'<p class="muted" style="margin:0 0 10px">Link the foods you log in Logbook v2 that use this item, and it goes down by itself.</p>'}
  <button class="btn ghost block sm" data-linkfood="${esc(id)}" style="margin-top:8px">${IC.inbox.replace('<svg','<svg width="18" height="18"')} Link a Logbook food</button></div>
  <div class="card lg"><h2>History <small>${lg.length}</small></h2>${lg.length?ledgerList(lg.slice(0,30)):'<p class="muted" style="margin:0">No changes yet.</p>'}</div>
  <button class="btn danger block" data-del="${esc(id)}">Remove item</button>`}};
const foodNm=fid=>(S.v2&&S.v2.foods[fid]&&S.v2.foods[fid].name)||((M().inbox&&Object.values(M().inbox).find(e=>e.fid===fid)||{}).food)||((M().links[fid]||{}).food)||'Logbook food';
function ledgerList(lg){return `<div class="list">${lg.map(l=>{const src=l.source||{},sub=l.reason==='eaten'?`${src.food?esc(src.food)+' · ':''}${src.date?prettyDate(src.date):''}${src.mealName||src.meal?' · '+esc(src.mealName||src.meal):''}`:l.reason==='correction'?`${esc(l.note||'Changed in Logbook')}${src.date?' · '+prettyDate(src.date):''}`:esc(l.note||'');
 return `<div class="item ${l.undone?'undone':''}" style="cursor:default"><div class="grow"><div class="t">${esc(REASON[l.reason]||l.reason)} · ${esc(l.itemName)}</div><div class="s">${sub||'&nbsp;'} · ${when(l.ts)}${l.undone?' · undone':''}</div></div><div class="q ${l.delta<0?'neg':'pos'}">${l.delta>0?'+':''}${esc(fq(l.delta,l.unit))}</div>${!l.undone&&l.reason!=='undo'&&D().items[l.itemId]?`<button class="undo" data-undo="${esc(l.id)}">Undo</button>`:''}</div>`}).join('')}</div>`}
V.history=()=>{const lg=ledger();if(!lg.length)return {title:'History',body:`<div class="empty">${ART()}<b>No changes yet</b><p>Every change to your stock shows here, and each one can be undone.</p></div>`};
 const by={};lg.forEach(l=>(by[iso(l.ts)]=by[iso(l.ts)]||[]).push(l));return {title:'History',body:Object.keys(by).sort().reverse().map(d=>`<div class="gcat">${prettyDate(d)}</div><div class="card lg" style="padding:0 14px">${ledgerList(by[d])}</div>`).join('')}};
V.inbox=()=>{const g=inboxGroups();if(!g.length)return {title:'Link inbox',body:`<div class="empty">${ART()}<b>All linked</b><p>When you log a food in Logbook v2 that isn’t linked to a pantry item yet, it waits here so you can link it once.</p></div>`};
 return {title:'Link inbox',body:`<p class="muted" style="margin:0 0 12px">Link each food once. Next time you log it, the pantry updates by itself.</p>${g.map(x=>{const last=x.list.map(e=>e.date).sort().pop();return `<div class="card"><div class="row"><div class="ico">${IC.eat.replace('<svg','<svg width="20" height="20"')}</div><div class="grow"><div style="font-weight:650">${esc(x.name)}</div><div class="muted">Logged ${x.list.length}× · last ${prettyDate(last)}</div></div></div>
  <div class="row" style="margin-top:12px"><button class="btn sm grow" data-linkin="${esc(x.fid)}">Link to pantry</button><button class="btn ghost sm grow" data-ignore="${esc(x.fid)}">Not a pantry item</button></div></div>`}).join('')}`}};
V.settings=()=>{const u=S.store.user,st=M().state||{},ig=Object.entries(M().ignored||{}),cloud=S.store.kind==='cloud';
 const acct=cloud?`<div class="kv"><span>Signed in</span><b>${esc(u.email||u.displayName||'Google account')}</b></div><div class="kv"><span>Saved to</span><b>Your account (cloud)</b></div><button class="btn ghost block sm" id="signout" style="margin-top:10px">Sign out</button><p class="muted" style="margin:8px 0 0">Pantry and Logbook share one sign-in on this site, so signing out here also signs you out of Logbook on this browser.</p>`
  :`<div class="kv"><span>Mode</span><b>This device only</b></div><p class="muted">Sign in to keep your pantry in your account and read your Logbook from any device.</p><button class="btn block gbtn" id="sg">${IC.google.replace('<svg','<svg width="20" height="20"')} Sign in with Google</button><button class="btn ghost block" id="se">${IC.mail} Sign in with email</button>`;
 return {title:'Settings',body:`<div class="gcat">Account</div><div class="card">${acct}</div>
 <div class="gcat">Logbook v2</div><div class="card"><div class="kv"><span>Status</span><b>${S.syncing?'Checking…':esc(S.v2s.ok===false?'Problem':S.v2s.ok?'Connected':'Not checked')}</b></div>${S.v2s.ok===false?`<p class="err">${esc(S.v2s.msg)}</p>`:''}
  <div class="kv"><span>Last check</span><b>${st.lastCheck?when(st.lastCheck):'—'}</b></div><div class="kv"><span>Reads from</span><b>${cloud?'Your Logbook v2 account':'Logbook v2 on this browser'}</b></div>
  <label class="f" for="sd">Count food logged from</label><input type="date" id="sd" value="${esc(st.startDate||iso(new Date()))}">
  <button class="btn block sm" id="chk" style="margin-top:12px" ${S.syncing?'disabled':''}>${IC.sync.replace('<svg','<svg width="18" height="18"')} Check Logbook now</button>
  <p class="muted" style="margin:10px 0 0">Read only: the pantry never changes your Logbook. Each logged food is counted once, and if you edit or delete it in Logbook the stock is put back.</p></div>
 <div class="gcat">Appearance</div><div class="card"><div class="seg">${[['auto','Auto'],['light','Light'],['dark','Dark']].map(([k,n])=>`<button data-mode="${k}" class="${TH.mode===k?'on':''}">${n}</button>`).join('')}</div>
  <div class="cwgrid">${CW_ORDER.map(k=>{const c=CW[k];return `<button class="cw ${TH.cw===k?'on':''}" data-cw="${k}"><div class="sw">${[c.L.a,c.L.a2,c.L.a3,c.Dk.bg].map(x=>`<i style="background:${x}"></i>`).join('')}</div><b>${esc(c.n)}</b></button>`}).join('')}</div></div>
 ${ig.length?`<div class="gcat">Not pantry items</div><div class="card"><div class="list">${ig.map(([fid,n])=>`<div class="item" style="cursor:default"><div class="grow t">${esc(n)}</div><button class="undo" data-unignore="${esc(fid)}">Restore</button></div>`).join('')}</div></div>`:''}
 <div class="gcat">Data</div><div class="card"><button class="btn ghost block sm" id="dl">Download a backup (JSON)</button>${cloud?'':'<button class="btn danger block sm" id="wipe">Erase this device’s pantry</button>'}</div>
 ${cloud&&/denied/.test(S.loadErr||'')?`<div class="note">Cloud access is blocked by the Firestore rules. Jackson needs to add the pantry rule in the Firebase console.</div>`:''}
 <p class="muted" style="text-align:center;margin:18px 0 0">Pantry ${VERSION} · <a href="${LOGBOOK_URL}" style="color:var(--accent)">Open Logbook v2</a></p>`}};
/* ---------- sheets ---------- */
function editSheet(id,preset){const it=id?D().items[id]:Object.assign({unit:'count',category:'Pantry'},preset);const cats=[...new Set(CATS.concat(items().map(x=>x.category).filter(Boolean)))];
 sheet(`<h3>${id?'Edit item':'New item'}</h3><label class="f" for="en">Name</label><input id="en" value="${esc(it.name||'')}" placeholder="e.g. Eggs" autofocus>
 <div class="row"><div class="grow"><label class="f" for="eu">Unit</label><select id="eu">${PE.ITEM_UNITS.map(u=>`<option value="${u}" ${u===it.unit?'selected':''}>${u==='count'?'count (whole items)':u}</option>`).join('')}</select></div><div class="grow"><label class="f" for="ec">Category</label><select id="ec">${cats.map(c=>`<option ${c===(it.category||'Pantry')?'selected':''}>${esc(c)}</option>`).join('')}</select></div></div>
 ${id?'':`<label class="f" for="eq">Amount on hand</label><input id="eq" inputmode="decimal" value="${esc(it.qty??'')}" placeholder="0">`}
 <label class="f" for="el">Low at (optional)</label><input id="el" inputmode="decimal" value="${esc(it.lowAt??'')}" placeholder="Warn me at this amount">
 <p class="err" id="ee"></p><button class="btn block" id="es">${id?'Save':'Add item'}</button>`,el=>{const g=s=>el.querySelector(s);
 g('#es').onclick=async()=>{const name=g('#en').value.trim();if(!name){g('#ee').textContent='Give it a name';return}const lowRaw=g('#el').value.trim(),lowAt=lowRaw===''?null:+lowRaw,q=id?null:+(g('#eq').value||0);
  if(lowRaw!==''&&!(lowAt>=0)||(!id&&!(q>=0))){g('#ee').textContent='Amounts need to be numbers';return}
  const nid=id||uid(),base={id:nid,name,unit:g('#eu').value,category:g('#ec').value,lowAt};if(!id){base.qty=0;base.createdAt=Date.now()}closeSheet();
  await guard(async()=>{await S.store.putItem(base);if(!id&&q>0)await S.store.adjust({id:'m_'+uid(),itemId:nid,setTo:q,reason:'manual',note:'Starting amount'});if(preset&&preset.linkFid)await linkFood(preset.linkFid,nid,preset.applyPending)},id?'Saved':'Added '+name);
  if(!id&&!preset)openOv('item',nid)}})}
function amountSheet(id,mode){const it=D().items[id];sheet(`<h3>${mode==='set'?'Set amount':'Bought '+esc(it.name)}</h3><p class="muted" style="margin-top:0">${mode==='set'?'How much do you have right now?':'How much did you buy?'} (${esc(it.unit==='count'?'count':it.unit)})</p>
 <input id="aq" inputmode="decimal" value="${mode==='set'?esc(nfmt(it.qty,it.unit)):''}" placeholder="${mode==='set'?'':esc(nfmt(STEP[it.unit]||1,it.unit))}" autofocus><div class="chips" style="margin-top:10px">${(mode==='set'?[0]:[1,2,6,12].map(x=>x*(STEP[it.unit]||1))).map(v=>`<button class="chip" data-v="${v}">${esc(fq(v,it.unit))}</button>`).join('')}</div>
 <p class="err" id="ae"></p><button class="btn block" id="ago">${mode==='set'?'Save':'Add to stock'}</button>`,el=>{const g=s=>el.querySelector(s);el.querySelectorAll('[data-v]').forEach(b=>b.onclick=()=>{g('#aq').value=b.dataset.v});
 g('#ago').onclick=async()=>{const raw=g('#aq').value.trim()||(mode==='set'?'':g('#aq').placeholder),v=+raw;if(raw===''||!(v>=0)||(mode!=='set'&&!(v>0))){g('#ae').textContent='Enter an amount';return}closeSheet();
  await guard(()=>S.store.adjust(mode==='set'?{id:'m_'+uid(),itemId:id,setTo:v,reason:'manual',note:'Set to '+fq(v,it.unit)}:{id:'b_'+uid(),itemId:id,delta:v,reason:'bought',note:'Bought '+fq(v,it.unit)}),mode==='set'?'Updated':'Added '+fq(v,it.unit))}})}
function boughtSheet(){const it=items().sort((a,b)=>({out:0,low:1,ok:2}[PE.status(a)]-{out:0,low:1,ok:2}[PE.status(b)]));
 sheet(`<h3>Bought</h3><p class="muted" style="margin-top:0">Pick what you bought. Low items are first.</p>${it.length?`<div class="list">${it.map(x=>`<button class="item" data-pick="${esc(x.id)}"><div class="grow"><div class="t">${esc(x.name)}</div><div class="s">${esc(fqItem(x))}</div></div>${pill(x)}</button>`).join('')}</div>`:'<div class="empty"><b>No items yet</b></div>'}
 <button class="btn ghost block" id="bn" style="margin-top:12px">${IC.plus} Something new</button>`,el=>{el.querySelectorAll('[data-pick]').forEach(b=>b.onclick=()=>amountSheet(b.dataset.pick,'bought'));el.querySelector('#bn').onclick=()=>editSheet(null)})}
/* link a Logbook food to an item and apply its waiting inbox entries */
async function linkFood(fid,itemId,applyPending=true,per){const it=D().items[itemId],food=S.v2&&S.v2.foods[fid],mode=PE.defaultMode(food,it);
 const links=Object.assign({},M().links,{[fid]:{itemId,mode,per:per||1,food:food?food.name:foodNm(fid)}});await S.store.setMeta('links',links);
 if(M().ignored&&M().ignored[fid]){const ig=Object.assign({},M().ignored);delete ig[fid];await S.store.setMeta('ignored',ig)}
 let r={eaten:0};if(applyPending)r=await applyOps(PE.opsForLink(S.v2,stateFor(),fid));else{const inbox=Object.assign({},M().inbox);Object.keys(inbox).forEach(k=>{if(inbox[k].fid===fid)delete inbox[k]});await S.store.setMeta('inbox',inbox)}
 toast(`Linked to ${it.name}`+(r.eaten?` · ${r.eaten} taken off`:''))}
function perField(food,it){const mode=PE.defaultMode(food,it);return mode==='per'?`<label class="f" for="lp">Each serving of this food uses (${esc(it.unit==='count'?'items':it.unit)})</label><input id="lp" inputmode="decimal" value="1">`:`<p class="note">Uses the amount you log in Logbook, converted to ${esc(it.unit)}.</p>`}
function linkInboxSheet(fid){const grp=inboxGroups().find(x=>x.fid===fid)||{name:foodNm(fid),list:[]},food=S.v2&&S.v2.foods[fid],it=items();
 sheet(`<h3>Link “${esc(grp.name)}”</h3><p class="muted" style="margin-top:0">Which pantry item does this food use?</p>${it.length?`<div class="list">${it.map(x=>`<button class="item" data-to="${esc(x.id)}"><div class="grow"><div class="t">${esc(x.name)}</div><div class="s">${esc(fqItem(x))}</div></div><span class="pill">${esc(x.unit)}</span></button>`).join('')}</div>`:''}
 <button class="btn ghost block" id="lnew" style="margin-top:10px">${IC.plus} New item from this food</button>
 ${grp.list.length?`<label class="tg row" style="margin-top:14px;gap:10px;font-size:15px"><input type="checkbox" id="lpend" checked style="width:22px;min-height:22px"> Also take off the ${grp.list.length} already logged</label>`:''}`,el=>{const pend=()=>{const c=el.querySelector('#lpend');return c?c.checked:true};
 el.querySelectorAll('[data-to]').forEach(b=>b.onclick=()=>{const target=D().items[b.dataset.to],mode=PE.defaultMode(food,target);if(mode==='auto'){const p=pend();closeSheet();guard(()=>linkFood(fid,target.id,p))}else{const p=pend();
   sheet(`<h3>${esc(grp.name)} → ${esc(target.name)}</h3>${perField(food,target)}<button class="btn block" id="lsave" style="margin-top:12px">Link</button>`,e2=>{e2.querySelector('#lsave').onclick=()=>{const per=+(e2.querySelector('#lp').value)||1;closeSheet();guard(()=>linkFood(fid,target.id,p,per))}})}});
 el.querySelector('#lnew').onclick=()=>{const p=pend(),meas=food&&food.kind==='measured';editSheet(null,{name:(grp.name||'').replace(/\s*\([^)]*\)\s*$/,''),unit:meas?food.unit:'count',linkFid:fid,applyPending:p})}})}
function pickFoodSheet(itemId){const it=D().items[itemId],linked=M().links||{},foods=S.v2?Object.values(S.v2.foods).filter(f=>!(linked[f.id]&&D().items[linked[f.id].itemId])):[];
 if(!S.v2){pop({title:'Logbook not read yet',msg:'Open Settings › Check Logbook now, then try again.',cancel:null});return}
 sheet(`<h3>Link a food to ${esc(it.name)}</h3><input id="fq" placeholder="Search your Logbook foods" autofocus><div class="list" id="fl" style="margin-top:8px"></div>`,el=>{const draw=()=>{const q=el.querySelector('#fq').value.toLowerCase();
  el.querySelector('#fl').innerHTML=foods.filter(f=>(f.name||'').toLowerCase().includes(q)).slice(0,60).map(f=>`<button class="item" data-f="${esc(f.id)}"><div class="grow t">${esc(f.name)}</div><span class="pill">${f.kind==='measured'?esc(f.size+' '+f.unit):'item'}</span></button>`).join('')||'<div class="empty">No unlinked foods</div>';
  el.querySelectorAll('[data-f]').forEach(b=>b.onclick=()=>{const food=S.v2.foods[b.dataset.f];if(PE.defaultMode(food,it)==='auto'){closeSheet();guard(()=>linkFood(food.id,itemId,true))}else sheet(`<h3>${esc(food.name)} → ${esc(it.name)}</h3>${perField(food,it)}<button class="btn block" id="lsave" style="margin-top:12px">Link</button>`,e2=>{e2.querySelector('#lsave').onclick=()=>{const per=+(e2.querySelector('#lp').value)||1;closeSheet();guard(()=>linkFood(food.id,itemId,true,per))}})})};
  el.querySelector('#fq').oninput=draw;draw()})}
function emailSheet(){let create=false;sheet(`<h3>Sign in with email</h3><div class="seg"><button class="on" data-m="in">Sign in</button><button data-m="up">Create account</button></div><label class="f" for="em">Email</label><input id="em" type="email" autocomplete="email" autofocus><label class="f" for="pw">Password</label><input id="pw" type="password" autocomplete="current-password">
 <p class="err" id="ee"></p><button class="btn block" id="go">Sign in</button><button class="btn ghost block sm" id="fp">Forgot password?</button>`,el=>{const g=s=>el.querySelector(s);
 el.querySelectorAll('[data-m]').forEach(b=>b.onclick=()=>{create=b.dataset.m==='up';el.querySelectorAll('[data-m]').forEach(x=>x.classList.toggle('on',x===b));g('#go').textContent=create?'Create account':'Sign in'});
 g('#go').onclick=async()=>{g('#ee').textContent='';try{const c=await STORE.email(g('#em').value.trim(),g('#pw').value,create);closeSheet();await useCloud(c.user)}catch(e){g('#ee').textContent=STORE.errMsg(e)}};
 g('#fp').onclick=async()=>{const e=g('#em').value.trim();if(!e){g('#ee').textContent='Type your email first';return}try{await STORE.reset(e);toast('Reset email sent')}catch(x){g('#ee').textContent=STORE.errMsg(x)}}})}
async function google(){try{const c=await STORE.google();if(c&&c.user)await useCloud(c.user)}catch(e){pop({title:'Couldn’t sign in',msg:esc(STORE.errMsg(e)),cancel:null})}}
/* ---------- welcome / sign-in ---------- */
function welcomeHtml(){return `<div class="welcome"><div class="inner">${ART('art')}<h1>Pantry</h1><p class="lead">${S.signedOutNote?'You’re signed out. Sign in again to see your pantry.':'Your kitchen stock, kept up to date from what you log in Logbook.'}</p>
 <div class="bul"><div class="ico">${IC.eat.replace('<svg','<svg width="20" height="20"')}</div><div><b>Goes down as you eat</b><div class="muted">Foods you log in Logbook v2 come off stock by themselves.</div></div></div>
 <div class="bul"><div class="ico">${IC.low.replace('<svg','<svg width="20" height="20"')}</div><div><b>Know what’s running low</b><div class="muted">Set a low level and it shows on Home and on Sally’s grocery list.</div></div></div>
 <div class="bul"><div class="ico">${IC.history.replace('<svg','<svg width="20" height="20"')}</div><div><b>Every change can be undone</b><div class="muted">Bought, eaten or edited, it’s all in History.</div></div></div>
 <button class="btn block gbtn" id="wg">${IC.google.replace('<svg','<svg width="20" height="20"')} Sign in with Google</button><button class="btn ghost block" id="we">${IC.mail} Sign in with email</button><button class="btn ghost block" id="wl" style="background:transparent">${IC.phone} Continue without account</button>
 <p class="muted" style="text-align:center;font-size:12.5px">Without an account your pantry stays on this device, and it reads Logbook v2 from this browser only.</p></div></div>`}
/* ---------- render ---------- */
function render(anim){const app=$('#app');if(!S.store){app.innerHTML=S.booting?'<div class="spin"></div>':welcomeHtml();return}
 const hs=$('#home')?$('#home').scrollTop:0,ovs=$('#ov .ovb')?$('#ov .ovb').scrollTop:0,top=S.stack[S.stack.length-1],qf=document.activeElement&&document.activeElement.id==='q';
 let html=homeHtml();if(top){const v=V[top.name](top.arg);html+=`<div class="ov" id="ov" style="${anim?'':'animation:none'}"><div class="ovh"><button class="back" data-back="1">‹ ${S.stack.length>1?'Back':'Home'}</button><b>${esc(v.title)}</b>${v.act||'<span style="width:84px"></span>'}</div><div class="ovb"><div class="inner">${v.body}</div></div></div>`}
 app.innerHTML=html;document.body.classList.toggle('ovopen',!!top);if($('#home'))$('#home').scrollTop=hs;if(!anim&&$('#ov .ovb'))$('#ov .ovb').scrollTop=ovs;
 if(qf&&$('#q')){const q=$('#q');q.focus();q.setSelectionRange(q.value.length,q.value.length)}}
document.addEventListener('input',e=>{if(e.target.id==='q'){S.q=e.target.value;render()}});
document.addEventListener('change',async e=>{if(e.target.id==='sd'){const v=e.target.value;if(!v)return;await guard(()=>S.store.setMeta('state',Object.assign({},M().state,{startDate:v,lastProcessed:0})),'Counting food from '+prettyDate(v));runSync(true)}});
document.addEventListener('click',async e=>{const t=e.target,c=s=>t.closest(s);let b;
 if(c('.sheet-bg')||c('.pop-bg'))return;
 if(!S.store){if(c('#wg'))return google();if(c('#we'))return emailSheet();if(c('#wl'))return useLocal();return}
 if((b=c('[data-back]')))return back();
 if((b=c('[data-add]')))return editSheet(null);
 if((b=c('[data-bought]'))){const id=b.dataset.bought;return D().items[id]?amountSheet(id,'bought'):items().length?boughtSheet():editSheet(null)}
 if((b=c('[data-item]')))return openOv('item',b.dataset.item);
 if((b=c('[data-open]'))){S.filterSet=false;return openOv(b.dataset.open,b.dataset.arg)}
 if((b=c('[data-f]'))){S.filter=b.dataset.f;return render()}
 if((b=c('[data-edit]')))return editSheet(b.dataset.edit);
 if((b=c('[data-set]')))return amountSheet(b.dataset.set,'set');
 if((b=c('[data-step]'))){const top=S.stack[S.stack.length-1],id=top.arg,d=+b.dataset.step,it=D().items[id];if(d<0&&(+it.qty||0)<=0)return toast('Already at 0');
  return guard(()=>S.store.adjust({id:'m_'+uid(),itemId:id,delta:d,reason:'manual',note:(d>0?'Added ':'Used ')+fq(Math.abs(d),it.unit)}))}
 if((b=c('[data-undo]'))){const l=D().ledger[b.dataset.undo];return guard(async()=>{if(!await S.store.undo(l.id))throw new Error('That change was already undone.')},`Undid ${(REASON[l.reason]||'change').toLowerCase()} · ${l.itemName}`)}
 if((b=c('[data-del]'))){const it=D().items[b.dataset.del];if(await pop({title:`Remove ${it.name}?`,msg:'Its links to Logbook foods are removed too. History stays.',ok:'Remove',danger:true})){
  await guard(async()=>{const links=Object.assign({},M().links);Object.keys(links).forEach(k=>{if(links[k].itemId===it.id)delete links[k]});await S.store.setMeta('links',links);await S.store.delItem(it.id)},'Removed '+it.name);back()}return}
 if((b=c('[data-unlink]'))){const fid=b.dataset.unlink;if(await pop({title:'Unlink this food?',msg:`Logging ${esc(foodNm(fid))} won’t change stock any more. Past changes stay.`,ok:'Unlink'})){const links=Object.assign({},M().links);delete links[fid];await guard(()=>S.store.setMeta('links',links),'Unlinked')}return}
 if((b=c('[data-linkfood]')))return pickFoodSheet(b.dataset.linkfood);
 if((b=c('[data-linkin]')))return linkInboxSheet(b.dataset.linkin);
 if((b=c('[data-ignore]'))){const fid=b.dataset.ignore,g=inboxGroups().find(x=>x.fid===fid);return guard(async()=>{const ig=Object.assign({},M().ignored,{[fid]:g.name}),inbox=Object.assign({},M().inbox);Object.keys(inbox).forEach(k=>{if(inbox[k].fid===fid)delete inbox[k]});await S.store.setMeta('ignored',ig);await S.store.setMeta('inbox',inbox)},`${g.name} won’t be asked about again`)}
 if((b=c('[data-unignore]'))){const ig=Object.assign({},M().ignored);delete ig[b.dataset.unignore];await guard(async()=>{await S.store.setMeta('ignored',ig);await S.store.setMeta('state',Object.assign({},M().state,{lastProcessed:0}))},'Restored');return runSync()}
 if((b=c('[data-mode]'))){TH.mode=b.dataset.mode;saveTheme();return render()}
 if((b=c('[data-cw]'))){TH.cw=b.dataset.cw;saveTheme();return render()}
 if(c('#chk'))return runSync(true);
 if(c('#sg'))return google();if(c('#se'))return emailSheet();
 if(c('#signout')){if(await pop({title:'Sign out?',msg:'This also signs you out of Logbook on this browser.',ok:'Sign out'})){await STORE.signOut();localStorage.removeItem('pantry:mode');S.store=null;S.stack=[];S.signedOutNote=false;render()}return}
 if(c('#dl')){const blob=new Blob([JSON.stringify({exportedAt:PE.ontario(Date.now()),...D()},null,1)],{type:'application/json'}),a=document.createElement('a');a.href=URL.createObjectURL(blob);a.download='pantry-backup-'+iso(new Date())+'.json';a.click();return}
 if(c('#wipe')){if(await pop({title:'Erase this device’s pantry?',msg:'All items and history on this device are deleted. This can’t be undone.',ok:'Erase',danger:true})){S.store.wipe();localStorage.removeItem('pantry:mode');S.store=null;S.stack=[];render()}return}});
/* ---------- boot ---------- */
async function ensureStart(){if(!(M().state&&M().state.startDate))await S.store.setMeta('state',Object.assign({},M().state,{startDate:iso(new Date()),createdAt:Date.now(),lastProcessed:0}))}
async function useLocal(){localStorage.setItem('pantry:mode','local');S.store=STORE.Local();await S.store.load();await ensureStart();render();runSync()}
async function useCloud(user){const prev=S.store&&S.store.kind==='local'?S.store:null;S.booting=true;S.store=null;render();
 try{const st=STORE.Cloud({uid:user.uid,email:user.email,displayName:user.displayName});await st.load();S.store=st;localStorage.setItem('pantry:mode','cloud');S.booting=false;S.signedOutNote=false;S.loadErr='';
  await ensureStart();const lt=prev&&Object.values(prev.data().items);
  if(lt&&lt.length&&!Object.keys(D().items).length&&await pop({title:`Copy ${lt.length} item${lt.length>1?'s':''} to your account?`,msg:'Your items and food links on this device will be added to your account. History stays on this device.',ok:'Copy',cancel:'Not now'})){
   for(const it of lt){await S.store.putItem(Object.assign({},it,{qty:0}));if(+it.qty>0)await S.store.adjust({id:'m_'+uid(),itemId:it.id,setTo:+it.qty,reason:'manual',note:'Copied from this device'})}
   await S.store.setMeta('links',Object.assign({},prev.data().meta.links,M().links));toast('Copied to your account')}
  render();runSync()}
 catch(e){console.warn(e);S.booting=false;S.loadErr=STORE.errMsg(e);S.store=prev;render();
  pop({title:'Couldn’t open your cloud pantry',msg:esc(S.loadErr)+(/denied/.test(S.loadErr)?'<br><br>The Firestore security rules don’t allow the pantry yet. Until that rule is added you can keep using this device only.':''),cancel:null})}}
async function boot(){applyTheme();const mode=localStorage.getItem('pantry:mode');
 if(mode==='local')return useLocal();
 if(mode==='cloud'){S.booting=true;render();try{const u=await STORE.whenAuthReady();if(u)return useCloud(u);S.signedOutNote=true}catch(e){S.signedOutNote=true;console.warn(e)}S.booting=false}
 render()}
window.__pantry={S,runSync,render};
boot();
})();
