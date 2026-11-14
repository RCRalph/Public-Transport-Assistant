import 'dart:collection';

import 'package:flutter/services.dart';
import 'package:public_transport_assistant/api/generated/city_city_generated.dart'
    as city_fb;
import 'package:public_transport_assistant/api/model.dart';

class CityData {
  // ignore: unused_field
  final city_fb.City _city;

  late final UnmodifiableMapView<int, StopGroup> stopGroups;
  late final UnmodifiableMapView<String, Stop> stops;

  CityData(city_fb.City city) : _city = city {
    final groups = _getStopsAndGroups(city);

    stopGroups = UnmodifiableMapView(groups);

    stops = UnmodifiableMapView(
      groups.values
          .expand((group) => group.stops)
          .fold<Map<String, Stop>>({}, (map, stop) => map..[stop.id] = stop),
    );
  }

  static Future<CityData> fromFile(String path) async {
    final data = await rootBundle.load(path);

    final bytes = Uint8List.fromList(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );

    return CityData(city_fb.City(bytes));
  }

  static Map<int, StopGroup> _getStopsAndGroups(city_fb.City city) {
    final stopGroups = city.stopGroups;
    if (stopGroups == null) {
      throw FormatException("Invalid stop groups");
    }

    final result = <int, StopGroup>{};

    for (var i = 0; i < stopGroups.length; i++) {
      final stops = stopGroups[i].stops;

      if (stops == null) {
        throw FormatException("Invalid stops for group ${stopGroups[i].name}");
      }

      final stopGroup = StopGroup.fromFbs(
        stopGroups[i],
        i + 1,
        stops.map(Stop.fromFbs).toList(),
      );

      result[stopGroup.id] = stopGroup;
    }

    return result;
  }
}
