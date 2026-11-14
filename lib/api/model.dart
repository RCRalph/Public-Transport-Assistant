import 'package:public_transport_assistant/api/generated/city_city_generated.dart'
    as city_fb;

class Stop {
  final String id;
  final String name;
  final double latitude;
  final double longitude;

  const Stop({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
  });

  Stop.fromFbs(city_fb.StopInfo stopInfo)
    : id = stopInfo.id ?? "",
      name = stopInfo.name ?? "",
      latitude = stopInfo.location?.latitude ?? 0,
      longitude = stopInfo.location?.longitude ?? 0;
}

class StopGroup {
  final int id;
  final String name;
  final double latitude;
  final double longitude;
  final List<Stop> stops;

  const StopGroup({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.stops,
  });

  StopGroup.fromFbs(city_fb.StopGroup stopGroup, this.id, this.stops)
    : name = stopGroup.name ?? "",
      latitude = stopGroup.center?.latitude ?? 0,
      longitude = stopGroup.center?.longitude ?? 0;
}
