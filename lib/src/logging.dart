import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';

/// The logger for this package.
@visibleForTesting
final Logger logger = Logger('WorkingRouter');

/// Whether or not logging is enabled.
bool _enabled = false;

/// Logs the message if logging is enabled.
void log(String message, {Level level = Level.INFO}) {
  if (_enabled) {
    logger.log(level, message);
  }
}

StreamSubscription<LogRecord>? _subscription;

/// Forwards diagnostic messages to the dart:developer log() API.
void setLogging({bool enabled = false}) {
  unawaited(_subscription?.cancel());
  _enabled = enabled;

  if (!enabled || hierarchicalLoggingEnabled) {
    return;
  }

  _subscription = logger.onRecord.listen((record) {
    if (record.level >= Level.SEVERE) {
      final error = record.error;
      FlutterError.dumpErrorToConsole(
        FlutterErrorDetails(
          exception: error is Exception ? error : Exception(error),
          stack: record.stackTrace,
          library: record.loggerName,
          context: ErrorDescription(record.message),
        ),
      );
    } else {
      _developerLogFunction(record);
    }
  });
}

void _developerLog(LogRecord record) {
  developer.log(
    record.message,
    time: record.time,
    sequenceNumber: record.sequenceNumber,
    level: record.level.value,
    name: record.loggerName,
    zone: record.zone,
    error: record.error,
    stackTrace: record.stackTrace,
  );
}

/// A function that can be set during test to mock the developer log function.
@visibleForTesting
void Function(LogRecord)? testDeveloperLog;

void Function(LogRecord) get _developerLogFunction =>
    testDeveloperLog ?? _developerLog;
