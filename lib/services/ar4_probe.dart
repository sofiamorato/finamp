import 'dart:developer' as developer;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// App Report 4 evaluation switch. Build with `--dart-define=AR4_AFTER=true`
/// to enable the threading improvements; the default build keeps the original
/// behaviour so both variants share the same code and the same instrumentation.
const bool ar4After = bool.fromEnvironment('AR4_AFTER');

/// Emits one greppable log line: `[AR4][<tag>] <variant> key=value ...`.
void ar4Log(String tag, String fields) {
  debugPrint('[AR4][$tag] ${ar4After ? "after" : "before"} $fields');
}

/// Wraps [body] in a timeline event (visible in DevTools) and logs its duration.
Future<T> ar4Timed<T>(String tag, String label, Future<T> Function() body) async {
  final task = developer.TimelineTask();
  final sw = Stopwatch()..start();
  task.start('AR4 $tag $label');
  try {
    return await body();
  } finally {
    task.finish();
    ar4Log(tag, 'label=$label ms=${sw.elapsedMilliseconds}');
  }
}

bool _frameProbeStarted = false;

/// Logs UI-build and raster time of every frame (`[AR4][frame]`).
void ar4StartFrameProbe() {
  if (_frameProbeStarted) return;
  _frameProbeStarted = true;
  SchedulerBinding.instance.addTimingsCallback((List<ui.FrameTiming> timings) {
    for (final t in timings) {
      ar4Log(
        'frame',
        'buildUs=${t.buildDuration.inMicroseconds} rasterUs=${t.rasterDuration.inMicroseconds} '
            'totalUs=${t.totalSpan.inMicroseconds}',
      );
    }
  });
}
