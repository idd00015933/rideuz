import 'package:flutter/material.dart';

/// A lightweight mixin for [State] subclasses that guards [setState] calls
/// and provides a [safeSetState] helper that is a no-op when the widget is
/// already disposed.
///
/// Usage:
/// ```dart
/// class _MyScreenState extends State<MyScreen> with SafeAsyncMixin {
///   void _onData(String v) => safeSetState(() => _value = v);
/// }
/// ```
mixin SafeAsyncMixin<T extends StatefulWidget> on State<T> {
  /// Calls [setState] only if the widget is still mounted.
  /// Use this inside Timer callbacks, async continuations, and any other
  /// context where the widget might have been disposed since the call began.
  void safeSetState(VoidCallback fn) {
    if (mounted) setState(fn);
  }
}
