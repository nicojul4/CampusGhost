enum ReportStatus {
  active('Active'),
  resolved('Resolved');

  const ReportStatus(this.value);
  final String value;

  static ReportStatus fromValue(Object? value) =>
      value == 'Resolved' ? ReportStatus.resolved : ReportStatus.active;
}
