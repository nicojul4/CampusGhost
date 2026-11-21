import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// Simple logging utility for CampusGhost.
/// 
/// Logs include timestamp, level, module name, and message.
/// In debug mode, errors and stack traces are also logged.
/// In release mode, sensitive information is minimized.
class Logger {
  /// Logs a debug message (only in debug mode).
  void debug(String module, String message) {
    if (kDebugMode) {
      final timestamp = DateTime.now().toIso8601String();
      developer.log('[DEBUG] $message', name: '[$module] $timestamp', level: 100);
    }
  }

  /// Logs an info message (always).
  void info(String module, String message) {
    final timestamp = DateTime.now().toIso8601String();
    developer.log('[INFO] $message', name: '[$module] $timestamp', level: 800);
  }

  /// Logs a warning message (always).
  void warning(String module, String message) {
    final timestamp = DateTime.now().toIso8601String();
    developer.log('[WARNING] $message', name: '[$module] $timestamp', level: 1300);
  }

  /// Logs an error message (always).
  /// In debug mode, also logs error object and stack trace.
  void error(String module, String message, [Object? error, StackTrace? stackTrace]) {
    final timestamp = DateTime.now().toIso8601String();
    developer.log('[ERROR] $message', name: '[$module] $timestamp', level: 2000);
    
    if (kDebugMode && error != null) {
      developer.log('Error: $error', name: '[$module] $timestamp', level: 2000);
      if (stackTrace != null) {
        developer.log('StackTrace: $stackTrace', name: '[$module] $timestamp', level: 2000);
      }
    }
  }

  /// Logs an error with stack trace.
  void errorWithStack(String module, String message, Object? exception, StackTrace? stackTrace) {
    error(module, message, exception, stackTrace);
  }
}

/// Global logger instance.
final logger = Logger();
