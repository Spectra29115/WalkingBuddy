import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;

/// Model for a Trip record from the backend.
class Trip {
  final String id;
  final String userId;
  final String transportMode;
  final String startName;
  final double startLat;
  final double startLng;
  final String endName;
  final double endLat;
  final double endLng;
  final String routeName;
  final DateTime submittedAt;

  const Trip({
    required this.id,
    required this.userId,
    required this.transportMode,
    required this.startName,
    required this.startLat,
    required this.startLng,
    required this.endName,
    required this.endLat,
    required this.endLng,
    required this.routeName,
    required this.submittedAt,
  });

  factory Trip.fromJson(Map<String, dynamic> json) {
    return Trip(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      transportMode: json['transport_mode']?.toString() ?? 'transit',
      startName: json['start_name']?.toString() ?? '',
      startLat: (json['start_lat'] as num?)?.toDouble() ?? 0.0,
      startLng: (json['start_lng'] as num?)?.toDouble() ?? 0.0,
      endName: json['end_name']?.toString() ?? '',
      endLat: (json['end_lat'] as num?)?.toDouble() ?? 0.0,
      endLng: (json['end_lng'] as num?)?.toDouble() ?? 0.0,
      routeName: json['route_name']?.toString() ?? '',
      submittedAt: DateTime.tryParse(json['submitted_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

/// Model for Google Directions API response
class DirectionsResponse {
  final String status;
  final List<Route> routes;

  const DirectionsResponse({
    required this.status,
    required this.routes,
  });

  factory DirectionsResponse.fromJson(Map<String, dynamic> json) {
    final routes = (json['routes'] as List?)
            ?.map((r) => Route.fromJson(r as Map<String, dynamic>))
            .toList() ??
        [];
    return DirectionsResponse(
      status: json['status']?.toString() ?? 'UNKNOWN',
      routes: routes,
    );
  }
}

class Route {
  final List<Leg> legs;
  final List<LatLng> points;

  const Route({required this.legs, required this.points});

  factory Route.fromJson(Map<String, dynamic> json) {
    final legs = (json['legs'] as List?)
            ?.map((l) => Leg.fromJson(l as Map<String, dynamic>))
            .toList() ??
        [];

    final polylinePoints =
        (json['overview_polyline']?['points'] as String?) ?? '';
    final points = _decodePolyline(polylinePoints);

    return Route(legs: legs, points: points);
  }

  static List<LatLng> _decodePolyline(String encoded) {
    final points = <LatLng>[];
    var index = 0;
    var lat = 0;
    var lng = 0;

    while (index < encoded.length) {
      var result = 0;
      var shift = 0;
      int ch;

      do {
        ch = encoded.codeUnitAt(index++) - 63;
        result |= (ch & 0x1f) << shift;
        shift += 5;
      } while (ch >= 0x20);

      var dlat = (result & 1) != 0 ? ~(result >> 1) : result >> 1;
      lat += dlat;

      result = 0;
      shift = 0;

      do {
        ch = encoded.codeUnitAt(index++) - 63;
        result |= (ch & 0x1f) << shift;
        shift += 5;
      } while (ch >= 0x20);

      var dlng = (result & 1) != 0 ? ~(result >> 1) : result >> 1;
      lng += dlng;

      points.add(LatLng(lat / 1e5, lng / 1e5));
    }

    return points;
  }
}

class Leg {
  final Distance distance;
  final DurationInfo duration;
  final List<Step> steps;
  final String startAddress;
  final String endAddress;

  const Leg({
    required this.distance,
    required this.duration,
    required this.steps,
    required this.startAddress,
    required this.endAddress,
  });

  factory Leg.fromJson(Map<String, dynamic> json) {
    final steps = (json['steps'] as List?)
            ?.map((s) => Step.fromJson(s as Map<String, dynamic>))
            .toList() ??
        [];

    return Leg(
      distance: Distance.fromJson(json['distance'] ?? {}),
      duration: DurationInfo.fromJson(json['duration'] ?? {}),
      steps: steps,
      startAddress: json['start_address']?.toString() ?? '',
      endAddress: json['end_address']?.toString() ?? '',
    );
  }
}

class Distance {
  final String text;
  final int valueMeters;

  const Distance({required this.text, required this.valueMeters});

  factory Distance.fromJson(Map<String, dynamic> json) {
    return Distance(
      text: json['text']?.toString() ?? '',
      valueMeters: (json['value'] as num?)?.toInt() ?? 0,
    );
  }

  double get valueKm => valueMeters / 1000.0;
}

class DurationInfo {
  final String text;
  final int valueSeconds;

  const DurationInfo({required this.text, required this.valueSeconds});

  factory DurationInfo.fromJson(Map<String, dynamic> json) {
    return DurationInfo(
      text: json['text']?.toString() ?? '',
      valueSeconds: (json['value'] as num?)?.toInt() ?? 0,
    );
  }
}

class Step {
  final String instruction;
  final Distance distance;
  final DurationInfo duration;
  final String travelMode;
  final int? transitStops;

  const Step({
    required this.instruction,
    required this.distance,
    required this.duration,
    required this.travelMode,
    required this.transitStops,
  });

  factory Step.fromJson(Map<String, dynamic> json) {
    return Step(
      instruction: json['html_instructions']?.toString() ?? '',
      distance: Distance.fromJson(json['distance'] ?? {}),
      duration: DurationInfo.fromJson(json['duration'] ?? {}),
      travelMode: json['travel_mode']?.toString() ?? '',
      transitStops: (json['transit_details']?['num_stops'] as num?)?.toInt(),
    );
  }
}

class LatLng {
  final double lat;
  final double lng;

  const LatLng(this.lat, this.lng);
}

class PlaceSuggestion {
  final String title;
  final String subtitle;
  final String placeId;
  final String formattedAddress;
  final LatLng? location;

  const PlaceSuggestion({
    required this.title,
    required this.subtitle,
    required this.placeId,
    required this.formattedAddress,
    required this.location,
  });

  PlaceSuggestion copyWith({
    String? title,
    String? subtitle,
    String? placeId,
    String? formattedAddress,
    LatLng? location,
  }) {
    return PlaceSuggestion(
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      placeId: placeId ?? this.placeId,
      formattedAddress: formattedAddress ?? this.formattedAddress,
      location: location ?? this.location,
    );
  }
}

/// API Service for trip-related backend calls
class ApiService {
  final String baseUrl;
  final String? authToken;
  final String? googleMapsApiKey;

  ApiService({
    required this.baseUrl,
    this.authToken,
    this.googleMapsApiKey,
  });

  Map<String, String> _getHeaders() {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (authToken != null && authToken!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $authToken';
    }
    return headers;
  }

  Future<String?> checkGoogleMapsAccess() async {
    final key = googleMapsApiKey?.trim() ?? '';
    if (key.isEmpty) {
      return 'Google Maps API key not loaded. Add GOOGLE_MAPS_API_KEY in .env or pass --dart-define.';
    }

    try {
      final response = await http
          .get(
            Uri.parse('https://maps.googleapis.com/maps/api/geocode/json')
                .replace(queryParameters: {
              'address': 'Kolkata',
              'key': key,
            }),
          )
          .timeout(Duration(seconds: 10));

      if (response.statusCode != 200) {
        return 'Google Maps API check failed with HTTP ${response.statusCode}.';
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final status = json['status']?.toString() ?? 'UNKNOWN_ERROR';
      if (status == 'OK') return null;

      final message = json['error_message']?.toString();
      return message == null || message.isEmpty
          ? 'Google Maps API check failed: $status.'
          : 'Google Maps API check failed: $message';
    } catch (_) {
      return 'Google Maps API check failed due to network or key restrictions.';
    }
  }

  /// Fetch a single trip by ID. Returns 404 if not found, 403 if unauthorized.
  Future<Trip?> fetchTrip(String tripId) async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/trips/$tripId'),
            headers: _getHeaders(),
          )
          .timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return Trip.fromJson(json);
      } else if (response.statusCode == 404) {
        return null; // Not found
      } else if (response.statusCode == 403) {
        throw Exception('Unauthorized: trip does not belong to this user');
      }
      throw Exception('Failed to fetch trip: ${response.statusCode}');
    } catch (e) {
      rethrow;
    }
  }

  /// Get directions from Google Directions API with transit mode.
  /// Returns null if the API is unavailable or returns ZERO_RESULTS.
  Future<DirectionsResponse?> fetchDirections(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
    String travelMode,
  ) async {
    if (googleMapsApiKey == null || googleMapsApiKey!.isEmpty) {
      return null;
    }

    try {
      final origin = '$startLat,$startLng';
      final destination = '$endLat,$endLng';
      final normalizedMode = travelMode.toLowerCase();

      final response = await http
          .get(
            Uri.parse('https://maps.googleapis.com/maps/api/directions/json')
                .replace(queryParameters: {
              'origin': origin,
              'destination': destination,
              'mode': normalizedMode,
              'key': googleMapsApiKey,
            }),
          )
          .timeout(Duration(seconds: 15));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final directionsResponse = DirectionsResponse.fromJson(json);

        // Return null if ZERO_RESULTS (no transit data in this area)
        if (directionsResponse.status == 'ZERO_RESULTS') {
          return null;
        }

        if (directionsResponse.status == 'OK' &&
            directionsResponse.routes.isNotEmpty) {
          return directionsResponse;
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Resolve a place name to coordinates using the Google Geocoding API.
  Future<LatLng?> geocodePlace(String address) async {
    if (googleMapsApiKey == null || googleMapsApiKey!.isEmpty) {
      return null;
    }

    final query = address.trim();
    if (query.isEmpty) return null;

    try {
      final response = await http
          .get(
            Uri.parse('https://maps.googleapis.com/maps/api/geocode/json')
                .replace(queryParameters: {
              'address': query,
              'key': googleMapsApiKey,
            }),
          )
          .timeout(Duration(seconds: 12));

      if (response.statusCode != 200) return null;

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (json['status']?.toString() != 'OK') return null;

      final results = json['results'] as List?;
      if (results == null || results.isEmpty) return null;

      final geometry = results.first['geometry'] as Map<String, dynamic>?;
      final location = geometry?['location'] as Map<String, dynamic>?;
      if (location == null) return null;

      return LatLng(
        (location['lat'] as num?)?.toDouble() ?? 0.0,
        (location['lng'] as num?)?.toDouble() ?? 0.0,
      );
    } catch (e) {
      return null;
    }
  }

  /// Search similar places/stations for user selection in dropdowns.
  Future<List<PlaceSuggestion>> searchPlaceSuggestions(String query) async {
    if (googleMapsApiKey == null || googleMapsApiKey!.isEmpty) {
      return const [];
    }

    final trimmed = query.trim();
    if (trimmed.length < 2) return const [];

    try {
      final results = <PlaceSuggestion>[];

      results.addAll(await _autocompletePlaceSuggestions(trimmed));
      if (results.length < 4) {
        results.addAll(await _textSearchPlaceSuggestions(trimmed));
      }

      final deduped = <String, PlaceSuggestion>{};
      for (final suggestion in results) {
        final key = suggestion.placeId.isNotEmpty
            ? suggestion.placeId
            : suggestion.formattedAddress.toLowerCase();
        deduped.putIfAbsent(key, () => suggestion);
      }

      final merged = deduped.values.toList();
      if (merged.isNotEmpty) {
        return merged.take(6).toList();
      }

      return await _fallbackGeocodeSuggestions(trimmed);
    } catch (_) {
      return const [];
    }
  }

  Future<PlaceSuggestion?> resolvePlaceFromQuery(String query) async {
    if (googleMapsApiKey == null || googleMapsApiKey!.isEmpty) {
      return null;
    }

    final trimmed = query.trim();
    if (trimmed.length < 2) return null;

    final place = await _findPlaceFromText(trimmed);
    if (place != null) return place;

    final suggestions = await searchPlaceSuggestions(trimmed);
    if (suggestions.isNotEmpty) {
      final detailed = await fetchPlaceDetails(suggestions.first);
      return detailed ?? suggestions.first;
    }

    final fallback = await _fallbackGeocodeSuggestions(trimmed);
    if (fallback.isNotEmpty) {
      return fallback.first;
    }

    return null;
  }

  Future<PlaceSuggestion?> _findPlaceFromText(String query) async {
    final response = await http
        .get(
          Uri.parse(
                  'https://maps.googleapis.com/maps/api/place/findplacefromtext/json')
              .replace(queryParameters: {
            'input': query,
            'inputtype': 'textquery',
            'fields': 'formatted_address,geometry,name,place_id',
            'locationbias': 'circle:50000@22.5726,88.3639',
            'language': 'en',
            'key': googleMapsApiKey,
          }),
        )
        .timeout(Duration(seconds: 12));

    if (response.statusCode != 200) return null;

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    if (json['status']?.toString() != 'OK') return null;

    final candidates = (json['candidates'] as List?) ?? const [];
    if (candidates.isEmpty) return null;

    final row = candidates.first as Map<String, dynamic>;
    final geometry = row['geometry'] as Map<String, dynamic>?;
    final location = geometry?['location'] as Map<String, dynamic>?;
    final lat = (location?['lat'] as num?)?.toDouble();
    final lng = (location?['lng'] as num?)?.toDouble();

    return PlaceSuggestion(
      title: row['name']?.toString() ?? query,
      subtitle: row['formatted_address']?.toString() ?? query,
      placeId: row['place_id']?.toString() ?? '',
      formattedAddress: row['formatted_address']?.toString() ?? query,
      location: (lat != null && lng != null) ? LatLng(lat, lng) : null,
    );
  }

  Future<List<PlaceSuggestion>> _autocompletePlaceSuggestions(
      String query) async {
    final response = await http
        .get(
          Uri.parse(
                  'https://maps.googleapis.com/maps/api/place/autocomplete/json')
              .replace(queryParameters: {
            'input': query,
            'components': 'country:in',
            'locationbias': 'circle:50000@22.5726,88.3639',
            'key': googleMapsApiKey,
          }),
        )
        .timeout(Duration(seconds: 12));

    if (response.statusCode != 200) return const [];

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final predictions = (json['predictions'] as List?) ?? const [];
    if (json['status']?.toString() != 'OK' || predictions.isEmpty) {
      return const [];
    }

    return predictions.take(6).map((item) {
      final row = item as Map<String, dynamic>;
      final mainText = row['structured_formatting']?['main_text']?.toString() ??
          row['description']?.toString() ??
          query;
      final secondaryText =
          row['structured_formatting']?['secondary_text']?.toString() ??
              row['description']?.toString() ??
              '';

      return PlaceSuggestion(
        title: mainText,
        subtitle: secondaryText,
        placeId: row['place_id']?.toString() ?? '',
        formattedAddress: row['description']?.toString() ?? secondaryText,
        location: null,
      );
    }).toList();
  }

  Future<List<PlaceSuggestion>> _textSearchPlaceSuggestions(
      String query) async {
    final response = await http
        .get(
          Uri.parse(
                  'https://maps.googleapis.com/maps/api/place/textsearch/json')
              .replace(queryParameters: {
            'query': query,
            'region': 'in',
            'location': '22.5726,88.3639',
            'radius': '50000',
            'key': googleMapsApiKey,
          }),
        )
        .timeout(Duration(seconds: 12));

    if (response.statusCode != 200) return const [];

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    if (json['status']?.toString() != 'OK') {
      return const [];
    }

    final results = (json['results'] as List?) ?? const [];
    return results.take(6).map((item) {
      final row = item as Map<String, dynamic>;
      final formattedAddress = row['formatted_address']?.toString() ?? '';
      final name = row['name']?.toString() ?? query;
      final geometry = row['geometry'] as Map<String, dynamic>?;
      final location = geometry?['location'] as Map<String, dynamic>?;
      final lat = (location?['lat'] as num?)?.toDouble();
      final lng = (location?['lng'] as num?)?.toDouble();

      return PlaceSuggestion(
        title: name,
        subtitle: formattedAddress,
        placeId: row['place_id']?.toString() ?? '',
        formattedAddress: formattedAddress,
        location: (lat != null && lng != null) ? LatLng(lat, lng) : null,
      );
    }).toList();
  }

  Future<PlaceSuggestion?> fetchPlaceDetails(PlaceSuggestion suggestion) async {
    if (googleMapsApiKey == null || googleMapsApiKey!.isEmpty) {
      return null;
    }

    final placeId = suggestion.placeId.trim();
    if (placeId.isEmpty) {
      return suggestion;
    }

    try {
      final response = await http
          .get(
            Uri.parse('https://maps.googleapis.com/maps/api/place/details/json')
                .replace(queryParameters: {
              'place_id': placeId,
              'fields': 'formatted_address,geometry,name,place_id',
              'key': googleMapsApiKey,
            }),
          )
          .timeout(Duration(seconds: 12));

      if (response.statusCode != 200) return null;

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (json['status']?.toString() != 'OK') return null;

      final result = json['result'] as Map<String, dynamic>?;
      final geometry = result?['geometry'] as Map<String, dynamic>?;
      final location = geometry?['location'] as Map<String, dynamic>?;
      final lat = (location?['lat'] as num?)?.toDouble();
      final lng = (location?['lng'] as num?)?.toDouble();
      final formattedAddress = result?['formatted_address']?.toString() ??
          suggestion.formattedAddress;
      final name = result?['name']?.toString() ?? suggestion.title;

      return suggestion.copyWith(
        title: name,
        formattedAddress: formattedAddress,
        location: (lat != null && lng != null) ? LatLng(lat, lng) : null,
      );
    } catch (_) {
      return null;
    }
  }

  Future<List<PlaceSuggestion>> _fallbackGeocodeSuggestions(
      String query) async {
    try {
      final response = await http
          .get(
            Uri.parse('https://maps.googleapis.com/maps/api/geocode/json')
                .replace(queryParameters: {
              'address': query,
              'key': googleMapsApiKey,
            }),
          )
          .timeout(Duration(seconds: 12));

      if (response.statusCode != 200) return const [];

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (json['status']?.toString() != 'OK') return const [];

      final results = (json['results'] as List?) ?? const [];
      return results.take(6).map((item) {
        final row = item as Map<String, dynamic>;
        final formattedAddress = row['formatted_address']?.toString() ?? '';
        final parts = formattedAddress.split(',');
        final title = parts.isNotEmpty ? parts.first.trim() : formattedAddress;
        final subtitle = parts.length > 1
            ? parts.sublist(1).join(',').trim()
            : formattedAddress;
        final location = row['geometry']?['location'] as Map<String, dynamic>?;
        final lat = (location?['lat'] as num?)?.toDouble() ?? 0.0;
        final lng = (location?['lng'] as num?)?.toDouble() ?? 0.0;

        return PlaceSuggestion(
          title: title,
          subtitle: subtitle,
          placeId: row['place_id']?.toString() ?? '',
          formattedAddress: formattedAddress,
          location: LatLng(lat, lng),
        );
      }).toList();
    } catch (_) {
      return const [];
    }
  }

  /// Count commuters who traveled the same route on the same date.
  Future<int> fetchCommutorsOnRoute(String routeName, DateTime date) async {
    try {
      final dateStr =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final response = await http
          .get(
            Uri.parse('$baseUrl/routes/$routeName/commuters').replace(
              queryParameters: {'date': dateStr},
            ),
            headers: _getHeaders(),
          )
          .timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return (json['count'] as num?)?.toInt() ?? 0;
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }

  /// Count trips logged by the current user this month.
  Future<int> fetchUserTripsThisMonth() async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/user/trips/monthly'),
            headers: _getHeaders(),
          )
          .timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return (json['count'] as num?)?.toInt() ?? 0;
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }

  /// Calculate distance using Haversine formula
  static double calculateHaversineDistance(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const earthRadiusKm = 6371.0;

    final dLat = _toRadians(lat2 - lat1);
    final dLng = _toRadians(lng2 - lng1);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLng / 2) *
            sin(dLng / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadiusKm * c;
  }

  static double _toRadians(double degrees) => degrees * pi / 180.0;
}
