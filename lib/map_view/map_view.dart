import 'package:flutter/material.dart';
import 'package:public_transport_assistant/api/city_data.dart';
import 'package:public_transport_assistant/map_view/map_widget.dart';

class MapView extends StatefulWidget {
  const MapView({super.key});

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  static const String _cityFilePath = 'city.bin';
  static const List<String> _stops = [
    'Central Station',
    'City Hall',
    'University',
    'North Park',
    'Harbor Terminal',
    'Airport',
  ];

  late Future<CityData> _cityFuture;
  String? _originStop;
  String? _destinationStop;

  @override
  void initState() {
    super.initState();
    _cityFuture = CityData.fromFile(_cityFilePath);
  }

  void _retryLoad() {
    setState(() {
      _cityFuture = CityData.fromFile(_cityFilePath);
    });
  }

  void _swapStops() {
    setState(() {
      final temp = _originStop;
      _originStop = _destinationStop;
      _destinationStop = temp;
    });
    _notifyRouteChange();
  }

  void _notifyRouteChange() {
    debugPrint('Selected route: $_originStop -> $_destinationStop');
  }

  Future<void> _pickStop({
    required String title,
    required String? currentValue,
    required ValueChanged<String?> onSelected,
  }) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _StopSearchSheet(
        title: title,
        stops: _stops,
        selectedStop: currentValue,
      ),
    );

    if (result != null) {
      onSelected(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<CityData>(
        future: _cityFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 40),
                  const SizedBox(height: 12),
                  const Text('Failed to load city data'),
                  const SizedBox(height: 8),
                  Text('${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _retryLoad,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: Text('No city data available'));
          }

          return SafeArea(
            child: Stack(
              children: [
                Positioned.fill(child: MapWidget(cityData: snapshot.data!)),
                Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                    child: _RouteSelectorCard(
                      origin: _originStop,
                      destination: _destinationStop,
                      onOriginTap: () => _pickStop(
                        title: 'Select origin stop',
                        currentValue: _originStop,
                        onSelected: (value) {
                          setState(() => _originStop = value);
                          _notifyRouteChange();
                        },
                      ),
                      onDestinationTap: () => _pickStop(
                        title: 'Select destination stop',
                        currentValue: _destinationStop,
                        onSelected: (value) {
                          setState(() => _destinationStop = value);
                          _notifyRouteChange();
                        },
                      ),
                      onClearOrigin: _originStop != null
                          ? () {
                              setState(() => _originStop = null);
                              _notifyRouteChange();
                            }
                          : null,
                      onClearDestination: _destinationStop != null
                          ? () {
                              setState(() => _destinationStop = null);
                              _notifyRouteChange();
                            }
                          : null,
                      onSwap: (_originStop != null || _destinationStop != null)
                          ? _swapStops
                          : null,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _RouteSelectorCard extends StatelessWidget {
  const _RouteSelectorCard({
    required this.origin,
    required this.destination,
    required this.onOriginTap,
    required this.onDestinationTap,
    required this.onClearOrigin,
    required this.onClearDestination,
    required this.onSwap,
  });

  final String? origin;
  final String? destination;
  final VoidCallback onOriginTap;
  final VoidCallback onDestinationTap;
  final VoidCallback? onClearOrigin;
  final VoidCallback? onClearDestination;
  final VoidCallback? onSwap;

  @override
  Widget build(BuildContext context) {
    final sameStopSelected =
        origin != null && destination != null && origin == destination;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      _StopPickerField(
                        hint: 'Select origin stop',
                        icon: Icons.trip_origin,
                        value: origin,
                        onTap: onOriginTap,
                        onClear: onClearOrigin,
                      ),
                      const SizedBox(height: 8),
                      _StopPickerField(
                        hint: 'Select destination stop',
                        icon: Icons.location_on,
                        value: destination,
                        onTap: onDestinationTap,
                        onClear: onClearDestination,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Swap stops',
                  onPressed: onSwap,
                  icon: const Icon(Icons.swap_vert),
                ),
              ],
            ),
            if (sameStopSelected) ...[
              const SizedBox(height: 6),
              Text(
                'Origin and destination stops are the same.',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StopPickerField extends StatelessWidget {
  const _StopPickerField({
    required this.hint,
    required this.icon,
    required this.value,
    required this.onTap,
    required this.onClear,
  });

  final String hint;
  final IconData icon;
  final String? value;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        isEmpty: value == null,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, size: 20),
          suffixIcon: onClear != null
              ? IconButton(
                  tooltip: 'Clear',
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: onClear,
                )
              : const Icon(Icons.search, size: 20),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(
          value ?? hint,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: value != null
              ? theme.textTheme.bodyMedium
              : theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
        ),
      ),
    );
  }
}

class _StopSearchSheet extends StatefulWidget {
  const _StopSearchSheet({
    required this.title,
    required this.stops,
    required this.selectedStop,
  });

  final String title;
  final List<String> stops;
  final String? selectedStop;

  @override
  State<_StopSearchSheet> createState() => _StopSearchSheetState();
}

class _StopSearchSheetState extends State<_StopSearchSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final normalizedQuery = _query.trim().toLowerCase();
    final filteredStops = normalizedQuery.isEmpty
        ? widget.stops
        : widget.stops
              .where((stop) => stop.toLowerCase().contains(normalizedQuery))
              .toList();

    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.65,
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Type stop name...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: filteredStops.isEmpty
                  ? const Center(child: Text('No matching stops found'))
                  : ListView.separated(
                      itemCount: filteredStops.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final stop = filteredStops[index];
                        final isSelected = stop == widget.selectedStop;
                        return ListTile(
                          leading: const Icon(Icons.directions_bus_outlined),
                          title: Text(stop),
                          trailing: isSelected
                              ? Icon(
                                  Icons.check,
                                  color: Theme.of(context).colorScheme.primary,
                                )
                              : null,
                          onTap: () => Navigator.of(context).pop(stop),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
