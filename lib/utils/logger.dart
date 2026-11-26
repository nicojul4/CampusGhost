import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// Level keparahan log.
enum LogLevel {
  debug('DEBUG', 100),
  info('INFO', 800),
  warning('WARNING', 1300),
  error('ERROR', 2000);

  const LogLevel(this.name, this.levelValue);
  final String name;
  final int levelValue;
}

/// Model rekaman log untuk tracing runtime saat aplikasi berjalan.
class LogEntry {
  const LogEntry({
    required this.timestamp,
    required this.level,
    required this.module,
    required this.message,
    this.error,
    this.stackTrace,
  });

  final DateTime timestamp;
  final LogLevel level;
  final String module;
  final String message;
  final Object? error;
  final StackTrace? stackTrace;

  String get timeFormatted {
    final h = timestamp.hour.toString().padLeft(2, '0');
    final m = timestamp.minute.toString().padLeft(2, '0');
    final s = timestamp.second.toString().padLeft(2, '0');
    final ms = timestamp.millisecond.toString().padLeft(3, '0');
    return '$h:$m:$s.$ms';
  }

  String toFullString() {
    final buffer = StringBuffer();
    buffer.write('[$timeFormatted] [${level.name}] [$module] $message');
    if (error != null) {
      buffer.write('\n  Error: $error');
    }
    if (stackTrace != null) {
      buffer.write('\n  StackTrace: $stackTrace');
    }
    return buffer.toString();
  }
}

/// Sistem logging CampusGhost yang aman untuk Release Mode dan on-running tracing.
/// 
/// Fitur:
/// - Menyimpan log ke in-memory circular ring buffer (kapasitas hingga 250 entri).
/// - Sanitasi otomatis terhadap kredensial sensitif (token, password).
/// - Error & stack trace tetap terekam di buffer pada mode rilis untuk tracing kendala.
/// - Menghadirkan [logCountNotifier] untuk mengikat UI penampil log secara reaktif.
class Logger {
  static const int maxBufferSize = 250;
  final List<LogEntry> _buffer = [];
  final ValueNotifier<int> logCountNotifier = ValueNotifier<int>(0);

  /// Sanitasi teks agar kredensial atau token otentikasi tidak bocor ke log.
  String sanitize(String input) {
    return input
        .replaceAll(
          RegExp(r'(password\s*[:=]\s*)[^\s,;]+', caseSensitive: false),
          r'$1[REDACTED]',
        )
        .replaceAll(
          RegExp(r'(token\s*[:=]\s*)[^\s,;]+', caseSensitive: false),
          r'$1[REDACTED]',
        )
        .replaceAll(
          RegExp(r'Bearer\s+[A-Za-z0-9\-._~+/]+=*', caseSensitive: false),
          'Bearer [REDACTED]',
        );
  }

  void _addEntry(LogEntry entry) {
    if (_buffer.length >= maxBufferSize) {
      _buffer.removeAt(0);
    }
    _buffer.add(entry);
    logCountNotifier.value = _buffer.length;
  }

  /// Logs a debug message (only in debug mode for developer console, but kept in ring buffer).
  void debug(String module, String message) {
    final safeMessage = sanitize(message);
    final entry = LogEntry(
      timestamp: DateTime.now(),
      level: LogLevel.debug,
      module: module,
      message: safeMessage,
    );
    _addEntry(entry);

    if (kDebugMode) {
      developer.log(
        '[DEBUG] $safeMessage',
        name: '[$module] ${entry.timestamp.toIso8601String()}',
        level: LogLevel.debug.levelValue,
      );
    }
  }

  /// Logs an info message.
  void info(String module, String message) {
    final safeMessage = sanitize(message);
    final entry = LogEntry(
      timestamp: DateTime.now(),
      level: LogLevel.info,
      module: module,
      message: safeMessage,
    );
    _addEntry(entry);

    developer.log(
      '[INFO] $safeMessage',
      name: '[$module] ${entry.timestamp.toIso8601String()}',
      level: LogLevel.info.levelValue,
    );
  }

  /// Logs a warning message.
  void warning(String module, String message) {
    final safeMessage = sanitize(message);
    final entry = LogEntry(
      timestamp: DateTime.now(),
      level: LogLevel.warning,
      module: module,
      message: safeMessage,
    );
    _addEntry(entry);

    developer.log(
      '[WARNING] $safeMessage',
      name: '[$module] ${entry.timestamp.toIso8601String()}',
      level: LogLevel.warning.levelValue,
    );
  }

  /// Logs an error message.
  /// Di release mode, error dan stack trace tetap disimpan di ring buffer untuk tracing.
  void error(String module, String message, [Object? error, StackTrace? stackTrace]) {
    final safeMessage = sanitize(message);
    final entry = LogEntry(
      timestamp: DateTime.now(),
      level: LogLevel.error,
      module: module,
      message: safeMessage,
      error: error,
      stackTrace: stackTrace,
    );
    _addEntry(entry);

    developer.log(
      '[ERROR] $safeMessage',
      name: '[$module] ${entry.timestamp.toIso8601String()}',
      level: LogLevel.error.levelValue,
    );
    if (kDebugMode && error != null) {
      developer.log(
        'Error: $error',
        name: '[$module] ${entry.timestamp.toIso8601String()}',
        level: LogLevel.error.levelValue,
      );
      if (stackTrace != null) {
        developer.log(
          'StackTrace: $stackTrace',
          name: '[$module] ${entry.timestamp.toIso8601String()}',
          level: LogLevel.error.levelValue,
        );
      }
    }
  }

  /// Logs an error with stack trace.
  void errorWithStack(String module, String message, Object? exception, StackTrace? stackTrace) {
    error(module, message, exception, stackTrace);
  }

  /// Mendapatkan seluruh daftar riwayat log terkini (copy tidak dapat diubah dari luar).
  List<LogEntry> getLogs() => List.unmodifiable(_buffer);

  /// Menghasilkan seluruh log dalam format teks plaintext siap salin/ekspor.
  String getFormattedLogs() {
    if (_buffer.isEmpty) return 'Belum ada log yang tercatat.';
    final sb = StringBuffer();
    sb.writeln('=== CAMPUSGHOST SYSTEM LOG EXPORT ===');
    sb.writeln('Waktu Ekspor: ${DateTime.now().toIso8601String()}');
    sb.writeln('Jumlah Entri: ${_buffer.length}');
    sb.writeln('=====================================\n');
    for (final entry in _buffer) {
      sb.writeln(entry.toFullString());
    }
    return sb.toString();
  }

  /// Membersihkan isi ring buffer log.
  void clearLogs() {
    _buffer.clear();
    logCountNotifier.value = 0;
  }
}

/// Global logger instance.
final logger = Logger();
