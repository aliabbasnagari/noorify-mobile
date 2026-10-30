import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:noorify/models/models.dart';
import 'package:noorify/smart/smart_filter.dart';

void main() {
  final now = DateTime(2026, 6, 1);
  final ctx = SmartContext(now: now, isDownloaded: (id) => id == 'd');

  final songs = [
    Song(
      id: 'a',
      title: 'Blue in Green',
      artist: 'Miles Davis',
      genre: 'Jazz',
      year: 1959,
      duration: 337,
      playCount: 12,
      starred: true,
      created: now.subtract(const Duration(days: 3)),
    ),
    Song(
      id: 'b',
      title: 'So What',
      artist: 'Miles Davis',
      genre: 'Jazz',
      year: 1959,
      duration: 545,
      playCount: 3,
      created: now.subtract(const Duration(days: 90)),
    ),
    const Song(
        id: 'c',
        title: 'Roygbiv',
        artist: 'Boards of Canada',
        genre: 'Electronic',
        year: 1998,
        duration: 150),
    const Song(id: 'd', title: 'Untagged', duration: 60),
  ];

  List<String> ids(SmartFilter f, {Random? random}) =>
      f.apply(songs, ctx, random: random).map((s) => s.id).toList();

  group('rules', () {
    test('text operators are case-insensitive', () {
      expect(
        ids(const SmartFilter(rules: [
          SmartRule(SmartField.genre, SmartOperator.equals, 'jazz')
        ])),
        ['a', 'b'],
      );
      expect(
        ids(const SmartFilter(rules: [
          SmartRule(SmartField.artist, SmartOperator.startsWith, 'boards')
        ])),
        ['c'],
      );
      expect(
        // "Blue in Green" and "Untagged" have no letter o.
        ids(const SmartFilter(rules: [
          SmartRule(SmartField.title, SmartOperator.notContains, 'o')
        ])),
        ['a', 'd'],
      );
    });

    test('numeric operators ignore unknown values for greater/less', () {
      expect(
        ids(const SmartFilter(rules: [
          SmartRule(SmartField.year, SmartOperator.lessThan, '1990')
        ])),
        ['a', 'b'],
      );
      // "d" has no year: never greater, but is "not equal".
      expect(
        ids(const SmartFilter(rules: [
          SmartRule(SmartField.year, SmartOperator.notEquals, '1959')
        ])),
        ['c', 'd'],
      );
      expect(
        ids(const SmartFilter(rules: [
          SmartRule(SmartField.year, SmartOperator.greaterThan, 'abc')
        ])),
        isEmpty,
      );
    });

    test('flag and date operators', () {
      expect(
          ids(const SmartFilter(
              rules: [SmartRule(SmartField.starred, SmartOperator.isTrue)])),
          ['a']);
      expect(
          ids(const SmartFilter(
              rules: [SmartRule(SmartField.downloaded, SmartOperator.isTrue)])),
          ['d']);
      expect(
        ids(const SmartFilter(rules: [
          SmartRule(SmartField.added, SmartOperator.inLastDays, '30')
        ])),
        ['a'],
      );
      // Songs with no date count as "not in the last N days".
      expect(
        ids(const SmartFilter(rules: [
          SmartRule(SmartField.added, SmartOperator.notInLastDays, '30')
        ])),
        ['b', 'c', 'd'],
      );
    });
  });

  group('merge, groups, sort, limit', () {
    test('all vs any', () {
      const rules = [
        SmartRule(SmartField.genre, SmartOperator.equals, 'jazz'),
        SmartRule(SmartField.playCount, SmartOperator.greaterThan, '5'),
      ];
      expect(ids(const SmartFilter(rules: rules)), ['a']);
      expect(ids(const SmartFilter(merge: MergeRule.any, rules: rules)),
          ['a', 'b']);
    });

    test('nested group has its own merge rule', () {
      const filter = SmartFilter(rules: [
        SmartRule(SmartField.artist, SmartOperator.contains, 'miles'),
        SmartGroup(MergeRule.any, [
          SmartRule(SmartField.title, SmartOperator.contains, 'blue'),
          SmartRule(SmartField.duration, SmartOperator.greaterThan, '500'),
        ]),
      ]);
      expect(ids(filter), ['a', 'b']);
    });

    test('empty rules match everything', () {
      expect(ids(const SmartFilter()), ['a', 'b', 'c', 'd']);
    });

    test('sort applies in order with direction and then limit', () {
      const filter = SmartFilter(
        sort: [SmartSort('playCount', ascending: false)],
        limit: 2,
      );
      expect(ids(filter), ['a', 'b']);

      const byTitle = SmartFilter(sort: [SmartSort('title')]);
      expect(ids(byTitle), ['a', 'c', 'b', 'd']);
    });

    test('secondary sort breaks ties', () {
      const filter = SmartFilter(
        rules: [SmartRule(SmartField.genre, SmartOperator.equals, 'jazz')],
        sort: [SmartSort('year'), SmartSort('duration', ascending: false)],
      );
      expect(ids(filter), ['b', 'a']);
    });

    test('random sort keeps the same songs', () {
      const filter = SmartFilter(sort: [SmartSort(SmartSort.random)]);
      expect(ids(filter, random: Random(1))..sort(), ['a', 'b', 'c', 'd']);
    });
  });

  group('serialization', () {
    test('round-trips rules, groups, sort and limit', () {
      const original = SmartFilter(
        merge: MergeRule.any,
        rules: [
          SmartRule(SmartField.genre, SmartOperator.contains, 'jazz'),
          SmartGroup(MergeRule.all,
              [SmartRule(SmartField.starred, SmartOperator.isTrue)]),
        ],
        sort: [SmartSort('added', ascending: false)],
        limit: 50,
      );
      final copy = SmartFilter.fromJson(original.toJson());
      expect(copy.toJson(), original.toJson());
    });

    test('unknown fields and operators fall back instead of throwing', () {
      final rule =
          SmartRule.fromJson({'field': 'nope', 'operator': 'nope', 'value': 1});
      expect(rule.field, SmartField.title);
      expect(rule.operator, SmartOperator.contains);
      expect(rule.value, '1');
    });
  });
}
