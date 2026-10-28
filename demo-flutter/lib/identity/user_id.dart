import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Turns a username into the stable user id the analytics backend sees — byte for byte what
/// demo-android's `UserId.kt` and demo-ios's `UserId.swift` derive, so "ada" is one person on all
/// three demos and in the simulated history.
///
/// There is no sign-up API in this demo, so the id has to come from the only thing the user
/// supplies. A hash means the same username always produces the same id — on a relaunch, after a
/// reinstall, on another device. A random id would make every sign-in a new person.
abstract final class UserId {
  /// [username] as typed. Trimmed and lowercased first, so " Ada " and "ada" are one person.
  static String forUsername(String username) {
    final normalized = username.trim().toLowerCase();
    final digest = sha256.convert(utf8.encode(normalized)).bytes;
    // 16 hex characters — 64 bits, plenty for a demo and short enough to paste into a query.
    return 'u_${digest.take(8).map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
  }
}
