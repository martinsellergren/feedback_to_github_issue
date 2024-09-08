extension StringX on String {
  String? get nullIfEmpty => isEmpty ? null : this;
}
