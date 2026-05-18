int parseInt(dynamic value, {String field = 'value'}) {
  if (value == null) {
    throw FormatException('Expected int for $field, got null');
  }
  if (value is int) return value;
  if (value is double) return value.round();
  if (value is String) {
    final s = value.trim();
    return s.contains('.') ? double.parse(s).round() : int.parse(s);
  }
  throw FormatException('Cannot parse int for $field from $value');
}

int? parseIntOrNull(dynamic value) {
  if (value == null) return null;
  return parseInt(value);
}

double parseDouble(dynamic value, {String field = 'value'}) {
  if (value == null) {
    throw FormatException('Expected double for $field, got null');
  }
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.parse(value.trim());
  throw FormatException('Cannot parse double for $field from $value');
}

bool parseBool(dynamic value, {bool defaultValue = false}) {
  if (value == null) return defaultValue;
  if (value is bool) return value;
  if (value is int) return value != 0;
  if (value is String) {
    final v = value.toLowerCase().trim();
    return v == 'true' || v == '1' || v == 'yes';
  }
  return defaultValue;
}

String parseString(dynamic value, {String field = 'value'}) {
  if (value == null) {
    throw FormatException('Expected String for $field, got null');
  }
  return value.toString();
}

String? parseStringOrNull(dynamic value) {
  if (value == null) return null;
  final s = value.toString();
  return s.isEmpty ? null : s;
}

List<String> parseStringList(dynamic value) {
  if (value == null) return const [];
  if (value is List) {
    return value.map((e) => e.toString()).toList(growable: false);
  }
  return const [];
}

DateTime parseDateTime(dynamic value, {String field = 'value'}) {
  return DateTime.parse(parseString(value, field: field));
}

Map<String, dynamic> asJsonMap(dynamic value, {String field = 'value'}) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  throw FormatException('Expected Map for $field, got $value');
}

List<Map<String, dynamic>> asJsonMapList(dynamic value) {
  if (value == null) return const [];
  if (value is! List) return const [];
  return value
      .map((e) => asJsonMap(e))
      .toList(growable: false);
}
