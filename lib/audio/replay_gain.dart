import 'dart:math' as math;

import '../models/models.dart';
import '../settings/settings_models.dart';

/// Gain in dB to apply to a track under the given ReplayGain [mode].
///
/// Returns 0 when ReplayGain is off. Missing data falls back to the track's
/// `fallbackGain` (OpenSubsonic) or 0 dB. Positive results are limited by the
/// peak so boosting never clips.
double replayGainDb(ReplayGainInfo? info, ReplayGainMode mode, double preAmpDb) {
  if (mode == ReplayGainMode.off) return 0;
  if (info == null) return preAmpDb;

  final preferTrack = mode == ReplayGainMode.track;
  final gain = preferTrack
      ? (info.trackGain ?? info.albumGain)
      : (info.albumGain ?? info.trackGain);
  final peak = preferTrack
      ? (info.trackPeak ?? info.albumPeak)
      : (info.albumPeak ?? info.trackPeak);

  var db = (gain ?? info.fallbackGain ?? 0) + preAmpDb;
  if (peak != null && peak > 0) {
    // Largest gain that keeps the peak at or below full scale.
    db = math.min(db, -20 * math.log(peak) / math.ln10);
  }
  return db;
}

/// Linear volume (0..1) for [db]; positive gain is handled separately by the
/// loudness enhancer because player volume cannot exceed 1.0.
double dbToVolume(double db) =>
    math.pow(10, db / 20).toDouble().clamp(0.0, 1.0);
