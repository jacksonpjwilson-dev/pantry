import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';

test('web metadata edits preserve native fields and concurrent inventory adjustments', async()=> {
 const docs=new Map([
  ['pantry/test-user/items/rice',{name:'Rice',qty:1000,unit:'g',category:'Pantry',lowAt:200,createdAt:1,barcode:'12345678',expirationDate:1900000000000}],
  ['pantry/test-user/meta/state',{createdAt:1}]
 ]);
 const writes=[];
 const snapshot=path=>({id:path.split('/').at(-1),exists:docs.has(path),data:()=>structuredClone(docs.get(path))});
 const document=path=>({
  collection:name=>collection(path+'/'+name),get:async()=>snapshot(path),
  set:async(value,options)=> {writes.push(path);docs.set(path,options?.merge?{...docs.get(path),...value}:structuredClone(value));}
 });
 const collection=path=>({doc:id=>document(path+'/'+id),orderBy:()=>collection(path),limit:()=>collection(path),get:async()=>({forEach:fn=>{
  for(const key of docs.keys())if(key.startsWith(path+'/')&&!key.slice(path.length+1).includes('/'))fn(snapshot(key));
 }})});
 const firebase={apps:[{}],auth:()=>({getRedirectResult:()=>Promise.resolve()}),firestore:()=>({collection})};
 const sandbox={firebase,console};sandbox.window=sandbox;
 vm.runInNewContext(readFileSync('store.js','utf8'),sandbox);
 await sandbox.STORE.init();const store=sandbox.STORE.Cloud({uid:'test-user'});await store.load();
 // A native transaction commits after the web page cached its item.
 docs.get('pantry/test-user/items/rice').qty=850;
 await store.putItem({id:'rice',name:'Brown rice',unit:'g',category:'Pantry',lowAt:150});
 const saved=docs.get('pantry/test-user/items/rice');
 assert.equal(saved.qty,850);assert.equal(saved.barcode,'12345678');assert.equal(saved.expirationDate,1900000000000);
 assert.equal(saved.createdAt,1);assert.equal(saved.name,'Brown rice');assert.equal(saved.lowAt,150);
 await store.putItem({id:'eggs',name:'Eggs',qty:0,unit:'count',category:'Fridge',createdAt:2});
 assert.equal(docs.get('pantry/test-user/items/eggs').qty,0);
 assert.ok(writes.every(path=>path.startsWith('pantry/test-user')));
});
