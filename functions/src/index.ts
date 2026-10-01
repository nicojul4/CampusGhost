import { initializeApp } from 'firebase-admin/app';

initializeApp();

export { onReportCreated } from './on_report_created';
export { resolveStaleIncidents } from './resolve_stale_incidents';
