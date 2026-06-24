enum TransportMeans { bus, train, other }

extension TransportMeansExt on TransportMeans {
  String get label {
    switch (this) {
      case TransportMeans.bus:   return 'バス';
      case TransportMeans.train: return '電車';
      case TransportMeans.other: return 'その他';
    }
  }

  String get emoji {
    switch (this) {
      case TransportMeans.bus:   return '🚌';
      case TransportMeans.train: return '🚃';
      case TransportMeans.other: return '🚕';
    }
  }
}
