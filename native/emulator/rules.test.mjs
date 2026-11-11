import {readFileSync} from 'node:fs';
import {test, before, after} from 'node:test';
import assert from 'node:assert/strict';
import {initializeTestEnvironment, assertFails, assertSucceeds} from '@firebase/rules-unit-testing';
import {doc, getDoc, setDoc, deleteDoc, runTransaction} from 'firebase/firestore';
let env;
before(async()=> { env=await initializeTestEnvironment({projectId:'demo-pantry-native',firestore:{rules:readFileSync('firestore.rules','utf8')}}); });
after(async()=> { await env?.cleanup(); });
test('account boundaries and read-only Logbook integration',async()=> {
 const alice=env.authenticatedContext('alice').firestore(), bob=env.authenticatedContext('bob').firestore(), guest=env.unauthenticatedContext().firestore();
 await assertSucceeds(setDoc(doc(alice,'pantry/alice/items/rice'),{qty:1000}));
 await assertFails(getDoc(doc(bob,'pantry/alice/items/rice')));
 await assertFails(getDoc(doc(guest,'pantry/alice/items/rice')));
 await assertFails(setDoc(doc(alice,'logbookV2/alice'),{r:{}}));
 await assertFails(setDoc(doc(alice,'users/alice'),{}));
 await env.withSecurityRulesDisabled(async c=>setDoc(doc(c.firestore(),'logbookV2/alice'),{r:{}}));
 await assertSucceeds(getDoc(doc(alice,'logbookV2/alice')));
 await assertFails(getDoc(doc(bob,'logbookV2/alice')));
});
test('concurrent idempotent operation and retained historical ledger',async()=> {
 const db=env.authenticatedContext('concurrent').firestore();
 const item=doc(db,'pantry/concurrent/items/eggs'),ledger=doc(db,'pantry/concurrent/ledger/e_fixture');
 await setDoc(item,{qty:12});
 const apply=()=>runTransaction(db,async tx=> { const operation=await tx.get(ledger);if(operation.exists())return;const current=await tx.get(item);tx.update(item,{qty:current.data().qty-2});tx.set(ledger,{delta:-2,itemId:'eggs'}); });
 await Promise.all([apply(),apply()]);
 assert.equal((await getDoc(item)).data().qty,10);
 await assertFails(deleteDoc(ledger));
 // A ledger document older than any UI cache still prevents replay.
 await apply();assert.equal((await getDoc(item)).data().qty,10);
});
