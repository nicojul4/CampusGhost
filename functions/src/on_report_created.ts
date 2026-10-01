import { onDocumentCreated } from 'firebase-functions/v2/firestore';
import { getFirestore, Timestamp } from 'firebase-admin/firestore';
import { duplicateWindowMs, incidentWindowMs } from './config';
import { calculateSeverity } from './severity_scoring';

const database = getFirestore();

export const onReportCreated = onDocumentCreated(
  'reports/{reportId}',
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;

    const reportRef = snapshot.ref;
    const report = snapshot.data();
    const now = Timestamp.now();
    const createdAt = report.CreatedAt instanceof Timestamp
      ? report.CreatedAt
      : now;
    const cutoffDuplicate = Timestamp.fromMillis(
      createdAt.toMillis() - duplicateWindowMs,
    );

    const duplicate = await database.collection('reports')
      .where('UserId', '==', report.UserId)
      .where('LocationId', '==', report.LocationId)
      .where('Category', '==', report.Category)
      .where('CreatedAt', '>=', cutoffDuplicate)
      .where('CreatedAt', '<', createdAt)
      .limit(1)
      .get();

    if (!duplicate.empty) {
      await reportRef.delete();
      return;
    }

    const cutoffIncident = Timestamp.fromMillis(
      now.toMillis() - incidentWindowMs,
    );
    const activeQuery = database.collection('incidents')
      .where('LocationId', '==', report.LocationId)
      .where('Category', '==', report.Category)
      .where('Status', '==', 'Active')
      .where('LastUpdatedAt', '>=', cutoffIncident)
      .orderBy('LastUpdatedAt', 'desc')
      .limit(1);

    await database.runTransaction(async (transaction) => {
      const currentReport = await transaction.get(reportRef);
      if (!currentReport.exists) return;
      if (currentReport.get('IncidentId') != null) return;
      const matchingIncidents = await transaction.get(activeQuery);
      const incident = matchingIncidents.docs[0];
      if (incident) {
        const reportCount = (incident.get('ReportCount') as number) + 1;
        transaction.update(incident.ref, {
          ReportCount: reportCount,
          Severity: calculateSeverity(reportCount, report.Category),
          LastUpdatedAt: now,
        });
        transaction.update(reportRef, {
          IncidentId: incident.id,
          Status: 'Active',
          CreatedAt: createdAt,
          UpdatedAt: now,
        });
      } else {
        const newIncidentRef = database.collection('incidents').doc();
        transaction.create(newIncidentRef, {
          LocationId: report.LocationId,
          Category: report.Category,
          ReportCount: 1,
          Status: 'Active',
          Severity: calculateSeverity(1, report.Category),
          FirstReportedAt: createdAt,
          LastUpdatedAt: now,
        });
        transaction.update(reportRef, {
          IncidentId: newIncidentRef.id,
          Status: 'Active',
          CreatedAt: createdAt,
          UpdatedAt: now,
        });
      }
    });
  },
);
