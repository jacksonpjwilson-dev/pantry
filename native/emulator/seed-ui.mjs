// Isolated demo emulator fixtures only. Refuse a real Firebase destination.
import {initializeApp} from 'firebase/app';
import {getAuth,connectAuthEmulator,createUserWithEmailAndPassword} from 'firebase/auth';
import {getFirestore,connectFirestoreEmulator,doc,setDoc,terminate} from 'firebase/firestore';
if (process.env.FIRESTORE_EMULATOR_HOST !== '127.0.0.1:8080' || process.env.FIREBASE_AUTH_EMULATOR_HOST !== '127.0.0.1:9099') throw new Error('Local emulators required');
for (const name of ['alice','bob']) {
 const app=initializeApp({projectId:'demo-pantry-native',apiKey:'synthetic-emulator-key'},name);
 const auth=getAuth(app);connectAuthEmulator(auth,'http://127.0.0.1:9099',{disableWarnings:true});
 const user=(await createUserWithEmailAndPassword(auth,`${name}@pantry.example`,'SyntheticPassword123!')).user;
 const db=getFirestore(app);connectFirestoreEmulator(db,'127.0.0.1',8080);
 await setDoc(doc(db,`pantry/${user.uid}/meta/state`),{setup:{linkV2:false}});
 await terminate(db);
}
console.log('Seeded two synthetic isolated accounts; legacy Logbook sync disabled.');
