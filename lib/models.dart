class Reading {
  final int id;
  final double temperature;
  final double humidity;
  final String recordedAt;

  const Reading({
    required this.id,
    required this.temperature,
    required this.humidity,
    required this.recordedAt,
  });

  factory Reading.fromJson(Map<String, dynamic> json) {
    return Reading(
      id: (json['id'] as num).toInt(),
      temperature: (json['temperature'] as num).toDouble(),
      humidity: (json['humidity'] as num).toDouble(),
      recordedAt: json['recordedAt'] as String,
    );
  }
}

class TrendPoint {
  final String recordedAt;
  final double temperature;
  final double humidity;
  final bool synthetic;
  final bool live;

  const TrendPoint({
    required this.recordedAt,
    required this.temperature,
    required this.humidity,
    this.synthetic = false,
    this.live = false,
  });

  factory TrendPoint.fromJson(Map<String, dynamic> json) {
    return TrendPoint(
      recordedAt: json['recordedAt'] as String,
      temperature: (json['temperature'] as num).toDouble(),
      humidity: (json['humidity'] as num).toDouble(),
      synthetic: json['synthetic'] as bool? ?? false,
      live: json['live'] as bool? ?? false,
    );
  }
}

class Threshold {
  final String commodity;
  final double minTemp;
  final double maxTemp;
  final double minHumidity;
  final double maxHumidity;

  const Threshold({
    required this.commodity,
    required this.minTemp,
    required this.maxTemp,
    required this.minHumidity,
    required this.maxHumidity,
  });

  factory Threshold.fromJson(Map<String, dynamic> json) {
    return Threshold(
      commodity: json['commodity'] as String,
      minTemp: (json['minTemp'] as num).toDouble(),
      maxTemp: (json['maxTemp'] as num).toDouble(),
      minHumidity: (json['minHumidity'] as num).toDouble(),
      maxHumidity: (json['maxHumidity'] as num).toDouble(),
    );
  }
}

class StatusResponse {
  final Reading? latest;
  final Threshold threshold;
  final bool breached;

  const StatusResponse({
    required this.latest,
    required this.threshold,
    required this.breached,
  });

  factory StatusResponse.fromJson(Map<String, dynamic> json) {
    return StatusResponse(
      latest: json['latest'] == null
          ? null
          : Reading.fromJson(json['latest'] as Map<String, dynamic>),
      threshold: Threshold.fromJson(json['threshold'] as Map<String, dynamic>),
      breached: json['breached'] as bool,
    );
  }
}

class Alert {
  final int id;
  final int readingId;
  final String message;
  final String sentAt;
  final String? commodity;
  final Reading? reading;
  final Threshold? threshold;
  final bool acknowledged;

  const Alert({
    required this.id,
    required this.readingId,
    required this.message,
    required this.sentAt,
    this.commodity,
    this.reading,
    this.threshold,
    this.acknowledged = false,
  });

  factory Alert.fromJson(Map<String, dynamic> json) {
    return Alert(
      id: (json['id'] as num).toInt(),
      readingId: (json['readingId'] as num).toInt(),
      message: json['message'] as String,
      sentAt: json['sentAt'] as String,
      commodity: json['commodity'] as String?,
      reading: json['reading'] is Map<String, dynamic>
          ? Reading.fromJson(json['reading'] as Map<String, dynamic>)
          : null,
      threshold: json['threshold'] is Map<String, dynamic>
          ? Threshold.fromJson(json['threshold'] as Map<String, dynamic>)
          : null,
      acknowledged: json['acknowledged'] as bool? ?? false,
    );
  }
}
