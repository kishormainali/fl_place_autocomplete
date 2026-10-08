import 'dart:async';

import 'package:fl_place_autocomplete/fl_place_autocomplete.dart';
import 'package:flutter/material.dart';

// API keys are configured natively per platform (see the example README):
//   Android: android/local.properties      -> GOOGLE_API_KEY
//   iOS:     ios/Flutter/Keys.xcconfig     -> GOOGLE_API_KEY
//   Web:     web/keys.js                   -> window.GOOGLE_MAPS_API_KEY
// Without a key the app still runs; requests fail with `invalidApiKey`, which
// every tab shows in its UI.

void main() => runApp(const MyApp());

/// The example app.
class MyApp extends StatelessWidget {
  /// Creates the app.
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'fl_place_autocomplete',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

/// Hosts the three demos.
class HomePage extends StatelessWidget {
  /// Creates the page.
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('fl_place_autocomplete'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.code), text: 'Headless'),
              Tab(icon: Icon(Icons.search), text: 'Default field'),
              Tab(icon: Icon(Icons.brush), text: 'Custom field'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [HeadlessDemo(), DefaultFieldDemo(), CustomFieldDemo()],
        ),
      ),
    );
  }
}

String describeError(Object error) => switch (error) {
  PlaceAutocompleteException(:final code, :final message) =>
    '${code.name}: ${message ?? 'no details'}',
  _ => error.toString(),
};

// ---------------------------------------------------------------------------
// 1. Headless: drive the API directly.
// ---------------------------------------------------------------------------

/// Uses [FlPlaceAutocomplete] without any widget from the package.
class HeadlessDemo extends StatefulWidget {
  /// Creates the demo.
  const HeadlessDemo({super.key});

  @override
  State<HeadlessDemo> createState() => _HeadlessDemoState();
}

class _HeadlessDemoState extends State<HeadlessDemo> {
  final _api = FlPlaceAutocomplete.instance;
  final _text = TextEditingController();
  PlaceSession? _session;
  Timer? _debounce;
  int _generation = 0;
  bool _loading = false;
  List<PlacePrediction> _predictions = const [];
  Place? _place;
  String? _error;

  PlaceSession get _activeSession {
    final s = _session;
    if (s != null && !s.isEnded) return s;
    return _session = _api.newSession();
  }

  void _onChanged(String input) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => _search(input));
  }

  Future<void> _search(String input) async {
    final generation = ++_generation;
    if (input.trim().length < 2) {
      setState(() {
        _predictions = const [];
        _loading = false;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await _api.findPredictions(input, session: _activeSession);
      if (!mounted || generation != _generation) return;
      setState(() => _predictions = results);
    } catch (e) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _predictions = const [];
        _error = describeError(e);
      });
    } finally {
      if (mounted && generation == _generation) setState(() => _loading = false);
    }
  }

  Future<void> _select(PlacePrediction prediction) async {
    _generation++;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final place = await _api.fetchPlace(
        prediction.placeId,
        session: _activeSession,
        fields: const {
          PlaceField.displayName,
          PlaceField.formattedAddress,
          PlaceField.location,
          PlaceField.types,
        },
      );
      if (!mounted) return;
      setState(() {
        _place = place;
        _predictions = const [];
        _text.text = prediction.fullText;
      });
    } catch (e) {
      if (mounted) setState(() => _error = describeError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    final s = _session;
    if (s != null) unawaited(_api.cancelSession(s).catchError((Object _) {}));
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final location = _place?.location;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const ValueKey('headless-input'),
            controller: _text,
            onChanged: _onChanged,
            decoration: const InputDecoration(
              labelText: 'Search (headless API)',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
          ),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                _error!,
                key: const ValueKey('headless-error'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (location != null)
            ListTile(
              leading: const Icon(Icons.place),
              title: Text(_place?.displayName ?? ''),
              subtitle: Text('${location.latitude}, ${location.longitude}'),
            ),
          Expanded(
            child: ListView.builder(
              itemCount: _predictions.length,
              itemBuilder: (context, i) {
                final p = _predictions[i];
                return ListTile(
                  title: Text(p.primaryText),
                  subtitle: p.secondaryText.isEmpty ? null : Text(p.secondaryText),
                  onTap: () => _select(p),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 2. Default field.
// ---------------------------------------------------------------------------

/// [PlaceAutocompleteField] with its default UI.
class DefaultFieldDemo extends StatefulWidget {
  /// Creates the demo.
  const DefaultFieldDemo({super.key});

  @override
  State<DefaultFieldDemo> createState() => _DefaultFieldDemoState();
}

class _DefaultFieldDemoState extends State<DefaultFieldDemo>
    with AutomaticKeepAliveClientMixin {
  Place? _place;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        PlaceAutocompleteField(
          key: const ValueKey('default-field'),
          // Shown as text only; never sent to the API.
          initialValue: 'Eiffel Tower, Paris',
          decoration: const InputDecoration(
            labelText: 'Place',
            border: OutlineInputBorder(),
          ),
          onPlaceSelected: (p) => setState(() {
            _place = p;
            _error = null;
          }),
          onError: (e) => setState(() => _error = describeError(e)),
        ),
        const SizedBox(height: 16),
        if (_error != null)
          Text(
            _error!,
            key: const ValueKey('default-error'),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        if (_place != null) PlaceDetailsCard(place: _place!),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 3. Custom field: every builder replaced.
// ---------------------------------------------------------------------------

/// [PlaceAutocompleteField] with custom builders and all fields.
class CustomFieldDemo extends StatefulWidget {
  /// Creates the demo.
  const CustomFieldDemo({super.key});

  @override
  State<CustomFieldDemo> createState() => _CustomFieldDemoState();
}

class _CustomFieldDemoState extends State<CustomFieldDemo>
    with AutomaticKeepAliveClientMixin {
  final _controller = PlaceAutocompleteController();
  // Times Square: used as the origin so predictions carry `distanceMeters`.
  final _options = PredictionOptions(
    includedRegionCodes: const ['us'],
    origin: const LatLng(40.7580, -73.9855),
  );
  Place? _place;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        PlaceAutocompleteField(
          key: const ValueKey('custom-field'),
          controller: _controller,
          fields: PlaceField.values.toSet(),
          options: _options,
          onPlaceSelected: (p) => setState(() => _place = p),
          separatorBuilder: (_, _) => const Divider(height: 1),
          fieldBuilder: (context, controller, focusNode, onSubmit) => TextField(
            controller: controller.textController,
            focusNode: focusNode,
            onSubmitted: (_) => onSubmit(),
            decoration: InputDecoration(
              hintText: 'Search US places',
              prefixIcon: const Icon(Icons.travel_explore),
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(32),
                borderSide: BorderSide.none,
              ),
              suffixIcon: ListenableBuilder(
                listenable: controller.textController,
                builder: (context, _) => controller.textController.text.isEmpty
                    ? const SizedBox.shrink()
                    : IconButton(
                        tooltip: 'Clear',
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          controller.clear();
                          setState(() => _place = null);
                        },
                      ),
              ),
            ),
          ),
          predictionBuilder: (context, prediction, highlighted, onTap) =>
              _CustomPredictionTile(
                prediction: prediction,
                highlighted: highlighted,
                onTap: onTap,
              ),
          emptyBuilder: (context, query) => ListTile(
            leading: const Icon(Icons.search_off),
            title: Text('Nothing in the US matches "$query"'),
          ),
          errorBuilder: (context, error, retry) => ListTile(
            leading: Icon(Icons.error_outline, color: scheme.error),
            title: Text(error.code.name),
            subtitle: Text(error.message ?? 'Request failed'),
            trailing: IconButton(
              tooltip: 'Retry',
              icon: const Icon(Icons.refresh),
              onPressed: retry,
            ),
          ),
          footerBuilder: (context) => Container(
            color: scheme.surfaceContainerHighest,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                Icon(Icons.map, size: 14, color: scheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Text(
                  'Powered by Google',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (_place != null) PlaceDetailsCard(place: _place!),
      ],
    );
  }
}

class _CustomPredictionTile extends StatelessWidget {
  const _CustomPredictionTile({
    required this.prediction,
    required this.highlighted,
    required this.onTap,
  });

  final PlacePrediction prediction;
  final bool highlighted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = prediction.primaryText;
    final spans = <TextSpan>[];
    var cursor = 0;
    for (final r in prediction.matchesWithin(text.length)) {
      if (r.start < cursor) continue;
      if (r.start > cursor) spans.add(TextSpan(text: text.substring(cursor, r.start)));
      spans.add(
        TextSpan(
          text: text.substring(r.start, r.end),
          style: TextStyle(color: scheme.tertiary, fontWeight: FontWeight.w700),
        ),
      );
      cursor = r.end;
    }
    if (cursor < text.length) spans.add(TextSpan(text: text.substring(cursor)));
    final distance = prediction.distanceMeters;
    return ListTile(
      selected: highlighted,
      selectedTileColor: scheme.primaryContainer,
      leading: const Icon(Icons.location_on_outlined),
      title: Text.rich(TextSpan(children: spans)),
      subtitle: prediction.secondaryText.isEmpty ? null : Text(prediction.secondaryText),
      trailing: distance == null
          ? null
          : Text(
              distance >= 1000
                  ? '${(distance / 1000).toStringAsFixed(1)} km'
                  : '$distance m',
              style: Theme.of(context).textTheme.labelMedium,
            ),
      onTap: onTap,
    );
  }
}

// ---------------------------------------------------------------------------
// Shared details view.
// ---------------------------------------------------------------------------

/// Shows the main fields of a [Place].
class PlaceDetailsCard extends StatelessWidget {
  /// Creates the card.
  const PlaceDetailsCard({super.key, required this.place});

  /// The place to show.
  final Place place;

  @override
  Widget build(BuildContext context) {
    final location = place.location;
    final types = place.types;
    return Card(
      key: const ValueKey('place-details'),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.badge_outlined),
            title: Text(place.displayName ?? '—'),
            subtitle: const Text('displayName'),
          ),
          ListTile(
            leading: const Icon(Icons.home_outlined),
            title: Text(place.formattedAddress ?? '—'),
            subtitle: const Text('formattedAddress'),
          ),
          ListTile(
            leading: const Icon(Icons.my_location),
            title: location == null
                ? const Text('—')
                : Text(
                    '${location.latitude}, ${location.longitude}',
                    key: const ValueKey('place-location'),
                  ),
            subtitle: const Text('lat, lng'),
          ),
          ListTile(
            leading: const Icon(Icons.category_outlined),
            title: Text(types == null || types.isEmpty ? '—' : types.join(', ')),
            subtitle: const Text('types'),
          ),
        ],
      ),
    );
  }
}
