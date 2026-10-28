import 'dart:convert';
import 'dart:io';

import 'package:funnelbase_flutter/funnelbase_flutter.dart';
import 'package:path_provider/path_provider.dart';

/// Where the session's few values are kept between launches.
abstract interface class SessionFile {
  Future<String?> read();
  Future<void> write(String contents);
}

/// A small JSON file in the app's support directory — the same two facts demo-android keeps in
/// `SharedPreferences`, and as little machinery. Not shared_preferences: see pubspec.yaml.
class AppSupportSessionFile implements SessionFile {
  Future<File> _file() async => File('${(await getApplicationSupportDirectory()).path}/trade-demo-session.json');

  @override
  Future<String?> read() async {
    final file = await _file();
    return await file.exists() ? file.readAsString() : null;
  }

  @override
  Future<void> write(String contents) async {
    final file = await _file();
    await file.parent.create(recursive: true);
    await file.writeAsString(contents, flush: true);
  }
}

/// A file that only lives as long as the process, for tests.
class MemorySessionFile implements SessionFile {
  MemorySessionFile([this.contents]);

  String? contents;

  @override
  Future<String?> read() async => contents;

  @override
  Future<void> write(String contents) async => this.contents = contents;
}

/// The only thing this app persists: who is signed in (and on which plan), and which symbols they
/// favourited. Read once before the first frame, so every read after it is synchronous — the state
/// a screen draws and the identity `AppState` sends never wait on the disk.
class SessionStore {
  SessionStore._(this._file, Map<String, Object?> values)
      : _username = values['username'] as String?,
        _planRenewsOn = _parseDay(values['plan_renews_on'] as String?),
        _favourites = (values['favourites'] as List?)?.cast<String>().toSet();

  static Future<SessionStore> load(SessionFile file) async {
    Map<String, Object?> values = const {};
    try {
      final contents = await file.read();
      if (contents != null) values = (jsonDecode(contents) as Map).cast<String, Object?>();
    } catch (_) {
      // A file this build cannot read is a fresh start, not a crash at launch.
    }
    return SessionStore._(file, values);
  }

  final SessionFile _file;
  String? _username;
  AnalyticsDay? _planRenewsOn;
  Set<String>? _favourites;
  Future<void> _writing = Future.value();

  String? get username => _username;
  set username(String? value) {
    _username = value;
    _save();
  }

  /// The day the signed-in account's pro plan next renews, or null on the free plan. Kept so a
  /// relaunch's re-identify sends the same day the sign-in did.
  AnalyticsDay? get planRenewsOn => _planRenewsOn;
  set planRenewsOn(AnalyticsDay? value) {
    _planRenewsOn = value;
    _save();
  }

  Set<String> get favourites => _favourites ?? const {};
  set favourites(Set<String> value) {
    _favourites = {...value};
    _save();
  }

  /// True until favourites are first written, so they are seeded exactly once.
  bool get isFirstRun => _favourites == null;

  void clearUser() {
    _username = null;
    _planRenewsOn = null;
    _save();
  }

  /// Writes are chained, so two quick changes land in the order they were made.
  void _save() {
    final contents = jsonEncode({
      'username': _username,
      'plan_renews_on': _planRenewsOn?.toString(),
      'favourites': _favourites?.toList(),
    });
    _writing = _writing.then((_) => _file.write(contents)).catchError((_) {});
  }

  static AnalyticsDay? _parseDay(String? text) {
    final parts = text?.split('-');
    if (parts == null || parts.length != 3) return null;
    return AnalyticsDay(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
  }
}
