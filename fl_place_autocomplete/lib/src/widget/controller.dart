import 'dart:async';

import 'package:fl_place_autocomplete_platform_interface/fl_place_autocomplete_platform_interface.dart';
import 'package:flutter/widgets.dart';

import '../api.dart';

/// Default fields fetched on selection.
const Set<PlaceField> defaultPlaceFields = {
  PlaceField.location,
  PlaceField.displayName,
  PlaceField.formattedAddress,
};

/// Lifecycle state of the suggestions list.
enum PlaceAutocompleteStatus {
  /// Nothing to show.
  idle,

  /// A request is in flight.
  loading,

  /// Predictions available.
  results,

  /// Request completed with no predictions.
  empty,

  /// The last operation failed.
  error,
}

/// Behaviour configuration attached by [PlaceAutocompleteField] (or manually).
class PlaceAutocompleteConfig {
  /// Creates a configuration.
  const PlaceAutocompleteConfig({
    required this.api,
    required this.options,
    required this.fields,
    this.debounce = const Duration(milliseconds: 300),
    this.minChars = 2,
    this.fetchDetailsOnSelect = true,
    this.onPredictionSelected,
    this.onPlaceSelected,
    this.onError,
  });

  /// API used for requests.
  final FlPlaceAutocomplete api;

  /// Prediction options.
  final PredictionOptions options;

  /// Fields requested on selection.
  final Set<PlaceField> fields;

  /// Debounce between keystrokes and requests.
  final Duration debounce;

  /// Minimum characters before querying.
  final int minChars;

  /// Whether selecting a prediction fetches full details.
  final bool fetchDetailsOnSelect;

  /// Called when a prediction is chosen.
  ///
  /// With [fetchDetailsOnSelect] set to false, the app owns the rest of the
  /// session: call [PlaceAutocompleteController.takeSession] synchronously
  /// inside this callback (before the field can lose focus, which would
  /// dispose the session) and pass it to [FlPlaceAutocomplete.fetchPlace].
  final void Function(PlacePrediction)? onPredictionSelected;

  /// Called with full details after a successful fetch.
  final void Function(Place)? onPlaceSelected;

  /// Called when a request fails.
  final void Function(PlaceAutocompleteException)? onError;
}

/// Holds the text, suggestions and session state of an autocomplete field.
class PlaceAutocompleteController extends ChangeNotifier {
  /// Creates a controller; [text] is set without any API call.
  PlaceAutocompleteController({String text = ''})
    : textController = TextEditingController(text: text),
      _lastText = text {
    textController.addListener(_onTextChanged);
  }

  /// The underlying text controller.
  final TextEditingController textController;

  PlaceAutocompleteConfig? _config;
  PlaceSession? _session;
  Timer? _debounce;
  int _generation = 0;
  int _selectionId = 0;
  bool _suppress = false;
  bool _disposed = false;
  bool _selecting = false;
  bool _overlayOpen = false;
  String _lastText;
  List<PlacePrediction> _predictions = const [];
  PlaceAutocompleteStatus _status = PlaceAutocompleteStatus.idle;
  PlaceAutocompleteException? _error;
  Place? _selectedPlace;
  int _highlighted = -1;
  VoidCallback? _retry;

  /// Current list state.
  PlaceAutocompleteStatus get status => _status;

  /// Current predictions.
  List<PlacePrediction> get predictions => _predictions;

  /// Last error, if [status] is error.
  PlaceAutocompleteException? get error => _error;

  /// Place chosen by the user (or set via [setPlace]).
  Place? get selectedPlace => _selectedPlace;

  /// Keyboard-highlighted row, or -1.
  int get highlightedIndex => _highlighted;

  /// Whether the suggestions overlay should be shown.
  bool get overlayOpen => _overlayOpen;

  /// Current live session, if any.
  PlaceSession? get session => _session;

  /// Applies configuration. Cheap; call on every widget update.
  void attach(PlaceAutocompleteConfig config) => _config = config;

  void _onTextChanged() {
    final text = textController.text;
    if (text == _lastText) return; // caret/selection/composing change only
    _lastText = text;
    if (_suppress) return;
    _onUserInput(text);
  }

  void _onUserInput(String text) {
    final config = _config;
    if (config == null) return;
    _selectedPlace = null;
    _selectionId++; // user edit discards any in-flight selection result
    _selecting = false;
    _debounce?.cancel();
    final generation = ++_generation;
    _highlighted = -1;
    // A new edit supersedes any failure: drop the error and its stale retry.
    _error = null;
    _retry = null;
    if (text.trim().length < config.minChars) {
      _overlayOpen = false;
      _setState(PlaceAutocompleteStatus.idle, predictions: const []);
      return;
    }
    if (_status == PlaceAutocompleteStatus.error) {
      _status = PlaceAutocompleteStatus.loading;
    }
    _overlayOpen = true;
    _debounce = Timer(config.debounce, () => _runQuery(text, generation));
    notifyListeners();
  }

  Future<void> _runQuery(String text, int generation) async {
    final config = _config;
    if (config == null || _disposed || generation != _generation) return;
    var session = _session;
    if (session == null || session.isEnded) {
      session = _session = config.api.newSession();
    }
    _error = null;
    _setState(PlaceAutocompleteStatus.loading);
    try {
      final result = await config.api.findPredictions(
        text,
        session: session,
        options: config.options,
      );
      if (_disposed || generation != _generation) return;
      _highlighted = -1;
      _setState(
        result.isEmpty
            ? PlaceAutocompleteStatus.empty
            : PlaceAutocompleteStatus.results,
        predictions: result,
      );
    } catch (e) {
      if (_disposed || generation != _generation) return;
      _retry = () => _runQuery(text, generation);
      _fail(e);
    }
  }

  /// Selects [prediction]: closes the list, sets the text, and (by default)
  /// fetches full details with the current session.
  Future<void> select(PlacePrediction prediction) async {
    final config = _config;
    if (config == null || _disposed) return;
    _debounce?.cancel();
    _generation++;
    final selectionId = ++_selectionId;
    _selecting = true;
    _setTextProgrammatically(prediction.fullText);
    _overlayOpen = false;
    _highlighted = -1;
    _selectedPlace = null;
    _setState(PlaceAutocompleteStatus.idle, predictions: const []);
    config.onPredictionSelected?.call(prediction);
    if (!config.fetchDetailsOnSelect) {
      _selecting = false;
      return;
    }
    final session = _session;
    try {
      final place = await config.api.fetchPlace(
        prediction.placeId,
        session: session,
        fields: config.fields,
        languageCode: config.options.languageCode,
        regionCode: config.options.regionCode,
      );
      if (session != null && session.isEnded && identical(_session, session)) {
        _session = null;
      }
      if (_disposed || selectionId != _selectionId) return;
      _selectedPlace = place;
      notifyListeners();
      config.onPlaceSelected?.call(place);
    } catch (e) {
      if (_disposed || selectionId != _selectionId) return;
      _retry = () => select(prediction);
      _overlayOpen = true;
      _fail(e);
    } finally {
      if (selectionId == _selectionId) _selecting = false;
    }
  }

  /// Retries the last failed operation.
  void retry() {
    final r = _retry;
    _retry = null;
    r?.call();
  }

  /// Moves the keyboard highlight by [delta], wrapping around.
  void moveHighlight(int delta) {
    if (_predictions.isEmpty) return;
    final n = _predictions.length;
    _highlighted = _highlighted == -1
        ? (delta > 0 ? 0 : n - 1)
        : (_highlighted + delta) % n;
    notifyListeners();
  }

  /// Selects the highlighted row, if any.
  Future<void> selectHighlighted() async {
    if (_highlighted >= 0 && _highlighted < _predictions.length) {
      await select(_predictions[_highlighted]);
    }
  }

  /// Closes the suggestion list without touching the text.
  void dismiss() {
    if (!_overlayOpen) return;
    _overlayOpen = false;
    notifyListeners();
  }

  /// Sets the text programmatically. Never calls the API.
  void setText(String text) {
    _reset();
    _setTextProgrammatically(text);
    _selectedPlace = null;
    notifyListeners();
  }

  /// Sets [place] as selected without firing callbacks or calling the API.
  void setPlace(Place place, {String? text}) {
    _reset();
    _setTextProgrammatically(
      text ?? place.formattedAddress ?? place.displayName ?? '',
    );
    _selectedPlace = place;
    notifyListeners();
  }

  /// Clears text, selection, results and the session.
  void clear() {
    _reset();
    _setTextProgrammatically('');
    _selectedPlace = null;
    notifyListeners();
  }

  /// Called when the field loses focus.
  void onFocusLost() {
    if (_selecting) return;
    _debounce?.cancel();
    _generation++;
    _overlayOpen = false;
    _error = null;
    _retry = null;
    _cancelSession();
    _setState(PlaceAutocompleteStatus.idle, predictions: const []);
  }

  /// Detaches and returns the live session (for `fetchDetailsOnSelect: false`).
  ///
  /// Call it synchronously inside
  /// [PlaceAutocompleteConfig.onPredictionSelected]: once the field loses
  /// focus or is cleared, the controller disposes any session it still holds.
  /// The caller then owns the session and must end it, either via
  /// [FlPlaceAutocomplete.fetchPlace] or [FlPlaceAutocomplete.cancelSession].
  PlaceSession? takeSession() {
    final s = _session;
    _session = null;
    return s;
  }

  void _reset() {
    _debounce?.cancel();
    _generation++;
    _selectionId++;
    _selecting = false;
    _overlayOpen = false;
    _highlighted = -1;
    _predictions = const [];
    _status = PlaceAutocompleteStatus.idle;
    _error = null;
    _retry = null;
    _cancelSession();
  }

  void _cancelSession() {
    final s = _session;
    _session = null;
    final config = _config;
    if (s != null && !s.isEnded && config != null) {
      unawaited(config.api.cancelSession(s).catchError((Object _) {}));
    }
  }

  void _setTextProgrammatically(String text) {
    _suppress = true;
    textController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    _lastText = text;
    _suppress = false;
  }

  void _setState(
    PlaceAutocompleteStatus status, {
    List<PlacePrediction>? predictions,
  }) {
    _status = status;
    if (predictions != null) _predictions = predictions;
    notifyListeners();
  }

  void _fail(Object e) {
    final ex = e is PlaceAutocompleteException
        ? e
        : PlaceAutocompleteException(
            code: PlaceAutocompleteErrorCode.unknown,
            message: '$e',
          );
    _error = ex;
    _setState(PlaceAutocompleteStatus.error);
    _config?.onError?.call(ex);
  }

  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _debounce?.cancel();
    _cancelSession();
    textController.dispose();
    super.dispose();
  }
}
