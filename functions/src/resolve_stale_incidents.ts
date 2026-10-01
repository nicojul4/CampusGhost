import { onSchedule } from 'firebase-functions/v2/scheduler';
import { getFirestore, Timestamp } from 'firebase-admin/firestore';
import { incidentWindowMs, maxBatchWrites } from './config';

const database = getFirestore();

export const resolveStaleIncidents = onSchedule('every 60 minutes', async () => {
  const cutoff = Timestamp.fromMillis(Date.now() - incidentWindowMs);
  const staleIncidents = await database.collection('incidents')
    .where('Status', '==', 'Active')
    .where('LastUpdatedAt', '<', cutoff)
    .get();

  for (const incident of staleIncidents.docs) {
    const reports = await database.collection('reports')
      .where('IncidentId', '==', incident.id)
      .get();
    const operations = [
      { ref: incident.ref, data: { Status: 'Resolved' } },
      ...reports.docs.map((report) => ({
        ref: report.ref,
        data: { Status: 'Resolved', UpdatedAt: Timestamp.now() },
      })),
    ];

    for (let offset = 0; offset < operations.length; offset += maxBatchWrites) {
      const batch = database.batch();
      for (const operation of operations.slice(offset, offset + maxBatchWrites)) {
        batch.update(operation.ref, operation.data);
      }
      await batch.commit();
    }
  }
});
