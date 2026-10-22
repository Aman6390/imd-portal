import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/weather_data.dart';

/// Service managing 100% free, zero-config live weather forecasts for meteorological staff.
class WeatherService {
  static const String _keyCachedWeather = 'imd_cached_weather';
  static const String _keySelectedStation = 'imd_selected_station';

  /// Standard IMD Regional Centres (RMCs) and State Meteorological Centres (MCs)
  static const List<StationInfo> stations = [
    StationInfo(name: 'New Delhi (HQ)', state: 'Delhi', latitude: 28.6139, longitude: 77.2090),
    StationInfo(name: 'Pune (CR&S)', state: 'Maharashtra', latitude: 18.5204, longitude: 73.8567),
    StationInfo(name: 'Mumbai (RMC)', state: 'Maharashtra', latitude: 19.0760, longitude: 72.8777),
    StationInfo(name: 'Kolkata (RMC)', state: 'West Bengal', latitude: 22.5726, longitude: 88.3639),
    StationInfo(name: 'Chennai (RMC)', state: 'Tamil Nadu', latitude: 13.0827, longitude: 80.2707),
    StationInfo(name: 'Nagpur (RMC)', state: 'Maharashtra', latitude: 21.1458, longitude: 79.0882),
    StationInfo(name: 'Guwahati (RMC)', state: 'Assam', latitude: 26.1445, longitude: 91.7362),
    StationInfo(name: 'Bengaluru (MC)', state: 'Karnataka', latitude: 12.9716, longitude: 77.5946),
    StationInfo(name: 'Hyderabad (MC)', state: 'Telangana', latitude: 17.3850, longitude: 78.4867),
    StationInfo(name: 'Ahmedabad (MC)', state: 'Gujarat', latitude: 23.0225, longitude: 72.5714),
    StationInfo(name: 'Jaipur (MC)', state: 'Rajasthan', latitude: 26.9124, longitude: 75.7873),
    StationInfo(name: 'Lucknow (MC)', state: 'Uttar Pradesh', latitude: 26.8467, longitude: 80.9462),
    StationInfo(name: 'Patna (MC)', state: 'Bihar', latitude: 25.5941, longitude: 85.1376),
    StationInfo(name: 'Bhubaneswar (MC)', state: 'Odisha', latitude: 20.2961, longitude: 85.8245),
    StationInfo(name: 'Thiruvananthapuram (MC)', state: 'Kerala', latitude: 8.5241, longitude: 76.9366),
    StationInfo(name: 'Dehradun (MC)', state: 'Uttarakhand', latitude: 30.3165, longitude: 78.0322),
    StationInfo(name: 'Srinagar (MC)', state: 'Jammu & Kashmir', latitude: 34.0837, longitude: 74.7973),
    StationInfo(name: 'Shimla (MC)', state: 'Himachal Pradesh', latitude: 31.1048, longitude: 77.1734),
    StationInfo(name: 'Bhopal (MC)', state: 'Madhya Pradesh', latitude: 23.2599, longitude: 77.4126),
    StationInfo(name: 'Chandigarh (MC)', state: 'Punjab/Haryana', latitude: 30.7333, longitude: 76.7794),
    StationInfo(name: 'Ranchi (MC)', state: 'Jharkhand', latitude: 23.3441, longitude: 85.3096),
    StationInfo(name: 'Raipur (MC)', state: 'Chhattisgarh', latitude: 21.2514, longitude: 81.6296),
    StationInfo(name: 'Agartala (MC)', state: 'Tripura', latitude: 23.8315, longitude: 91.2868),
    StationInfo(name: 'Imphal (MC)', state: 'Manipur', latitude: 24.8170, longitude: 93.9368),
    StationInfo(name: 'Shillong (MC)', state: 'Meghalaya', latitude: 25.5788, longitude: 91.8933),
    StationInfo(name: 'Gangtok (MC)', state: 'Sikkim', latitude: 27.3389, longitude: 88.6065),
    StationInfo(name: 'Port Blair (MO)', state: 'Andaman & Nicobar', latitude: 11.6234, longitude: 92.7265),
  ];

  static const StationInfo defaultStation = StationInfo(
    name: 'New Delhi (HQ)',
    state: 'Delhi',
    latitude: 28.6139,
    longitude: 77.2090,
  );

  /// Loads the currently selected station from local storage
  static Future<StationInfo> loadSelectedStation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(_keySelectedStation);
      if (str != null && str.isNotEmpty) {
        return StationInfo.fromJson(jsonDecode(str) as Map<String, dynamic>);
      }
    } catch (_) {}
    return defaultStation;
  }

  /// Saves the selected station to local storage
  static Future<void> saveSelectedStation(StationInfo station) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keySelectedStation, jsonEncode(station.toJson()));
    } catch (_) {}
  }

  /// Loads the cached weather data for instant offline presentation
  static Future<WeatherData?> loadCachedWeather() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(_keyCachedWeather);
      if (str != null && str.isNotEmpty) {
        return WeatherData.fromJson(jsonDecode(str) as Map<String, dynamic>);
      }
    } catch (_) {}
    return null;
  }

  /// Saves freshly fetched weather data to cache
  static Future<void> saveCachedWeather(WeatherData data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyCachedWeather, jsonEncode(data.toJson()));
    } catch (_) {}
  }

  /// Fetches live weather for [station] using the free Open-Meteo public API
  static Future<WeatherData?> fetchWeather({StationInfo? station}) async {
    final targetStation = station ?? await loadSelectedStation();

    final url = Uri.parse(
      'https://api.open-meteo.com/v1/forecast'
      '?latitude=${targetStation.latitude}'
      '&longitude=${targetStation.longitude}'
      '&current=temperature_2m,relative_humidity_2m,apparent_temperature,precipitation,weather_code,wind_speed_10m'
      '&hourly=temperature_2m,weather_code,precipitation_probability'
      '&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max'
      '&forecast_days=7'
      '&timezone=auto',
    );

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 12));
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);

        // Parse current metrics
        final currentJson = data['current'] as Map<String, dynamic>? ?? {};
        final weatherCode = (currentJson['weather_code'] as num?)?.toInt() ?? 0;
        final details = WeatherData.getWeatherDetails(weatherCode);

        final currentWeather = CurrentWeather(
          temperature: (currentJson['temperature_2m'] as num?)?.toDouble() ?? 0.0,
          feelsLike: (currentJson['apparent_temperature'] as num?)?.toDouble() ?? 0.0,
          humidity: (currentJson['relative_humidity_2m'] as num?)?.toInt() ?? 0,
          windSpeed: (currentJson['wind_speed_10m'] as num?)?.toDouble() ?? 0.0,
          precipitation: (currentJson['precipitation'] as num?)?.toDouble() ?? 0.0,
          weatherCode: weatherCode,
          conditionText: details.$1,
          conditionIcon: details.$2,
        );

        // Parse next 24 hours
        final hourlyList = <HourlyForecast>[];
        final hourlyJson = data['hourly'] as Map<String, dynamic>? ?? {};
        final times = (hourlyJson['time'] as List<dynamic>? ?? []).cast<String>();
        final temps = (hourlyJson['temperature_2m'] as List<dynamic>? ?? []).cast<num>();
        final codes = (hourlyJson['weather_code'] as List<dynamic>? ?? []).cast<num>();
        final rains = (hourlyJson['precipitation_probability'] as List<dynamic>? ?? []).cast<num>();

        final now = DateTime.now();
        // Find index matching or immediately preceding current hour
        int startIndex = 0;
        for (int i = 0; i < times.length; i++) {
          final t = DateTime.tryParse(times[i]);
          if (t != null && t.isAfter(now.subtract(const Duration(hours: 1)))) {
            startIndex = i;
            break;
          }
        }

        final endIndex = (startIndex + 24).clamp(0, times.length);
        for (int i = startIndex; i < endIndex; i++) {
          final t = DateTime.tryParse(times[i]) ?? now;
          final c = i < codes.length ? codes[i].toInt() : 0;
          final d = WeatherData.getWeatherDetails(c);
          hourlyList.add(HourlyForecast(
            time: t,
            temperature: i < temps.length ? temps[i].toDouble() : 0.0,
            weatherCode: c,
            precipitationProbability: i < rains.length ? rains[i].toInt() : 0,
            conditionIcon: d.$2,
          ));
        }

        // Parse 7-day daily forecast
        final dailyList = <DailyForecast>[];
        final dailyJson = data['daily'] as Map<String, dynamic>? ?? {};
        final dTimes = (dailyJson['time'] as List<dynamic>? ?? []).cast<String>();
        final minTemps = (dailyJson['temperature_2m_min'] as List<dynamic>? ?? []).cast<num>();
        final maxTemps = (dailyJson['temperature_2m_max'] as List<dynamic>? ?? []).cast<num>();
        final dCodes = (dailyJson['weather_code'] as List<dynamic>? ?? []).cast<num>();
        final dRains = (dailyJson['precipitation_probability_max'] as List<dynamic>? ?? []).cast<num>();

        for (int i = 0; i < dTimes.length; i++) {
          final t = DateTime.tryParse(dTimes[i]) ?? now.add(Duration(days: i));
          final c = i < dCodes.length ? dCodes[i].toInt() : 0;
          final d = WeatherData.getWeatherDetails(c);

          dailyList.add(DailyForecast(
            date: t,
            minTemp: i < minTemps.length ? minTemps[i].toDouble() : 0.0,
            maxTemp: i < maxTemps.length ? maxTemps[i].toDouble() : 0.0,
            weatherCode: c,
            precipitationProbabilityMax: i < dRains.length ? dRains[i].toInt() : 0,
            conditionText: d.$1,
            conditionIcon: d.$2,
          ));
        }

        final weatherData = WeatherData(
          station: targetStation,
          current: currentWeather,
          hourly: hourlyList,
          daily: dailyList,
          lastUpdated: DateTime.now(),
        );

        await saveCachedWeather(weatherData);
        await saveSelectedStation(targetStation);
        return weatherData;
      }
    } catch (_) {
      // Fallback silently to cached weather on network timeout
    }

    return await loadCachedWeather();
  }
}
