/// Equalizer presets defined on five anchor points (bass → treble) in dB, and
/// helpers to project them onto however many bands the device exposes.
class EqPreset {
  const EqPreset(this.name, this.gains);

  final String name;
  final List<double> gains;
}

const eqPresets = <EqPreset>[
  EqPreset('Flat', [0, 0, 0, 0, 0]),
  EqPreset('Bass boost', [6, 4, 0, 0, 0]),
  EqPreset('Treble boost', [0, 0, 0, 3, 6]),
  EqPreset('Vocal', [-2, 0, 3, 3, 0]),
  EqPreset('Rock', [4, 2, -2, 2, 4]),
  EqPreset('Classical', [3, 2, -1, 2, 3]),
];

/// Gain for band [index] of [bandCount], linearly interpolated from [gains]
/// (which may have a different length).
double gainForBand(List<double> gains, int index, int bandCount) {
  if (gains.isEmpty || bandCount <= 0) return 0;
  if (gains.length == bandCount) return gains[index];
  if (bandCount == 1) return gains.first;
  final pos = index * (gains.length - 1) / (bandCount - 1);
  final lo = pos.floor();
  final hi = pos.ceil();
  if (lo == hi) return gains[lo];
  return gains[lo] + (gains[hi] - gains[lo]) * (pos - lo);
}

List<double> projectGains(List<double> gains, int bandCount) =>
    [for (var i = 0; i < bandCount; i++) gainForBand(gains, i, bandCount)];
