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
import 'package:chatdent/features/leads/whatsapp_templates.dart';
import 'package:chatdent/features/outreach/campaign_settings.dart';
import 'package:chatdent/features/settings/settings_stores.dart';
import 'package:chatdent/services/localization/locale.dart';
import 'package:chatdent/services/login.dart';
import 'package:chatdent/utils/constants.dart';
import 'package:chatdent/utils/uuid.dart';
import 'package:chatdent/widget_keys.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';

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
  int sortDirection = 1;
  int slice = 10;
  final selectedIds = <String>{};
  final _imageUrl = TextEditingController();
  final _msgBody = TextEditingController();
  final _msgTitle = TextEditingController();
  String? _templateId;

  List<Lead> _displayedItems = [];
  int _totalFilteredCount = 0;

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ensureWhatsAppTemplates();
    });
    _updateItems();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _imageUrl.dispose();
    _msgBody.dispose();
    _msgTitle.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _queueMarketing() {
    final typed = _imageUrl.text.trim();
    final fallback = WhatsAppCampaign.fromJsonString(
      globalSettings.campaignJson,
    ).marketingImageUrl;
    final url = typed.isNotEmpty ? typed : fallback;
    if (selectedIds.isEmpty) return;
    if (url.isEmpty && _msgBody.text.trim().isEmpty) return;
    for (final id in selectedIds) {
      final lead = leads.get(id);
      if (lead == null) continue;
      lead.marketingQueued = true;
      lead.marketingSent = false;
      lead.marketingImageUrl = url;
      final body = _msgBody.text.trim();
      if (body.isNotEmpty) {
        lead.marketingCaption =
            fillWhatsAppTemplate(body, name: lead.title);
      }
      leads.set(lead);
    }
    setState(() => selectedIds.clear());
  }

  void _onSearchChanged() => _updateItems();

  List<WhatsAppCampaignMsg> get _templates {
    return loadWhatsAppTemplates().campaigns
      ..sort((a, b) => a.title.compareTo(b.title));
  }

  void _selectTemplate(String? id) {
    _templateId = id;
    WhatsAppCampaignMsg? msg;
    for (final c in _templates) {
      if (c.id == id) {
        msg = c;
        break;
      }
    }
    _msgTitle.text = msg?.title ?? '';
    _msgBody.text = msg?.body ?? '';
    setState(() {});
  }

  void _saveTemplate() {
    if (!_canEdit) return;
    ensureWhatsAppTemplates();
    final title = _msgTitle.text.trim();
    final body = _msgBody.text.trim();
    if (title.isEmpty || body.isEmpty) return;
    final current = loadWhatsAppTemplates();
    final campaigns = [...current.campaigns];
    if (_templateId != null) {
      final i = campaigns.indexWhere((c) => c.id == _templateId);
      if (i >= 0) {
        campaigns[i] = WhatsAppCampaignMsg(
          id: _templateId!,
          title: title,
          body: body,
        );
      } else {
        campaigns.add(WhatsAppCampaignMsg(
          id: _templateId!,
          title: title,
          body: body,
        ));
      }
    } else {
      final msg = WhatsAppCampaignMsg(
        id: uuid(),
        title: title,
        body: body,
      );
      campaigns.add(msg);
      _templateId = msg.id;
    }
    persistWhatsAppTemplates(current.withCampaigns(campaigns));
    setState(() {});
  }

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
      leads.archive(id);
    }
    leads.set(kept);
    setState(() => selectedIds.clear());
  }

  Widget _statsBar() {
    final all = leads.present.values.toList();
    final converted = all.where((l) => l.stage == LeadStage.converted).length;
    final noVisit = all.where((l) =>
        l.stage == LeadStage.converted &&
        (l.patient == null || l.patient!.doneAppointments.isEmpty)).length;
    final called = all.where((l) => l.called).length;
    final paused = all.where((l) => l.assistantPaused).length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Wrap(
        spacing: 12,
        runSpacing: 4,
        children: [
          Txt('${txt('leads')}: ${all.length}'),
          Txt('${txt('leadCalled')}: $called'),
          Txt('${txt('leadStageConverted')}: $converted'),
          Txt('${txt('noVisitYet')}: $noVisit'),
          Txt('${txt('assistantOff')}: $paused'),
        ],
      ),
    );
  }

  Widget _messageLibrary() {
    final items = _templates;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Expander(
        header: Txt(txt('campaignMessages')),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 8,
          children: [
            ComboBox<String?>(
              isExpanded: true,
              value: _templateId,
              placeholder: Txt(txt('pickCampaignMessage')),
              items: [
                ComboBoxItem<String?>(
                    value: null, child: Txt(txt('newCampaignMessage'))),
                ...items.map(
                  (n) => ComboBoxItem<String?>(
                    value: n.id,
                    child: Text(n.title),
                  ),
                ),
              ],
              onChanged: _selectTemplate,
            ),
            CupertinoTextField(
              controller: _msgTitle,
              placeholder: txt('title'),
              enabled: _canEdit,
            ),
            CupertinoTextField(
              controller: _msgBody,
              maxLines: 8,
              placeholder: txt('campaignMessageBody'),
              enabled: _canEdit,
            ),
            Text(
              txt('templatePlaceholders'),
              style: FluentTheme.of(context).typography.caption,
            ),
            Row(
              spacing: 8,
              children: [
                Button(
                  onPressed: _canEdit ? _saveTemplate : null,
                  child: ButtonContent(WindowsIcons.save, txt('save')),
                ),
                Button(
                  onPressed: _canEdit && selectedIds.length >= 2
                      ? _mergeSelected
                      : null,
                  child: ButtonContent(FluentIcons.people, txt('mergeLeads')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
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

    _totalFilteredCount = candidates.length;
    candidates.sort(
        (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()) * sortDirection);

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
              icon: ButtonContent(WindowsIcons.copy, txt('importCsv')),
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
          ],
        ),
        Expanded(
          child: Scrollbar(
            controller: _scrollController,
            thumbVisibility: true,
            child: CustomScrollView(
              controller: _scrollController,
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Row(children: [_buildSearch()]),
                  ),
                ),
                SliverToBoxAdapter(child: _statsBar()),
                SliverToBoxAdapter(child: _messageLibrary()),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: CupertinoTextField(
                            controller: _imageUrl,
                            placeholder: txt('marketingImageUrl'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Button(
                          onPressed: _canEdit && selectedIds.isNotEmpty
                              ? _queueMarketing
                              : null,
                          child: ButtonContent(
                              FluentIcons.send, txt('queueMarketing')),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Container(
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
                      child: Row(
                        spacing: 5,
                        children: [
                          _buildStageFilter(),
                          _buildSourceFilter(),
                          _buildSortByTitle(),
                        ],
                      ),
                    ),
                  ),
                ),
                if (_displayedItems.isEmpty)
                  const SliverFillRemaining(child: NoItemsFound())
                else
                  SliverFixedExtentList(
                    itemExtent: 86,
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final lead = _displayedItems[index];
                        return _leadTile(lead);
                      },
                      childCount: _displayedItems.length,
                    ),
                  ),
                SliverToBoxAdapter(
                  child: ShowMoreBar(
                    all: _totalFilteredCount,
                    slice: _displayedItems.length,
                    scrollController: _scrollController,
                    callBack: () {
                      slice = slice + 10;
                      _updateItems();
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearch() {
    return Expanded(
      child: TopSearch(controller: _searchController, setState: setState),
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
      checked: true,
      onChanged: (_) {
        sortDirection *= -1;
        _updateItems();
      },
      child: Row(
        spacing: 3,
        mainAxisSize: MainAxisSize.min,
        children: [
          sortDirection == -1
              ? const Icon(FluentIcons.sort_down)
              : const Icon(FluentIcons.sort_up),
          Txt(txt('byName')),
        ],
      ),
    );
  }

  Widget _leadTile(Lead lead) {
    return ListTile(
      key: ValueKey(lead.id),
      margin: EdgeInsets.zero,
      shape: listDividerBorder(context),
      onPressed: () => openLead(lead),
      title: SizedBox(
        height: 76,
        child: _LeadRow(
          lead: lead,
          selected: selectedIds.contains(lead.id),
          onSelect: _canEdit
              ? (v) {
                  setState(() {
                    if (v == true) {
                      selectedIds.add(lead.id);
                    } else {
                      selectedIds.remove(lead.id);
                    }
                  });
                }
              : null,
          onCalled: _canEdit
              ? (v) {
                  lead.called = v ?? false;
                  leads.set(lead);
                }
              : null,
        ),
      ),
      contentPadding: const EdgeInsetsDirectional.only(
        top: 0,
        bottom: 0,
        start: 5,
        end: 8,
      ),
    );
  }
}

class _LeadRow extends StatelessWidget {
  const _LeadRow({
    required this.lead,
    required this.selected,
    this.onSelect,
    this.onCalled,
  });
  final Lead lead;
  final bool selected;
  final ValueChanged<bool?>? onSelect;
  final ValueChanged<bool?>? onCalled;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final missedVisit = lead.stage == LeadStage.converted &&
        (lead.patient == null || lead.patient!.doneAppointments.isEmpty);
    return Row(
      spacing: 5,
      children: [
        Checkbox(checked: selected, onChanged: onSelect),
        const Divider(size: 48, direction: Axis.vertical),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: ItemTitle(item: lead)),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: lead.stageColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: lead.stageColor.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Text(
                      lead.stageLabel,
                      style: TextStyle(
                        color: lead.stageColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                spacing: 10,
                children: [
                  if (lead.phone.isNotEmpty)
                    PhoneNumberButton(
                      onlyIcon: true,
                      phoneNumbers: lead.phone,
                    )
                  else
                    Text(
                      txt('phone'),
                      style: theme.typography.caption?.copyWith(
                        color: Colors.orange,
                      ),
                    ),
                  Text(
                    lead.sourceLabel,
                    style: theme.typography.caption,
                  ),
                  if (lead.campaign.isNotEmpty)
                    Flexible(
                      child: Text(
                        lead.campaign,
                        overflow: TextOverflow.ellipsis,
                        style: theme.typography.caption?.copyWith(
                          color: theme.resources.textFillColorSecondary,
                        ),
                      ),
                    ),
                  if (missedVisit)
                    Text(
                      txt('noVisitYet'),
                      style: theme.typography.caption?.copyWith(
                        color: Colors.orange,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        Checkbox(
          checked: lead.called,
          onChanged: onCalled,
          content: Txt(txt('leadCalled')),
        ),
      ],
    );
  }
}
