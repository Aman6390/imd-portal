import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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

  @override
  void initState() {
    super.initState();
    _weather = widget.initialData;
    if (_weather == null) {
      _loadWeather();
    }
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

  void _showStationPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        String query = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filteredStations = WeatherService.stations.where((s) {
              final q = query.toLowerCase().trim();
              return s.name.toLowerCase().contains(q) || s.state.toLowerCase().contains(q);
            }).toList();

            return DraggableScrollableSheet(
              initialChildSize: 0.7,
              minChildSize: 0.4,
              maxChildSize: 0.9,
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
                            'Select IMD Station / Centre',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        decoration: InputDecoration(
                          hintText: 'Search RMC, MC, or State (e.g. Pune, Delhi)',
                          prefixIcon: const Icon(Icons.search),
                          isDense: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onChanged: (val) {
                          setModalState(() {
                            query = val;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: ListView.builder(
                          controller: scrollController,
                          itemCount: filteredStations.length,
                          itemBuilder: (context, index) {
                            final station = filteredStations[index];
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
                      '100% Free • Open-Meteo & IMD High-Resolution Global Forecast System',
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

  Widget _buildMetricPill({
    required IconData icon,
    required String label,
    required String value,
    Color? iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: iconColor ?? Colors.white70),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 10, color: Colors.white70),
              ),
              Text(
                value,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_weather == null && _isLoading) {
      return Container(
        height: 140,
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
        ),
        child: const Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
              SizedBox(width: 12),
              Text('Fetching live station weather...'),
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
      margin: const EdgeInsets.only(bottom: 22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
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
            color: const Color(0xFF1E3A8A).withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: _showForecastSheet,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top bar: Station Selector Chip & Refresh Icon
                Row(
                  children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: _showStationPicker,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.location_on, size: 14, color: Colors.amberAccent),
                            const SizedBox(width: 4),
                            Text(
                              data.station.name,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const Icon(Icons.arrow_drop_down, size: 18, color: Colors.white70),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (_isLoading)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                        ),
                      )
                    else
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(Icons.refresh, size: 18, color: Colors.white70),
                        tooltip: 'Refresh Weather',
                        onPressed: () => _loadWeather(station: data.station),
                      ),
                  ],
                ),
                const SizedBox(height: 14),

                // Main Metric Row: Big Temp + Condition Emoji/Text + High/Low
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      '${data.current.temperature.round()}°C',
                      style: const TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(data.current.conditionIcon, style: const TextStyle(fontSize: 22)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  data.current.conditionText,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'H: $maxTemp°  •  L: $minTemp°',
                            style: const TextStyle(fontSize: 12, color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Micro metrics row (4 cards)
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricPill(
                        icon: Icons.thermostat_rounded,
                        label: 'Feels Like',
                        value: '${data.current.feelsLike.round()}°',
                        iconColor: Colors.orangeAccent,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildMetricPill(
                        icon: Icons.water_drop_rounded,
                        label: 'Humidity',
                        value: '${data.current.humidity}%',
                        iconColor: Colors.lightBlueAccent,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildMetricPill(
                        icon: Icons.air_rounded,
                        label: 'Wind',
                        value: '${data.current.windSpeed.round()} km/h',
                        iconColor: Colors.tealAccent,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildMetricPill(
                        icon: Icons.umbrella_rounded,
                        label: 'Rain Chance',
                        value: '$rainProb%',
                        iconColor: Colors.amberAccent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Bottom CTA
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Tap to view 24h & 7-day outlook',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 12,
                      color: Colors.white.withOpacity(0.7),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
