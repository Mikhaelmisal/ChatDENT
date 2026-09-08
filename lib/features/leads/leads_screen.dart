import 'dart:math';

import 'package:chatdent/app/routes.dart';
import 'package:chatdent/common_widgets/button_styles.dart';
import 'package:chatdent/common_widgets/contact_buttons.dart';
import 'package:chatdent/common_widgets/item_title.dart';
import 'package:chatdent/common_widgets/no_items_found.dart';
import 'package:chatdent/common_widgets/screen_command_bar.dart';
import 'package:chatdent/common_widgets/show_more_bar.dart';
import 'package:chatdent/core/multi_stream_builder.dart';
import 'package:chatdent/features/leads/import_leads_dialog.dart';
import 'package:chatdent/features/leads/lead_model.dart';
import 'package:chatdent/features/leads/leads_store.dart';
import 'package:chatdent/features/leads/open_lead_panel.dart';
import 'package:chatdent/features/settings/settings_stores.dart';
import 'package:chatdent/services/localization/locale.dart';
import 'package:chatdent/services/login.dart';
import 'package:chatdent/utils/constants.dart';
import 'package:chatdent/widget_keys.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart';

Widget _leadOutcomePill(String text, Color color, {required bool filled}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: filled
          ? color.withValues(alpha: 0.9)
          : color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(4),
      border: Border.all(
        color: color.withValues(alpha: filled ? 0.9 : 0.35),
      ),
    ),
    child: Txt(
      text,
      style: TextStyle(
        color: filled ? const Color(0xFFFFFFFF) : color,
        fontWeight: FontWeight.w700,
        fontSize: 12,
      ),
    ),
  );
}

class LeadsScreen extends StatelessWidget {
  const LeadsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MStreamBuilder(
      streams: [
        leads.observableMap.stream,
        globalSettings.observableMap.stream,
        routes.panels.stream,
      ],
      builder: (context, snapshot) {
        return _LeadsPage(DateTime.now().millisecondsSinceEpoch);
      },
    );
  }
}

class _LeadsPage extends StatefulWidget {
  const _LeadsPage(this.tick);
  final int tick;

  @override
  State<_LeadsPage> createState() => _LeadsPageState();
}

class _LeadsPageState extends State<_LeadsPage> {
  String? byStage;
  String? bySource;
  String? byOutcome;
  int sortBy = -1;
  int sortDirection = 1;
  int slice = 10;
  final selectedIds = <String>{};

  List<Lead> _displayedItems = [];
  int _totalFilteredCount = 0;

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  double calWidth(double x) => ((2 / 41) * x + (2580 / 41)).clamp(125, 145.0);

  bool get _canEdit => login.perm(Perm.leads).full || login.isAdmin;

  @override
  void didUpdateWidget(covariant _LeadsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tick != widget.tick) {
      _updateItems();
    }
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _updateItems();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged() => _updateItems();

  void _mergeSelected() {
    if (!_canEdit || selectedIds.length < 2) return;
    final kept = leads.get(selectedIds.first);
    if (kept == null) return;
    for (final id in selectedIds.skip(1)) {
      final other = leads.get(id);
      if (other == null) continue;
      if (kept.title.isEmpty) kept.title = other.title;
      if (kept.phonesString.isEmpty) kept.phone = other.phone;
      if (kept.email.isEmpty) kept.email = other.email;
      if (other.notes.isNotEmpty && !kept.notes.contains(other.notes)) {
        kept.notes = [kept.notes, other.notes]
            .where((s) => s.isNotEmpty)
            .join('\n');
      }
      if (kept.interest.isEmpty) kept.interest = other.interest;
      if (other.called) kept.called = true;
      if (other.coming) kept.coming = true;
      leads.archive(id);
    }
    leads.set(kept);
    setState(() => selectedIds.clear());
  }

  void _updateItems() {
    final words = _searchController.text
        .toLowerCase()
        .replaceAll(RegExp('أ|إ'), 'ا')
        .split(' ');

    var candidates = leads.present.values.where((item) {
      return words.every((word) => item.searchString.contains(word));
    }).toList();

    if (byStage != null) {
      candidates = candidates.where((l) => l.stage == byStage).toList();
    }
    if (bySource != null) {
      candidates = candidates.where((l) => l.source == bySource).toList();
    }
    if (byOutcome != null) {
      candidates =
          candidates.where((l) => l.callOutcome == byOutcome).toList();
    }

    _totalFilteredCount = candidates.length;
    if (sortBy < 0) {
      candidates.sort((a, b) {
        return a.title.toLowerCase().compareTo(b.title.toLowerCase()) *
            sortDirection;
      });
    } else {
      candidates.sort((a, b) {
        final aVal = a.tableLabels[sortBy].value;
        final bVal = b.tableLabels[sortBy].value;
        return aVal.compareTo(bVal) * sortDirection;
      });
    }

    if (candidates.length > slice) {
      candidates = candidates.sublist(0, min(candidates.length, slice));
    }

    if (listEquals(_displayedItems, candidates)) return;
    setState(() => _displayedItems = candidates);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      key: WK.leadsScreen,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ScreenCommandBar(
          mainButton: IconButton(
            icon: ButtonContent(FluentIcons.add, txt('newLead')),
            onPressed: _canEdit ? () => openLead() : null,
          ),
          otherButtons: [
            IconButton(
              icon: ButtonContent(WindowsIcons.copy, txt('import')),
              onPressed: _canEdit
                  ? () {
                      showDialog(
                        barrierDismissible: true,
                        dismissWithEsc: true,
                        context: context,
                        builder: (context) => const ImportLeadsDialog(),
                      );
                    }
                  : null,
            ),
            if (selectedIds.length >= 2)
              IconButton(
                icon: ButtonContent(
                  FluentIcons.people,
                  '${txt('mergeLeads')} (${selectedIds.length})',
                ),
                onPressed: _canEdit ? _mergeSelected : null,
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Expanded(
                child: TopSearch(
                  controller: _searchController,
                  setState: setState,
                ),
              ),
            ],
          ),
        ),
        Container(
          width: double.infinity,
          decoration: topBarDecoration(context, Colors.grey),
          padding: const EdgeInsetsDirectional.only(
            start: 8.0,
            end: 0,
            top: 8.0,
            bottom: 8.0,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsetsDirectional.only(end: 8.0),
            scrollDirection: Axis.horizontal,
            physics: const AlwaysScrollableScrollPhysics(),
            child: Row(
              spacing: 5,
              children: [
                _buildStageFilter(),
                _buildOutcomeFilter(),
                _buildSourceFilter(),
                _buildSortByTitle(),
                ..._buildSortByLabels(),
              ],
            ),
          ),
        ),
        _buildTable(),
        ShowMoreBar(
          all: _totalFilteredCount,
          slice: _displayedItems.length,
          scrollController: _scrollController,
          callBack: () {
            slice = slice + 10;
            _updateItems();
          },
        ),
      ],
    );
  }

  Widget _buildTable() {
    return Expanded(
      child: LayoutBuilder(builder: (context, constraints) {
        final searchStringLowerCased = _searchController.text.toLowerCase();
        final calculatedWidth = calWidth(constraints.maxWidth);
        if (_displayedItems.isEmpty) {
          return const NoItemsFound();
        }
        return ListView.builder(
          controller: _scrollController,
          itemCount: _displayedItems.length,
          padding: const EdgeInsets.all(0),
          itemExtent: 95,
          itemBuilder: (context, index) {
            final lead = _displayedItems[index];
            return _buildRow(
              lead,
              constraints,
              calculatedWidth,
              searchStringLowerCased,
            );
          },
        );
      }),
    );
  }

  ListTile _buildRow(
    Lead lead,
    BoxConstraints constraints,
    double calculatedWidth,
    String searchStringLowerCased,
  ) {
    return ListTile.selectable(
      key: ValueKey(lead.id),
      selected: selectedIds.contains(lead.id),
      selectionMode: ListTileSelectionMode.multiple,
      onSelectionChange: _canEdit
          ? (isSelected) {
              if (isSelected) {
                selectedIds.add(lead.id);
              } else {
                selectedIds.remove(lead.id);
              }
              setState(() {});
            }
          : null,
      margin: const EdgeInsets.only(bottom: 0),
      shape: listDividerBorder(context),
      tileColor: WidgetStateColor.resolveWith((states) {
        if (selectedIds.contains(lead.id)) {
          return Colors.blue.withAlpha(20);
        } else if (states.contains(WidgetState.hovered)) {
          return FluentTheme.of(context).resources.controlAltFillColorTertiary;
        }
        return FluentTheme.of(context).resources.solidBackgroundFillColorBase;
      }),
      title: _LeadTileBody(
        lead: lead,
        constraints: constraints,
        calculatedWidth: calculatedWidth,
        searchStringLowerCased: searchStringLowerCased,
      ),
      contentPadding:
          const EdgeInsetsDirectional.only(top: 0, bottom: 5, start: 5, end: 0),
    );
  }

  ComboBox<String?> _buildStageFilter() {
    return ComboBox<String?>(
      onChanged: (stage) {
        byStage = stage;
        _updateItems();
      },
      value: byStage,
      placeholder: Txt(txt('leadStage')),
      items: [
        ComboBoxItem<String?>(value: null, child: Txt(txt('allStages'))),
        ...LeadStage.all.map(
          (s) => ComboBoxItem<String?>(
            value: s,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 6,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: LeadStage.color(s),
                    shape: BoxShape.circle,
                  ),
                ),
                Txt(txt(LeadStage.labelKey(s))),
              ],
            ),
          ),
        ),
      ],
    );
  }

  ComboBox<String?> _buildOutcomeFilter() {
    return ComboBox<String?>(
      onChanged: (outcome) {
        byOutcome = outcome;
        _updateItems();
      },
      value: byOutcome,
      placeholder: Txt(txt('callOutcome')),
      items: [
        ComboBoxItem<String?>(value: null, child: Txt(txt('callOutcome'))),
        ...CallOutcome.all.map(
          (o) => ComboBoxItem<String?>(
            value: o,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 6,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: CallOutcome.color(o),
                    shape: BoxShape.circle,
                  ),
                ),
                Txt(CallOutcome.label(o)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  ComboBox<String?> _buildSourceFilter() {
    return ComboBox<String?>(
      onChanged: (source) {
        bySource = source;
        _updateItems();
      },
      value: bySource,
      placeholder: Txt(txt('leadSource')),
      items: [
        ComboBoxItem<String?>(value: null, child: Txt(txt('allSources'))),
        ...LeadSource.all.map(
          (s) => ComboBoxItem<String?>(
            value: s,
            child: Txt(txt(s)),
          ),
        ),
      ],
    );
  }

  ToggleButton _buildSortByTitle() {
    return ToggleButton(
      checked: sortBy == -1,
      onChanged: (s) {
        s ? setSortBy(-1) : toggleSortDirection();
      },
      child: Row(
        spacing: 3,
        mainAxisSize: MainAxisSize.min,
        children: [
          sortBy == -1
              ? (sortDirection == -1
                  ? const Icon(FluentIcons.sort_down)
                  : const Icon(FluentIcons.sort_up))
              : const SizedBox.shrink(),
          Txt(txt('byName')),
        ],
      ),
    );
  }

  Iterable<Widget> _buildSortByLabels() sync* {
    final labels = leads.present.values.firstOrNull?.tableLabels ??
        Lead.fromJson({}).tableLabels;
    for (int i = 0; i < labels.length; i++) {
      final label = labels[i];
      if (label.sortable == false) continue;
      yield ToggleButton(
        checked: sortBy == i,
        onChanged: (s) {
          s ? setSortBy(i) : toggleSortDirection();
        },
        child: Row(
          spacing: 3,
          mainAxisSize: MainAxisSize.min,
          children: sortBy == i
              ? [
                  sortDirection == -1
                      ? const Icon(FluentIcons.sort_down)
                      : const Icon(FluentIcons.sort_up),
                  Txt(label.title)
                ]
              : [Txt(label.title)],
        ),
      );
    }
  }

  void setSortBy(int? index) {
    sortBy = index ?? -1;
    _updateItems();
  }

  void toggleSortDirection() {
    sortDirection = sortDirection * -1;
    _updateItems();
  }
}

class _LeadTileBody extends StatelessWidget {
  const _LeadTileBody({
    required this.lead,
    required this.constraints,
    required this.calculatedWidth,
    required this.searchStringLowerCased,
  });

  final Lead lead;
  final BoxConstraints constraints;
  final double calculatedWidth;
  final String searchStringLowerCased;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => openLead(lead),
      child: Row(
        spacing: 5,
        children: [
          const Divider(size: 65, direction: Axis.vertical),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ItemTitle(item: lead),
                    _buildStagePills(),
                  ],
                ),
                _buildBottomLabels(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStagePills() {
    return GestureDetector(
      onTap: () => openLead(lead),
      child: SizedBox(
        width: (constraints.maxWidth - 255).clamp(72.0, 400.0),
        height: 30,
        child: SingleChildScrollView(
          reverse: true,
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _leadOutcomePill(
                CallOutcome.label(lead.callOutcome),
                CallOutcome.color(lead.callOutcome),
                filled: lead.callOutcome.isNotEmpty,
              ),
              const SizedBox(width: 6),
              _leadOutcomePill(
                lead.stageLabel,
                lead.stageColor,
                filled: false,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomLabels(BuildContext context) {
    final labelsList = lead.tableLabels;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 5),
      width: (constraints.maxWidth - 52).clamp(120.0, 2000.0),
      height: 48,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(labelsList.length, (i) {
            final label = labelsList[i];
            if (label.view == false) return const SizedBox.shrink();
            final color =
                label.color ?? FluentTheme.of(context).inactiveColor;
            return _LeadBottomLabel(
              cW: calculatedWidth,
              searchStringLowerCased: searchStringLowerCased,
              label: label,
              color: color,
              lead: lead,
            );
          }),
        ),
      ),
    );
  }
}

class _LeadBottomLabel extends StatelessWidget {
  _LeadBottomLabel({
    required this.cW,
    required this.searchStringLowerCased,
    required this.label,
    required this.color,
    required this.lead,
  });

  final double cW;
  final String searchStringLowerCased;
  final LeadTableLabel label;
  final Color color;
  final Lead lead;
  final GlobalKey<PhoneNumberButtonState> phoneButtonKey =
      GlobalKey<PhoneNumberButtonState>();

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '${label.title}: ${label.content}',
      child: GestureDetector(
        onTap: () => _activate(),
        child: Container(
          width: label.chipWidth ?? (cW + 5),
          padding: const EdgeInsets.symmetric(horizontal: 2),
          decoration:
              searchStringLowerCased == label.searchableString.toLowerCase() &&
                      searchStringLowerCased.isNotEmpty
                  ? BoxDecoration(
                      borderRadius: BorderRadius.circular(5),
                      color: color.withValues(alpha: .1),
                    )
                  : BoxDecoration(
                      color: Colors.transparent,
                      border: BorderDirectional(
                        end: BorderSide(
                          color: FluentTheme.of(context)
                              .resources
                              .dividerStrokeColorDefault,
                        ),
                      ),
                    ),
          child: Row(
            spacing: 5,
            children: [
              if (label.title == txt('phone') && lead.phone.isNotEmpty)
                PhoneNumberButton(
                  phoneNumbers: lead.phone,
                  key: phoneButtonKey,
                )
              else
                IconButton(
                  icon: Icon(
                    label.icon,
                    color: label.color == null ? null : Colors.white,
                  ),
                  style: darkIconButtonStyle(context, label.color),
                  onPressed: _activate,
                ),
              Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: label.titleWidth ?? 89,
                    child: Txt(
                      label.title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        color: color,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Txt(
                    label.content.length > 14
                        ? '${label.content.substring(0, 14)}...'
                        : label.content,
                    overflow: TextOverflow.clip,
                    style: TextStyle(fontSize: 11, color: color),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _activate() {
    if (label.title == txt('phone') && lead.phone.isNotEmpty) {
      phoneButtonKey.currentState?.showMenu();
      return;
    }
    openLead(lead);
  }
}
