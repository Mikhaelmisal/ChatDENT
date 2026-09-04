import 'dart:convert';

import 'package:chatdent/app/chatdent_theme.dart';
import 'package:chatdent/app/routes.dart';
import 'package:chatdent/common_widgets/appointments_list_footer.dart';
import 'package:chatdent/common_widgets/audio_recorder.dart';
import 'package:chatdent/common_widgets/birthdate_picker_dialog.dart';
import 'package:chatdent/common_widgets/button_styles.dart';
import 'package:chatdent/common_widgets/contact_buttons.dart';
import 'package:chatdent/common_widgets/error_dialog.dart';
import 'package:chatdent/common_widgets/extra_notes_expander.dart';
import 'package:chatdent/common_widgets/live_transcribing_textfield.dart';
import 'package:chatdent/common_widgets/teeth_selector/teeth_selector.dart';
import 'package:chatdent/common_widgets/teeth_selector/tx_options.dart';
import 'package:chatdent/core/multi_stream_builder.dart';
import 'package:chatdent/core/observable.dart';
import 'package:chatdent/features/appointments/appointment_model.dart';
import 'package:chatdent/services/ai_services/dental_history.dart';
import 'package:chatdent/services/login.dart';
import 'package:chatdent/services/network.dart';
import 'package:chatdent/utils/color_based_on_payment.dart';
import 'package:chatdent/services/localization/locale.dart';
import 'package:chatdent/utils/constants.dart';
import 'package:chatdent/utils/dd_mm_yyyy_input_formatter.dart';
import 'package:chatdent/utils/flyout_focus_fix.dart';
import 'package:chatdent/utils/india_phone.dart';
import 'package:chatdent/utils/iso_to_textual.dart';
import 'package:chatdent/utils/logger.dart';
import 'package:chatdent/utils/parsed_phone_number.dart';
import 'package:chatdent/utils/print/print_link.dart';
import 'package:chatdent/common_widgets/appointment_card.dart';
import 'package:chatdent/common_widgets/qrlink.dart';
import 'package:chatdent/common_widgets/tag_input.dart';
import 'package:chatdent/features/appointments/appointments_store.dart';
import 'package:chatdent/features/leads/clinic_whatsapp.dart';
import 'package:chatdent/features/patients/patient_model.dart';
import 'package:chatdent/features/invoices/patient_invoices.dart';
import 'package:chatdent/features/prescriptions/patient_prescriptions.dart';
import 'package:chatdent/features/patients/patients_store.dart';
import 'package:chatdent/features/settings/settings_stores.dart';
import 'package:chatdent/widget_keys.dart';
import 'package:fluent_ui/fluent_ui.dart' hide TextBox;
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

final transcriptionEditCounter = ObservableState(0);

Future<Patient> openPatient([Patient? patient, int? selectedTabIndex]) {
  final editingCopy = Patient.fromJson(patient?.toJson() ?? {});
  final wasNew = patients.get(editingCopy.id) == null;
  final previous = wasNew ? null : Patient.fromJson(patient!.toJson());
  late final Panel<Patient> panel;
  panel = Panel<Patient>(
    singularName: "patient",
    unicodeSymbol: "👤",
    selectedTabIndex: selectedTabIndex,
    item: editingCopy,
    store: patients,
    icon: FluentIcons.medication_admin,
    title: wasNew ? txt("newPatient") : editingCopy.title,
    onSave: () {
      final isFirstSave = patients.get(editingCopy.id) == null;
      final hadPhone =
          previous != null && previous.phonesString.trim().isNotEmpty;
      patients.set(editingCopy);
      panel.savedJson = jsonEncode(editingCopy.toJson());
      panel.identifier = editingCopy.id;
      if (!panel.result.isCompleted) {
        panel.result.complete(editingCopy);
      }
      final shouldWelcome = editingCopy.phonesString.trim().isNotEmpty &&
          !editingCopy.welcomeWhatsAppSent &&
          editingCopy.intakeSource == PatientIntakeSource.phoneCall &&
          (isFirstSave || !hadPhone);
      if (shouldWelcome) {
        editingCopy.welcomeWhatsAppSent = true;
        patients.set(editingCopy);
        panel.savedJson = jsonEncode(editingCopy.toJson());
        ClinicWhatsApp.sendForNewPatient(editingCopy);
      }
      if (editingCopy.whatsappHold || editingCopy.archived == true) {
        for (final a in appointments.present.values) {
          if (a.patientID != editingCopy.id) continue;
          if (a.briefConfirmDueMs == null && !a.briefConfirmSent) continue;
          a.briefConfirmDueMs = null;
          appointments.set(a);
        }
      }
    },
    tabs: [
      PanelTab(
        title: txt("patientDetails"),
        icon: FluentIcons.medication_admin,
        body: _PatientDetails(editingCopy),
      ),
      PanelTab(
        title: txt("dentalNotes"),
        icon: FluentIcons.teeth,
        footer: (network.isOnline() && globalSettings.aiServicesEnabled)
            ? Builder(
                builder: (context) => AudioRecorderButton(
                  hint: txt("dentalHistoryVoiceAutoFillHint"),
                  label: txt("voiceAutoFill"),
                  onRecordingComplete: (bytes, mimeType) async {
                    try {
                      final result = await DentalHistory.processAudioBytes(
                        bytes,
                        mimeType,
                      );
                      if (result.teeth.isNotEmpty) {
                        editingCopy.teeth.addAll(result.teeth);
                      }
                      if (result.teethExtraNotes.isNotEmpty) {
                        editingCopy.teethExtraNotes
                            .addAll(result.teethExtraNotes);
                      }
                      transcriptionEditCounter(transcriptionEditCounter() + 1);
                    } catch (e, s) {
                      showErrorMessage(e, "processingDentalHistory");
                      logger("Error processing dental history audio: $e", s);
                    }
                  },
                ),
              )
            : null,
        body: MStreamBuilder(
            streams: [
              patients.observableMap.stream,
              appointments.observableMap.stream,
              transcriptionEditCounter.stream
            ],
            builder: (context, asyncSnapshot) {
              return InfoLabel(
                label: "${txt("dentalNotes")}:",
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      decoration: chatDentInnerCard(ChatDentPalette.of(context)),
                      padding: const EdgeInsets.all(4),
                      child: TeethSelector(
                        key: ValueKey(jsonEncode({
                          ...editingCopy.teeth,
                          ...editingCopy.teethExtraNotes
                        })),
                        type: StateType.state,
                        onNote: (x, y) {
                          if (y != null) {
                            editingCopy.teeth[x] = y;
                          } else {
                            editingCopy.teeth.remove(x);
                            editingCopy.teethExtraNotes.remove(x);
                          }
                        },
                        onExtraNote: (x, extra) {
                          editingCopy.teethExtraNotes[x] = extra;
                        },
                        extraNotes: editingCopy.teethExtraNotes,
                        notation: (isoString) =>
                            isoToTextualNotation(isoString),
                        rightString: txt("right"),
                        leftString: txt("left"),
                        currentNotes: editingCopy.teeth,
                        oldNotes: editingCopy.allAppointmentsDentalNotes
                          ..removeWhere(
                              (k, v) => editingCopy.teeth.containsKey(k)),
                        showPrimary: editingCopy.age < 14,
                      ),
                    ),
                    if (editingCopy.allAppointmentsDentalNotes.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const Divider(),
                      const SizedBox(height: 12),
                      AppointmentExtraNotes(
                        patient: editingCopy,
                        initiallyExpanded: true,
                        bottomMargin: true,
                        title: txt("extraNotesFromAppointments"),
                      ),
                    ]
                  ],
                ),
              );
            }),
      ),
      if (login.perm(Perm.appointments).some)
        PanelTab(
          title: txt("appointments"),
          icon: WindowsIcons.calendar,
          body: PatientAppointments(editingCopy),
          footer: AppointmentsListFooter(forPatientID: editingCopy.id),
          onlyIfSaved: true,
          padding: 0,
        ),
      if (login.perm(Perm.appointments).some)
        PanelTab(
          title: txt("prescriptions"),
          icon: FluentIcons.pill,
          body: PatientPrescriptions(editingCopy),
          onlyIfSaved: true,
          padding: 0,
        ),
      if (login.perm(Perm.appointments).some)
        PanelTab(
          title: txt("invoices"),
          icon: FluentIcons.money,
          body: PatientInvoices(editingCopy),
          onlyIfSaved: true,
          padding: 0,
        ),
      PanelTab(
        title: txt("patientPage"),
        icon: FluentIcons.q_r_code,
        body: _PatientQrPage(editingCopy: editingCopy),
        onlyIfSaved: true,
      ),
    ],
  );
  routes.openPanel(panel);
  return panel.result.future;
}

class _PatientQrPage extends StatefulWidget {
  const _PatientQrPage({
    required this.editingCopy,
  });

  final Patient editingCopy;

  @override
  State<_PatientQrPage> createState() => _PatientQrPageState();
}

class _PatientQrPageState extends State<_PatientQrPage> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 25),
        Center(
          child: FilledButton(
            child: ButtonContent(FluentIcons.q_r_code, txt("generateQRLink")),
            onPressed: () async {
              final pID = widget.editingCopy.id;
              final p = patients.get(pID);
              if (p == null) {
                return;
              } else {
                try {
                  p.link = await p.generatePatientLink();
                } catch (e, stacktrace) {
                  showErrorMessage(e, "generatingPatientLink");
                  login.askForLoginAgain(e);
                  logger("error while generating patient link $e", stacktrace);
                }
                patients.set(p);
                widget.editingCopy.link = p.link;
              }
              setState(() {});
            },
          ),
        ),
        if (widget.editingCopy.shortLink.isNotEmpty) ...[
          const SizedBox(height: 10),
          _PatientWebPage(widget.editingCopy),
          _PrintQRButton(widget.editingCopy)
        ]
      ],
    );
  }
}

class _PrintQRButton extends StatelessWidget {
  final Patient patient;
  const _PrintQRButton(this.patient);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FilledButton(
              child: Row(
                children: [
                  const Icon(FluentIcons.print),
                  const SizedBox(width: 5),
                  Txt(txt("printQR"))
                ],
              ),
              onPressed: () {
                printingQRCode(
                  context,
                  patient.shortLink,
                  "Access your information",
                  "Scan to visit link:\n${patient.shortLink}\nto access your appointments, payments and photos.",
                );
              }),
        ],
      ),
    );
  }
}

class _PatientWebPage extends StatelessWidget {
  final Patient patient;
  const _PatientWebPage(this.patient);

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      InfoBar(
        title: Txt(txt("patientCanUseTheFollowing")),
      ),
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.all(10),
        decoration: chatDentInnerCard(ChatDentPalette.of(context)),
        child: SelectableText(patient.shortLink),
      ),
      QRLink(link: patient.shortLink),
    ]);
  }
}

class PatientAppointments extends StatelessWidget {
  final Patient patient;
  final List<AppointmentSections> hide;
  final Appointment? excludedAppointment;
  final bool readOnly;
  const PatientAppointments(this.patient,
      {super.key,
      this.readOnly = false,
      this.excludedAppointment,
      this.hide = const [AppointmentSections.patient]});
  @override
  Widget build(BuildContext context) {
    return MStreamBuilder(
        streams: [appointments.observableMap.stream],
        builder: (context, snapshot) {
          final apts = patient.allAppointments;
          return Column(
            children: apts.isEmpty
                ? [
                    InfoBar(title: Txt(txt("noAppointmentsFound"))),
                  ]
                : [
                    ...List.generate(apts.length, (index) {
                      final appointment = apts[index];
                      String? difference;
                      if (apts.last != appointment &&
                          !hide.contains(AppointmentSections.timeDifference)) {
                        difference =
                            "${txt("after")} ${Patient.formatDuration(appointment.date, apts[index + 1].date)}";
                      }
                      if (appointment.id == excludedAppointment?.id) {
                        return const SizedBox.shrink();
                      }
                      return AppointmentCard(
                        key: Key(appointment.id),
                        appointment: appointment,
                        difference: difference,
                        hide: hide,
                        number: index + 1,
                        readOnly: readOnly,
                      );
                    }),
                    const Divider(),
                    if (!hide.contains(AppointmentSections.paymentSummary))
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 10, 12, 50),
                        child: Builder(builder: (context) {
                          final p = ChatDentPalette.of(context);
                          return Container(
                          padding: const EdgeInsets.all(6),
                          decoration: chatDentInnerCard(p).copyWith(
                            boxShadow: chatDentPopupShadow(p),
                          ),
                          child: Column(
                            children: [
                              Container(
                                height: 4,
                                width: double.infinity,
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  color: (colorBasedOnPayments(
                                              patient.paymentsMade,
                                              patient.pricesGiven) ??
                                          p.fluentBlue)
                                      .withValues(alpha: 0.45),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 5),
                                child: Txt(
                                    "${txt("paymentSummary")} (${currency()})",
                                    style: TextStyle(
                                        fontFamily: ChatDentFonts.ui,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: p.muted)),
                              ),
                              const SizedBox(height: 10),
                              const Divider(),
                              const SizedBox(height: 15),
                              Wrap(
                                alignment: WrapAlignment.center,
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  PaymentPill(
                                    finalTextColor: p.muted,
                                    title: txt("cost"),
                                    amount:
                                        patient.pricesGiven.toStringAsFixed(2),
                                  ),
                                  PaymentPill(
                                    finalTextColor: p.muted,
                                    title: txt("paid"),
                                    amount:
                                        patient.paymentsMade.toStringAsFixed(2),
                                  ),
                                  PaymentPill(
                                    finalTextColor: p.muted,
                                    title: patient.overPaid
                                        ? txt("overpaid")
                                        : patient.underPaid
                                            ? txt("underpaid")
                                            : txt("fullyPaid"),
                                    amount: (patient.paymentsMade -
                                            patient.pricesGiven)
                                        .abs()
                                        .toStringAsFixed(2),
                                  )
                                ],
                              ),
                            ],
                          ),
                        );
                        }),
                      ),
                  ],
          );
        });
  }
}

class _PatientDetails extends StatefulWidget {
  final Patient patient;
  const _PatientDetails(this.patient);

  @override
  State<_PatientDetails> createState() => _PatientDetailsState();
}

class _PatientDetailsState extends State<_PatientDetails> {
  final phoneTextController = TextEditingController();
  final emailTextController = TextEditingController();
  final phoneFlyoutController = FlyoutController();
  final birthdateFlyoutController = FlyoutController();
  final nameController = TextEditingController();
  final birthdateController = TextEditingController();
  final addressController = TextEditingController();
  final notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    phoneTextController.text = IndiaPhone.localDigitsFrom(widget.patient.phonesString);
    emailTextController.text = widget.patient.email;
    nameController.text = widget.patient.title;
    birthdateController.text = _initialBirthdateText();
    addressController.text = widget.patient.address;
    notesController.text = widget.patient.notes;
  }

  String _capFirst(String value) {
    if (value.isEmpty) return "Birthdate";
    return value[0].toUpperCase() + value.substring(1);
  }

  String _initialBirthdateText() {
    if (widget.patient.hasFullBirthDate) {
      return widget.patient.birthDateString;
    }
    final defaultYear = DateTime.now().year - 18;
    if (widget.patient.birth == defaultYear) return '';
    return widget.patient.birth.toString();
  }

  void _applyIndiaPhone(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (IndiaPhone.isCompleteLocal(digits)) {
      try {
        widget.patient.phone = [
          ParsedPhoneNumber(IndiaPhone.e164(digits)),
        ];
        return;
      } catch (_) {
        // Fall through to clear an incomplete/invalid number.
      }
    }
    widget.patient.phone = [];
  }

  void _applyBirthdateInput(String value) {
    final date = Patient.tryParseBirthDate(value);
    if (date != null) {
      widget.patient.setBirthFromDate(date);
      return;
    }
    final year = Patient.tryParseBirthYear(value);
    if (year != null) {
      widget.patient.birth = year;
    }
  }

  Future<void> _pickBirthDate() async {
    await flyoutFocusFix(context);
    final initial = widget.patient.hasFullBirthDate
        ? widget.patient.birthAsDate
        : DateTime(widget.patient.birthYear, 1, 1);
    final now = DateTime.now();
    final selected = await showBirthdatePicker(
      controller: birthdateFlyoutController,
      initialDate: initial.isAfter(now) ? now : initial,
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (selected == null || !mounted) return;
    widget.patient.setBirthFromDate(selected);
    birthdateController.text = widget.patient.birthDateString;
    setState(() {});
  }

  @override
  void dispose() {
    phoneTextController.dispose();
    emailTextController.dispose();
    phoneFlyoutController.dispose();
    birthdateFlyoutController.dispose();
    nameController.dispose();
    birthdateController.dispose();
    addressController.dispose();
    notesController.dispose();
    super.dispose();
  }

  TextStyle _fieldTextStyle(BuildContext context) {
    final p = ChatDentPalette.of(context);
    return TextStyle(
      fontFamily: ChatDentFonts.ui,
      fontSize: FluentTheme.of(context).typography.body?.fontSize ?? 14,
      fontWeight: FontWeight.w600,
      color: p.stone,
    );
  }

  TextStyle _fieldPlaceholderStyle(BuildContext context) {
    return _fieldTextStyle(context).copyWith(
      fontWeight: FontWeight.w400,
      color: ChatDentPalette.of(context).muted,
    );
  }

  @override
  Widget build(BuildContext context) {
    final inputStyle = _fieldTextStyle(context);
    final hintStyle = _fieldPlaceholderStyle(context);
    final fieldFill = chatDentFieldFill(ChatDentPalette.of(context));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 10,
      children: [
        InfoLabel(
          label: "${txt("name")}:",
          isHeader: true,
          child: CupertinoTextField(
            key: WK.fieldPatientName,
            placeholder: "${txt("name")}...",
            style: inputStyle,
            placeholderStyle: hintStyle,
            decoration: fieldFill,
            controller: nameController,
            onChanged: (value) => widget.patient.title = value,
          ),
        ),
        Row(mainAxisSize: MainAxisSize.min, children: [
          Expanded(
            flex: 2,
            child: InfoLabel(
              label: "${_capFirst(txt("birthdate"))}:",
              isHeader: true,
              child: FlyoutTarget(
                controller: birthdateFlyoutController,
                child: CupertinoTextField(
                key: WK.fieldPatientYOB,
                placeholder: "DD/MM/YYYY",
                style: inputStyle,
                placeholderStyle: hintStyle,
                decoration: fieldFill,
                keyboardType: TextInputType.number,
                controller: birthdateController,
                inputFormatters: [ddMmYyyyInputFormatter],
                onChanged: _applyBirthdateInput,
                suffix: Tooltip(
                  message: txt("calendar"),
                  child: IconButton(
                    icon: const Icon(FluentIcons.calendar, size: 16),
                    onPressed: _pickBirthDate,
                  ),
                ),
              ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: InfoLabel(
              label: "${txt("gender")}:",
              isHeader: true,
              child: ComboBox<int>(
                key: WK.fieldPatientGender,
                isExpanded: true,
                items: [
                  ComboBoxItem<int>(
                    value: 1,
                    child: Txt("♂️ ${txt("male")}"),
                  ),
                  ComboBoxItem<int>(
                    value: 0,
                    child: Txt("♀️ ${txt("female")}"),
                  )
                ],
                value: widget.patient.gender,
                onChanged: (value) {
                  setState(() {
                    widget.patient.gender = value ?? widget.patient.gender;
                  });
                },
              ),
            ),
          ),
        ]),
        InfoLabel(
          label: "${txt("email")}:",
          isHeader: true,
          child: CupertinoTextField(
            textDirection: TextDirection.ltr,
            key: WK.fieldPatientEmail,
            placeholder: "${txt("email")}...",
            style: inputStyle,
            placeholderStyle: hintStyle,
            decoration: fieldFill,
            controller: emailTextController,
            onChanged: (value) {
              setState(() {
                widget.patient.email = value;
              });
            },
            suffix: widget.patient.email.isNotEmpty
                ? EmailButton(email: widget.patient.email)
                : null,
          ),
        ),
        InfoLabel(
          label: "${txt("phone")}:",
          isHeader: true,
          child: CupertinoTextField(
            prefix: Padding(
              padding: const EdgeInsets.only(left: 10, right: 6),
              child: Text(
                IndiaPhone.countryCode,
                style: inputStyle,
              ),
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
                : widget.patient.phone.isNotEmpty
                    ? PhoneNumberButton(
                        onlyIcon: true,
                        phoneNumbers: widget.patient.phone,
                      )
                    : null,
            textDirection: TextDirection.ltr,
            key: WK.fieldPatientPhone,
            placeholder: "9876543210",
            style: inputStyle,
            placeholderStyle: hintStyle,
            decoration: fieldFill,
            keyboardType: TextInputType.phone,
            controller: phoneTextController,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(IndiaPhone.localLength),
            ],
            onChanged: (value) {
              setState(() {
                _applyIndiaPhone(value);
              });
            },
          ),
        ),
        if (phoneTextController.text.isNotEmpty &&
            phoneTextController.text.length < IndiaPhone.localLength)
          Txt(txt("phoneMustBe10Digits")),
        InfoLabel(
          label: "${txt("patientIntakeSource")}:",
          isHeader: true,
          child: ComboBox<String>(
            isExpanded: true,
            value: widget.patient.intakeSource == PatientIntakeSource.phoneCall
                ? PatientIntakeSource.phoneCall
                : PatientIntakeSource.walkIn,
            items: [
              ComboBoxItem(
                value: PatientIntakeSource.walkIn,
                child: Text(txt("intakeWalkIn")),
              ),
              ComboBoxItem(
                value: PatientIntakeSource.phoneCall,
                child: Text(txt("intakePhoneCall")),
              ),
            ],
            onChanged: (value) {
              setState(() {
                widget.patient.intakeSource =
                    value ?? PatientIntakeSource.walkIn;
              });
            },
          ),
        ),
        InfoLabel(
          label: "${txt("address")}:",
          isHeader: true,
          child: CupertinoTextField(
            key: WK.fieldPatientAddress,
            controller: addressController,
            style: inputStyle,
            placeholderStyle: hintStyle,
            decoration: fieldFill,
            onChanged: (value) => widget.patient.address = value,
            placeholder: "${txt("address")}...",
          ),
        ),
        InfoLabel(
          label: "${txt("notes")}:",
          isHeader: true,
          child: LiveTranscribingTextField(
            key: WK.fieldPatientNotes,
            controller: notesController,
            style: inputStyle,
            placeholderStyle: hintStyle,
            onChanged: (value) => setState(() => widget.patient.notes = value),
            maxLines: null,
            placeholder: "${txt("notes")}...",
          ),
        ),
        InfoLabel(
          label: "${txt("patientTags")}:",
          isHeader: true,
          child: TagInputWidget(
            key: WK.fieldPatientTags,
            suggestions: patients.allTags
                .map((t) => TagInputItem(value: t, label: t))
                .toList(),
            onChanged: (tags) {
              widget.patient.tags = List<String>.from(
                  tags.map((e) => e.value).where((e) => e != null));
            },
            initialValue: widget.patient.tags
                .map((e) => TagInputItem(value: e, label: e))
                .toList(),
            strict: false,
            limit: 9999,
            placeholder: "${txt("patientTags")}...",
          ),
        ),
        Checkbox(
          checked: widget.patient.whatsappHold,
          content: Text(txt("whatsappHoldPatient")),
          onChanged: (v) {
            setState(() {
              widget.patient.whatsappHold = v == true;
            });
          },
        ),
        if (widget.patient.whatsappHold)
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 6),
            child: Txt(txt("whatsappHoldPatientHint")),
          ),
        Checkbox(
          checked: widget.patient.treatmentCompleted,
          content: Text(txt("treatmentCompleted")),
          onChanged: (v) {
            setState(() {
              widget.patient.treatmentCompleted = v == true;
            });
          },
        ),
        if (widget.patient.reviewDone)
          Txt(txt("reviewAlreadyReceived"))
        else if (widget.patient.reviewAskCount >= 1)
          Txt(txt("reviewAlreadySent"))
        else
          FilledButton(
            onPressed: !widget.patient.treatmentCompleted ||
                    widget.patient.whatsappHold ||
                    widget.patient.phonesString.trim().isEmpty
                ? null
                : () async {
                    final ok =
                        await ClinicWhatsApp.sendReviewRequest(widget.patient);
                    if (!context.mounted) return;
                    setState(() {});
                    if (ok) {
                      displayInfoBar(
                        context,
                        builder: (context, close) => InfoBar(
                          title: Txt(txt("reviewRequestSent")),
                          severity: InfoBarSeverity.success,
                          action: IconButton(
                            icon: const Icon(FluentIcons.clear),
                            onPressed: close,
                          ),
                        ),
                      );
                    } else {
                      displayInfoBar(
                        context,
                        builder: (context, close) => InfoBar(
                          title: Txt(txt("reviewRequestSkipped")),
                          severity: InfoBarSeverity.warning,
                          action: IconButton(
                            icon: const Icon(FluentIcons.clear),
                            onPressed: close,
                          ),
                        ),
                      );
                    }
                  },
            child: ButtonContent(
              FluentIcons.favorite_star,
              txt("sendReviewRequest"),
            ),
          ),
      ],
    );
  }
}
