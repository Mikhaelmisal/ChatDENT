import 'package:chatdent/app/chatdent_theme.dart';
import 'package:chatdent/common_widgets/notation.dart';
import 'package:chatdent/common_widgets/teeth_selector/tx_options.dart';
import 'package:chatdent/features/appointments/appointment_model.dart';
import 'package:chatdent/features/appointments/procedure_protocols.dart';
import 'package:chatdent/services/localization/locale.dart';
import 'package:fluent_ui/fluent_ui.dart';

class ProcedureStepsTracker extends StatelessWidget {
  const ProcedureStepsTracker({
    super.key,
    required this.appointment,
    required this.onChanged,
  });

  final Appointment appointment;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = ChatDentPalette.of(context);
    final entries = appointment.teeth.entries.toList()
      ..sort((a, b) => int.parse(a.key).compareTo(int.parse(b.key)));

    if (entries.isEmpty) {
      return Txt(
        txt("markTeethToTrackSteps"),
        style: FluentTheme.of(context).typography.caption!.copyWith(
              color: palette.muted,
              height: 1.4,
            ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < entries.length; i++) ...[
          if (i > 0) const SizedBox(height: 16),
          _ToothProtocolCard(
            iso: entries[i].key,
            label: entries[i].value,
            progress: appointment.procedureProgress.putIfAbsent(
              entries[i].key,
              () => ToothProcedureProgress(label: entries[i].value),
            ),
            onChanged: onChanged,
          ),
        ],
      ],
    );
  }
}

class _ToothProtocolCard extends StatelessWidget {
  const _ToothProtocolCard({
    required this.iso,
    required this.label,
    required this.progress,
    required this.onChanged,
  });

  final String iso;
  final String label;
  final ToothProcedureProgress progress;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final protocol = protocolFor(label);
    final steps = protocol.steps;
    final color = labelToColor(label);
    final visibleCount =
        (progress.done + 1).clamp(1, steps.length);
    final allDone = progress.done >= steps.length;
    final theme = FluentTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            DentalNotation(
              iso: iso,
              color: color,
              withTooltip: false,
            ),
            const SizedBox(width: 8),
            Icon(labelToIcon(label), size: 16, color: color),
            const SizedBox(width: 6),
            Expanded(
              child: Txt(
                "${txt(protocol.titleKey)} -",
                style: theme.typography.bodyStrong,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < visibleCount; i++)
          _StepRow(
            index: i,
            step: steps[i],
            progress: progress,
            isCompleted: i < progress.done,
            isCurrent: !allDone && i == progress.done,
            canUndo: i == progress.done - 1,
            onChanged: onChanged,
          ),
      ],
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.index,
    required this.step,
    required this.progress,
    required this.isCompleted,
    required this.isCurrent,
    required this.canUndo,
    required this.onChanged,
  });

  final int index;
  final ProcedureStepDef step;
  final ToothProcedureProgress progress;
  final bool isCompleted;
  final bool isCurrent;
  final bool canUndo;
  final VoidCallback onChanged;

  static const _doneGreen = Color(0xFF16A34A);
  static const _progressAmber = Color(0xFFC2410C);

  @override
  Widget build(BuildContext context) {
    final caption = FluentTheme.of(context).typography.caption!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  "${index + 1}. ${txt(step.titleKey)}",
                  style: caption.copyWith(
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                    color: isCompleted ? _doneGreen : null,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              HoverButton(
                onPressed: isCurrent
                    ? () {
                        progress.done += 1;
                        onChanged();
                      }
                    : canUndo
                        ? () {
                            progress.done -= 1;
                            onChanged();
                          }
                        : null,
                builder: (context, states) {
                  final label = isCompleted
                      ? txt("completed")
                      : txt("inProgress");
                  final color =
                      isCompleted ? _doneGreen : _progressAmber;
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    child: Text(
                      label,
                      style: caption.copyWith(
                        color: color,
                        fontWeight: FontWeight.w700,
                        decoration: TextDecoration.underline,
                        decorationColor: color,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          if (step.fields.isNotEmpty && (isCurrent || isCompleted))
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 18),
              child: Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  for (final field in step.fields)
                    _StepField(
                      field: field,
                      value: progress.fields[field.id] ?? '',
                      onChanged: (v) {
                        progress.fields[field.id] = v;
                        onChanged();
                      },
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _StepField extends StatefulWidget {
  const _StepField({
    required this.field,
    required this.value,
    required this.onChanged,
  });

  final ProcedureFieldDef field;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  State<_StepField> createState() => _StepFieldState();
}

class _StepFieldState extends State<_StepField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant _StepField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && _controller.text != widget.value) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      child: InfoLabel(
        label: txt(widget.field.labelKey),
        child: TextBox(
          controller: _controller,
          placeholder: widget.field.placeholder,
          onChanged: widget.onChanged,
        ),
      ),
    );
  }
}
