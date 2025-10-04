class TemperatureData {
  final double internalTempF;
  final double ambientTempF;
  final double internalTempC;
  final double ambientTempC;
  final double difference;

  TemperatureData({
    required this.internalTempF,
    required this.ambientTempF,
    required this.internalTempC,
    required this.ambientTempC,
    required this.difference,
  });

  String getMatchStatus() {
    if (difference <= 3) return 'Perfect Match!';
    if (difference <= 8) return 'Getting closer...';
    return 'Keep trying!';
  }

  MatchLevel getMatchLevel() {
    if (difference <= 3) return MatchLevel.perfect;
    if (difference <= 8) return MatchLevel.close;
    return MatchLevel.far;
  }
}

enum MatchLevel {
  perfect,
  close,
  far,
}

class TemperatureDecoder {
  static TemperatureData decode(List<int> data) {
    if (data.length != 8) {
      throw ArgumentError('Temperature data must be 8 bytes');
    }

    // Internal temp (probe tip): ((bytes[2] | bytes[3]<<8) * 1.667) - 19 = °F
    int internalRaw = data[2] | (data[3] << 8);
    double internalTempF = (internalRaw * 1.667) - 19;

    // Ambient temp (probe body): bytes[6] | bytes[7]<<8 = °F directly
    double ambientTempF = (data[6] | (data[7] << 8)).toDouble();

    // Convert to Celsius
    double internalTempC = (internalTempF - 32) * 5 / 9;
    double ambientTempC = (ambientTempF - 32) * 5 / 9;

    // Calculate difference
    double difference = (internalTempF - ambientTempF).abs();

    return TemperatureData(
      internalTempF: internalTempF,
      ambientTempF: ambientTempF,
      internalTempC: internalTempC,
      ambientTempC: ambientTempC,
      difference: difference,
    );
  }
}
