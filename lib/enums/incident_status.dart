enum IncidentStatus {
  active('Active'),
  resolved('Resolved');

  const IncidentStatus(this.value);
  final String value;

  static IncidentStatus fromValue(Object? value) =>
      value == 'Resolved' ? IncidentStatus.resolved : IncidentStatus.active;
}
