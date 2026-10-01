import { applicationDefault, initializeApp } from 'firebase-admin/app';
import { FieldValue, getFirestore } from 'firebase-admin/firestore';

const projectId =
  process.env.CAMPUS_GHOST_FIREBASE_PROJECT_ID ?? 'campusghost-adita';

initializeApp({
  credential: applicationDefault(),
  projectId,
});

const database = getFirestore();
const campusLatitude = -6.2607827;
const campusLongitude = 106.6184306;
const locations = [
  { id: 'gedung-1-lantai-b', name: 'Gedung 1 Lantai B', building: 'Gedung 1', floor: -1 },
  { id: 'gedung-1-lantai-gf', name: 'Gedung 1 Lantai GF', building: 'Gedung 1', floor: 0 },
  { id: 'gedung-1-lantai-1', name: 'Gedung 1 Lantai 1', building: 'Gedung 1', floor: 1 },
  { id: 'gedung-1-lantai-2', name: 'Gedung 1 Lantai 2', building: 'Gedung 1', floor: 2 },
  { id: 'gedung-1-lantai-3', name: 'Gedung 1 Lantai 3', building: 'Gedung 1', floor: 3 },
  { id: 'gedung-2-lantai-b', name: 'Gedung 2 Lantai B', building: 'Gedung 2', floor: -1 },
  { id: 'gedung-2-lantai-gf', name: 'Gedung 2 Lantai GF', building: 'Gedung 2', floor: 0 },
  { id: 'gedung-2-lantai-1', name: 'Gedung 2 Lantai 1', building: 'Gedung 2', floor: 1 },
  { id: 'gedung-2-lantai-2', name: 'Gedung 2 Lantai 2', building: 'Gedung 2', floor: 2 },
  { id: 'gedung-2-lantai-3', name: 'Gedung 2 Lantai 3', building: 'Gedung 2', floor: 3 },
  {
    id: 'perpustakaan-gedung-1-lantai-gf',
    name: 'Perpustakaan Gedung 1 Lantai GF',
    building: 'Perpustakaan',
    floor: 0,
  },
  { id: 'kantin-basement', name: 'Kantin (Basement)', building: 'Kantin', floor: -1 },
  { id: 'parkiran-motor', name: 'Parkiran Motor', building: 'Parkiran (Basement)', floor: -1 },
  { id: 'parkiran-mobil', name: 'Parkiran Mobil', building: 'Parkiran (Basement)', floor: -1 },
];

for (const location of locations) {
  const reference = database.collection('locations').doc(location.id);
  const existing = await reference.get();
  const data = {
    Name: location.name,
    Building: location.building,
    Floor: location.floor,
    Latitude: campusLatitude,
    Longitude: campusLongitude,
  };
  if (!existing.exists) data.CreatedAt = FieldValue.serverTimestamp();
  await reference.set(data, { merge: true });
}

console.log(`Berhasil menyiapkan ${locations.length} lokasi di proyek ${projectId}.`);
