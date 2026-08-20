import 'package:chatdent/services/localization/locale.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:intl/intl.dart';

Future<DateTime?> showBirthdatePicker({
  required FlyoutController controller,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
}) {
  return controller.showFlyout<DateTime>(
    barrierDismissible: true,
    dismissWithEsc: true,
    barrierColor: const Color(0x33000000),
    autoModeConfiguration: FlyoutAutoConfiguration(
      preferredMode: FlyoutPlacementMode.bottomLeft,
    ),
    builder: (context) => BirthdatePickerDialog(
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    ),
  );
}

enum _PickerStep { year, month, day }

class BirthdatePickerDialog extends StatefulWidget {
  const BirthdatePickerDialog({
    super.key,
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
  });

  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;

  @override
  State<BirthdatePickerDialog> createState() => _BirthdatePickerDialogState();
}

class _BirthdatePickerDialogState extends State<BirthdatePickerDialog> {
  static const _yearCols = 5;
  static const _monthCols = 3;
  static const _visibleYearRows = 4;
  static const _tileH = 46.0;
  static const _gap = 10.0;
  static const _rowStride = _tileH + _gap;
  static const _yearSnapRows = 2;

  static const _boardH =
      _visibleYearRows * _tileH + (_visibleYearRows - 1) * _gap;

  _PickerStep _step = _PickerStep.day;
  int _year = DateTime.now().year;
  int _month = 1;
  int _day = 1;
  final _yearScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    final clamped = _clamp(widget.initialDate);
    _year = clamped.year;
    _month = clamped.month;
    _day = clamped.day;
    _step = _PickerStep.day;
  }

  @override
  void dispose() {
    _yearScroll.dispose();
    super.dispose();
  }

  DateTime _clamp(DateTime date) {
    if (date.isBefore(widget.firstDate)) return widget.firstDate;
    if (date.isAfter(widget.lastDate)) return widget.lastDate;
    return date;
  }

  /// Group start so rows are 2025–2021, 2020–2016, …
  static int _groupStart(int year) => year - ((year - 1) % 5);

  List<List<int?>> get _yearRows {
    final first = widget.firstDate.year;
    final last = widget.lastDate.year;
    final rows = <List<int?>>[];
    for (var start = _groupStart(last);
        start >= _groupStart(first);
        start -= 5) {
      final descending = [
        for (var i = 4; i >= 0; i--) start + i
      ].where((y) => y >= first && y <= last).toList();
      rows.add([
        ...descending,
        ...List<int?>.filled(_yearCols - descending.length, null),
      ]);
    }
    return rows;
  }

  void _scrollToYear() {
    if (!_yearScroll.hasClients) return;
    final rows = _yearRows;
    final row = rows.indexWhere((r) => r.contains(_year));
    if (row < 0) return;
    final page = (row ~/ _yearSnapRows) * _yearSnapRows;
    final max = _yearScroll.position.maxScrollExtent;
    _yearScroll.jumpTo((page * _rowStride).clamp(0, max));
  }

  bool _monthEnabled(int month) {
    final daysInMonth = DateTime(2000, month + 1, 0).day;
    if (_day > daysInMonth) return false;
    return true;
  }

  bool _yearEnabled(int year) {
    final date = DateTime(year, _month, _day);
    if (date.year != year || date.month != _month || date.day != _day) {
      return false;
    }
    return !date.isBefore(widget.firstDate) && !date.isAfter(widget.lastDate);
  }

  String get _heading {
    final birthdate = txt("birthdate");
    final label = birthdate.isEmpty
        ? "Birthdate"
        : birthdate[0].toUpperCase() + birthdate.substring(1);
    switch (_step) {
      case _PickerStep.day:
        return label;
      case _PickerStep.month:
        return "$_day";
      case _PickerStep.year:
        return "$_day · ${_monthFullName(_month)}";
    }
  }

  String get _hint {
    switch (_step) {
      case _PickerStep.year:
        return "Select year";
      case _PickerStep.month:
        return "Select month";
      case _PickerStep.day:
        return "Select day";
    }
  }

  String _monthName(int month) {
    return DateFormat.MMM(locale.s.$code).format(DateTime(2000, month));
  }

  String _monthFullName(int month) {
    return DateFormat.MMMM(locale.s.$code).format(DateTime(2000, month));
  }

  void _goBack() {
    setState(() {
      _step = _step == _PickerStep.year ? _PickerStep.month : _PickerStep.day;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return FlyoutContent(
      constraints: const BoxConstraints(maxWidth: 420),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: SizedBox(
        width: 396,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (_step != _PickerStep.day)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: IconButton(
                      icon: const Icon(FluentIcons.back, size: 12),
                      onPressed: _goBack,
                    ),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Txt(
                        _heading,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Txt(
                        _hint,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                          color: theme.inactiveColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              height: _boardH + 24,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.resources.subtleFillColorSecondary,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: theme.resources.controlStrokeColorDefault,
                ),
              ),
              child: switch (_step) {
                _PickerStep.year => _yearGrid(),
                _PickerStep.month => _monthGrid(),
                _PickerStep.day => _dayGrid(),
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _yearGrid() {
    final rows = _yearRows;
    return _SlotScroller(
      controller: _yearScroll,
      columns: _yearCols,
      visibleRows: _visibleYearRows,
      tileH: _tileH,
      gap: _gap,
      snapRows: _yearSnapRows,
      scrollable: true,
      itemCount: rows.length,
      rowBuilder: (index) {
        final row = rows[index];
        return Row(
          children: [
            for (var c = 0; c < _yearCols; c++) ...[
              if (c > 0) const SizedBox(width: _gap),
              Expanded(
                child: row[c] == null
                    ? const SizedBox.shrink()
                    : _Chip(
                        label: row[c].toString(),
                        textOnly: true,
                        selected: row[c] == _year,
                        enabled: _yearEnabled(row[c]!),
                        onPressed: () {
                          final year = row[c]!;
                          if (!_yearEnabled(year)) return;
                          Navigator.of(context).pop(
                            DateTime(year, _month, _day),
                          );
                        },
                      ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _monthGrid() {
    const rows = 4;
    return _SlotScroller(
      columns: _monthCols,
      visibleRows: rows,
      tileH: _tileH,
      gap: _gap,
      snapRows: 1,
      scrollable: false,
      itemCount: rows,
      rowBuilder: (index) {
        return Row(
          children: [
            for (var col = 0; col < _monthCols; col++) ...[
              if (col > 0) const SizedBox(width: _gap),
              Expanded(
                child: Builder(
                  builder: (context) {
                    final month = index * _monthCols + col + 1;
                    return _Chip(
                      label: _monthName(month),
                      tooltip: _monthFullName(month),
                      textOnly: true,
                      selected: month == _month,
                      enabled: _monthEnabled(month),
                      onPressed: () {
                        setState(() {
                          _month = month;
                          _step = _PickerStep.year;
                        });
                        WidgetsBinding.instance
                            .addPostFrameCallback((_) => _scrollToYear());
                      },
                    );
                  },
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _dayGrid() {
    const days = 31;
    const cols = 7;
    const rows = 5;
    const dayGap = 6.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final tileH =
            ((constraints.maxHeight - (rows - 1) * dayGap) / rows)
                .clamp(22.0, _tileH);
        return _SlotScroller(
          columns: cols,
          visibleRows: rows,
          tileH: tileH,
          gap: dayGap,
          snapRows: 1,
          scrollable: false,
          itemCount: rows,
          rowBuilder: (row) {
            return Row(
              children: [
                for (var col = 0; col < cols; col++) ...[
                  if (col > 0) const SizedBox(width: dayGap),
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final day = row * cols + col + 1;
                        if (day > days) return const SizedBox.shrink();
                        return _Chip(
                          label: day.toString(),
                          textOnly: true,
                          compact: true,
                          selected: day == _day,
                          onPressed: () => setState(() {
                            _day = day;
                            _step = _PickerStep.month;
                          }),
                        );
                      },
                    ),
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }
}

class _SlotScroller extends StatelessWidget {
  const _SlotScroller({
    this.controller,
    required this.columns,
    required this.visibleRows,
    required this.tileH,
    required this.gap,
    required this.snapRows,
    required this.itemCount,
    required this.rowBuilder,
    this.scrollable = true,
  });

  final ScrollController? controller;
  final int columns;
  final int visibleRows;
  final double tileH;
  final double gap;
  final int snapRows;
  final int itemCount;
  final bool scrollable;
  final Widget Function(int index) rowBuilder;

  double get _stride => tileH + gap;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final frameRows = scrollable
            ? ((constraints.maxHeight + gap) / _stride)
                .floor()
                .clamp(1, visibleRows)
            : itemCount.clamp(1, visibleRows);
        return Stack(
          children: [
            IgnorePointer(
              child: Column(
                children: [
                  for (var r = 0; r < frameRows; r++) ...[
                    if (r > 0) SizedBox(height: gap),
                    SizedBox(
                      height: tileH,
                      child: Row(
                        children: [
                          for (var c = 0; c < columns; c++) ...[
                            if (c > 0) SizedBox(width: gap),
                            Expanded(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: theme.resources.controlFillColorDefault,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: theme.resources.controlStrokeColorDefault
                                        .withValues(alpha: 0.7),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (scrollable)
              ClipRect(
                child: ListView.builder(
                  controller: controller,
                  padding: EdgeInsets.zero,
                  physics: _SnapScrollPhysics(snapSize: _stride * snapRows),
                  itemExtent: _stride,
                  itemCount: itemCount,
                  itemBuilder: (context, index) {
                    return Align(
                      alignment: Alignment.topCenter,
                      child: SizedBox(
                        height: tileH,
                        child: rowBuilder(index),
                      ),
                    );
                  },
                ),
              )
            else
              Column(
                children: [
                  for (var i = 0; i < itemCount; i++) ...[
                    if (i > 0) SizedBox(height: gap),
                    SizedBox(
                      height: tileH,
                      child: rowBuilder(i),
                    ),
                  ],
                ],
              ),
          ],
        );
      },
    );
  }
}

class _SnapScrollPhysics extends ScrollPhysics {
  const _SnapScrollPhysics({required this.snapSize, super.parent});

  final double snapSize;

  @override
  _SnapScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return _SnapScrollPhysics(snapSize: snapSize, parent: buildParent(ancestor));
  }

  double _target(ScrollMetrics position, double velocity) {
    final min = position.minScrollExtent;
    final max = position.maxScrollExtent;
    if (max <= min || snapSize <= 0) return position.pixels;
    var page = position.pixels / snapSize;
    if (velocity.abs() > 180) {
      page = velocity > 0 ? page.ceilToDouble() : page.floorToDouble();
    } else {
      page = page.roundToDouble();
    }
    return (page * snapSize).clamp(min, max);
  }

  @override
  Simulation? createBallisticSimulation(
      ScrollMetrics position, double velocity) {
    final target = _target(position, velocity);
    if ((target - position.pixels).abs() < 0.5) {
      return super.createBallisticSimulation(position, velocity);
    }
    return ScrollSpringSimulation(
      spring,
      position.pixels,
      target,
      velocity,
      tolerance: toleranceFor(position),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.onPressed,
    this.selected = false,
    this.enabled = true,
    this.compact = false,
    this.textOnly = false,
    this.tooltip,
  });

  final String label;
  final VoidCallback onPressed;
  final bool selected;
  final bool enabled;
  final bool compact;
  final bool textOnly;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final bg = !enabled
        ? Colors.transparent
        : selected
            ? theme.accentColor
            : textOnly
                ? Colors.transparent
                : theme.resources.controlFillColorDefault;
    final fg = !enabled
        ? theme.inactiveColor.withValues(alpha: 0.45)
        : selected
            ? Colors.white
            : theme.typography.body?.color;

    final chip = HoverButton(
      onPressed: enabled ? onPressed : null,
      builder: (context, states) {
        final hovered = states.isHovered && enabled && !selected;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: hovered
                ? theme.accentColor.withValues(alpha: 0.12)
                : bg,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: selected
                  ? theme.accentColor
                  : textOnly
                      ? Colors.transparent
                      : theme.resources.controlStrokeColorDefault
                          .withValues(alpha: 0.7),
            ),
          ),
          child: Txt(
            label,
            style: TextStyle(
              fontSize: compact ? 12 : 13,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: fg,
            ),
          ),
        );
      },
    );

    if (tooltip == null) return chip;
    return Tooltip(message: tooltip!, child: chip);
  }
}
