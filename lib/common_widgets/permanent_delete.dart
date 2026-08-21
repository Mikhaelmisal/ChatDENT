import 'package:chatdent/common_widgets/button_styles.dart';
import 'package:chatdent/core/store.dart';
import 'package:chatdent/features/settings/settings_model.dart';
import 'package:chatdent/features/settings/settings_stores.dart';
import 'package:chatdent/services/localization/locale.dart';
import 'package:chatdent/utils/flyout_focus_fix.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';

/// 4-digit code required for irreversible [Store.permanentDelete].
class PermanentDeletePasscode {
  static const settingId = 'perm_del_pin___';
  static const defaultPin = '1234';

  static String get expected {
    final raw = globalSettings.get(settingId).value.trim();
    if (RegExp(r'^\d{4}$').hasMatch(raw)) return raw;
    return defaultPin;
  }

  static void save(String pin) {
    final cleaned = pin.trim();
    if (!RegExp(r'^\d{4}$').hasMatch(cleaned)) return;
    globalSettings.set(Setting.fromJson({
      'id': settingId,
      'value': cleaned,
    }));
  }
}

/// Delete control that asks for the clinic 4-digit passcode before confirming.
class PermanentDeleteButton extends StatefulWidget {
  const PermanentDeleteButton({
    super.key,
    required this.store,
    required this.itemId,
    required this.preview,
    this.onDeleted,
    this.style,
    this.label,
  });

  final Store store;
  final String itemId;
  final Widget preview;
  final VoidCallback? onDeleted;
  final ButtonStyle? style;
  final String? label;

  @override
  State<PermanentDeleteButton> createState() => _PermanentDeleteButtonState();
}

class _PermanentDeleteButtonState extends State<PermanentDeleteButton> {
  final FlyoutController flyoutController = FlyoutController();

  @override
  void dispose() {
    flyoutController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.label ?? txt('deleteForever');
    return FlyoutTarget(
      controller: flyoutController,
      child: IconButton(
        style: widget.style ??
            greyishErrorStyle(context),
        icon: ButtonContent(WindowsIcons.delete, label),
        onPressed: () async {
          await flyoutFocusFix(context);
          flyoutController.showFlyout(builder: (ctx) {
            return _PermanentDeleteFlyout(
              controller: flyoutController,
              preview: widget.preview,
              onConfirm: () async {
                await widget.store.permanentDelete(widget.itemId);
                widget.onDeleted?.call();
              },
            );
          });
        },
      ),
    );
  }

  ButtonStyle greyishErrorStyle(BuildContext context) {
    return ButtonStyle(
      backgroundColor: WidgetStatePropertyAll(Colors.red.withValues(alpha: 0.85)),
      foregroundColor: const WidgetStatePropertyAll(Colors.white),
      textStyle: const WidgetStatePropertyAll(TextStyle(fontSize: 13)),
    );
  }
}

class _PermanentDeleteFlyout extends StatefulWidget {
  const _PermanentDeleteFlyout({
    required this.controller,
    required this.preview,
    required this.onConfirm,
  });

  final FlyoutController controller;
  final Widget preview;
  final Future<void> Function() onConfirm;

  @override
  State<_PermanentDeleteFlyout> createState() => _PermanentDeleteFlyoutState();
}

class _PermanentDeleteFlyoutState extends State<_PermanentDeleteFlyout> {
  final TextEditingController _pin = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final typed = _pin.text.trim();
    if (typed != PermanentDeletePasscode.expected) {
      setState(() => _error = txt('wrongDeletePasscode'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      widget.controller.close();
      await widget.onConfirm();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FlyoutContent(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        spacing: 6,
        children: [
          Txt(
            '${txt('areYouSureYouWantTo')} ${txt('deleteForever')}?',
            style: FluentTheme.of(context)
                .typography
                .bodyStrong
                ?.copyWith(color: FluentTheme.of(context).inactiveColor),
          ),
          widget.preview,
          Txt(
            '(${txt('youWillNotBeAbleToRestore')})',
            style: FluentTheme.of(context).typography.caption?.copyWith(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
          ),
          SizedBox(
            width: 160,
            child: InfoLabel(
              label: txt('deletePasscode'),
              child: TextBox(
                controller: _pin,
                placeholder: '••••',
                obscureText: true,
                maxLength: 4,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(4),
                ],
                onSubmitted: (_) => _submit(),
              ),
            ),
          ),
          if (_error != null)
            Txt(
              _error!,
              style: TextStyle(color: Colors.red, fontSize: 12),
            ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Divider(size: 250),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FilledButton(
                onPressed: _busy ? null : _submit,
                style: const ButtonStyle(
                  backgroundColor:
                      WidgetStatePropertyAll(Colors.errorPrimaryColor),
                  foregroundColor: WidgetStatePropertyAll(Colors.white),
                ),
                child: Row(
                  children: [
                    const Icon(WindowsIcons.delete),
                    const SizedBox(width: 5),
                    Txt(txt('deleteForever')),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              FilledButton(
                onPressed: _busy
                    ? null
                    : () {
                        if (widget.controller.isOpen) {
                          widget.controller.close();
                        }
                      },
                style: const ButtonStyle(
                  backgroundColor: WidgetStatePropertyAll(Colors.grey),
                  foregroundColor: WidgetStatePropertyAll(Colors.white),
                ),
                child: Row(
                  children: [
                    const Icon(WindowsIcons.cancel),
                    const SizedBox(width: 5),
                    Txt(txt('cancel')),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Shared helper for bulk permanent deletes from Deleted Items.
Future<bool> confirmPermanentDeletePasscode(BuildContext context) async {
  final pin = TextEditingController();
  String? error;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setLocal) {
          return ContentDialog(
            title: Txt(txt('deleteForever')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Txt(txt('deleteForeverHint')),
                const SizedBox(height: 12),
                InfoLabel(
                  label: txt('deletePasscode'),
                  child: TextBox(
                    controller: pin,
                    placeholder: '••••',
                    obscureText: true,
                    maxLength: 4,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                    ],
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 8),
                  Txt(error!, style: TextStyle(color: Colors.red)),
                ],
              ],
            ),
            actions: [
              Button(
                child: Txt(txt('cancel')),
                onPressed: () => Navigator.pop(ctx, false),
              ),
              FilledButton(
                style: const ButtonStyle(
                  backgroundColor:
                      WidgetStatePropertyAll(Colors.errorPrimaryColor),
                ),
                child: Txt(txt('deleteForever')),
                onPressed: () {
                  if (pin.text.trim() != PermanentDeletePasscode.expected) {
                    setLocal(() => error = txt('wrongDeletePasscode'));
                    return;
                  }
                  Navigator.pop(ctx, true);
                },
              ),
            ],
          );
        },
      );
    },
  );
  pin.dispose();
  return ok == true;
}
