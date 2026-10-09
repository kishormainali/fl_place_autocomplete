import 'package:fl_place_autocomplete/fl_place_autocomplete.dart';
import 'package:flutter/material.dart';

import 'main.dart' show PlaceDetailsCard, describeError;

/// Shows the three [PlaceSuggestionsMode]s and a custom overlay panel.
class ModesDemo extends StatefulWidget {
  /// Creates the demo.
  const ModesDemo({super.key});

  @override
  State<ModesDemo> createState() => _ModesDemoState();
}

class _ModesDemoState extends State<ModesDemo>
    with AutomaticKeepAliveClientMixin {
  PlaceSuggestionsMode _mode = PlaceSuggestionsMode.overlay;
  bool _customPanel = false;
  bool _styledModals = false;
  Place? _place;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final scheme = Theme.of(context).colorScheme;
    final modalSearch = InputDecoration(
      hintText: 'Type an address',
      prefixIcon: const Icon(Icons.search),
      filled: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: BorderSide.none,
      ),
    );
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SegmentedButton<PlaceSuggestionsMode>(
          key: const ValueKey('modes-selector'),
          segments: const [
            ButtonSegment(
              value: PlaceSuggestionsMode.overlay,
              label: Text('Overlay'),
              icon: Icon(Icons.arrow_drop_down_circle_outlined),
            ),
            ButtonSegment(
              value: PlaceSuggestionsMode.bottomSheet,
              label: Text('Sheet'),
              icon: Icon(Icons.vertical_align_bottom),
            ),
            ButtonSegment(
              value: PlaceSuggestionsMode.dialog,
              label: Text('Dialog'),
              icon: Icon(Icons.web_asset),
            ),
          ],
          selected: {_mode},
          onSelectionChanged: (s) => setState(() => _mode = s.first),
        ),
        SwitchListTile(
          key: const ValueKey('modes-custom-panel'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Custom overlay panel'),
          subtitle: const Text('panelBuilder (overlay mode only)'),
          value: _customPanel,
          onChanged: (v) => setState(() => _customPanel = v),
        ),
        SwitchListTile(
          key: const ValueKey('modes-styled-modals'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Styled sheet and dialog'),
          subtitle: const Text('bottomSheetOptions / dialogOptions'),
          value: _styledModals,
          onChanged: (v) => setState(() => _styledModals = v),
        ),
        const SizedBox(height: 8),
        PlaceAutocompleteField(
          key: const ValueKey('modes-field'),
          suggestionsMode: _mode,
          decoration: const InputDecoration(
            labelText: 'Place',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
          ),
          bottomSheetOptions: _styledModals
              ? PlaceBottomSheetOptions(
                  searchDecoration: modalSearch,
                  showDragHandle: true,
                  backgroundColor: scheme.surfaceContainerHigh,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                  ),
                  maxHeightFactor: 0.7,
                )
              : const PlaceBottomSheetOptions(),
          dialogOptions: _styledModals
              ? PlaceDialogOptions(
                  searchDecoration: modalSearch,
                  alignment: Alignment.topCenter,
                  backgroundColor: scheme.surfaceContainerHigh,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                  maxWidth: 420,
                )
              : const PlaceDialogOptions(),
          panelBuilder: _customPanel
              ? (context, content) => Material(
                  elevation: 8,
                  color: scheme.surfaceContainerHigh,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(color: scheme.primary, width: 2),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 320),
                    child: content,
                  ),
                )
              : null,
          onPlaceSelected: (p) => setState(() {
            _place = p;
            _error = null;
          }),
          onError: (e) => setState(() => _error = describeError(e)),
        ),
        const SizedBox(height: 16),
        if (_error != null)
          Text(_error!, style: TextStyle(color: scheme.error)),
        if (_place != null) PlaceDetailsCard(place: _place!),
      ],
    );
  }
}
