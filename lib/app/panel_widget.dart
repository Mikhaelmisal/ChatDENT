import 'package:chatdent/app/chatdent_theme.dart';
import 'package:chatdent/common_widgets/button_styles.dart';
import 'package:chatdent/common_widgets/delete_button.dart';
import 'package:chatdent/common_widgets/item_title.dart';
import 'package:chatdent/common_widgets/permanent_delete.dart';
import 'package:chatdent/common_widgets/dialogs/close_dialog_button.dart';
import 'package:chatdent/common_widgets/swipe_detector.dart';
import 'package:chatdent/core/model.dart';
import 'package:chatdent/core/multi_stream_builder.dart';
import 'package:chatdent/core/observable.dart';
import 'package:chatdent/features/appointments/appointment_model.dart';
import 'package:chatdent/features/appointments/appointments_store.dart';
import 'package:chatdent/features/settings/settings_stores.dart';
import 'package:chatdent/services/localization/locale.dart';
import 'package:chatdent/utils/flyout_focus_fix.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:convert';
import 'package:chatdent/app/routes.dart';

class PanelScreen extends StatefulWidget {
  final double layoutHeight;
  final double layoutWidth;
  final Panel panel;
  const PanelScreen({
    required this.panel,
    this.layoutHeight = 500,
    this.layoutWidth = 500,
    super.key,
  });

  @override
  State<PanelScreen> createState() => _PanelScreenState();
}

class _PanelScreenState extends State<PanelScreen> {
  late bool isNew;
  final FocusNode focusNode = FocusNode();
  final panelSwitchController = FlyoutController();
  final confirmCancelController = FlyoutController();
  late Timer saveButtonCheckTimer;
  bool ctrlPressed = false;

  @override
  void dispose() {
    saveButtonCheckTimer.cancel();
    if (widget.panel.item is Appointment) {
      widget.panel.store.observableMap
          .unObserve(observeAppointmentForImgUpdate);
    }
    focusNode.dispose();
    panelSwitchController.dispose();
    confirmCancelController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    isNew = widget.panel.canNotBeNew
        ? false
        : widget.panel.store.get(widget.panel.item.id) == null;
    saveButtonCheckTimer =
        Timer.periodic(const Duration(milliseconds: 750), (_) {
      final changesDetected = widget.panel.checkUnsavedChanges?.call() ??
          (jsonEncode(widget.panel.item.toJson()) != widget.panel.savedJson);
      if (changesDetected && widget.panel.hasUnsavedChanges() != true) {
        widget.panel.hasUnsavedChanges(true);
      } else if (!changesDetected &&
          widget.panel.hasUnsavedChanges() != false) {
        widget.panel.hasUnsavedChanges(false);
      }
    });

    if (widget.panel.item is Appointment) {
      widget.panel.store.observableMap.observe(observeAppointmentForImgUpdate);
    }
  }

  observeAppointmentForImgUpdate(List<DictEvent> events) {
    // update the imgs if it has been changed on the server
    final itemID = (widget.panel.item).id;
    for (var event in events) {
      if (event.id == itemID && event.type == DictEventType.modify) {
        final appointmentInStore = appointments.get(itemID);
        if (appointmentInStore != null &&
            (widget.panel.item as Appointment).imgs.length !=
                appointmentInStore.imgs.length) {
          (widget.panel.item as Appointment).imgs = appointmentInStore.imgs;
          widget.panel.selectedTab(widget.panel.selectedTab()); // notify
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      autofocus: true,
      focusNode: focusNode,
      onKeyEvent: (value) {
        if (value is KeyDownEvent &&
            value.logicalKey == LogicalKeyboardKey.escape &&
            routes.panels().isNotEmpty &&
            widget.panel.inProgress() == false) {
          closeOrConfirmCancel();
          return;
        }

        if (value.logicalKey == LogicalKeyboardKey.controlLeft ||
            value.logicalKey == LogicalKeyboardKey.controlLeft) {
          if (value is KeyDownEvent) {
            ctrlPressed = true;
          } else {
            ctrlPressed = false;
          }
        }

        if (value is KeyDownEvent &&
            value.logicalKey == LogicalKeyboardKey.tab &&
            ctrlPressed) {
          if (widget.panel.selectedTab() == widget.panel.tabs.length - 1) {
            widget.panel.selectedTab(0);
          } else {
            widget.panel.selectedTab(widget.panel.selectedTab() + 1);
          }
        }
      },
      child: Container(
        margin: const EdgeInsetsDirectional.only(
            top: 5, bottom: 5, start: 0, end: 5),
        decoration: chatDentPopupCard(ChatDentPalette.of(context)),
        child: MStreamBuilder(
            streams: [
              localSettings.stream,
              widget.panel.selectedTab.stream,
              routes.minimizePanels.stream,
            ],
            builder: (context, snapshot) {
              return Column(
                key: Key(localSettings.selectedLocale.toString()),
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildPanelHeader(),
                  if (routes.minimizePanels() == false ||
                      widget.layoutWidth >= 710) ...[
                    _buildTabsControllers(),
                    _buildTabBody(),
                    if (widget.panel.tabs[widget.panel.selectedTab()].footer !=
                        null)
                      widget.panel.tabs[widget.panel.selectedTab()].footer!,
                    _buildBottomControls(),
                  ],
                ],
              );
            }),
      ),
    );
  }

  Widget _buildTabBody() {
    return Expanded(
      child: widget.panel.inherentlyScrollable
          ? _buildBodyChild()
          : SingleChildScrollView(
              child: _buildBodyChild(),
            ),
    );
  }

  SwipeDetector _buildBodyChild() {
    return SwipeDetector(
      onSwipePrev: () {
        if (widget.panel.selectedTab() > 0) {
          widget.panel.selectedTab(widget.panel.selectedTab() - 1);
        }
      },
      onSwipeNext: () {
        if (widget.panel.selectedTab() < widget.panel.tabs.length - 1) {
          widget.panel.selectedTab(widget.panel.selectedTab() + 1);
        }
      },
      child: Container(
        color: ChatDentPalette.of(context).canvas,
        padding: EdgeInsets.all(
            widget.panel.tabs[widget.panel.selectedTab()].padding.toDouble()),
        constraints: BoxConstraints(
            minHeight:
                widget.panel.tabs[widget.panel.selectedTab()].footer == null
                    ? widget.layoutHeight - 161
                    : widget.layoutHeight - 206),
        child: widget.panel.tabs[widget.panel.selectedTab()].body,
      ),
    );
  }

  Widget _buildBottomControls() {
    return Container(
      constraints: const BoxConstraints(minHeight: 50),
      child: StreamBuilder(
          stream: widget.panel.inProgress.stream,
          builder: (context, snapshot) {
            return Container(
              decoration: BoxDecoration(
                border: Border(
                    top: BorderSide(color: ChatDentPalette.of(context).border)),
              ),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              child: widget.panel.inProgress()
                  ? const Center(child: ProgressBar())
                  : OverflowBar(
                      alignment: MainAxisAlignment.center,
                      overflowAlignment: OverflowBarAlignment.center,
                      spacing: 6,
                      overflowSpacing: 8,
                      children: [
                        if (widget.panel.additionalControls != null)
                          widget.panel.additionalControls!,
                        if (widget.panel.showBottomControls) ...[
                          if (isNew == false) _buildArchiveButton(),
                          if (isNew == false &&
                              widget.panel.item.archived == true)
                            _buildPermanentDeleteButton(),
                          _buildSaveButton(),
                        ],
                        _buildCancelButton(),
                      ],
                    ),
            );
          }),
    );
  }

  Widget _buildCancelButton() {
    return FlyoutTarget(
      controller: confirmCancelController,
      child: StreamBuilder<bool>(
          stream: widget.panel.hasUnsavedChanges.stream,
          builder: (context, _) {
            return IconButton(
              onPressed: closeOrConfirmCancel,
              style: greyButtonStyle.copyWith(
                textStyle:
                    const WidgetStatePropertyAll(TextStyle(fontSize: 13)),
                backgroundColor: widget.panel.hasUnsavedChanges()
                    ? WidgetStatePropertyAll(Colors.orange)
                    : const WidgetStatePropertyAll(Colors.grey),
              ),
              icon: ButtonContent(
                WindowsIcons.cancel,
                widget.panel.hasUnsavedChanges() ? txt("cancel") : txt("close"),
              ),
            );
          }),
    );
  }

  Widget _buildSaveButton() {
    return StreamBuilder<bool>(
        stream: widget.panel.hasUnsavedChanges.stream,
        builder: (context, _) {
          return IconButton(
            onPressed: () {
              if (widget.panel.hasUnsavedChanges()) {
                if (widget.panel.onSave != null) {
                  widget.panel.onSave!();
                } else {
                  widget.panel.store.set(widget.panel.item);
                  widget.panel.savedJson =
                      jsonEncode(widget.panel.item.toJson());
                  widget.panel.identifier = widget.panel.item.id;
                  if (!widget.panel.result.isCompleted) {
                    widget.panel.result.complete(widget.panel.item);
                  }
                }
                setState(() {
                  isNew = false;
                  widget.panel.title = null;
                });
              }
            },
            style: greyButtonStyle.copyWith(
              textStyle: const WidgetStatePropertyAll(TextStyle(fontSize: 13)),
              backgroundColor: WidgetStatePropertyAll(
                  widget.panel.hasUnsavedChanges()
                      ? Colors.blue
                      : Colors.grey.withValues(alpha: 0.25)),
            ),
            icon: ButtonContent(WindowsIcons.save, txt("save")),
          );
        });
  }

  Widget _buildPermanentDeleteButton() {
    return PermanentDeleteButton(
      store: widget.panel.store,
      itemId: widget.panel.item.id,
      preview: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 5,
        children: [
          Icon(widget.panel.icon),
          Txt(
            "${txt(widget.panel.singularName)}:",
            style: FluentTheme.of(context).typography.bodyStrong,
          ),
          ItemTitle(item: widget.panel.item),
        ],
      ),
      onDeleted: () {
        routes.closePanel(widget.panel.item.id);
      },
    );
  }

  Widget _buildArchiveButton() {
    final icon = widget.panel.item.archived == true
        ? WindowsIcons.undo
        : WindowsIcons.delete;
    final action =
        widget.panel.item.archived == true ? txt("restore") : txt("delete");
    final color =
        widget.panel.item.archived == true ? Colors.teal : Colors.grey;
    return widget.panel.archiveButtonReplacement ??
        DeleteButton(
          actionText: action,
          actionIcon: icon,
          restorable: true,
          preview: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 5,
            children: [
              Icon(widget.panel.icon),
              Txt(
                "${txt(widget.panel.singularName)}:",
                style: FluentTheme.of(context).typography.bodyStrong,
              ),
              ItemTitle(item: widget.panel.item),
            ],
          ),
          onConfirm: () {
            setState(() {
              if (widget.panel.item.archived == true) {
                widget.panel.store.unarchive(widget.panel.item.id);
                widget.panel.item.archived = null;
              } else {
                widget.panel.store.archive(widget.panel.item.id);
                widget.panel.item.archived = true;
              }
            });
          },
          style: greyButtonStyle.copyWith(
            backgroundColor: WidgetStatePropertyAll(color),
            textStyle: const WidgetStatePropertyAll(TextStyle(fontSize: 13)),
          ),
          child:
              ButtonContent(icon, "$action ${txt(widget.panel.singularName)}"),
        );
  }

  Widget _buildTabsControllers() {
    return Container(
      decoration:
          BoxDecoration(color: ChatDentPalette.of(context).chrome),
      padding: const EdgeInsets.fromLTRB(3, 15, 3, 0),
      child: SizedBox(
        height: 39,
        child: TabView(
          closeButtonVisibility: CloseButtonVisibilityMode.never,
          onChanged: (value) => widget.panel.selectedTab(value),
          currentIndex: widget.panel.selectedTab(),
          showScrollButtons: true,
          shortcutsEnabled: true,
          tabWidthBehavior: widget.panel.showTitles
              ? TabWidthBehavior.equal
              : (widget.layoutWidth < 710
                  ? TabWidthBehavior.sizeToContent
                  : TabWidthBehavior.compact),
          header: widget.panel.selectedTab() != 0
              ? IconButton(
                  icon: Icon(Directionality.of(context) == TextDirection.rtl
                      ? WindowsIcons.chevron_right
                      : WindowsIcons.chevron_left),
                  onPressed: () =>
                      widget.panel.selectedTab(widget.panel.selectedTab() - 1),
                )
              : const SizedBox(width: 25),
          footer: widget.panel.selectedTab() <
                  widget.panel.tabs
                          .where((t) => t.onlyIfSaved ? (!isNew) : true)
                          .length -
                      1
              ? IconButton(
                  icon: Icon(Directionality.of(context) == TextDirection.rtl
                      ? WindowsIcons.chevron_left
                      : WindowsIcons.chevron_right),
                  onPressed: () =>
                      widget.panel.selectedTab(widget.panel.selectedTab() + 1),
                )
              : const SizedBox(width: 25),
          tabs: widget.panel.tabs
              .map((e) => Tab(
                    text: Txt(e.title),
                    icon: Icon(e.icon),
                    body: const SizedBox(),
                    disabled: e.onlyIfSaved && isNew,
                  ))
              .toList(),
        ),
      ),
    );
  }

  Widget _buildPanelHeader() {
    return GestureDetector(
      onTap: () {
        if (routes.minimizePanels()) routes.minimizePanels(false);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 2.8, horizontal: 5),
        color: ChatDentPalette.of(context).chrome,
        child: StreamBuilder(
            stream: widget.panel.inProgress.stream,
            builder: (context, snapshot) {
              return Row(
                children: [
                  Expanded(
                    child: Row(
                      spacing: 2,
                      children: [
                        Flexible(child: _buildPanelHeaderStoreName()),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: _buildPanelHeaderItemName(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(children: [
                    if (routes.panels().length > 1) _buildPanelSwitcher(),
                    // minimization is useless is prevented in big screens
                    if (widget.layoutWidth < 710) _buildPanelMinimizeButton(),
                    widget.panel.inProgress()
                        ? const SizedBox(
                            height: 20, width: 20, child: ProgressRing())
                        : _buildPanelCloseButton()
                  ])
                ],
              );
            }),
      ),
    );
  }

  Widget _buildPanelCloseButton() {
    return FlyoutTarget(
      controller: confirmCancelController,
      child: IconButton(
        icon: const Icon(WindowsIcons.cancel),
        onPressed: closeOrConfirmCancel,
      ),
    );
  }

  IconButton _buildPanelMinimizeButton() {
    return IconButton(
      icon: Icon(routes.minimizePanels()
          ? WindowsIcons.chevron_up
          : WindowsIcons.chevron_down),
      onPressed: () => routes.minimizePanels(!routes.minimizePanels()),
    );
  }

  FlyoutTarget _buildPanelSwitcher() {
    return FlyoutTarget(
      controller: panelSwitchController,
      child: IconButton(
        icon: Row(
          spacing: 2,
          children: [
            const Icon(FluentIcons.reopen_pages),
            Text(
              routes.panels().length.toString(),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            )
          ],
        ),
        onPressed: openPanelSwitch,
      ),
    );
  }

  Widget _buildPanelHeaderStoreName() {
    return Row(
      children: [
        Txt(
          widget.panel.unicodeSymbol,
          style: const TextStyle(fontSize: 20),
        ),
        Expanded(
          child: Txt(
            txt(widget.panel.singularName),
            style: TextStyle(
                fontFamily: ChatDentFonts.ui,
                fontSize: 12,
                color: ChatDentPalette.of(context).muted,
                fontWeight: FontWeight.w500),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildPanelHeaderItemName() {
    return ItemTitle(
      radius: 0,
      fontSize: 13,
      item: widget.panel.title != null
          ? Model.fromJson({"title": widget.panel.title})
          : widget.panel.item,
      predefinedColor:
          widget.panel.item.archived == true ? Colors.grey : null,
    );
  }

  void closeOrConfirmCancel() async {
    if (widget.panel.hasUnsavedChanges() == false) {
      routes.closePanel(widget.panel.item.id);
    } else {
      await flyoutFocusFix(context);
      confirmCancelController.showFlyout(builder: (context) {
        return FlyoutContent(
          constraints: const BoxConstraints(maxWidth: 350),
          color: ChatDentPalette.of(context).card,
          child: Column(
            spacing: 12,
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Txt(txt("sureClosePanel")),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FilledButton(
                    style: filledButtonStyle(Colors.warningPrimaryColor),
                    onPressed: () {
                      Flyout.of(context).close();
                      routes.closePanel(widget.panel.item.id);
                    },
                    child: Row(
                      children: [
                        const Icon(FluentIcons.check_mark, size: 16),
                        const SizedBox(width: 5),
                        Txt(txt("sure")),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  CloseButtonInDialog(buttonText: txt("back")),
                ],
              ),
            ],
          ),
        );
      });
    }
  }

  void openPanelSwitch() async {
    await flyoutFocusFix(context);
    panelSwitchController.showFlyout(
      barrierDismissible: widget.layoutWidth < 710,
      dismissWithEsc: true,
      dismissOnPointerMoveAway: true,
      builder: (context) => MenuFlyout(items: [
        ...([...routes.panels()]
              ..sort((a, b) => b.creationDate - a.creationDate))
            .map((panel) {
          return MenuFlyoutItem(
            selected: panel == widget.panel,
            leading: Icon(panel.icon),
            trailing: panel.inProgress()
                ? const SizedBox(height: 20, width: 20, child: ProgressRing())
                : Icon(widget.panel.canNotBeNew == false &&
                        panel.store.get(panel.item.id) == null
                    ? FluentIcons.add
                    : FluentIcons.edit),
            text: Txt(
                "${txt(panel.singularName)}: ${panel.title ?? panel.item.title}",
                style: TextStyle(
                    fontWeight:
                        panel == widget.panel ? FontWeight.w500 : null)),
            onPressed: () =>
                routes.bringPanelToFront(routes.panels().indexOf(panel)),
            closeAfterClick: true,
          );
        })
      ]),
    );
  }
}
