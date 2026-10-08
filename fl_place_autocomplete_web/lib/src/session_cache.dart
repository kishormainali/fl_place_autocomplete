/// Per-session state for the web implementation.
class SessionEntry<TToken, TPrediction> {
  /// Creates an entry.
  SessionEntry(this.token);

  /// The JS `AutocompleteSessionToken`.
  final TToken token;

  /// Original JS prediction objects, keyed by place id. Needed because only
  /// `placePrediction.toPlace()` carries the session token into `fetchFields`.
  final Map<String, TPrediction> predictions = {};
}

/// Maps Dart session ids to web session state.
class SessionCache<TToken, TPrediction> {
  /// Creates a cache; [_tokenFactory] builds a new token.
  SessionCache(this._tokenFactory);

  final TToken Function() _tokenFactory;
  final Map<String, SessionEntry<TToken, TPrediction>> _entries = {};

  /// Gets or creates the entry for [id].
  SessionEntry<TToken, TPrediction> entry(String id) =>
      _entries.putIfAbsent(id, () => SessionEntry(_tokenFactory()));

  /// Remembers [prediction] for [placeId] in session [id].
  void cachePrediction(String id, String placeId, TPrediction prediction) =>
      entry(id).predictions[placeId] = prediction;

  /// Returns the cached prediction, if any.
  TPrediction? prediction(String id, String placeId) =>
      _entries[id]?.predictions[placeId];

  /// Drops session [id].
  void remove(String id) => _entries.remove(id);
}
