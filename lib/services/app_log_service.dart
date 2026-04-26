import 'dart:collection';

import 'package:flutter/foundation.dart';

class AppLogEntry {
  const AppLogEntry({
    required this.timestamp,
    required this.level,
    required this.message,
    this.error,
    this.stackTrace,
  });

  final DateTime timestamp;
  final String level;
  final String message;
  final Object? error;
  final StackTrace? stackTrace;

  String toReadableLine() {
    final errorText = error == null ? '' : '\nerror: $error';
    final traceText = stackTrace == null ? '' : '\nstack:\n$stackTrace';
    return '[${timestamp.toIso8601String()}] [$level] $message$errorText$traceText';
  }
}

class AppLogService {
  AppLogService._();

  static final AppLogService instance = AppLogService._();
  static const int _maxEntries = 400;

  final ValueNotifier<List<AppLogEntry>> logs = ValueNotifier<List<AppLogEntry>>(
    const <AppLogEntry>[],
  );

  final Queue<AppLogEntry> _buffer = Queue<AppLogEntry>();

  void info(String message) {
    _add(
      AppLogEntry(
        timestamp: DateTime.now(),
        level: 'INFO',
        message: message,
      ),
    );
  }

  void error(String message, Object error, [StackTrace? stackTrace]) {
    _add(
      AppLogEntry(
        timestamp: DateTime.now(),
        level: 'ERROR',
        message: message,
        error: error,
        stackTrace: stackTrace,
      ),
    );
  }

  void clear() {
    _buffer.clear();
    logs.value = const <AppLogEntry>[];
  }

  String exportAll() {
    if (_buffer.isEmpty) {
      return 'No logs captured yet.';
    }
    return _buffer.map((entry) => entry.toReadableLine()).join('\n\n');
  }

  void _add(AppLogEntry entry) {
    _buffer.addLast(entry);
    while (_buffer.length > _maxEntries) {
      _buffer.removeFirst();
    }
    logs.value = List<AppLogEntry>.unmodifiable(_buffer.toList(growable: false));
    debugPrint(entry.toReadableLine());
  }
}
