String toSupabaseTimestamp(DateTime value) {
  return value.toUtc().toIso8601String();
}

DateTime parseLocalDateTime(Object? value) {
  return parseNullableLocalDateTime(value) ??
      DateTime.fromMillisecondsSinceEpoch(0);
}

DateTime? parseNullableLocalDateTime(Object? value) {
  if (value == null) return null;
  final parsed = value is DateTime
      ? value
      : DateTime.tryParse(value.toString());
  if (parsed == null) return null;
  return parsed.isUtc ? parsed.toLocal() : parsed;
}
