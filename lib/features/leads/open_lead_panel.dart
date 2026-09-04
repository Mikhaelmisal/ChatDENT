import 'package:chatdent/app/routes.dart';
import 'package:chatdent/common_widgets/button_styles.dart';
import 'package:chatdent/common_widgets/clinic_slot_time_picker.dart';
import 'package:chatdent/common_widgets/contact_buttons.dart';
import 'package:chatdent/core/multi_stream_builder.dart';
import 'package:chatdent/features/accounts/accounts_controller.dart';
import 'package:chatdent/features/appointments/appointment_model.dart';
import 'package:chatdent/features/appointments/appointments_store.dart';
import 'package:chatdent/features/appointments/open_appointment_panel.dart';
import 'package:chatdent/features/leads/booking_service.dart';
import 'package:chatdent/features/leads/lead_model.dart';
import 'package:chatdent/features/leads/leads_store.dart';
import 'package:chatdent/features/leads/slot_engine.dart';
import 'package:chatdent/features/patients/open_patient_panel.dart';
import 'package:chatdent/features/patients/patient_model.dart';
import 'package:chatdent/features/patients/patients_store.dart';
import 'package:chatdent/services/localization/locale.dart';
import 'package:chatdent/services/login.dart';
import 'package:chatdent/utils/constants.dart';
import 'package:chatdent/utils/india_phone.dart';
import 'package:chatdent/utils/parsed_phone_number.dart';
import 'package:chatdent/features/settings/settings_stores.dart';
import 'package:chatdent/widget_keys.dart';
import 'package:fluent_ui/fluent_ui.dart' hide TextBox;
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

Future<Lead> openLead([Lead? lead, int? selectedTabIndex]) {
  final editingCopy = Lead.fromJson(lead?.toJson() ?? {});
  final panel = Panel<Lead>(
    singularName: 'lead',
    unicodeSymbol: '📣',
    selectedTabIndex: selectedTabIndex,
    item: editingCopy,
    store: leads,
    icon: FluentIcons.people,
    title: leads.get(editingCopy.id) == null
        ? txt('newLead')
        : editingCopy.title,
    tabs: [
      PanelTab(
        title: txt('leadDetails'),
        icon: FluentIcons.contact,
        body: _LeadDetails(editingCopy),
      ),
      PanelTab(
        title: txt('followUp'),
        icon: FluentIcons.phone,
        body: _LeadFollowUp(editingCopy),
      ),
    ],
  );
  routes.openPanel(panel);
  return panel.result.future;
}

TextStyle _fieldTextStyle(BuildContext context) {
  final body = FluentTheme.of(context).typography.body;
  return TextStyle(
    fontSize: body?.fontSize ?? 14,
    fontWeight: FontWeight.w600,
    color: body?.color,
  );
}

TextStyle _fieldPlaceholderStyle(BuildContext context) {
  return _fieldTextStyle(context).copyWith(
    fontWeight: FontWeight.w400,
    color: FluentTheme.of(context).resources.textFillColorSecondary,
  );
}

bool get _canEditLeads =>
    login.perm(Perm.leads).full || login.isAdmin;

class _LeadDetails extends StatefulWidget {
  final Lead lead;
  const _LeadDetails(this.lead);

  @override
  State<_LeadDetails> createState() => _LeadDetailsState();
}

class _LeadDetailsState extends State<_LeadDetails> {
  final nameController = TextEditingController();
  final phoneTextController = TextEditingController();
  final emailTextController = TextEditingController();
  final campaignController = TextEditingController();
  final interestController = TextEditingController();
  final notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    nameController.text = widget.lead.title;
    phoneTextController.text =
        IndiaPhone.localDigitsFrom(widget.lead.phonesString);
    emailTextController.text = widget.lead.email;
    campaignController.text = widget.lead.campaign;
    interestController.text = widget.lead.interest;
    notesController.text = widget.lead.notes;
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneTextController.dispose();
    emailTextController.dispose();
    campaignController.dispose();
    interestController.dispose();
    notesController.dispose();
    super.dispose();
  }

  void _applyIndiaPhone(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (IndiaPhone.isCompleteLocal(digits)) {
      try {
        widget.lead.phone = [ParsedPhoneNumber(IndiaPhone.e164(digits))];
        return;
      } catch (_) {}
    }
    widget.lead.phone = [];
  }

  @override
  Widget build(BuildContext context) {
    final inputStyle = _fieldTextStyle(context);
    final hintStyle = _fieldPlaceholderStyle(context);
    final enabled = _canEditLeads && !widget.lead.locked;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InfoLabel(
          label: '${txt("name")}:',
          isHeader: true,
          child: CupertinoTextField(
            key: WK.fieldLeadName,
            enabled: enabled,
            placeholder: '${txt("name")}...',
            style: inputStyle,
            placeholderStyle: hintStyle,
            controller: nameController,
            onChanged: (value) => widget.lead.title = value,
          ),
        ),
        InfoLabel(
          label: '${txt("phone")}:',
          isHeader: true,
          child: CupertinoTextField(
            prefix: Padding(
              padding: const EdgeInsets.only(left: 10, right: 6),
              child: Text(IndiaPhone.countryCode, style: inputStyle),
            ),
            suffix: phoneTextController.text.isNotEmpty &&
                    phoneTextController.text.length < IndiaPhone.localLength
                ? const Padding(
                    padding: EdgeInsets.all(5),
                    child: Icon(
                      WindowsIcons.warning,
                      color: Colors.warningPrimaryColor,
                    ),
                  )
                : widget.lead.phone.isNotEmpty
                    ? PhoneNumberButton(
                        onlyIcon: true,
                        phoneNumbers: widget.lead.phone,
                      )
                    : null,
            textDirection: TextDirection.ltr,
            key: WK.fieldLeadPhone,
            enabled: enabled,
            placeholder: '9876543210',
            style: inputStyle,
            placeholderStyle: hintStyle,
            keyboardType: TextInputType.phone,
            controller: phoneTextController,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(IndiaPhone.localLength),
            ],
            onChanged: (value) {
              _applyIndiaPhone(value);
              setState(() {});
            },
          ),
        ),
        if (phoneTextController.text.isNotEmpty &&
            phoneTextController.text.length < IndiaPhone.localLength)
          Txt(txt('phoneMustBe10Digits')),
        InfoLabel(
          label: '${txt("email")}:',
          isHeader: true,
          child: CupertinoTextField(
            textDirection: TextDirection.ltr,
            key: WK.fieldLeadEmail,
            enabled: enabled,
            placeholder: '${txt("email")}...',
            style: inputStyle,
            placeholderStyle: hintStyle,
            controller: emailTextController,
            onChanged: (value) {
              setState(() => widget.lead.email = value);
            },
            suffix: widget.lead.email.isNotEmpty
                ? EmailButton(email: widget.lead.email)
                : null,
          ),
        ),
        Row(
          children: [
            Expanded(
              child: InfoLabel(
                label: '${txt("leadSource")}:',
                isHeader: true,
                child: ComboBox<String>(
                  isExpanded: true,
                  value: LeadSource.all.contains(widget.lead.source)
                      ? widget.lead.source
                      : LeadSource.other,
                  items: [
                    for (final s in LeadSource.all)
                      ComboBoxItem(value: s, child: Txt(txt(s))),
                  ],
                  onChanged: enabled
                      ? (v) => setState(() => widget.lead.source = v ?? widget.lead.source)
                      : null,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: InfoLabel(
                label: '${txt("campaign")}:',
                isHeader: true,
                child: CupertinoTextField(
                  enabled: enabled,
                  placeholder: '${txt("campaign")}...',
                  style: inputStyle,
                  placeholderStyle: hintStyle,
                  controller: campaignController,
                  onChanged: (v) => widget.lead.campaign = v,
                ),
              ),
            ),
          ],
        ),
        InfoLabel(
          label: '${txt("interest")}:',
          isHeader: true,
          child: CupertinoTextField(
            enabled: enabled,
            placeholder: '${txt("interest")}...',
            style: inputStyle,
            placeholderStyle: hintStyle,
            controller: interestController,
            onChanged: (v) => widget.lead.interest = v,
          ),
        ),
        InfoLabel(
          label: '${txt("notes")}:',
          isHeader: true,
          child: CupertinoTextField(
            key: WK.fieldLeadNotes,
            enabled: enabled,
            maxLines: 4,
            placeholder: '${txt("notes")}...',
            style: inputStyle,
            placeholderStyle: hintStyle,
            controller: notesController,
            onChanged: (v) => widget.lead.notes = v,
          ),
        ),
      ],
    );
  }
}

class _LeadFollowUp extends StatefulWidget {
  final Lead lead;
  const _LeadFollowUp(this.lead);

  @override
  State<_LeadFollowUp> createState() => _LeadFollowUpState();
}

class _LeadFollowUpState extends State<_LeadFollowUp> {
  String? _bookError;
  String? _whatsappUrl;
  String? _selectedDoctorId;
  late DateTime _bookWhen;

  @override
  void initState() {
    super.initState();
    _bookWhen = booking.hours.snapToSlot(DateTime.now());
  }

  Patient? _ensurePatient() {
    if (widget.lead.patientID.isNotEmpty) {
      final existing = patients.get(widget.lead.patientID);
      if (existing != null) return existing;
    }
    if (widget.lead.phonesString.isNotEmpty) {
      for (final p in patients.present.values) {
        if (p.phonesString == widget.lead.phonesString) {
          widget.lead.patientID = p.id;
          return p;
        }
      }
    }
    final patient = Patient.fromJson({
      'title': widget.lead.title,
      if (widget.lead.phonesString.isNotEmpty) 'phone': widget.lead.phonesString,
      if (widget.lead.email.isNotEmpty) 'email': widget.lead.email,
      'notes': [
        if (widget.lead.source.isNotEmpty)
          '${txt("leadSource")}: ${widget.lead.sourceLabel}',
        if (widget.lead.campaign.isNotEmpty)
          '${txt("campaign")}: ${widget.lead.campaign}',
        if (widget.lead.notes.isNotEmpty) widget.lead.notes,
      ].join('\n'),
    });
    patients.set(patient);
    widget.lead.patientID = patient.id;
    return patient;
  }

  void _convert() {
    final patient = _ensurePatient();
    if (patient != null) {
      patient.fromLead = true;
      patient.fromLeadId = widget.lead.id;
      if (!patient.tags.contains('lead')) {
        patient.tags = [...patient.tags, 'lead'];
      }
      patients.set(patient);
    }
    widget.lead.stage = LeadStage.converted;
    widget.lead.called = true;
    if (leads.get(widget.lead.id) != null) {
      leads.set(widget.lead);
    }
    setState(() {});
  }

  void _bookSlot(FreeSlot slot) {
    try {
      final result = booking.book(
        lead: widget.lead,
        slot: slot,
        operatorId: slot.operatorId,
        durationMinutes: booking.hours.slotMinutes,
      );
      _bookError = null;
      _whatsappUrl = result.whatsappUrl;
      setState(() {});
    } on BookSlotException {
      setState(() => _bookError = txt('slotTaken'));
    }
  }

  void _setBookDate(DateTime day) {
    final hours = booking.hours;
    setState(() {
      _bookWhen = hours.snapToSlot(DateTime(
        day.year,
        day.month,
        day.day,
        _bookWhen.hour,
        _bookWhen.minute,
      ));
      _bookError = null;
    });
  }

  void _jumpBookDays(int days) {
    final n = DateTime.now();
    _setBookDate(DateTime(n.year, n.month, n.day).add(Duration(days: days)));
  }

  bool _isBookOffset(int days) {
    final n = DateTime.now();
    final target = DateTime(n.year, n.month, n.day).add(Duration(days: days));
    return _bookWhen.year == target.year &&
        _bookWhen.month == target.month &&
        _bookWhen.day == target.day;
  }

  void _bookPicked() {
    final hours = booking.hours;
    final when = hours.snapToSlot(_bookWhen);
    if (hours.slotStartsForLocalDate(when).isEmpty) {
      setState(() => _bookError = txt('closed'));
      return;
    }
    final op = _selectedDoctorId ??
        (booking.bookingOperatorIds().isEmpty
            ? ''
            : booking.bookingOperatorIds().first);
    final start = hours.applyMinutes(
      when,
      when.hour * 60 + when.minute,
    );
    _bookSlot(FreeSlot(
      id: FreeSlot.makeId(op, start),
      start: start,
      end: start.add(Duration(minutes: hours.slotMinutes)),
      operatorId: op,
    ));
  }

  void _sendWhatsAppConfirm() {
    final url = _whatsappUrl;
    if (url == null) return;
    launchUrl(Uri.parse(url));
  }

  void _schedule() {
    final patient = _ensurePatient();
    if (patient == null) return;
    widget.lead.stage = LeadStage.scheduled;
    if (leads.get(widget.lead.id) != null) {
      leads.set(widget.lead);
    }
    openAppointment(Appointment.fromJson({
      'patientID': patient.id,
      'duration': booking.hours.slotMinutes,
      if (login.perm(Perm.patients).exact(1) ||
          login.perm(Perm.appointments).exact(1) ||
          login.currentLoginIsOperator)
        'operatorsIDs': [login.currentAccountID],
    }));
  }

  @override
  Widget build(BuildContext context) {
    final enabled = _canEditLeads && !widget.lead.locked;
    final linked = widget.lead.patient;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InfoLabel(
          label: '${txt("leadStage")}:',
          isHeader: true,
          child: ComboBox<String>(
            isExpanded: true,
            value: LeadStage.all.contains(widget.lead.stage)
                ? widget.lead.stage
                : LeadStage.newLead,
            items: [
              for (final s in LeadStage.all)
                ComboBoxItem(
                  value: s,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 8,
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
            ],
            onChanged: enabled
                ? (v) => setState(() => widget.lead.stage = v ?? widget.lead.stage)
                : null,
          ),
        ),
        const SizedBox(height: 8),
        Checkbox(
          checked: widget.lead.called,
          onChanged: enabled
              ? (v) => setState(() => widget.lead.markCalled(v ?? false))
              : null,
          content: Txt(txt('leadCalled')),
        ),
        const SizedBox(height: 4),
        Checkbox(
          checked: widget.lead.isComing,
          onChanged: enabled && widget.lead.called
              ? (v) => setState(() => widget.lead.markComing(v ?? false))
              : null,
          content: Txt(txt('coming')),
        ),
        const SizedBox(height: 8),
        InfoLabel(
          label: '${txt("callOutcome")}:',
          isHeader: true,
          child: ComboBox<String>(
            isExpanded: true,
            value: CallOutcome.all.contains(widget.lead.callOutcome)
                ? widget.lead.callOutcome
                : CallOutcome.none,
            items: [
              for (final o in CallOutcome.all)
                ComboBoxItem(
                  value: o,
                  child: Txt(o.isEmpty ? '—' : txt(CallOutcome.labelKey(o))),
                ),
            ],
            onChanged: enabled
                ? (v) {
                    setState(() {
                      widget.lead.callOutcome = v ?? CallOutcome.none;
                      if (v == CallOutcome.booked ||
                          v == CallOutcome.callback) {
                        widget.lead.called = true;
                      }
                      if (v == CallOutcome.notInterested) {
                        widget.lead.stage = LeadStage.lost;
                      }
                    });
                  }
                : null,
          ),
        ),
        const SizedBox(height: 8),
        Checkbox(
          checked: widget.lead.assistantPaused,
          onChanged: enabled
              ? (v) =>
                  setState(() => widget.lead.assistantPaused = v ?? false)
              : null,
          content: Txt(txt('assistantOff')),
        ),
        if (widget.lead.sendError.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: InfoBar(
              title: Txt(txt('whatsappSendError')),
              content: Text(widget.lead.sendError),
              severity: InfoBarSeverity.warning,
              action: enabled
                  ? Button(
                      onPressed: () =>
                          setState(() => widget.lead.sendError = ''),
                      child: Txt(txt('done')),
                    )
                  : null,
            ),
          ),
        const SizedBox(height: 8),
        Checkbox(
          checked: widget.lead.whatsappConsent,
          onChanged: enabled
              ? (v) =>
                  setState(() => widget.lead.whatsappConsent = v ?? false)
              : null,
          content: Txt(txt('whatsappConsent')),
        ),
        const SizedBox(height: 12),
        if (widget.lead.phone.isNotEmpty)
          Row(
            spacing: 8,
            children: [
              PhoneNumberButton(
                onlyIcon: false,
                showFlag: false,
                phoneNumbers: widget.lead.phone,
              ),
            ],
          ),
        const SizedBox(height: 16),
        if (enabled && login.perm(Perm.appointments).some) ...[
          if (widget.lead.canBookVisit)
            MStreamBuilder(
              streams: [
                appointments.observableMap.stream,
                accounts.list.stream,
              ],
              builder: (context, _) => _buildDoctorBooking(enabled),
            ),
          if (_bookError != null)
            InfoBar(
              title: Text(_bookError!),
              severity: InfoBarSeverity.error,
            ),
          if (_whatsappUrl != null && widget.lead.whatsappConsent)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: FilledButton(
                onPressed: _sendWhatsAppConfirm,
                child: ButtonContent(
                    WindowsIcons.message, txt('sendWhatsappConfirm')),
              ),
            ),
          const SizedBox(height: 8),
        ],
        if (linked != null) ...[
          InfoBar(
            isLong: true,
            title: Txt(txt('linkedPatient')),
            content: Text(linked.title),
            action: Button(
              onPressed: () => openPatient(linked),
              child: Txt(txt('openPatient')),
            ),
          ),
        ] else if (enabled)
          FilledButton(
            onPressed: _convert,
            child: ButtonContent(FluentIcons.medication_admin, txt('convertToPatient')),
          ),
        const SizedBox(height: 8),
        if (enabled && login.perm(Perm.appointments).some)
          Button(
            onPressed: _schedule,
            child: ButtonContent(FluentIcons.add_event, txt('scheduleAppointment')),
          ),
      ],
    );
  }

  Widget _buildDoctorBooking(bool enabled) {
    final boards = booking.doctorBoards();
    if (boards.isEmpty) {
      return Txt(txt('noFreeSlots'));
    }
    final selectedId = _selectedDoctorId != null &&
            boards.any((b) => b.operatorId == _selectedDoctorId)
        ? _selectedDoctorId!
        : boards.first.operatorId;
    final selected = boards.firstWhere(
      (b) => b.operatorId == selectedId,
      orElse: () => boards.first,
    );
    final hours = booking.hours;
    final dayBooked = booking.bookedOn(
      operatorId: selected.operatorId,
      day: _bookWhen,
    );
    final dayOpen = hours.slotStartsForLocalDate(_bookWhen).isNotEmpty;
    final now = DateTime.now();
    final sameDay = _bookWhen.year == now.year &&
        _bookWhen.month == now.month &&
        _bookWhen.day == now.day;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InfoLabel(
          label: '${txt("pickDoctor")}:',
          child: ComboBox<String>(
            isExpanded: true,
            value: selected.operatorId,
            items: [
              for (final board in boards)
                ComboBoxItem(
                  value: board.operatorId,
                  child: Text(
                    board.name.isEmpty ? txt('doctors') : board.name,
                  ),
                ),
            ],
            onChanged: enabled
                ? (id) => setState(() => _selectedDoctorId = id)
                : null,
          ),
        ),
        const SizedBox(height: 8),
        InfoLabel(
          label: '${txt("date")}:',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 8,
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final days in [0, 1, 2, 3, 7])
                    ToggleButton(
                      checked: _isBookOffset(days),
                      onChanged: enabled
                          ? (_) => _jumpBookDays(days)
                          : null,
                      child: Text(days == 0 ? txt('today') : '+$days'),
                    ),
                ],
              ),
              DatePicker(
                selected: DateTime(
                  _bookWhen.year,
                  _bookWhen.month,
                  _bookWhen.day,
                ),
                startDate: DateTime(now.year, now.month, now.day),
                endDate: DateTime(now.year + 1, now.month, now.day),
                onChanged: enabled ? _setBookDate : null,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        InfoLabel(
          label: '${txt("time")}:',
          child: ClinicSlotTimePicker(
            value: _bookWhen,
            onChange: (d) => setState(() => _bookWhen = d),
          ),
        ),
        const SizedBox(height: 10),
        if (dayBooked.isNotEmpty) ...[
          Txt(sameDay ? txt('bookedToday') : DF.commonDate(_bookWhen)),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final apt in dayBooked)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: FluentTheme.of(context)
                          .resources
                          .controlStrokeColorDefault,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${DF.time(apt.date.toLocal())} ${apt.title.trim()}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
        ],
        FilledButton(
          onPressed: enabled && dayOpen ? _bookPicked : null,
          child: ButtonContent(FluentIcons.add_event, txt('addAppointment')),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
