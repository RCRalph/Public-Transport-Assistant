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
}
