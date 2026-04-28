import 'dart:isolate';

bool isIsolateOverride = false;
bool get isIsolate => isIsolateOverride || (Isolate.current.debugName != null && Isolate.current.debugName != 'main');

/// Override the isolate name shown in log entries.
/// Used when the Dart VM names the isolate "main" even though it is a background
/// worker (e.g. the DartWorker FlutterEngine), where the true debugName cannot
/// be set at spawn time.
String? isolateNameOverride;
