enum SplitType { none, food75, daily50, custom }

extension SplitTypeExt on SplitType {
  String get label {
    switch (this) {
      case SplitType.none:    return 'なし';
      case SplitType.food75:  return '食事';
      case SplitType.daily50: return '日用品';
      case SplitType.custom:  return 'カスタム';
    }
  }

  int get defaultPercent {
    switch (this) {
      case SplitType.none:    return 0;
      case SplitType.food75:  return 75;
      case SplitType.daily50: return 50;
      case SplitType.custom:  return 50;
    }
  }
}
