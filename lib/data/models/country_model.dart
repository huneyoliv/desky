class CountryModel {
  final int id;
  final String name;
  final String code;
  final String timezone;
  final String continent;
  final double? gmtOffset;
  final int? startGmt;
  final int? endGmt;
  final String? startTime;
  final List<Map<String, dynamic>>? multiCountries;

  const CountryModel({
    required this.id,
    required this.name,
    required this.code,
    required this.timezone,
    required this.continent,
    this.gmtOffset,
    this.startGmt,
    this.endGmt,
    this.startTime,
    this.multiCountries,
  });

  String get formattedName {
    if (name.isEmpty) return code;
    return name.split(' ').map((word) {
      if (word.isEmpty) return '';
      if (word.startsWith('(') && word.length > 1) {
        return '(${word[1].toUpperCase()}${word.substring(2).toLowerCase()}';
      }
      return '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}';
    }).join(' ');
  }

  /// Fixed GMT offset published by YPT for the country, when known.
  Duration? get gmtOffsetDuration =>
      gmtOffset == null ? null : Duration(minutes: (gmtOffset! * 60).round());

  /// Hour at which YPT starts a new study day for the country (5 AM by default).
  int get startHour {
    final raw = startTime?.trim() ?? '';
    final match = RegExp(r'^(\d{1,2})').firstMatch(raw);
    final parsed = match == null ? null : int.tryParse(match.group(1)!);
    if (parsed == null) return 5;

    final upper = raw.toUpperCase();
    var hour = parsed;
    if (upper.contains('AM') && hour == 12) {
      hour = 0;
    } else if (upper.contains('PM') && hour < 12) {
      hour += 12;
    }
    return (hour >= 0 && hour <= 23) ? hour : 5;
  }

  String get gmtDisplay {
    if (gmtOffset == null) return '';
    final g = gmtOffset!;
    final sign = g >= 0 ? '+' : '';
    if (g % 1 == 0) {
      return 'GMT$sign${g.toInt()}';
    }
    final int h = g.toInt();
    final int m = ((g.abs() % 1) * 60).round();
    return 'GMT$sign$h:${m.toString().padLeft(2, '0')}';
  }

  factory CountryModel.fromJson(Map<String, dynamic> json) {
    return CountryModel(
      id: json['id'] as int? ?? 0,
      name: json['t'] as String? ?? '',
      code: json['c'] as String? ?? 'BR',
      timezone: json['tz'] as String? ?? 'America/Sao_Paulo',
      continent: json['con'] as String? ?? '',
      gmtOffset: (json['g'] as num?)?.toDouble(),
      startGmt: json['sg'] as int?,
      endGmt: json['eg'] as int?,
      startTime: json['st'] as String?,
      multiCountries: (json['mc'] as List?)?.cast<Map<String, dynamic>>(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        't': name,
        'c': code,
        'tz': timezone,
        'con': continent,
        if (gmtOffset != null) 'g': gmtOffset,
        if (startGmt != null) 'sg': startGmt,
        if (endGmt != null) 'eg': endGmt,
        if (startTime != null) 'st': startTime,
        if (multiCountries != null) 'mc': multiCountries,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CountryModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          code == other.code;

  @override
  int get hashCode => id.hashCode ^ code.hashCode;
}
