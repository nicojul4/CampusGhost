enum IncidentStatus {
  active('Active'),
  inProgress('In Progress'),
  resolved('Resolved');

  const IncidentStatus(this.value);
  final String value;

  static IncidentStatus fromValue(Object? value) {
    if (value == 'Resolved') return IncidentStatus.resolved;
    if (value == 'In Progress' || value == 'Sedang Dikerjakan') {
      return IncidentStatus.inProgress;
    }
    return IncidentStatus.active;
  }
}
