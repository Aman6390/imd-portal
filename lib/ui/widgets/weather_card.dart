import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/weather_data.dart';
import '../../services/weather_service.dart';

/// Interactive, zero-config live weather card displayed on the main dashboard.
class WeatherCard extends StatefulWidget {
  final WeatherData? initialData;
  final Function(WeatherData)? onWeatherUpdated;

  const WeatherCard({
    Key? key,
    this.initialData,
    this.onWeatherUpdated,
  }) : super(key: key);

  @override
  State<WeatherCard> createState() => _WeatherCardState();
}

class _WeatherCardState extends State<WeatherCard> {
  WeatherData? _weather;
  bool _isLoading = false;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _weather = widget.initialData;
    _loadExpandedState();
    if (_weather == null) {
      _loadWeather();
    }
  }

  Future<void> _loadExpandedState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final expanded = prefs.getBool('weather_card_expanded') ?? false;
      if (mounted) {
        setState(() {
          _isExpanded = expanded;
        });
      }
    } catch (_) {}
  }

  void _toggleExpanded() async {
    setState(() {
      _isExpanded = !_isExpanded;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('weather_card_expanded', _isExpanded);
    } catch (_) {}
  }

  @override
  void didUpdateWidget(covariant WeatherCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialData != null && widget.initialData != _weather) {
      setState(() {
        _weather = widget.initialData;
      });
    }
  }

  Future<void> _loadWeather({StationInfo? station}) async {
    setState(() {
      _isLoading = true;
    });

    final fresh = await WeatherService.fetchWeather(station: station);
    if (mounted) {
      setState(() {
        _weather = fresh ?? _weather;
        _isLoading = false;
      });
      if (fresh != null && widget.onWeatherUpdated != null) {
        widget.onWeatherUpdated!(fresh);
      }
    }
  }

  Future<void> _autoDetectAndLoad() async {
    setState(() {
      _isLoading = true;
    });

    final detected = await WeatherService.autoDetectLocation();
    if (detected != null && mounted) {
      await _loadWeather(station: detected);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('📍 Location updated: ${detected.name} (${detected.state})'),
            backgroundColor: Colors.blueAccent,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } else {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showStationPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        String query = '';
        bool isDetecting = false;
        bool isSearching = false;
        List<StationInfo> searchResults = [];
        Timer? debounceTimer;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.8,
              minChildSize: 0.45,
              maxChildSize: 0.95,
              expand: false,
              builder: (_, scrollController) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade600,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          const Icon(Icons.location_on_rounded, color: Colors.blueAccent),
                          const SizedBox(width: 8),
                          const Text(
                            'Choose Weather Location',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              debounceTimer?.cancel();
                              Navigator.pop(ctx);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Auto-Detect Current Location Card Button
                      InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: isDetecting
                            ? null
                            : () async {
                                setModalState(() => isDetecting = true);
                                final detected = await WeatherService.autoDetectLocation();
                                setModalState(() => isDetecting = false);
                                if (detected != null && mounted) {
                                  Navigator.pop(ctx);
                                  _loadWeather(station: detected);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('📍 Location updated: ${detected.name} (${detected.state})'),
                                      backgroundColor: Colors.blueAccent,
                                      duration: const Duration(seconds: 3),
                                    ),
                                  );
                                }
                              },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.blueAccent.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.blueAccent.withOpacity(0.35), width: 1.2),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.blueAccent.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: isDetecting
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Icon(Icons.my_location_rounded, color: Colors.blueAccent, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Use My Current Location',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    Text(
                                      isDetecting ? 'Detecting GPS / network location...' : 'Automatically detects your city / town',
                                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.blueAccent),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Global Search Input Field
                      TextField(
                        decoration: InputDecoration(
                          hintText: 'Search any city, town, or village in India/worldwide',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: query.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    setModalState(() {
                                      query = '';
                                      searchResults.clear();
                                      isSearching = false;
                                    });
                                  },
                                )
                              : null,
                          isDense: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onChanged: (val) {
                          setModalState(() {
                            query = val;
                          });
                          debounceTimer?.cancel();
                          if (val.trim().length >= 2) {
                            setModalState(() => isSearching = true);
                            debounceTimer = Timer(const Duration(milliseconds: 350), () async {
                              final results = await WeatherService.searchLocations(val);
                              setModalState(() {
                                searchResults = results;
                                isSearching = false;
                              });
                            });
                          } else {
                            setModalState(() {
                              searchResults.clear();
                              isSearching = false;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 10),

                      // Section Header
                      Row(
                        children: [
                          Text(
                            query.trim().length >= 2
                                ? (isSearching ? '🔍 Searching...' : '🌍 Search Results (${searchResults.length})')
                                : '⭐ Quick Select IMD Centres & RMCs',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Results / Preset List
                      Expanded(
                        child: query.trim().length >= 2
                            ? (isSearching
                                ? const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(24.0),
                                      child: CircularProgressIndicator(),
                                    ),
                                  )
                                : (searchResults.isEmpty
                                    ? Center(
                                        child: Padding(
                                          padding: const EdgeInsets.all(24.0),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.location_off_rounded, size: 40, color: Colors.grey),
                                              const SizedBox(height: 8),
                                              Text(
                                                'No matching locations found for "$query"',
                                                style: const TextStyle(color: Colors.grey, fontSize: 13),
                                              ),
                                              const SizedBox(height: 4),
                                              const Text(
                                                'Try checking the spelling or searching a nearby town/district',
                                                style: TextStyle(color: Colors.grey, fontSize: 11),
                                                textAlign: TextAlign.center,
                                              ),
                                            ],
                                          ),
                                        ),
                                      )
                                    : ListView.builder(
                                        controller: scrollController,
                                        itemCount: searchResults.length,
                                        itemBuilder: (context, index) {
                                          final station = searchResults[index];
                                          final isSelected = _weather?.station.name == station.name &&
                                              _weather?.station.state == station.state;

                                          return ListTile(
                                            leading: CircleAvatar(
                                              backgroundColor: isSelected
                                                  ? Colors.blueAccent.withOpacity(0.2)
                                                  : Colors.grey.withOpacity(0.1),
                                              child: Icon(
                                                Icons.place_rounded,
                                                size: 18,
                                                color: isSelected ? Colors.blueAccent : Colors.grey,
                                              ),
                                            ),
                                            title: Text(
                                              station.name,
                                              style: TextStyle(
                                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                                color: isSelected ? Colors.blueAccent : null,
                                              ),
                                            ),
                                            subtitle: Text(
                                              station.state,
                                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                                            ),
                                            trailing: isSelected
                                                ? const Icon(Icons.check_circle_rounded, color: Colors.blueAccent)
                                                : null,
                                            onTap: () {
                                              debounceTimer?.cancel();
                                              Navigator.pop(ctx);
                                              _loadWeather(station: station);
                                            },
                                          );
                                        },
                                      )))
                            : ListView.builder(
                                controller: scrollController,
                                itemCount: WeatherService.stations.length,
                                itemBuilder: (context, index) {
                                  final station = WeatherService.stations[index];
                                  final isSelected = _weather?.station == station;

                                  return ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: isSelected
                                          ? Colors.blueAccent.withOpacity(0.2)
                                          : Colors.grey.withOpacity(0.1),
                                      child: Icon(
                                        Icons.near_me_rounded,
                                        size: 18,
                                        color: isSelected ? Colors.blueAccent : Colors.grey,
                                      ),
                                    ),
                                    title: Text(
                                      station.name,
                                      style: TextStyle(
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                        color: isSelected ? Colors.blueAccent : null,
                                      ),
                                    ),
                                    subtitle: Text(
                                      station.state,
                                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                                    ),
                                    trailing: isSelected
                                        ? const Icon(Icons.check_circle_rounded, color: Colors.blueAccent)
                                        : null,
                                    onTap: () {
                                      debounceTimer?.cancel();
                                      Navigator.pop(ctx);
                                      _loadWeather(station: station);
                                    },
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _showForecastSheet() {
    if (_weather == null) return;
    final data = _weather!;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade600,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Header with station and current metrics
                  Row(
                    children: [
                      Text(
                        data.current.conditionIcon,
                        style: const TextStyle(fontSize: 40),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data.station.name,
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '${data.current.temperature.round()}°C • ${data.current.conditionText}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Theme.of(context).colorScheme.outline,
                              ),
                            ),
                            Text(
                              data.station.state,
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton.filledTonal(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // 24-Hour Hourly Timeline
                  const Text(
                    '⏰ Next 24 Hours Forecast',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 115,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: data.hourly.length,
                      itemBuilder: (context, index) {
                        final h = data.hourly[index];
                        final isNow = index == 0;
                        final hourStr = isNow ? 'Now' : DateFormat('ha').format(h.time);

                        return Container(
                          width: 68,
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                          decoration: BoxDecoration(
                            color: isNow
                                ? Colors.blueAccent.withOpacity(0.18)
                                : Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isNow ? Colors.blueAccent : Colors.transparent,
                              width: 1.2,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              Text(
                                hourStr,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: isNow ? FontWeight.bold : FontWeight.w500,
                                  color: isNow ? Colors.blueAccent : null,
                                ),
                              ),
                              Text(
                                h.conditionIcon,
                                style: const TextStyle(fontSize: 20),
                              ),
                              Text(
                                '${h.temperature.round()}°',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                              if (h.precipitationProbability > 0)
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.water_drop, size: 9, color: Colors.blueAccent),
                                    Text(
                                      '${h.precipitationProbability}%',
                                      style: const TextStyle(fontSize: 9, color: Colors.blueAccent),
                                    ),
                                  ],
                                )
                              else
                                const SizedBox(height: 10),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 28),

                  // 7-Day Outlook
                  const Text(
                    '📅 7-Day Weather Outlook',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: data.daily.length,
                    separatorBuilder: (_, __) => const Divider(height: 14),
                    itemBuilder: (context, index) {
                      final d = data.daily[index];
                      final isToday = index == 0;
                      final dayStr = isToday ? 'Today' : DateFormat('EEEE').format(d.date);

                      return Row(
                        children: [
                          SizedBox(
                            width: 85,
                            child: Text(
                              dayStr,
                              style: TextStyle(
                                fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                                color: isToday ? Colors.blueAccent : null,
                              ),
                            ),
                          ),
                          Text(d.conditionIcon, style: const TextStyle(fontSize: 18)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              d.conditionText,
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (d.precipitationProbabilityMax > 0) ...[
                            const Icon(Icons.water_drop, size: 11, color: Colors.blueAccent),
                            const SizedBox(width: 2),
                            Text(
                              '${d.precipitationProbabilityMax}%',
                              style: const TextStyle(fontSize: 11, color: Colors.blueAccent),
                            ),
                            const SizedBox(width: 12),
                          ],
                          Text(
                            '${d.maxTemp.round()}°',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '/ ${d.minTemp.round()}°',
                            style: const TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  // Footer note
                  Center(
                    child: Text(
                      '100% Free • Open-Meteo & IMD Numerical Weather Prediction Models',
                      style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.outline),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMetricCard({
    required IconData icon,
    required String label,
    required String value,
    Color? iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: iconColor ?? Colors.white70),
          const SizedBox(width: 5),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 9, color: Colors.white70),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInlineHourlyStrip(List<HourlyForecast> hourly) {
    return SizedBox(
      height: 84,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: hourly.take(16).length,
        itemBuilder: (context, index) {
          final h = hourly[index];
          final isNow = index == 0;
          final hourStr = isNow ? 'Now' : DateFormat('ha').format(h.time);

          return Container(
            width: 56,
            margin: const EdgeInsets.only(right: 6),
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            decoration: BoxDecoration(
              color: isNow
                  ? Colors.white.withOpacity(0.25)
                  : Colors.black.withOpacity(0.16),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isNow ? Colors.white.withOpacity(0.5) : Colors.transparent,
                width: 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Text(
                  hourStr,
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  h.conditionIcon,
                  style: const TextStyle(fontSize: 16),
                ),
                Text(
                  '${h.temperature.round()}°',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                if (h.precipitationProbability > 0)
                  Text(
                    '${h.precipitationProbability}%',
                    style: const TextStyle(fontSize: 8.5, color: Colors.amberAccent, fontWeight: FontWeight.bold),
                  )
                else
                  const SizedBox(height: 9),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_weather == null && _isLoading) {
      return Container(
        height: 54,
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
        ),
        child: const Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
              SizedBox(width: 10),
              Text('Fetching live station weather...', style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
      );
    }

    if (_weather == null) {
      return const SizedBox.shrink();
    }

    final data = _weather!;
    final todayDaily = data.daily.isNotEmpty ? data.daily.first : null;
    final maxTemp = todayDaily?.maxTemp.round() ?? data.current.temperature.round();
    final minTemp = todayDaily?.minTemp.round() ?? data.current.temperature.round();
    final rainProb = todayDaily?.precipitationProbabilityMax ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1E3A8A), // Rich Deep Blue
            Color(0xFF0F766E), // Deep Teal
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3A8A).withOpacity(0.25),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _toggleExpanded,
          child: AnimatedSize(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeInOut,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Top Row: Location Chip (Left) + Quick Actions & Expand Chevron (Right)
                  Row(
                    children: [
                      InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: _showStationPicker,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.location_on, size: 12, color: Colors.amberAccent),
                              const SizedBox(width: 4),
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 160),
                                child: Text(
                                  data.station.name,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const Icon(Icons.arrow_drop_down, size: 16, color: Colors.white70),
                            ],
                          ),
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                        icon: const Icon(Icons.my_location_rounded, size: 15, color: Colors.white70),
                        tooltip: 'Auto-Detect Location',
                        onPressed: _isLoading ? null : _autoDetectAndLoad,
                      ),
                      const SizedBox(width: 2),
                      if (_isLoading)
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                          ),
                        )
                      else
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                          icon: const Icon(Icons.refresh, size: 15, color: Colors.white70),
                          tooltip: 'Refresh Weather',
                          onPressed: () => _loadWeather(station: data.station),
                        ),
                      const SizedBox(width: 4),
                      // Animated Expand / Collapse Chevron
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                        icon: AnimatedRotation(
                          turns: _isExpanded ? 0.5 : 0.0,
                          duration: const Duration(milliseconds: 250),
                          child: const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 22,
                            color: Colors.white70,
                          ),
                        ),
                        tooltip: _isExpanded ? 'Collapse weather panel' : 'Expand weather panel',
                        onPressed: _toggleExpanded,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Main Metric Row: Temp + Icon + Condition/HL (Left) & Compact Stats (Right)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        '${data.current.temperature.round()}°C',
                        style: const TextStyle(
                          fontSize: 27,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(data.current.conditionIcon, style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              data.current.conditionText,
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Feels ${data.current.feelsLike.round()}° • H: $maxTemp° L: $minTemp°',
                              style: const TextStyle(fontSize: 10, color: Colors.white70),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.water_drop_rounded, size: 11, color: Colors.lightBlueAccent),
                                const SizedBox(width: 2),
                                Text('${data.current.humidity}%', style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                                const SizedBox(width: 5),
                                const Icon(Icons.air_rounded, size: 11, color: Colors.tealAccent),
                                const SizedBox(width: 2),
                                Text('${data.current.windSpeed.round()}k/h', style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            if (rainProb > 0) ...[
                              const SizedBox(height: 2),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.umbrella_rounded, size: 10, color: Colors.amberAccent),
                                  const SizedBox(width: 3),
                                  Text('$rainProb% rain', style: const TextStyle(fontSize: 9.5, color: Colors.amberAccent, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),

                  // EXPANDED BODY (Unfolds smoothly on click)
                  if (_isExpanded) ...[
                    const SizedBox(height: 12),
                    Divider(color: Colors.white.withOpacity(0.18), height: 1),
                    const SizedBox(height: 12),

                    // 4 Micro Metric Cards
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricCard(
                            icon: Icons.thermostat_rounded,
                            label: 'Feels Like',
                            value: '${data.current.feelsLike.round()}°C',
                            iconColor: Colors.orangeAccent,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _buildMetricCard(
                            icon: Icons.water_drop_rounded,
                            label: 'Humidity',
                            value: '${data.current.humidity}%',
                            iconColor: Colors.lightBlueAccent,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _buildMetricCard(
                            icon: Icons.air_rounded,
                            label: 'Wind',
                            value: '${data.current.windSpeed.round()}k/h',
                            iconColor: Colors.tealAccent,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _buildMetricCard(
                            icon: Icons.umbrella_rounded,
                            label: 'Rain Chance',
                            value: '$rainProb%',
                            iconColor: Colors.amberAccent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Inline Hourly Forecast Strip
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '⏰ Next 16 Hours Forecast',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Hourly',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: Colors.white.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildInlineHourlyStrip(data.hourly),
                    const SizedBox(height: 10),

                    // Bottom Bar: 7-Day Outlook Button & Tap to collapse hint
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: _showForecastSheet,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                            child: Row(
                              children: [
                                Icon(Icons.calendar_month_rounded, size: 13, color: Colors.amberAccent.shade200),
                                const SizedBox(width: 4),
                                Text(
                                  'View 7-Day Detailed Outlook Sheet ›',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.amberAccent.shade200,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Text(
                          'Tap strip to collapse',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.white.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
