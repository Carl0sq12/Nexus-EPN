import '../../features/trips/domain/entities/trip.dart';

String normalizeTripSearchText(String value) {
  var text = value.toLowerCase().trim();
  const from = 'áàäâéèëêíìïîóòöôúùüûñç';
  const to = 'aaaaeeeeiiiioooouuuunc';
  for (var i = 0; i < from.length; i++) {
    text = text.replaceAll(from[i], to[i]);
  }
  return text;
}

Set<String> tripSearchTokens(String value) {
  return normalizeTripSearchText(value)
      .split(RegExp(r'[^a-z0-9]+'))
      .where((token) => token.length >= 2)
      .toSet();
}

/// Matches passenger search text against published trip origin/destination.
bool tripMatchesDestinationQuery(Trip trip, String query) {
  final normalizedQuery = normalizeTripSearchText(query);
  if (normalizedQuery.isEmpty) return true;

  final destination = normalizeTripSearchText(trip.destination);
  final origin = normalizeTripSearchText(trip.origin);
  final haystack = '$origin $destination';

  if (destination.contains(normalizedQuery) ||
      origin.contains(normalizedQuery) ||
      haystack.contains(normalizedQuery)) {
    return true;
  }

  final queryTokens = tripSearchTokens(query);
  if (queryTokens.isEmpty) return false;

  final tripTokens = tripSearchTokens('${trip.origin} ${trip.destination}');
  if (queryTokens.any(destination.contains) ||
      queryTokens.any(origin.contains) ||
      queryTokens.any(haystack.contains)) {
    return true;
  }
  if (tripTokens.any(normalizedQuery.contains)) return true;
  return queryTokens.intersection(tripTokens).isNotEmpty;
}

List<Trip> filterTripsByDestinationQuery(List<Trip> trips, String? query) {
  final q = query?.trim();
  if (q == null || q.isEmpty) return trips;
  return trips.where((trip) => tripMatchesDestinationQuery(trip, q)).toList();
}
