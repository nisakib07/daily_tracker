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

/// The earliest date the app offers when picking a transaction date or
/// browsing history. It used to be 2020, which hid older history.
final earliestPickableDate = DateTime(2000);

/// First and last dates for a date picker starting at [initial]: from
/// [earliestPickableDate] to today, widened to include [initial] itself. A
/// record already dated outside that range (imported, or entered on the
/// website) would otherwise make the picker fail when edited. Future dates
/// aren't offered: an entry dated ahead would change today's balance
/// before the money moves.
({DateTime first, DateTime last}) pickableDateRange(
  DateTime initial, {
  DateTime? now,
}) {
  DateTime dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);
  final day = dateOnly(initial);
  final today = dateOnly(now ?? DateTime.now());
  return (
    first: day.isBefore(earliestPickableDate) ? day : earliestPickableDate,
    last: day.isAfter(today) ? day : today,
  );
}
