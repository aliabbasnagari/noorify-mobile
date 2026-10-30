/// Rule-based smart playlists.
///
/// Structure mirrors what REA observed in Symfonium: a SmartFilter has a name,
/// a merge rule, rules (which may be nested groups, each with its own merge
/// rule), an ordered sort list of {field, ascending} and a limit. The set of
/// fields and operators is our own design; the obfuscated enums were not
/// recoverable.
library;

import 'dart:math' as math;

import '../models/models.dart';

enum FieldType { text, number, flag, date }

enum SmartField {
  title('Title', FieldType.text),
  artist('Artist', FieldType.text),
  album('Album', FieldType.text),
  genre('Genre', FieldType.text),
  year('Year', FieldType.number),
  duration('Duration (seconds)', FieldType.number),
  bitRate('Bitrate (kbps)', FieldType.number),
  playCount('Play count', FieldType.number),
  userRating('Rating (1-5)', FieldType.number),
  starred('Favorite', FieldType.flag),
  downloaded('Downloaded', FieldType.flag),
  added('Date added', FieldType.date),
  lastPlayed('Last played', FieldType.date);

  const SmartField(this.label, this.type);

  final String label;
  final FieldType type;
}

enum SmartOperator {
  contains('contains'),
  notContains('does not contain'),
  equals('is'),
  notEquals('is not'),
  startsWith('starts with'),
  endsWith('ends with'),
  greaterThan('is greater than'),
  lessThan('is less than'),
  isTrue('is yes'),
  isFalse('is no'),
  inLastDays('in the last (days)'),
  notInLastDays('not in the last (days)');

  const SmartOperator(this.label);

  final String label;

  bool get needsValue => this != isTrue && this != isFalse;
}

List<SmartOperator> operatorsFor(FieldType type) => switch (type) {
      FieldType.text => const [
          SmartOperator.contains,
          SmartOperator.notContains,
          SmartOperator.equals,
          SmartOperator.notEquals,
          SmartOperator.startsWith,
          SmartOperator.endsWith,
        ],
      FieldType.number => const [
          SmartOperator.equals,
          SmartOperator.notEquals,
          SmartOperator.greaterThan,
          SmartOperator.lessThan,
        ],
      FieldType.flag => const [SmartOperator.isTrue, SmartOperator.isFalse],
      FieldType.date => const [
          SmartOperator.inLastDays,
          SmartOperator.notInLastDays
        ],
    };

enum MergeRule { all, any }

/// Evaluation environment: current time and which songs are downloaded.
class SmartContext {
  SmartContext({DateTime? now, this.isDownloaded})
      : now = now ?? DateTime.now();

  final DateTime now;
  final bool Function(String songId)? isDownloaded;
}

sealed class SmartNode {
  const SmartNode();

  Map<String, dynamic> toJson();

  bool matches(Song song, SmartContext ctx);

  factory SmartNode.fromJson(Map<String, dynamic> j) =>
      j['type'] == 'group' ? SmartGroup.fromJson(j) : SmartRule.fromJson(j);
}

class SmartRule extends SmartNode {
  const SmartRule(this.field, this.operator, [this.value = '']);

  final SmartField field;
  final SmartOperator operator;
  final String value;

  @override
  Map<String, dynamic> toJson() => {
        'type': 'rule',
        'field': field.name,
        'operator': operator.name,
        'value': value,
      };

  factory SmartRule.fromJson(Map<String, dynamic> j) {
    final field = SmartField.values.firstWhere(
      (f) => f.name == j['field'],
      orElse: () => SmartField.title,
    );
    final op = SmartOperator.values.firstWhere(
      (o) => o.name == j['operator'],
      orElse: () => operatorsFor(field.type).first,
    );
    return SmartRule(field, op, '${j['value'] ?? ''}');
  }

  @override
  bool matches(Song s, SmartContext ctx) {
    switch (field.type) {
      case FieldType.text:
        final actual = (_text(s) ?? '').toLowerCase();
        final expected = value.toLowerCase();
        return switch (operator) {
          SmartOperator.contains => actual.contains(expected),
          SmartOperator.notContains => !actual.contains(expected),
          SmartOperator.equals => actual == expected,
          SmartOperator.notEquals => actual != expected,
          SmartOperator.startsWith => actual.startsWith(expected),
          SmartOperator.endsWith => actual.endsWith(expected),
          _ => false,
        };
      case FieldType.number:
        final actual = _number(s);
        final expected = double.tryParse(value.trim());
        if (expected == null) return false;
        return switch (operator) {
          SmartOperator.equals => actual == expected,
          // Unknown numeric values count as "not equal" but never "greater".
          SmartOperator.notEquals => actual != expected,
          SmartOperator.greaterThan => actual != null && actual > expected,
          SmartOperator.lessThan => actual != null && actual < expected,
          _ => false,
        };
      case FieldType.flag:
        final actual = _flag(s, ctx);
        return operator == SmartOperator.isTrue ? actual : !actual;
      case FieldType.date:
        final days = int.tryParse(value.trim());
        if (days == null) return false;
        final date = _date(s);
        final within = date != null && ctx.now.difference(date).inDays < days;
        return operator == SmartOperator.inLastDays ? within : !within;
    }
  }

  String? _text(Song s) => switch (field) {
        SmartField.title => s.title,
        SmartField.artist => s.artist,
        SmartField.album => s.album,
        SmartField.genre => s.genre,
        _ => null,
      };

  double? _number(Song s) => switch (field) {
        SmartField.year => s.year?.toDouble(),
        SmartField.duration => s.duration.toDouble(),
        SmartField.bitRate => s.bitRate?.toDouble(),
        SmartField.playCount => s.playCount.toDouble(),
        SmartField.userRating => s.userRating?.toDouble(),
        _ => null,
      };

  bool _flag(Song s, SmartContext ctx) => switch (field) {
        SmartField.starred => s.starred,
        SmartField.downloaded => ctx.isDownloaded?.call(s.id) ?? false,
        _ => false,
      };

  DateTime? _date(Song s) => switch (field) {
        SmartField.added => s.created,
        SmartField.lastPlayed => s.played,
        _ => null,
      };
}

class SmartGroup extends SmartNode {
  const SmartGroup(this.merge, this.children);

  final MergeRule merge;
  final List<SmartNode> children;

  @override
  Map<String, dynamic> toJson() => {
        'type': 'group',
        'merge': merge.name,
        'children': [for (final c in children) c.toJson()],
      };

  factory SmartGroup.fromJson(Map<String, dynamic> j) => SmartGroup(
        MergeRule.values.firstWhere((m) => m.name == j['merge'],
            orElse: () => MergeRule.all),
        [
          for (final c in (j['children'] as List? ?? const []))
            SmartNode.fromJson(c as Map<String, dynamic>),
        ],
      );

  @override
  bool matches(Song song, SmartContext ctx) =>
      mergeMatches(merge, children, song, ctx);
}

/// An empty rule list matches everything.
bool mergeMatches(
    MergeRule merge, List<SmartNode> nodes, Song song, SmartContext ctx) {
  if (nodes.isEmpty) return true;
  return merge == MergeRule.all
      ? nodes.every((n) => n.matches(song, ctx))
      : nodes.any((n) => n.matches(song, ctx));
}

/// [field] is a [SmartField] name or [SmartSort.random].
class SmartSort {
  const SmartSort(this.field, {this.ascending = true});

  static const random = 'random';

  final String field;
  final bool ascending;

  Map<String, dynamic> toJson() => {'field': field, 'ascending': ascending};

  factory SmartSort.fromJson(Map<String, dynamic> j) =>
      SmartSort(j['field'] as String? ?? 'title',
          ascending: j['ascending'] as bool? ?? true);
}

class SmartFilter {
  const SmartFilter({
    this.merge = MergeRule.all,
    this.rules = const [],
    this.sort = const [],
    this.limit = 0,
  });

  final MergeRule merge;
  final List<SmartNode> rules;
  final List<SmartSort> sort;

  /// 0 = no limit.
  final int limit;

  Map<String, dynamic> toJson() => {
        'merge': merge.name,
        'rules': [for (final r in rules) r.toJson()],
        'sort': [for (final s in sort) s.toJson()],
        'limit': limit,
      };

  factory SmartFilter.fromJson(Map<String, dynamic> j) => SmartFilter(
        merge: MergeRule.values.firstWhere((m) => m.name == j['merge'],
            orElse: () => MergeRule.all),
        rules: [
          for (final r in (j['rules'] as List? ?? const []))
            SmartNode.fromJson(r as Map<String, dynamic>),
        ],
        sort: [
          for (final s in (j['sort'] as List? ?? const []))
            SmartSort.fromJson(s as Map<String, dynamic>),
        ],
        limit: (j['limit'] as num?)?.toInt() ?? 0,
      );

  /// Filters, sorts and limits [songs]. [random] makes shuffles deterministic
  /// in tests.
  List<Song> apply(Iterable<Song> songs, SmartContext ctx,
      {math.Random? random}) {
    final out = [
      for (final s in songs)
        if (mergeMatches(merge, rules, s, ctx)) s,
    ];

    if (sort.any((s) => s.field == SmartSort.random)) {
      out.shuffle(random);
    } else if (sort.isNotEmpty) {
      out.sort((a, b) {
        for (final s in sort) {
          final field =
              SmartField.values.where((f) => f.name == s.field).firstOrNull;
          if (field == null) continue;
          final c = _compare(field, a, b, ctx);
          if (c != 0) return s.ascending ? c : -c;
        }
        return 0;
      });
    }
    return limit > 0 && out.length > limit ? out.sublist(0, limit) : out;
  }

  static int _compare(SmartField f, Song a, Song b, SmartContext ctx) {
    switch (f.type) {
      case FieldType.text:
        return (_text(f, a) ?? '')
            .toLowerCase()
            .compareTo((_text(f, b) ?? '').toLowerCase());
      case FieldType.number:
        return (_num(f, a) ?? -1).compareTo(_num(f, b) ?? -1);
      case FieldType.flag:
        final fa = f == SmartField.starred
            ? a.starred
            : (ctx.isDownloaded?.call(a.id) ?? false);
        final fb = f == SmartField.starred
            ? b.starred
            : (ctx.isDownloaded?.call(b.id) ?? false);
        return (fa ? 1 : 0).compareTo(fb ? 1 : 0);
      case FieldType.date:
        final da = f == SmartField.added ? a.created : a.played;
        final db = f == SmartField.added ? b.created : b.played;
        return (da?.millisecondsSinceEpoch ?? 0)
            .compareTo(db?.millisecondsSinceEpoch ?? 0);
    }
  }

  static String? _text(SmartField f, Song s) => switch (f) {
        SmartField.title => s.title,
        SmartField.artist => s.artist,
        SmartField.album => s.album,
        SmartField.genre => s.genre,
        _ => null,
      };

  static num? _num(SmartField f, Song s) => switch (f) {
        SmartField.year => s.year,
        SmartField.duration => s.duration,
        SmartField.bitRate => s.bitRate,
        SmartField.playCount => s.playCount,
        SmartField.userRating => s.userRating,
        _ => null,
      };
}

class SmartPlaylist {
  const SmartPlaylist(
      {required this.id, required this.title, required this.filter});

  factory SmartPlaylist.create(String title, SmartFilter filter) =>
      SmartPlaylist(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        title: title,
        filter: filter,
      );

  final String id;
  final String title;
  final SmartFilter filter;

  SmartPlaylist copyWith({String? title, SmartFilter? filter}) => SmartPlaylist(
      id: id, title: title ?? this.title, filter: filter ?? this.filter);

  Map<String, dynamic> toJson() =>
      {'id': id, 'title': title, 'filter': filter.toJson()};

  factory SmartPlaylist.fromJson(Map<String, dynamic> j) => SmartPlaylist(
        id: j['id'] as String,
        title: j['title'] as String? ?? 'Smart playlist',
        filter: SmartFilter.fromJson(
            j['filter'] as Map<String, dynamic>? ?? const {}),
      );
}
