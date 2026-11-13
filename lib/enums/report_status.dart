enum ReportStatus {
  active('Active'),
  inProgress('In Progress'),
  resolved('Resolved');

  const ReportStatus(this.value);
  final String value;

  static ReportStatus fromValue(Object? value) {
    if (value == 'Resolved' || value == 'Selesai') {
      return ReportStatus.resolved;
    }
    if (value == 'In Progress' ||
        value == 'Sedang Dikerjakan' ||
        value == 'Sedang Diperbaiki') {
      return ReportStatus.inProgress;
    }
    return ReportStatus.active;
  }

  String get labelIndonesian => switch (this) {
        ReportStatus.active => 'Menunggu',
        ReportStatus.inProgress => 'Sedang Dikerjakan',
        ReportStatus.resolved => 'Selesai',
      };
}
