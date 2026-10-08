import 'package:fl_place_autocomplete_platform_interface/fl_place_autocomplete_platform_interface.dart';
import 'package:flutter/material.dart';

/// Builds a suggestion row.
typedef PlacePredictionBuilder = Widget Function(BuildContext context, PlacePrediction prediction, bool highlighted, VoidCallback onTap);

/// Builds the "no results" state.
typedef PlaceEmptyBuilder = Widget Function(BuildContext context, String query);

/// Builds the error state.
typedef PlaceErrorBuilder = Widget Function(BuildContext context, PlaceAutocompleteException error, VoidCallback retry);

/// Default suggestion row: primary text with highlighted matches, secondary text below.
class DefaultPredictionTile extends StatelessWidget {
  /// Creates a tile.
  const DefaultPredictionTile({super.key, required this.prediction, required this.highlighted, required this.onTap});

  /// The prediction to show.
  final PlacePrediction prediction;
  /// Whether the row is keyboard-highlighted.
  final bool highlighted;
  /// Tap handler.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = prediction.primaryText;
    final spans = <TextSpan>[];
    var cursor = 0;
    for (final r in prediction.matchesWithin(primary.length)) {
      if (r.start < cursor) continue;
      if (r.start > cursor) spans.add(TextSpan(text: primary.substring(cursor, r.start)));
      spans.add(TextSpan(text: primary.substring(r.start, r.end), style: const TextStyle(fontWeight: FontWeight.bold)));
      cursor = r.end;
    }
    if (cursor < primary.length) spans.add(TextSpan(text: primary.substring(cursor)));
    return ExcludeFocus(
      child: ListTile(
        dense: true,
        selected: highlighted,
        selectedTileColor: theme.colorScheme.primary.withValues(alpha: 0.08),
        title: Text.rich(TextSpan(children: spans)),
        subtitle: prediction.secondaryText.isEmpty ? null : Text(prediction.secondaryText),
        onTap: onTap,
      ),
    );
  }
}

/// Default loading indicator.
Widget defaultLoading(BuildContext context) => const Padding(padding: EdgeInsets.all(12), child: LinearProgressIndicator());

/// Default empty state.
Widget defaultEmpty(BuildContext context, String query) => const Padding(padding: EdgeInsets.all(12), child: Text('No results'));

/// Default error state.
Widget defaultError(BuildContext context, PlaceAutocompleteException error, VoidCallback retry) => ListTile(
      dense: true,
      title: Text(error.message ?? 'Something went wrong'),
      trailing: TextButton(onPressed: retry, child: const Text('Retry')),
    );

/// Default attribution footer.
Widget defaultFooter(BuildContext context) => Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Align(alignment: Alignment.centerRight, child: Text('Powered by Google', style: Theme.of(context).textTheme.labelSmall)),
    );
