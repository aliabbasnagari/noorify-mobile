import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noorify/data/local/app_database.dart';
import 'package:noorify/models/models.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.withExecutor(NativeDatabase.memory()));
  tearDown(() => db.close());

  const owner = 'https://music.example.com|alice';
  const other = 'https://music.example.com|bob';

  Song song(String id, {String title = 'Title'}) => Song(id: id, title: title);

  test('replaceSongs then loadSongs round-trips fields including ReplayGain',
      () async {
    const s = Song(
      id: 's1',
      title: 'One',
      album: 'Album',
      artist: 'Artist',
      starred: true,
      genre: 'Jazz',
      playCount: 3,
      replayGain: ReplayGainInfo(trackGain: -6.2, trackPeak: 0.97),
    );
    await db.replaceSongs(owner, [s]);

    final loaded = await db.loadSongs(owner);
    expect(loaded, hasLength(1));
    expect(loaded.single.title, 'One');
    expect(loaded.single.starred, isTrue);
    expect(loaded.single.replayGain?.trackGain, -6.2);
    expect(loaded.single.replayGain?.trackPeak, 0.97);
  });

  test('replaceSongs drops rows that are no longer present', () async {
    await db.replaceSongs(owner, [song('s1'), song('s2')]);
    await db.replaceSongs(owner, [song('s2')]);

    final loaded = await db.loadSongs(owner);
    expect(loaded.map((s) => s.id), ['s2']);
  });

  test('upsertSongs adds to the existing set without clearing it first',
      () async {
    await db.upsertSongs(owner, [song('s1')]);
    await db.upsertSongs(owner, [song('s2')]);

    final loaded = await db.loadSongs(owner);
    expect(loaded.map((s) => s.id).toSet(), {'s1', 's2'});
  });

  test('rows are scoped per owner', () async {
    await db.replaceSongs(owner, [song('s1')]);
    await db.replaceSongs(other, [song('s2')]);

    expect((await db.loadSongs(owner)).map((s) => s.id), ['s1']);
    expect((await db.loadSongs(other)).map((s) => s.id), ['s2']);
  });

  test('clearOwner removes songs and sync state for that owner only', () async {
    await db.replaceSongs(owner, [song('s1')]);
    await db.replaceSongs(other, [song('s2')]);
    await db.setLastSync(owner, DateTime(2024, 1, 1));

    await db.clearOwner(owner);

    expect(await db.loadSongs(owner), isEmpty);
    expect(await db.getLastSync(owner), isNull);
    expect(await db.loadSongs(other), hasLength(1));
  });

  test('getLastSync is null until set, then returns the stored time', () async {
    expect(await db.getLastSync(owner), isNull);
    final time = DateTime(2024, 3, 10, 12);
    await db.setLastSync(owner, time);
    expect(await db.getLastSync(owner), time);
  });
}
