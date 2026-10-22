import 'package:flutter/material.dart';

/// Represents an IMD Station or Regional Centre for weather forecasting.
class StationInfo {
  final String name;
  final String state;
  final double latitude;
  final double longitude;

  const StationInfo({
    required this.name,
    required this.state,
    required this.latitude,
    required this.longitude,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'state': state,
        'latitude': latitude,
        'longitude': longitude,
      };

  factory StationInfo.fromJson(Map<String, dynamic> json) => StationInfo(
        name: json['name'] as String? ?? 'New Delhi (HQ)',
        state: json['state'] as String? ?? 'Delhi',
        latitude: (json['latitude'] as num?)?.toDouble() ?? 28.6139,
        longitude: (json['longitude'] as num?)?.toDouble() ?? 77.2090,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StationInfo &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          latitude == other.latitude &&
          longitude == other.longitude;

  @override
  int get hashCode => name.hashCode ^ latitude.hashCode ^ longitude.hashCode;
}

/// Instantaneous weather readings at the station.
class CurrentWeather {
  final double temperature;
  final double feelsLike;
  final int humidity;
  final double windSpeed;
  final double precipitation;
  final int weatherCode;
  final String conditionText;
  final String conditionIcon;

  const CurrentWeather({
    required this.temperature,
    required this.feelsLike,
    required this.humidity,
    required this.windSpeed,
    required this.precipitation,
    required this.weatherCode,
    required this.conditionText,
    required this.conditionIcon,
  });

  Map<String, dynamic> toJson() => {
        'temperature': temperature,
        'feelsLike': feelsLike,
        'humidity': humidity,
        'windSpeed': windSpeed,
        'precipitation': precipitation,
        'weatherCode': weatherCode,
        'conditionText': conditionText,
        'conditionIcon': conditionIcon,
      };

  factory CurrentWeather.fromJson(Map<String, dynamic> json) => CurrentWeather(
        temperature: (json['temperature'] as num?)?.toDouble() ?? 0.0,
        feelsLike: (json['feelsLike'] as num?)?.toDouble() ?? 0.0,
        humidity: (json['humidity'] as num?)?.toInt() ?? 0,
        windSpeed: (json['windSpeed'] as num?)?.toDouble() ?? 0.0,
        precipitation: (json['precipitation'] as num?)?.toDouble() ?? 0.0,
        weatherCode: (json['weatherCode'] as num?)?.toInt() ?? 0,
        conditionText: json['conditionText'] as String? ?? 'Fair',
        conditionIcon: json['conditionIcon'] as String? ?? '🌤️',
      );
}

/// Hourly weather forecast for the 24-hour timeline carousel.
class HourlyForecast {
  final DateTime time;
  final double temperature;
  final int weatherCode;
  final int precipitationProbability;
  final String conditionIcon;

  const HourlyForecast({
    required this.time,
    required this.temperature,
    required this.weatherCode,
    required this.precipitationProbability,
    required this.conditionIcon,
  });

  Map<String, dynamic> toJson() => {
        'time': time.toIso8601String(),
        'temperature': temperature,
        'weatherCode': weatherCode,
        'precipitationProbability': precipitationProbability,
        'conditionIcon': conditionIcon,
      };

  factory HourlyForecast.fromJson(Map<String, dynamic> json) => HourlyForecast(
        time: DateTime.tryParse(json['time'] as String? ?? '') ?? DateTime.now(),
        temperature: (json['temperature'] as num?)?.toDouble() ?? 0.0,
        weatherCode: (json['weatherCode'] as num?)?.toInt() ?? 0,
        precipitationProbability: (json['precipitationProbability'] as num?)?.toInt() ?? 0,
        conditionIcon: json['conditionIcon'] as String? ?? '🌤️',
      );
}

/// Daily weather outlook for 7-day planning.
class DailyForecast {
  final DateTime date;
  final double minTemp;
  final double maxTemp;
  final int weatherCode;
  final int precipitationProbabilityMax;
  final String conditionText;
  final String conditionIcon;

  const DailyForecast({
    required this.date,
    required this.minTemp,
    required this.maxTemp,
    required this.weatherCode,
    required this.precipitationProbabilityMax,
    required this.conditionText,
    required this.conditionIcon,
  });

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'minTemp': minTemp,
        'maxTemp': maxTemp,
        'weatherCode': weatherCode,
        'precipitationProbabilityMax': precipitationProbabilityMax,
        'conditionText': conditionText,
        'conditionIcon': conditionIcon,
      };

  factory DailyForecast.fromJson(Map<String, dynamic> json) => DailyForecast(
        date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
        minTemp: (json['minTemp'] as num?)?.toDouble() ?? 0.0,
        maxTemp: (json['maxTemp'] as num?)?.toDouble() ?? 0.0,
        weatherCode: (json['weatherCode'] as num?)?.toInt() ?? 0,
        precipitationProbabilityMax: (json['precipitationProbabilityMax'] as num?)?.toInt() ?? 0,
        conditionText: json['conditionText'] as String? ?? 'Fair',
        conditionIcon: json['conditionIcon'] as String? ?? '🌤️',
      );
}

/// Comprehensive Weather State containing station, current metrics, hourly and daily trends.
class WeatherData {
  final StationInfo station;
  final CurrentWeather current;
  final List<HourlyForecast> hourly;
  final List<DailyForecast> daily;
  final DateTime lastUpdated;

  const WeatherData({
    required this.station,
    required this.current,
    required this.hourly,
    required this.daily,
    required this.lastUpdated,
  });

  Map<String, dynamic> toJson() => {
        'station': station.toJson(),
        'current': current.toJson(),
        'hourly': hourly.map((h) => h.toJson()).toList(),
        'daily': daily.map((d) => d.toJson()).toList(),
        'lastUpdated': lastUpdated.toIso8601String(),
      };

  factory WeatherData.fromJson(Map<String, dynamic> json) => WeatherData(
        station: StationInfo.fromJson(json['station'] as Map<String, dynamic>? ?? {}),
        current: CurrentWeather.fromJson(json['current'] as Map<String, dynamic>? ?? {}),
        hourly: (json['hourly'] as List<dynamic>? ?? [])
            .map((h) => HourlyForecast.fromJson(h as Map<String, dynamic>))
            .toList(),
        daily: (json['daily'] as List<dynamic>? ?? [])
            .map((d) => DailyForecast.fromJson(d as Map<String, dynamic>))
            .toList(),
        lastUpdated: DateTime.tryParse(json['lastUpdated'] as String? ?? '') ?? DateTime.now(),
      );

  /// Resolves standard WMO weather codes into descriptive condition name and emoji.
  static (String condition, String icon, IconData iconData) getWeatherDetails(int code) {
    switch (code) {
      case 0:
        return ('Clear Sky', '☀️', Icons.wb_sunny_rounded);
      case 1:
        return ('Mainly Clear', '🌤️', Icons.wb_sunny_outlined);
      case 2:
        return ('Partly Cloudy', '⛅', Icons.cloud_queue_rounded);
      case 3:
        return ('Overcast', '☁️', Icons.cloud_rounded);
      case 45:
      case 48:
        return ('Fog / Mist', '🌫️', Icons.foggy);
      case 51:
      case 53:
      case 55:
        return ('Drizzle', '🌦️', Icons.water_drop_outlined);
      case 56:
      case 57:
        return ('Freezing Drizzle', '🌨️', Icons.ac_unit_rounded);
      case 61:
        return ('Slight Rain', '🌦️', Icons.water_drop_rounded);
      case 63:
        return ('Moderate Rain', '🌧️', Icons.grain_rounded);
      case 65:
        return ('Heavy Rain', '🌧️', Icons.thunderstorm_rounded);
      case 66:
      case 67:
        return ('Freezing Rain', '🌨️', Icons.ac_unit_rounded);
      case 71:
      case 73:
      case 75:
      case 77:
        return ('Snow Fall', '❄️', Icons.snowing);
      case 80:
      case 81:
      case 82:
        return ('Rain Showers', '🌧️', Icons.shower_rounded);
      case 85:
      case 86:
        return ('Snow Showers', '🌨️', Icons.snowing);
      case 95:
        return ('Thunderstorm', '⛈️', Icons.flash_on_rounded);
      case 96:
      case 99:
        return ('Thunderstorm & Hail', '⛈️', Icons.thunderstorm_rounded);
      default:
        return ('Fair Weather', '🌤️', Icons.wb_cloudy_rounded);
    }
  }
}
