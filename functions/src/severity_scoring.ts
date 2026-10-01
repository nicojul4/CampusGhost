const categoryUrgencyWeight: Record<string, number> = {
  Lift: 3,
  Ac: 2,
  Toilet: 1,
  Wifi: 1,
  Printer: 1,
  Proyektor: 1,
  Parkir: 2,
  Lainnya: 1,
};

export function calculateSeverity(reportCount: number, category: string): string {
  const weight = categoryUrgencyWeight[category] ?? 1;
  return reportCount * weight >= 3 ? 'Critical' : 'Warning';
}
