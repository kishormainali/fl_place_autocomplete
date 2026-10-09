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

  /// Above the field, unless that side is too small and the other has more
  /// room (e.g. with the keyboard open).
  up,

  /// Below the field, unless that side is too small and the other has more
  /// room (e.g. with the keyboard open).
  down,
}

/// How the suggestions are presented.
enum PlaceSuggestionsMode {
  /// A popover anchored to the field; typing happens in the field itself.
  overlay,

  /// A modal bottom sheet with its own search field.
  ///
  /// Tapping the field opens the sheet; selecting a row closes it.
  bottomSheet,

  /// A dialog with its own search field.
  ///
  /// Tapping the field opens the dialog; selecting a row closes it.
  dialog,
}

/// Styling of the [PlaceSuggestionsMode.bottomSheet] modal.
///
/// The sheet always sits above the keyboard and its list scrolls when the
/// space runs out. Null colors/shapes fall back to `BottomSheetThemeData`.
@immutable
class PlaceBottomSheetOptions {
  /// Creates sheet options.
  const PlaceBottomSheetOptions({
    this.backgroundColor,
    this.shape,
    this.elevation,
    this.clipBehavior,
    this.showDragHandle,
    this.barrierColor,
    this.isDismissible = true,
    this.enableDrag = true,
    this.useSafeArea = true,
    this.maxHeightFactor = 0.9,
    this.searchPadding = const EdgeInsets.all(16),
    this.searchDecoration,
    this.searchFieldBuilder,
    this.autofocusSearch = true,
  });

  /// Sheet color.
  final Color? backgroundColor;

  /// Sheet shape, e.g. rounded top corners.
  final ShapeBorder? shape;

  /// Sheet elevation.
  final double? elevation;

  /// Clip behavior of the sheet.
  final Clip? clipBehavior;

  /// Whether to show a drag handle.
  final bool? showDragHandle;

  /// Color of the scrim behind the sheet.
  final Color? barrierColor;

  /// Whether tapping the scrim or pressing back closes the sheet.
  final bool isDismissible;

  /// Whether the sheet can be dragged down to close.
  final bool enableDrag;

  /// Whether to keep the sheet out of system UI (notch, status bar).
  final bool useSafeArea;

  /// Largest share (0 to 1) of the space above the keyboard the sheet may use.
  final double maxHeightFactor;

  /// Padding around the search field.
  final EdgeInsetsGeometry searchPadding;

  /// Decoration of the default search field; falls back to the field's
  /// `decoration`.
  final InputDecoration? searchDecoration;

  /// Builds the search field yourself; falls back to the field's
  /// `fieldBuilder`, then to the default `TextField`.
  ///
  /// Wire the given controller and focus node into your field exactly as for
  /// `fieldBuilder`.
  final PlaceFieldBuilder? searchFieldBuilder;

  /// Whether the search field takes focus (and opens the keyboard) as soon as
  /// the modal opens.
  final bool autofocusSearch;
}

/// Styling of the [PlaceSuggestionsMode.dialog] modal.
///
/// The dialog always moves above the keyboard and its list scrolls when the
/// space runs out. Null colors/shapes fall back to `DialogThemeData`.
@immutable
class PlaceDialogOptions {
  /// Creates dialog options.
  const PlaceDialogOptions({
    this.backgroundColor,
    this.shape,
    this.elevation,
    this.insetPadding,
    this.alignment,
    this.barrierColor,
    this.barrierDismissible = true,
    this.maxWidth = 560,
    this.maxHeightFactor = 0.8,
    this.searchPadding = const EdgeInsets.all(16),
    this.searchDecoration,
    this.searchFieldBuilder,
    this.autofocusSearch = true,
  });

  /// Dialog color.
  final Color? backgroundColor;

  /// Dialog shape.
  final ShapeBorder? shape;

  /// Dialog elevation.
  final double? elevation;

  /// Minimum distance to the screen edges.
  final EdgeInsets? insetPadding;

  /// Where the dialog sits, e.g. `Alignment.topCenter`.
  final AlignmentGeometry? alignment;

  /// Color of the scrim behind the dialog.
  final Color? barrierColor;

  /// Whether tapping the scrim closes the dialog.
  final bool barrierDismissible;

  /// Largest dialog width.
  final double maxWidth;

  /// Largest share (0 to 1) of the space above the keyboard the dialog may use.
  final double maxHeightFactor;

  /// Padding around the search field.
  final EdgeInsetsGeometry searchPadding;

  /// Decoration of the default search field; falls back to the field's
  /// `decoration`.
  final InputDecoration? searchDecoration;

  /// Builds the search field yourself; falls back to the field's
  /// `fieldBuilder`, then to the default `TextField`.
  ///
  /// Wire the given controller and focus node into your field exactly as for
  /// `fieldBuilder`.
  final PlaceFieldBuilder? searchFieldBuilder;

  /// Whether the search field takes focus (and opens the keyboard) as soon as
  /// the modal opens.
  final bool autofocusSearch;
}

/// Wraps the suggestion [content] (header, rows, footer) in your own panel.
typedef PlacePanelBuilder = Widget Function(
  BuildContext context,
  Widget content,
);

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
    this.suggestionsMode = PlaceSuggestionsMode.overlay,
    this.panelBuilder,
    this.bottomSheetOptions = const PlaceBottomSheetOptions(),
    this.dialogOptions = const PlaceDialogOptions(),
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
  ///
  /// Merged over the ambient `InputDecorationTheme`, so the field looks like
  /// the other text fields in your app by default and only the properties you
  /// set here differ. The modal search field (bottom sheet, dialog) is merged
  /// over the theme the same way. Pass `null` to opt out of decoration (and
  /// the theme) entirely.
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

  /// Where the suggestions appear; defaults to an anchored [overlay].
  ///
  /// With [PlaceSuggestionsMode.bottomSheet] or [PlaceSuggestionsMode.dialog]
  /// the inline field becomes a tap target and the modal holds a second field
  /// built the same way ([fieldBuilder] or the default [TextField] with
  /// [decoration]) sharing the controller's text. The modal is styled by the
  /// ambient `BottomSheetThemeData` / `DialogThemeData` unless
  /// [bottomSheetOptions] / [dialogOptions] override it; [overlayDecoration],
  /// [overlayMaxHeight], [overlayElevation], [overlayOffset], [openDirection]
  /// and [panelBuilder] only apply to the overlay.
  final PlaceSuggestionsMode suggestionsMode;

  /// Styling of the bottom sheet in [PlaceSuggestionsMode.bottomSheet].
  final PlaceBottomSheetOptions bottomSheetOptions;

  /// Styling of the dialog in [PlaceSuggestionsMode.dialog].
  final PlaceDialogOptions dialogOptions;

  /// Replaces the default overlay chrome (the elevated, rounded, height
  /// limited [Material]) with your own panel around `content`.
  ///
  /// You are responsible for bounding the height (the space left above the
  /// keyboard is not enforced on your panel). Overlay mode only.
  final PlacePanelBuilder? panelBuilder;

  /// Replaces the default [TextField].
  ///
  /// The suggestion panel is wrapped in a [TextFieldTapRegion], so a
  /// [TextField] or [EditableText] using the default `groupId` treats taps on
  /// suggestion rows as taps inside the field and stays focused. If your field
  /// uses a custom `groupId` or its own `onTapOutside`, make sure tapping the
  /// panel does not unfocus it, or the selection is lost.
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
  BuildContext? _modalContext;

  bool get _modal => widget.suggestionsMode != PlaceSuggestionsMode.overlay;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller =
        widget.controller ??
        PlaceAutocompleteController(text: widget.initialValue ?? '');
    if (!_ownsController && widget.initialValue != null) {
      _controller.setText(widget.initialValue!);
    }
    _ownsFocus = widget.focusNode == null;
    _focusNode =
        widget.focusNode ?? FocusNode(debugLabel: 'PlaceAutocompleteField');
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
        onPredictionSelected: (p) {
          widget.onPredictionSelected?.call(p);
          _closeModal();
        },
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
        _controller = PlaceAutocompleteController(
          text: old.textController.text,
        );
      }
      if (_ownsController) {
        old.dispose();
      } else {
        old.detach(); // drop its debounce, session and our callbacks
      }
      _ownsController = widget.controller == null;
      _controller.addListener(_onControllerChanged);
    }
    if (widget.focusNode != oldWidget.focusNode) {
      final old = _focusNode;
      final hadFocus = old.hasFocus;
      old.removeListener(_onFocus);
      if (_ownsFocus) old.dispose();
      _ownsFocus = widget.focusNode == null;
      _focusNode =
          widget.focusNode ?? FocusNode(debugLabel: 'PlaceAutocompleteField');
      _focusNode.addListener(_onFocus);
      if (_focusNode.hasFocus) {
        _controller.onFocusGained();
      } else if (hadFocus) {
        // The swap is a blur from the field's point of view. We are inside
        // build, so run the blur path (which notifies listeners and hides the
        // overlay) after this frame.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_focusNode.hasFocus) _onFocus();
        });
      }
    }
    _attach();
  }

  void _onFocus() {
    if (_focusNode.hasFocus) {
      _controller.onFocusGained();
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
    if (!mounted || _modal || _portal.isShowing) return;
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
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
    if (_ownsController) {
      _controller.dispose();
    } else {
      // An external controller outlives the field: stop its pending work and
      // drop the callbacks that close over this widget.
      _controller.detach();
    }
    super.dispose();
  }

  void _closeModal() {
    final ctx = _modalContext;
    _modalContext = null;
    if (ctx != null && ctx.mounted) Navigator.of(ctx).pop();
  }

  Future<void> _openModal() async {
    if (widget.enabled == false || _modalContext != null) return;
    _controller.onFocusGained();
    Widget body(
      BuildContext ctx, {
      required EdgeInsetsGeometry padding,
      required InputDecoration? decoration,
      required PlaceFieldBuilder? builder,
      required bool autofocus,
    }) {
      _modalContext = ctx;
      return _FocusNodeScope(
        builder: (context, node) => _modalContent(
          context,
          node,
          padding: padding,
          decoration: decoration,
          builder: builder,
          autofocus: autofocus,
        ),
      );
    }

    if (widget.suggestionsMode == PlaceSuggestionsMode.bottomSheet) {
      final o = widget.bottomSheetOptions;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: o.useSafeArea,
        backgroundColor: o.backgroundColor,
        shape: o.shape,
        elevation: o.elevation,
        clipBehavior: o.clipBehavior,
        showDragHandle: o.showDragHandle,
        barrierColor: o.barrierColor,
        isDismissible: o.isDismissible,
        enableDrag: o.enableDrag,
        builder: (ctx) {
          // The sheet is not resized by the keyboard: lift it by the inset
          // and cap its height to what is left.
          final inset = MediaQuery.viewInsetsOf(ctx).bottom;
          return Padding(
            padding: EdgeInsets.only(bottom: inset),
            child: LayoutBuilder(
              builder: (ctx, constraints) => ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: constraints.maxHeight * o.maxHeightFactor,
                ),
                child: body(
                  ctx,
                  padding: o.searchPadding,
                  decoration: o.searchDecoration,
                  builder: o.searchFieldBuilder,
                  autofocus: o.autofocusSearch,
                ),
              ),
            ),
          );
        },
      );
    } else {
      final o = widget.dialogOptions;
      await showDialog<void>(
        context: context,
        barrierDismissible: o.barrierDismissible,
        barrierColor: o.barrierColor,
        builder: (ctx) {
          // Dialog already pads itself by the keyboard inset.
          final space =
              MediaQuery.sizeOf(ctx).height -
              MediaQuery.viewInsetsOf(ctx).bottom;
          return Dialog(
            backgroundColor: o.backgroundColor,
            shape: o.shape,
            elevation: o.elevation,
            insetPadding: o.insetPadding,
            alignment: o.alignment,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: o.maxWidth,
                maxHeight: space * o.maxHeightFactor,
              ),
              child: body(
                ctx,
                padding: o.searchPadding,
                decoration: o.searchDecoration,
                builder: o.searchFieldBuilder,
                autofocus: o.autofocusSearch,
              ),
            ),
          );
        },
      );
    }
    _modalContext = null;
    if (mounted) _controller.onFocusLost();
  }

  Widget _modalContent(
    BuildContext context,
    FocusNode node, {
    required EdgeInsetsGeometry padding,
    required InputDecoration? decoration,
    required PlaceFieldBuilder? builder,
    required bool autofocus,
  }) {
    final search =
        (builder ?? widget.fieldBuilder)?.call(
          context,
          _controller,
          node,
          _submit,
        ) ??
        TextField(
          controller: _controller.textController,
          focusNode: node,
          decoration: decoration ?? widget.decoration,
          style: widget.style,
          textInputAction: widget.textInputAction,
          keyboardType: widget.keyboardType,
          textCapitalization: widget.textCapitalization,
          autofocus: autofocus,
          onSubmitted: (_) => _submit(),
        );
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: _onKey,
      child: TextFieldTapRegion(
        child: SafeArea(
          top: false,
          child: ListenableBuilder(
            listenable: _controller,
            builder: (context, _) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(padding: padding, child: search),
                ..._contentChildren(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _contentChildren(BuildContext context) => [
    if (widget.headerBuilder != null) widget.headerBuilder!(context),
    Flexible(child: _buildBody(context)),
    (widget.footerBuilder ?? defaultFooter)(context),
  ];

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
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
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
    final field =
        widget.fieldBuilder?.call(context, _controller, _focusNode, _submit) ??
        TextField(
          controller: _controller.textController,
          focusNode: _focusNode,
          decoration: widget.decoration,
          style: widget.style,
          textInputAction: widget.textInputAction,
          keyboardType: widget.keyboardType,
          textCapitalization: widget.textCapitalization,
          enabled: widget.enabled,
          autofocus: widget.autofocus && !_modal,
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
          child: KeyedSubtree(
            key: _fieldKey,
            child: _modal
                ? GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _openModal,
                    child: ExcludeFocus(child: AbsorbPointer(child: field)),
                  )
                : field,
          ),
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
        var maxHeight = widget.overlayMaxHeight;
        if (laidOut) {
          // Room on each side, with the keyboard (and system UI) excluded.
          final top = box.localToGlobal(Offset.zero).dy;
          final spaceAbove = top - MediaQuery.paddingOf(context).top;
          final spaceBelow =
              MediaQuery.sizeOf(context).height -
              MediaQuery.viewInsetsOf(context).bottom -
              (top + box.size.height);
          // `auto` picks the roomier side; `up`/`down` are preferences that
          // flip only when the keyboard leaves that side too cramped.
          up = switch (widget.openDirection) {
            PlaceOverlayDirection.auto =>
              spaceBelow < maxHeight && spaceAbove > spaceBelow,
            PlaceOverlayDirection.up =>
              !(spaceAbove < maxHeight && spaceBelow > spaceAbove),
            PlaceOverlayDirection.down =>
              spaceBelow < maxHeight && spaceAbove > spaceBelow,
          };
          // Never grow past the screen or under the keyboard.
          maxHeight = (up ? spaceAbove : spaceBelow)
              .clamp(0.0, maxHeight)
              .toDouble();
        }

        final content = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: _contentChildren(context),
        );
        Widget panel =
            widget.panelBuilder?.call(context, content) ??
            Material(
              elevation: widget.overlayElevation,
              borderRadius: BorderRadius.circular(8),
              clipBehavior: Clip.antiAlias,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxHeight),
                child: content,
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
            // The panel belongs to both tap groups: the default TextField's
            // private group and EditableText's shared group, so a custom
            // fieldBuilder's text field does not treat a tap on a row as a
            // tap outside (which would blur it before the row's tap-up).
            child: TapRegion(
              groupId: _tapGroup,
              child: TextFieldTapRegion(
                child: SizedBox(width: width, child: panel),
              ),
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
              child: builder(
                c,
                p,
                i == _controller.highlightedIndex,
                () => _controller.select(p),
              ),
            );
          },
          separatorBuilder:
              widget.separatorBuilder ?? (_, _) => const SizedBox.shrink(),
        );
      case PlaceAutocompleteStatus.empty:
        return (widget.emptyBuilder ?? defaultEmpty)(
          context,
          _controller.textController.text,
        );
      case PlaceAutocompleteStatus.error:
        final error = _controller.error;
        if (error == null) return const SizedBox.shrink();
        return (widget.errorBuilder ?? defaultError)(
          context,
          error,
          _controller.retry,
        );
      case PlaceAutocompleteStatus.idle:
        return const SizedBox.shrink();
    }
  }

  static Widget _defaultPrediction(
    BuildContext context,
    PlacePrediction prediction,
    bool highlighted,
    VoidCallback onTap,
  ) => DefaultPredictionTile(
    prediction: prediction,
    highlighted: highlighted,
    onTap: onTap,
  );
}

/// Owns a [FocusNode] for the lifetime of a modal route's content.
class _FocusNodeScope extends StatefulWidget {
  const _FocusNodeScope({required this.builder});

  final Widget Function(BuildContext context, FocusNode node) builder;

  @override
  State<_FocusNodeScope> createState() => _FocusNodeScopeState();
}

class _FocusNodeScopeState extends State<_FocusNodeScope> {
  final FocusNode _node = FocusNode(debugLabel: 'PlaceAutocompleteModal');

  @override
  void dispose() {
    _node.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _node);
}
