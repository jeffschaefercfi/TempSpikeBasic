class TemperatureData {
  final double internalTempF;
  final double ambientTempF;
  final double internalTempC;
  final double ambientTempC;
  final double differenceC;
  final double differenceF;

  TemperatureData({
    required this.internalTempF,
    required this.ambientTempF,
    required this.internalTempC,
    required this.ambientTempC,
    required this.differenceC,
    required this.differenceF,
  });

  String getMatchStatus() {
    if (differenceF <= 3) return 'Perfect Match!';
    if (differenceF <= 10) return 'Getting closer...';
    return 'Keep trying!';
  }

  MatchLevel getMatchLevel() {
    if (differenceF <= 3) return MatchLevel.perfect;
    if (differenceF <= 10) return MatchLevel.close;
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
    int internalRaw = data[2];
    print(data);
    double internalTempC = (internalRaw - 30).toDouble();

    // Ambient temp (probe body): bytes[6] | bytes[7]<<8 = °F directly
    int ambientRaw = data[6];
    double ambientTempC = (ambientRaw - 30).toDouble();

    // Convert to Celsius
    double internalTempF = ((internalTempC * 9) / 5 ) + 32;
    double ambientTempF = ((ambientTempC * 9) / 5 ) + 32;

    // Calculate difference
    double differenceC = (internalTempC - ambientTempC).abs();
    double differenceF = (internalTempF - ambientTempF).abs();

    return TemperatureData(
      internalTempF: internalTempF,
      ambientTempF: ambientTempF,
      internalTempC: internalTempC,
      ambientTempC: ambientTempC,
      differenceC: differenceC,
      differenceF: differenceF,
    );
  }
}
