import 'package:fl_place_autocomplete_platform_interface/fl_place_autocomplete_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../api.dart';
import 'controller.dart';
import 'default_builders.dart';

/// Builds the text field yourself.
///
/// Wire `controller.textController` and `focusNode` into your field and call
/// `onSubmit` from its submit action.
typedef PlaceFieldBuilder = Widget Function(
  BuildContext context,
  PlaceAutocompleteController controller,
  FocusNode focusNode,
  VoidCallback onSubmit,
);

/// Builds the loading state.
typedef PlaceLoadingBuilder = WidgetBuilder;

/// Where the suggestion list opens.
enum PlaceOverlayDirection {
  /// Picks the side with more room.
  auto,

  /// Above the field.
  up,

  /// Below the field.
  down,
}

/// A Google Places autocomplete text field.
///
/// Typing (after [minChars] characters and [debounce]) shows predictions in an
/// overlay. Selecting one sets the text and, by default, fetches the full
/// [Place] with the same session and reports it through [onPlaceSelected].
///
/// [initialValue], [initialPlace], focusing the field and programmatic
/// controller updates never call the API or open the overlay; only user edits
/// do.
class PlaceAutocompleteField extends StatefulWidget {
  /// Creates the field.
  const PlaceAutocompleteField({
    super.key,
    this.api,
    this.controller,
    this.focusNode,
    this.initialValue,
    this.initialPlace,
    this.options,
    this.fields = defaultPlaceFields,
    this.debounce = const Duration(milliseconds: 300),
    this.minChars = 2,
    this.fetchDetailsOnSelect = true,
    this.onPredictionSelected,
    this.onPlaceSelected,
    this.onError,
    this.decoration = const InputDecoration(),
    this.style,
    this.textInputAction,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.enabled,
    this.autofocus = false,
    this.overlayDecoration,
    this.overlayMaxHeight = 280,
    this.overlayElevation = 4,
    this.overlayOffset = Offset.zero,
    this.openDirection = PlaceOverlayDirection.auto,
    this.fieldBuilder,
    this.predictionBuilder,
    this.loadingBuilder,
    this.emptyBuilder,
    this.errorBuilder,
    this.separatorBuilder,
    this.headerBuilder,
    this.footerBuilder,
  });

  /// API used for requests; defaults to [FlPlaceAutocomplete.instance].
  final FlPlaceAutocomplete? api;

  /// External controller; one is created (and disposed) internally if null.
  final PlaceAutocompleteController? controller;

  /// External focus node; one is created (and disposed) internally if null.
  final FocusNode? focusNode;

  /// Initial text. Never triggers a request.
  final String? initialValue;

  /// Initially selected place. Never fires [onPlaceSelected].
  final Place? initialPlace;

  /// Prediction options; defaults to `PredictionOptions()`.
  final PredictionOptions? options;

  /// Fields fetched on selection.
  final Set<PlaceField> fields;

  /// Debounce between keystrokes and requests.
  final Duration debounce;

  /// Minimum characters before querying.
  final int minChars;

  /// Whether selecting a prediction fetches full details.
  ///
  /// When false, call [PlaceAutocompleteController.takeSession] synchronously
  /// inside [onPredictionSelected] to keep the session for your own fetch.
  final bool fetchDetailsOnSelect;

  /// Called when a prediction is chosen.
  final void Function(PlacePrediction prediction)? onPredictionSelected;

  /// Called with full details after a successful fetch.
  final void Function(Place place)? onPlaceSelected;

  /// Called when a request fails.
  final void Function(PlaceAutocompleteException error)? onError;

  /// Decoration of the default text field.
  final InputDecoration? decoration;

  /// Text style of the default text field.
  final TextStyle? style;

  /// Keyboard action button of the default text field.
  final TextInputAction? textInputAction;

  /// Keyboard type of the default text field.
  final TextInputType? keyboardType;

  /// Capitalization of the default text field.
  final TextCapitalization textCapitalization;

  /// Whether the default text field is enabled.
  final bool? enabled;

  /// Whether the field requests focus when first built.
  final bool autofocus;

  /// Optional decoration painted around the suggestion panel.
  final Decoration? overlayDecoration;

  /// Maximum height of the suggestion panel.
  final double overlayMaxHeight;

  /// Elevation of the suggestion panel.
  final double overlayElevation;

  /// Extra offset applied to the suggestion panel.
  final Offset overlayOffset;

  /// Which side of the field the suggestion panel opens on.
  final PlaceOverlayDirection openDirection;

  /// Replaces the default [TextField].
  final PlaceFieldBuilder? fieldBuilder;

  /// Builds each suggestion row; defaults to [DefaultPredictionTile].
  final PlacePredictionBuilder? predictionBuilder;

  /// Builds the loading state; defaults to [defaultLoading].
  final PlaceLoadingBuilder? loadingBuilder;

  /// Builds the "no results" state; defaults to [defaultEmpty].
  final PlaceEmptyBuilder? emptyBuilder;

  /// Builds the error state; defaults to [defaultError].
  final PlaceErrorBuilder? errorBuilder;

  /// Builds separators between rows; none by default.
  final IndexedWidgetBuilder? separatorBuilder;

  /// Builds a header above the rows.
  final WidgetBuilder? headerBuilder;

  /// Builds the footer below the rows; defaults to [defaultFooter]
  /// ("Powered by Google"). Attribution is the app developer's responsibility.
  final WidgetBuilder? footerBuilder;

  @override
  State<PlaceAutocompleteField> createState() => _PlaceAutocompleteFieldState();
}

class _PlaceAutocompleteFieldState extends State<PlaceAutocompleteField> {
  late PlaceAutocompleteController _controller;
  late bool _ownsController;
  late FocusNode _focusNode;
  late bool _ownsFocus;
  final OverlayPortalController _portal = OverlayPortalController();
  final LayerLink _link = LayerLink();
  final GlobalKey _fieldKey = GlobalKey();
  final Object _tapGroup = Object();

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller =
        widget.controller ?? PlaceAutocompleteController(text: widget.initialValue ?? '');
    if (!_ownsController && widget.initialValue != null) {
      _controller.setText(widget.initialValue!);
    }
    _ownsFocus = widget.focusNode == null;
    _focusNode = widget.focusNode ?? FocusNode(debugLabel: 'PlaceAutocompleteField');
    _focusNode.addListener(_onFocus);
    _controller.addListener(_onControllerChanged);
    _attach();
    if (widget.initialPlace != null) _controller.setPlace(widget.initialPlace!);
    if (widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _focusNode.hasFocus) _showPortal();
      });
    }
  }

  void _attach() {
    _controller.attach(
      PlaceAutocompleteConfig(
        api: widget.api ?? FlPlaceAutocomplete.instance,
        options: widget.options ?? PredictionOptions(),
        fields: widget.fields,
        debounce: widget.debounce,
        minChars: widget.minChars,
        fetchDetailsOnSelect: widget.fetchDetailsOnSelect,
        onPredictionSelected: widget.onPredictionSelected,
        onPlaceSelected: widget.onPlaceSelected,
        onError: widget.onError,
      ),
    );
  }

  @override
  void didUpdateWidget(PlaceAutocompleteField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      final old = _controller;
      old.removeListener(_onControllerChanged);
      if (widget.controller != null) {
        _controller = widget.controller!;
      } else {
        _controller = PlaceAutocompleteController(text: old.textController.text);
      }
      if (_ownsController) old.dispose();
      _ownsController = widget.controller == null;
      _controller.addListener(_onControllerChanged);
    }
    if (widget.focusNode != oldWidget.focusNode) {
      final old = _focusNode;
      old.removeListener(_onFocus);
      if (_ownsFocus) old.dispose();
      _ownsFocus = widget.focusNode == null;
      _focusNode = widget.focusNode ?? FocusNode(debugLabel: 'PlaceAutocompleteField');
      _focusNode.addListener(_onFocus);
    }
    _attach();
  }

  void _onFocus() {
    if (_focusNode.hasFocus) {
      // Gaining focus only makes the overlay slot available; its content stays
      // empty until the controller opens it after a user edit.
      _showPortal();
    } else {
      _controller.onFocusLost();
      if (_portal.isShowing && !_controller.overlayOpen) _portal.hide();
    }
  }

  void _onControllerChanged() {
    // Keep the overlay slot available when the controller opens the list
    // (e.g. a custom fieldBuilder that does not use the provided focus node).
    if (_controller.overlayOpen && !_portal.isShowing) _showPortal();
  }

  void _showPortal() {
    if (!mounted || _portal.isShowing) return;
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_portal.isShowing) _portal.show();
      });
    } else {
      _portal.show();
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocus);
    _controller.removeListener(_onControllerChanged);
    if (_ownsFocus) _focusNode.dispose();
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  void _submit() {
    _controller.selectHighlighted();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (!_controller.overlayOpen) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown) {
      _controller.moveHighlight(1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      _controller.moveHighlight(-1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      _controller.dismiss();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) {
      if (_controller.highlightedIndex >= 0) {
        _controller.selectHighlighted();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final field = widget.fieldBuilder?.call(context, _controller, _focusNode, _submit) ??
        TextField(
          controller: _controller.textController,
          focusNode: _focusNode,
          decoration: widget.decoration,
          style: widget.style,
          textInputAction: widget.textInputAction,
          keyboardType: widget.keyboardType,
          textCapitalization: widget.textCapitalization,
          enabled: widget.enabled,
          autofocus: widget.autofocus,
          groupId: _tapGroup,
          onSubmitted: (_) => _submit(),
        );

    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: _onKey,
      child: OverlayPortal(
        controller: _portal,
        overlayChildBuilder: _buildOverlay,
        child: CompositedTransformTarget(
          link: _link,
          child: KeyedSubtree(key: _fieldKey, child: field),
        ),
      ),
    );
  }

  Widget _buildOverlay(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        if (!_controller.overlayOpen) return const SizedBox.shrink();
        final box = _fieldKey.currentContext?.findRenderObject() as RenderBox?;
        final laidOut = box != null && box.attached && box.hasSize;
        final width = laidOut ? box.size.width : null;
        var up = widget.openDirection == PlaceOverlayDirection.up;
        if (widget.openDirection == PlaceOverlayDirection.auto && laidOut) {
          final top = box.localToGlobal(Offset.zero).dy;
          final spaceAbove = top;
          final spaceBelow = MediaQuery.sizeOf(context).height -
              MediaQuery.viewInsetsOf(context).bottom -
              (top + box.size.height);
          up = spaceBelow < widget.overlayMaxHeight && spaceAbove > spaceBelow;
        }

        Widget panel = Material(
          elevation: widget.overlayElevation,
          borderRadius: BorderRadius.circular(8),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: widget.overlayMaxHeight),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.headerBuilder != null) widget.headerBuilder!(context),
                Flexible(child: _buildBody(context)),
                (widget.footerBuilder ?? defaultFooter)(context),
              ],
            ),
          ),
        );
        final decoration = widget.overlayDecoration;
        if (decoration != null) {
          panel = DecoratedBox(decoration: decoration, child: panel);
        }

        return CompositedTransformFollower(
          link: _link,
          showWhenUnlinked: false,
          targetAnchor: up ? Alignment.topLeft : Alignment.bottomLeft,
          followerAnchor: up ? Alignment.bottomLeft : Alignment.topLeft,
          offset: widget.overlayOffset,
          child: Align(
            alignment: up ? Alignment.bottomLeft : Alignment.topLeft,
            child: TapRegion(
              groupId: _tapGroup,
              child: SizedBox(width: width, child: panel),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context) {
    final predictions = _controller.predictions;
    switch (_controller.status) {
      case PlaceAutocompleteStatus.loading when predictions.isEmpty:
        return (widget.loadingBuilder ?? defaultLoading)(context);
      case PlaceAutocompleteStatus.loading:
      case PlaceAutocompleteStatus.results:
        final builder = widget.predictionBuilder ?? _defaultPrediction;
        return ListView.separated(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          itemCount: predictions.length,
          itemBuilder: (c, i) {
            final p = predictions[i];
            return ExcludeFocus(
              child: builder(c, p, i == _controller.highlightedIndex, () => _controller.select(p)),
            );
          },
          separatorBuilder: widget.separatorBuilder ?? (_, _) => const SizedBox.shrink(),
        );
      case PlaceAutocompleteStatus.empty:
        return (widget.emptyBuilder ?? defaultEmpty)(context, _controller.textController.text);
      case PlaceAutocompleteStatus.error:
        final error = _controller.error;
        if (error == null) return const SizedBox.shrink();
        return (widget.errorBuilder ?? defaultError)(context, error, _controller.retry);
      case PlaceAutocompleteStatus.idle:
        return const SizedBox.shrink();
    }
  }

  static Widget _defaultPrediction(
    BuildContext context,
    PlacePrediction prediction,
    bool highlighted,
    VoidCallback onTap,
  ) =>
      DefaultPredictionTile(prediction: prediction, highlighted: highlighted, onTap: onTap);
}
