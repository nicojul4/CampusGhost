enum FacilitySeverity {
  normal('Normal'),
  warning('Warning'),
  critical('Critical');

  const FacilitySeverity(this.value);
  final String value;

  static FacilitySeverity fromValue(Object? value) => switch (value) {
        'Critical' => FacilitySeverity.critical,
        'Warning' => FacilitySeverity.warning,
        _ => FacilitySeverity.normal,
      };
}
