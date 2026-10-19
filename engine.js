/* Pantry engine: pure logic shared by the web app and tools/export-pantry.mjs.
   Reads Logbook v2 data (never writes it), works out which eaten foods should come off pantry stock,
   and keeps everything idempotent: every eaten entry gets a stable key, and its ledger id is derived from that key. */
(function(root,factory){const E=factory();if(typeof module==='object'&&module.exports)module.exports=E;else root.PE=E})(typeof self!=='undefined'?self:this,function(){
const UNITS={g:['m',1],kg:['m',1000],mg:['m',.001],oz:['m',28.349523125],lb:['m',453.59237],ml:['v',1],L:['v',1000],'fl oz':['v',29.5735295625],cup:['v',240],tbsp:['v',14.78676478125],tsp:['v',4.92892159375]};
const ITEM_UNITS=['count','g','kg','oz','lb','ml','L','fl oz','cup','tbsp','tsp'];
const fam=u=>UNITS[u]?UNITS[u][0]:null;
const convU=(v,from,to)=>{const a=UNITS[from],b=UNITS[to];if(!a||!b||a[0]!==b[0])return null;return v*a[1]/b[1]};
const unitNorm=u=>{u=(u||'').toLowerCase().trim();return u==='l'?'L':u==='floz'||u==='fl. oz'?'fl oz':u==='cups'?'cup':UNITS[u]?u:null};
/* same rule Logbook v2 uses to decide whether a food is measured (has a size+unit in its name/serving) or a whole item */
function normFood(f){if(!f)return null;if(f.kind)return f;const src=(f.serving||'')+' '+(f.name||''),all=[...src.matchAll(/(\d+(?:\.\d+)?)\s*(fl\.? ?oz|kg|mg|g|oz|lb|ml|l|cups?|tbsp|tsp)\b/gi)],m=all.sort((x,y)=>(/^(g|kg|mg|ml|l)$/i.test(y[2])?1:0)-(/^(g|kg|mg|ml|l)$/i.test(x[2])?1:0))[0];const u=m&&unitNorm(m[2].replace('.',''));
 return u?Object.assign({},f,{kind:'measured',size:+m[1],unit:u}):Object.assign({},f,{kind:'item'})}
function hash(s){let h=2166136261,h2=5381;for(let i=0;i<s.length;i++){const c=s.charCodeAt(i);h^=c;h=Math.imul(h,16777619);h2=(Math.imul(h2,33)^c)>>>0}return (h>>>0).toString(36)+(h2>>>0).toString(36)}
const r3=v=>Math.round(v*1000)/1000;
/* Logbook v2 cloud doc logbookV2/{uid}: {r:{'foods#<id>':{v:json},'food@YYYY-MM-DD':{v:json array,t:ms}}} */
function readV2Cloud(doc){const r=(doc&&doc.r)||{},foods={},days={};let meals=Object.assign({},DEF_MEALS);
 for(const rid of Object.keys(r)){const x=r[rid];if(!x||x.d)continue;let val;try{val=typeof x.v==='string'?JSON.parse(x.v):x.v}catch(e){continue}
  let m;if((m=rid.match(/^foods#(.+)$/))){if(val&&val.id!=null)foods[val.id]=normFood(val)}
  else if((m=rid.match(/^food@(\d{4}-\d\d-\d\d)$/)))days[m[1]]={t:x.t||0,entries:Array.isArray(val)?val:[]};
  else if(rid==='mealSlots'&&Array.isArray(val))meals=mealMap(val)}
 return {foods,days,meals,at:doc&&doc.at||null,src:'cloud'}}
const DEF_MEALS={m1:'Meal 1',m2:'Meal 2',m3:'Meal 3'};
function mealMap(list){const o=Object.assign({},DEF_MEALS);(list||[]).forEach(x=>{if(x&&x.id)o[x.id]=x.name||x.id});return o}
/* Logbook v2 local data (localStorage lb2w:data9 on the same site): {foods:[...],food:{date:[entries]}} */
function readV2Local(d){const foods={},days={};(d&&d.foods||[]).forEach(f=>{if(f&&f.id!=null)foods[f.id]=normFood(f)});
 Object.keys(d&&d.food||{}).forEach(dt=>{if(/^\d{4}-\d\d-\d\d$/.test(dt))days[dt]={t:null,entries:Array.isArray(d.food[dt])?d.food[dt]:[]}});return {foods,days,meals:mealMap(d&&d.mealSlots),src:'local'}}
/* stable key per eaten entry: identical entries on the same day are numbered (#1, #2) so removing one only affects one */
function entryKeys(date,entries){const n={};return (entries||[]).filter(e=>e&&e.fid!=null).map(e=>{const base=[date,e.fid,e.meal||'',e.amt??'',e.unit||'',e.q??1].join('|');n[base]=(n[base]||0)+1;return {key:base+'#'+n[base],e}})}
const ledgerId=(kind,key)=>kind+'_'+hash(key);
/* how much of an item one eaten entry uses (positive number in the item's unit) */
function amountFor(food,e,item,link){link=link||{};const q=+(e.q??1)||0;
 if(link.mode!=='per'&&item.unit!=='count'&&food&&food.kind==='measured'){
  const amt=e.amt!=null?+e.amt:q*(food.size||1),from=e.amt!=null?unitNorm(e.unit)||food.unit:food.unit,v=convU(amt,from,item.unit);
  if(v!=null)return {qty:r3(v),how:`${r3(amt)} ${from} → ${r3(v)} ${item.unit}`}}
 const per=+(link.per||1);return {qty:r3(q*per),how:`${r3(q)} serving${q===1?'':'s'} × ${per} ${item.unit==='count'?'item'+(per===1?'':'s'):item.unit}`}}
function defaultMode(food,item){return item.unit!=='count'&&food&&food.kind==='measured'&&fam(food.unit)===fam(item.unit)?'auto':'per'}
const foodName=(v2,fid)=>(v2.foods[fid]&&v2.foods[fid].name)||'(food '+fid+')';
/* plan: given Logbook v2 data and pantry state, return ops to apply. st={items,ledger:[...],links,ignored,inbox,startDate,lastProcessed} */
function plan(v2,st){const ops=[],items=st.items||{},links=st.links||{},ignored=st.ignored||{},inbox=st.inbox||{},start=st.startDate||'0000-00-00',cur=st.lastProcessed||0;
 const L={};(st.ledger||[]).forEach(l=>{L[l.id]=l});let cursor=cur,scanned=0;
 for(const date of Object.keys(v2.days).sort()){if(date<start)continue;const day=v2.days[date];if(day.t!=null&&day.t<=cur)continue;if(day.t!=null)cursor=Math.max(cursor,day.t);scanned++;
  const keys=entryKeys(date,day.entries),present=new Set();
  for(const {key,e} of keys){present.add(key);if(ignored[e.fid])continue;const id=ledgerId('e',key);if(L[id])continue;
   const link=links[e.fid],item=link&&items[link.itemId],food=v2.foods[e.fid];
   const src={key,date,fid:e.fid,meal:e.meal||'',mealName:(v2.meals&&v2.meals[e.meal])||e.meal||'',amt:e.amt??null,unit:e.unit||null,q:e.q??1,food:foodName(v2,e.fid)};
   if(item){const a=amountFor(food,e,item,link);ops.push({t:'adjust',id,itemId:item.id,delta:-a.qty,reason:'eaten',source:src,note:a.how});if(inbox[key])ops.push({t:'uninbox',key})}
   else if(!inbox[key])ops.push({t:'inbox',key,entry:src})}
  /* Logbook entry removed or edited after it was counted: put the stock back once */
  for(const l of Object.values(L)){if(l.reason!=='eaten'||!l.source||l.source.date!==date||present.has(l.source.key)||l.undone)continue;const cid=ledgerId('c',l.source.key);if(L[cid])continue;
   if(items[l.itemId])ops.push({t:'adjust',id:cid,itemId:l.itemId,delta:-l.delta,reason:'correction',source:Object.assign({},l.source,{of:l.id}),note:'Removed or changed in Logbook'})}
  for(const k of Object.keys(inbox)){if(inbox[k].date===date&&!present.has(k))ops.push({t:'uninbox',key:k})}}
 return {ops,cursor,scanned}}
/* when a food gets linked, its waiting inbox entries can be applied */
function opsForLink(v2,st,fid){const ops=[],link=st.links[fid],item=link&&st.items[link.itemId];if(!item)return ops;const L=new Set((st.ledger||[]).map(l=>l.id));
 for(const [key,src] of Object.entries(st.inbox||{})){if(src.fid!==fid)continue;const id=ledgerId('e',key);ops.push({t:'uninbox',key});if(L.has(id))continue;
  const a=amountFor(v2&&v2.foods[fid]||null,src,item,link);ops.push({t:'adjust',id,itemId:item.id,delta:-a.qty,reason:'eaten',source:src,note:a.how})}
 return ops}
const status=it=>(+it.qty||0)<=0?'out':(it.lowAt!=null&&it.lowAt!==''&&+it.qty<=+it.lowAt)?'low':'ok';
/* Ontario time with offset, e.g. 2026-10-19T16:30:00-04:00 */
function ontario(ms){const d=new Date(ms),p=Object.fromEntries(new Intl.DateTimeFormat('en-CA',{timeZone:'America/Toronto',year:'numeric',month:'2-digit',day:'2-digit',hour:'2-digit',minute:'2-digit',second:'2-digit',hourCycle:'h23'}).formatToParts(d).map(x=>[x.type,x.value]));
 const local=Date.UTC(+p.year,+p.month-1,+p.day,+p.hour,+p.minute,+p.second),off=Math.round((local-Math.floor(ms/1000)*1000)/60000),s=off<0?'-':'+',a=Math.abs(off);
 return `${p.year}-${p.month}-${p.day}T${p.hour}:${p.minute}:${p.second}${s}${String(Math.floor(a/60)).padStart(2,'0')}:${String(a%60).padStart(2,'0')}`}
return {UNITS,ITEM_UNITS,fam,convU,unitNorm,normFood,hash,r3,readV2Cloud,readV2Local,entryKeys,ledgerId,amountFor,defaultMode,plan,opsForLink,status,ontario,foodName}});
