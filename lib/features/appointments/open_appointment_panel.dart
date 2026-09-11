import 'dart:convert';
import 'package:chatdent/app/chatdent_theme.dart';
import 'package:chatdent/app/routes.dart';
import 'package:chatdent/common_widgets/appointment_card.dart';
import 'package:chatdent/common_widgets/audio_recorder.dart';
import 'package:chatdent/common_widgets/button_styles.dart';
import 'package:chatdent/common_widgets/error_dialog.dart';
import 'package:chatdent/common_widgets/extra_notes_expander.dart';
import 'package:chatdent/common_widgets/money_display.dart';
import 'package:chatdent/common_widgets/teeth_selector/teeth_selector.dart';
import 'package:chatdent/common_widgets/teeth_selector/tx_options.dart';
import 'package:chatdent/core/observable.dart';
import 'package:chatdent/features/labwork/open_labwork_panel.dart';
import 'package:chatdent/features/leads/clinic_whatsapp.dart';
import 'package:chatdent/features/patients/patient_model.dart';
import 'package:chatdent/features/patients/patients_store.dart';
import 'package:chatdent/features/prescriptions/add_prescription_dialog.dart';
import 'package:chatdent/features/prescriptions/prescription_line.dart';
import 'package:chatdent/services/ai_services/post_op_notes.dart';
import 'package:chatdent/common_widgets/live_transcribing_textfield.dart';
import 'package:chatdent/services/login.dart';
import 'package:chatdent/services/network.dart';
import 'package:chatdent/utils/constants.dart';
import 'package:chatdent/utils/flyout_focus_fix.dart';
import 'package:chatdent/utils/iso_to_textual.dart';
import 'package:chatdent/utils/logger.dart';
import 'package:chatdent/services/localization/locale.dart';
import 'package:chatdent/features/patients/open_patient_panel.dart';
import 'package:chatdent/utils/money_editing_controller.dart';
import 'package:chatdent/utils/money_input_formatter.dart';
import 'package:chatdent/utils/print/print_prescription.dart';
import 'package:chatdent/common_widgets/clinic_slot_time_picker.dart';
import 'package:chatdent/common_widgets/date_time_picker.dart';
import 'package:chatdent/common_widgets/duration_pill.dart';
import 'package:chatdent/features/leads/clinic_hours.dart';
import 'package:chatdent/common_widgets/grid_gallery.dart';
import 'package:chatdent/common_widgets/operators_picker.dart';
import 'package:chatdent/common_widgets/patient_picker.dart';
import 'package:chatdent/features/appointments/appointment_model.dart';
import 'package:chatdent/features/appointments/appointments_store.dart';
import 'package:chatdent/features/appointments/appointment_procedure_carry.dart';
import 'package:chatdent/features/appointments/procedure_protocols.dart';
import 'package:chatdent/features/appointments/procedure_steps_tracker.dart';
import 'package:chatdent/features/settings/settings_stores.dart';
import 'package:chatdent/utils/uuid.dart';
import 'package:chatdent/widget_keys.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/cupertino.dart';

void closeAppointmentsPanels() {
  List<String> toClose = [];
  for (var panel in routes.panels()) {
    final identifier = panel.identifier;
    if (identifier.contains("appointments") ||
        appointments.get(identifier) != null) {
      toClose.add(identifier);
    }
  }
  for (final identifier in toClose) {
    routes.closePanel(identifier);
  }
}

final transcriptionEditCounter = ObservableState(0);

void openAppointment([Appointment? appointment, int? selectedTabIndex]) {
  closeLabworksPanels();

  final canViewPostOp = login.perm(Perm.postOp).exact(2) ||
      (login.perm(Perm.postOp).exact(1) &&
          appointment?.operatorsIDs.contains(login.currentAccountID) == true);

  if (appointment != null &&
      appointment.isDone &&
      selectedTabIndex == 0 &&
      canViewPostOp) {
    selectedTabIndex = 1;
  }

  final editingCopy = Appointment.fromJson(appointment?.toJson() ?? {});
  final previous = appointments.get(editingCopy.id) == null
      ? null
      : Appointment.fromJson(appointment!.toJson());
  if (previous == null) {
    final hours = ClinicHours.fromJsonString(
        globalSettings.get(ClinicHours.settingId).value);
    editingCopy.duration = hours.slotMinutes;
    editingCopy.date = hours.snapToSlot(editingCopy.date);
  }
  late final Panel<Appointment> panel;
  panel = Panel<Appointment>(
    singularName: "appointment",
    unicodeSymbol: "📅",
    selectedTabIndex: selectedTabIndex,
    item: editingCopy,
    store: appointments,
    icon: WindowsIcons.calendar,
    title: appointments.get(editingCopy.id) == null
        ? txt("addAppointment")
        : editingCopy.title,
    onSave: () {
      final wasNew = previous == null;
      final dateChanged = previous != null &&
          previous.date.millisecondsSinceEpoch !=
              editingCopy.date.millisecondsSinceEpoch;
      final becameDone = editingCopy.isDone && previous?.isDone != true;
      final becameNoShow =
          editingCopy.isNoShow && previous?.isNoShow != true;

      if (editingCopy.isNoShow) {
        editingCopy.isDone = false;
      }
      if (editingCopy.isDone) {
        editingCopy.isNoShow = false;
      }

      appointments.set(editingCopy);
      panel.savedJson = jsonEncode(editingCopy.toJson());
      panel.identifier = editingCopy.id;
      if (!panel.result.isCompleted) {
        panel.result.complete(editingCopy);
      }

      final patient = editingCopy.patientID == null
          ? null
          : patients.get(editingCopy.patientID!);
      if (patient == null || patient.phonesString.trim().isEmpty) return;

      if (becameNoShow && !editingCopy.noShowWhatsAppSent) {
        editingCopy.noShowWhatsAppSent = true;
        appointments.set(editingCopy);
        panel.savedJson = jsonEncode(editingCopy.toJson());
        ClinicWhatsApp.sendNoShow(
          appointment: editingCopy,
          patient: patient,
        );
        return;
      }

      if (becameDone && !editingCopy.aftercareWhatsAppSent) {
        editingCopy.aftercareWhatsAppSent = true;
        appointments.set(editingCopy);
        panel.savedJson = jsonEncode(editingCopy.toJson());
        ClinicWhatsApp.sendTreatmentDone(
          appointment: editingCopy,
          patient: patient,
        );
        return;
      }

      if ((wasNew || dateChanged) &&
          !editingCopy.isNoShow &&
          !editingCopy.isDone) {
        // Walk-ins and same-day post-visit patients: no confirm spam.
        // Phone-call bookings still get confirm / welcome+confirm.
        final skipConfirm =
            patient.intakeSource == PatientIntakeSource.walkIn ||
                ClinicWhatsApp.hadPostVisitWhatsAppToday(patient);
        if (wasNew && !editingCopy.confirmWhatsAppSent && !skipConfirm) {
          editingCopy.confirmWhatsAppSent = true;
          final useWelcomeConfirm = !patient.welcomeWhatsAppSent &&
              patient.intakeSource == PatientIntakeSource.phoneCall;
          if (useWelcomeConfirm) {
            patient.welcomeWhatsAppSent = true;
            patients.set(patient);
          }
          appointments.set(editingCopy);
          panel.savedJson = jsonEncode(editingCopy.toJson());
          ClinicWhatsApp.sendAppointmentBooked(
            appointment: editingCopy,
            patient: patient,
            useWelcomeConfirm: useWelcomeConfirm,
          );
        } else if (wasNew && skipConfirm) {
          // Mark confirm as handled so we never backfill spam later.
          editingCopy.confirmWhatsAppSent = true;
          appointments.set(editingCopy);
          panel.savedJson = jsonEncode(editingCopy.toJson());
        } else if (dateChanged) {
          appointments.set(editingCopy);
          ClinicWhatsApp.sendReschedule(
            appointment: editingCopy,
            patient: patient,
          );
        }
      }
    },
    tabs: [],
  );
  final tabs = [
    PanelTab(
      title: txt("appointment"),
      icon: WindowsIcons.calendar,
      body: _AppointmentDetails(editingCopy),
    ),
    if (canViewPostOp)
      PanelTab(
        title: txt("operativeDetails"),
        icon: FluentIcons.medical_care,
        body: _OperativeDetails(editingCopy),
        footer: (network.isOnline() && globalSettings.aiServicesEnabled)
            ? AudioRecorderButton(
                hint: txt("postOperativeVoiceAutoFillHint"),
                label: txt("voiceAutoFill"),
                onRecordingComplete: (bytes, mimeType) async {
                  try {
                    final existing = PostOpData(
                      postOpNotes: editingCopy.postOpNotes,
                      prescriptions: editingCopy.prescriptions,
                      price: editingCopy.price,
                      paid: editingCopy.paid,
                      teeth: editingCopy.teeth,
                      teethExtraNotes: editingCopy.teethExtraNotes,
                      hasLabwork: editingCopy.hasLabwork,
                      labName: editingCopy.labName,
                      labworkNotes: editingCopy.labworkNotes,
                    );
                    final result = await PostOpNotes.processAudioBytes(
                      bytes,
                      mimeType,
                      existingFields: existing,
                    );
                    if (result.postOpNotes.isNotEmpty) {
                      editingCopy.postOpNotes = result.postOpNotes;
                    }
                    if (result.prescriptions.isNotEmpty) {
                      editingCopy.prescriptions = result.prescriptions;
                    }
                    if (result.price != 0) editingCopy.price = result.price;
                    if (result.paid != 0) editingCopy.paid = result.paid;
                    if (result.teeth.isNotEmpty) {
                      editingCopy.teeth.addAll(result.teeth);
                    }
                    if (result.teethExtraNotes.isNotEmpty) {
                      editingCopy.teethExtraNotes
                          .addAll(result.teethExtraNotes);
                    }
                    editingCopy.hasLabwork = result.hasLabwork;
                    if (result.labName.isNotEmpty) {
                      editingCopy.labName = result.labName;
                    }
                    if (result.labworkNotes.isNotEmpty) {
                      editingCopy.labworkNotes = result.labworkNotes;
                    }

                    transcriptionEditCounter(transcriptionEditCounter() + 1);
                  } catch (e, s) {
                    showErrorMessage(e, "processingPostOpNotes");
                    logger("Error processing post-op notes audio: $e", s);
                  }
                },
              )
            : null,
      ),
    PanelTab(
      title: txt("prescription"),
      icon: FluentIcons.pill,
      body: _PrescriptionDetails(editingCopy),
    ),
    PanelTab(
      title: txt("gallery"),
      icon: FluentIcons.camera,
      body: _AppointmentGallery(panel),
      onlyIfSaved: true,
      padding: 0,
    ),
  ];
  panel.tabs.addAll(tabs);
  routes.openPanel(panel);
}

class _AppointmentGallery extends StatefulWidget {
  final Panel<Appointment> panel;
  const _AppointmentGallery(this.panel);

  @override
  State<_AppointmentGallery> createState() => _AppointmentGalleryState();
}

class _AppointmentGalleryState extends State<_AppointmentGallery> {
  @override
  Widget build(BuildContext context) {
    // Other appointments surfaced below the current one's gallery: include
    // any appointment that has photos OR DCM X-rays (deduped by id).
    final patient = widget.panel.item.patient;
    final otherImages = <Appointment>[];
    if (patient != null) {
      final seen = <String>{};
      for (final a in [
        ...patient.appointmentsWithImages,
        ...patient.appointmentsWithDcmImgs,
      ]) {
        if (a.id != widget.panel.item.id && seen.add(a.id)) {
          otherImages.add(a);
        }
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildCurrentAppointmentPhotos(),
        if (otherImages.isNotEmpty)
          _OtherAppointmentsPhotos(otherImages: otherImages),
      ],
    );
  }

  StreamBuilder<int> _buildCurrentAppointmentPhotos() {
    return StreamBuilder(
        stream: widget.panel.selectedTab.stream,
        builder: (context, _) {
          return StreamBuilder(
              stream: widget.panel.inProgress.stream,
              builder: (context, snapshot) {
                return GridGallery(
                  onProgress: (inProgress) {
                    setState(() {
                      widget.panel.inProgress(inProgress);
                    });
                  },
                  canDelete: login.perm(Perm.photos).exact(1),
                  rowId: widget.panel.item.id,
                  imgs: widget.panel.item.imgs,
                  dcmImgs: widget.panel.item.dcmImgs,
                  slideshowEnabled: true,
                  drawings: widget.panel.item.drawings,
                  onSaveDrawing: (img, drawing) {
                    widget.panel.item.drawings[img] = drawing;
                    appointments.set(widget.panel.item);
                    widget.panel.savedJson =
                        jsonEncode(widget.panel.item.toJson());
                  },
                  onPressDelete: (img) async {
                    widget.panel.inProgress(true);
                    try {
                      await appointments.deleteImg(widget.panel.item.id, img);
                      widget.panel.item.imgs.remove(img);
                      widget.panel.item.drawings.remove(img);
                      appointments.set(widget.panel.item);
                      widget.panel.savedJson =
                          jsonEncode(widget.panel.item.toJson());
                    } catch (e, s) {
                      showErrorMessage(e, "deletingPatientImageFromServer");
                      login.askForLoginAgain(e);
                      logger("Error during deleting image: $e", s);
                    }
                    widget.panel.inProgress(false);
                    widget.panel.selectedTab(widget.panel.selectedTab());
                  },
                  onPressDeleteDcm: (dcmName) async {
                    widget.panel.inProgress(true);
                    try {
                      await appointments.deleteDcmImg(
                          widget.panel.item.id, dcmName);
                      widget.panel.item.dcmImgs.remove(dcmName);
                      appointments.set(widget.panel.item);
                      widget.panel.savedJson =
                          jsonEncode(widget.panel.item.toJson());
                    } catch (e, s) {
                      showErrorMessage(e, "deletingPatientImageFromServer");
                      login.askForLoginAgain(e);
                      logger("Error during deleting DCM image: $e", s);
                    }
                    widget.panel.inProgress(false);
                    widget.panel.selectedTab(widget.panel.selectedTab());
                  },
                  uploadConfig: GalleryUploadConfig(
                    store: appointments,
                    canUpload: login.perm(Perm.photos).exact(1),
                    modelPersistence: (names) async {
                      widget.panel.item.imgs.addAll(names);
                      widget.panel.item.imgs =
                          widget.panel.item.imgs.toSet().toList();
                      appointments.set(widget.panel.item);
                      widget.panel.savedJson =
                          jsonEncode(widget.panel.item.toJson());
                      if (mounted) {
                        widget.panel.selectedTab(widget.panel.selectedTab());
                      }
                    },
                  ),
                );
              });
        });
  }
}

class _OtherAppointmentsPhotos extends StatelessWidget {
  const _OtherAppointmentsPhotos({required this.otherImages});

  final List<Appointment> otherImages;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Divider(),
        const SizedBox(height: 10),
        Txt(txt("otherPhotos"),
            style: FluentTheme.of(context)
                .typography
                .bodyStrong!
                .copyWith(fontStyle: FontStyle.italic)),
        const SizedBox(height: 10),
        ...List.generate(otherImages.length, (index) {
          return AppointmentCard(
            appointment: otherImages[index],
            number: index + 1,
            readOnly: true,
            showLeftBorder: false,
            showSectionTitle: false,
            photosClipCount: 999,
            openButtonColor: Colors.grey,
            hide: const [
              AppointmentSections.dentalNotes,
              AppointmentSections.doctors,
              AppointmentSections.labworks,
              AppointmentSections.patient,
              AppointmentSections.pay,
              AppointmentSections.postNotes,
              AppointmentSections.preNotes,
              AppointmentSections.prescriptions,
              AppointmentSections.appointmentNumber,
            ],
          );
        })
      ],
    );
  }
}

class _AppointmentDetails extends StatefulWidget {
  final Appointment appointment;
  const _AppointmentDetails(this.appointment);

  @override
  State<_AppointmentDetails> createState() => _AppointmentDetailsState();
}

class _AppointmentDetailsState extends State<_AppointmentDetails> {
  final TextEditingController noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    noteController.text = widget.appointment.preOpNotes;
  }

  @override
  void dispose() {
    noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InfoLabel(
          /// rebuild needed if a patient is selected/deselected
          key: Key(widget.appointment.patientID ?? ""),
          label: "${txt("patient")}:",
          child: Row(
              children: [
                Expanded(
                  child: PatientPicker(
                      value: widget.appointment.patientID,
                      onChanged: (id) {
                        setState(() {
                          widget.appointment.patientID = id;
                        });
                      }),
                ),
                const SizedBox(width: 5),
                if (widget.appointment.patientID == null)
                  Button(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6.0),
                        child: ButtonContent(
                            FluentIcons.add_friend, txt("newPatient")),
                      ),
                      onPressed: () async {
                        final newPatientId = uuid();
                        final newPatient = await openPatient(
                            Patient.fromJson({"id": newPatientId}));
                        routes.closePanel(newPatientId);
                        widget.appointment.patientID = newPatient.id;
                      })
                else
                  FilledButton(
                    child: ButtonContent(FluentIcons.go, txt("open")),
                    onPressed: () {
                      openPatient(widget.appointment.patient!);
                    },
                  )
              ]),
        ),
        InfoLabel(
          label: "${txt("doctors")}:",
          child: OperatorsPicker(
              value: widget.appointment.operatorsIDs,
              onChanged: (s) {
                widget.appointment.operatorsIDs = s;
              }),
        ),
        InfoLabel(
          label: "${txt("date")}:",
          child: DateTimePicker(
            key: WK.fieldAppointmentDate,
            initValue: widget.appointment.date,
            onChange: (d) {
              final hours = ClinicHours.fromJsonString(
                  globalSettings.get(ClinicHours.settingId).value);
              widget.appointment.date = hours.snapToSlot(DateTime(
                d.year,
                d.month,
                d.day,
                widget.appointment.date.hour,
                widget.appointment.date.minute,
              ));
              setState(() {});
            },
            buttonText: txt("changeDate"),
            buttonIcon: WindowsIcons.calendar,
          ),
        ),
        InfoLabel(
          label: "${txt("time")}:",
          child: ClinicSlotTimePicker(
            hourKey: WK.fieldAppointmentTime,
            value: widget.appointment.date,
            onChange: (d) => setState(() {
              widget.appointment.date = DateTime(
                widget.appointment.date.year,
                widget.appointment.date.month,
                widget.appointment.date.day,
                d.hour,
                d.minute,
              );
            }),
          ),
        ),
        InfoLabel(
          label: "${txt("duration")}:",
          child: DurationPill(
            item: widget.appointment,
            color: ChatDentPalette.of(context).fluentBlue,
            onSet: (d) => widget.appointment.duration = d,
            isCompact: false,
          ),
        ),
        InfoLabel(
          label: "${txt("preOperativeNotes")}:",
          child: LiveTranscribingTextField(
            key: WK.fieldAppointmentPreOpNotes,
            expands: true,
            maxLines: null,
            controller: noteController,
            onChanged: (v) => setState(() => widget.appointment.preOpNotes = v),
            placeholder: "${txt("preOperativeNotes")}...",
          ),
        )
      ].map((e) => [e, const SizedBox(height: 10)]).expand((e) => e).toList(),
    );
  }
}

class _OperativeDetails extends StatefulWidget {
  final Appointment appointment;
  const _OperativeDetails(this.appointment);

  @override
  State<_OperativeDetails> createState() => _OperativeDetailsState();
}

class _OperativeDetailsState extends State<_OperativeDetails> {
  final TextEditingController postOpNotesController = TextEditingController();
  final MoneyEditingController priceController = MoneyEditingController();
  final MoneyEditingController paidController = MoneyEditingController();
  bool didNotEditPaidYet = true;

  void setToDone() {
    setState(() {
      widget.appointment.isDone = true;
    });
  }

  void _fillControllers() {
    postOpNotesController.text = widget.appointment.postOpNotes;
    priceController.text =
        moneyInputFormatter.formatDouble(widget.appointment.price);
    paidController.text =
        moneyInputFormatter.formatDouble(widget.appointment.paid);
  }

  @override
  void initState() {
    super.initState();
    _fillControllers();
    if (widget.appointment.paid != 0) didNotEditPaidYet = false;
    continueOpenProceduresFromPriorVisits(widget.appointment);
    transcriptionEditCounter.observe(_updateWhenTranscriptionOccurs);
  }

  void _updateWhenTranscriptionOccurs(_) {
    if (mounted) {
      setState(_fillControllers);
    }
  }

  @override
  void dispose() {
    postOpNotesController.dispose();
    priceController.dispose();
    paidController.dispose();
    transcriptionEditCounter.unObserve(_updateWhenTranscriptionOccurs);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double paymentDifference = 0;
    Patient? patient = widget.appointment.patient;
    final priorBalance = patient?.runningBalance(
          excludingAppointmentId: widget.appointment.id,
        ) ??
        0;
    if (patient != null) {
      paymentDifference = widget.appointment.price -
          widget.appointment.paid -
          priorBalance;
    }
    final credit = priorBalance > 0 ? priorBalance : 0.0;
    final outstanding = priorBalance < 0 ? -priorBalance : 0.0;
    final fieldFill = chatDentFieldFill(ChatDentPalette.of(context));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.appointment.patient != null)
          InfoLabel(
            label: "${txt("dentalNotes")}:",
            child: Container(
              decoration: chatDentInnerCard(ChatDentPalette.of(context)),
              padding: const EdgeInsets.all(8),
              child: Column(
                spacing: 10,
                children: [
                  TeethSelector(
                    key: ValueKey(jsonEncode({
                      ...widget.appointment.teeth,
                      ...widget.appointment.teethExtraNotes
                    })),
                    type: StateType.treatment,
                    onNote: (x, y) {
                      setState(() {
                        if (y != null) {
                          widget.appointment.teeth[x] = y;
                          syncAppointmentProcedureProgress(
                            widget.appointment.teeth,
                            widget.appointment.procedureProgress,
                          );
                          seedProcedureFromPriorVisits(widget.appointment, x);
                        } else {
                          widget.appointment.teeth.remove(x);
                          widget.appointment.teethExtraNotes.remove(x);
                          widget.appointment.procedureProgress.remove(x);
                          syncAppointmentProcedureProgress(
                            widget.appointment.teeth,
                            widget.appointment.procedureProgress,
                          );
                        }
                      });
                    },
                    onExtraNote: (x, extra) {
                      widget.appointment.teethExtraNotes[x] = extra;
                    },
                    extraNotes: widget.appointment.teethExtraNotes,
                    notation: (isoString) => isoToTextualNotation(isoString),
                    rightString: txt("right"),
                    leftString: txt("left"),
                    currentNotes: widget.appointment.teeth,
                    oldNotes: (widget
                            .appointment.patient?.allAppointmentsDentalNotes ??
                        {})
                      ..removeWhere((key, val) =>
                          widget.appointment.teeth.containsKey(key)),
                    showPrimary: (widget.appointment.patient?.age ?? 18) < 14,
                  ),
                  if (widget.appointment.patient?.allAppointmentsDentalNotes
                          .isNotEmpty ==
                      true) ...[
                    AppointmentExtraNotes(
                      patient: widget.appointment.patient!,
                      initiallyExpanded: false,
                      excludedAppointment: widget.appointment,
                      title: txt("otherAppointmentsNotes"),
                    ),
                  ],
                ],
              ),
            ),
          ),
        const SizedBox(height: 10),
        InfoLabel(
          label: "${txt("procedureTracking")}:",
          child: Container(
            width: double.infinity,
            decoration: chatDentInnerCard(ChatDentPalette.of(context)),
            padding: const EdgeInsets.all(12),
            child: ProcedureStepsTracker(
              appointment: widget.appointment,
              onChanged: () => setState(() {}),
            ),
          ),
        ),
        Column(
          spacing: 5,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            InfoLabel(
              label: "${txt("postOperativeNotes")}:",
              child: LiveTranscribingTextField(
                key: WK.fieldAppointmentPostOpNotes,
                controller: postOpNotesController,
                placeholder: "${txt("postOperativeNotes")}...",
                onChanged: (v) {
                  setState(() {
                    widget.appointment.postOpNotes = v;
                    widget.appointment.isDone = true;
                  });
                },
              ),
            ),
            if ((widget.appointment.patient?.allAppointments.length ?? 0) > 1)
              _buildOtherAppointmentsFlyout(context),
          ],
        ),
        const Divider(direction: Axis.horizontal),
        if (credit > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InfoBar(
              isLong: true,
              title: Txt(
                '${txt("creditBalance")}: ${credit.toStringAsFixed(2)} ${currency()}',
              ),
              content: Txt(txt("creditAppliedNextHint")),
              severity: InfoBarSeverity.success,
            ),
          ),
        if (outstanding > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InfoBar(
              isLong: true,
              title: Txt(
                '${txt("outstandingBalance")}: ${outstanding.toStringAsFixed(2)} ${currency()}',
              ),
              content: Txt(txt("outstandingAppliedNextHint")),
              severity: InfoBarSeverity.warning,
            ),
          ),
        Row(
          children: [
            Expanded(
              child: InfoLabel(
                label: "${txt("priceIn")} ${currency()}",
                child: CupertinoTextField(
                  key: WK.fieldAppointmentPrice,
                  controller: priceController,
                  decoration: fieldFill,
                  onChanged: (v) {
                    setState(() {
                      widget.appointment.price = moneyInputFormatter.parse(v);
                      if (didNotEditPaidYet) {
                        final due = widget.appointment.price - priorBalance;
                        widget.appointment.paid = due > 0 ? due : 0;
                        paidController.text = moneyInputFormatter
                            .formatDouble(widget.appointment.paid);
                      }
                      widget.appointment.isDone = true;
                    });
                  },
                  placeholder: txt("price"),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [moneyInputFormatter],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: InfoLabel(
                label: "${txt("paidIn")} ${currency()}",
                child: CupertinoTextField(
                  key: WK.fieldAppointmentPayment,
                  controller: paidController,
                  decoration: fieldFill,
                  onChanged: (v) {
                    setState(() {
                      didNotEditPaidYet = false;
                      widget.appointment.paid = moneyInputFormatter.parse(v);
                      widget.appointment.isDone = true;
                    });
                  },
                  placeholder: txt("paid"),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [moneyInputFormatter],
                ),
              ),
            ),
          ],
        ),
        if (paymentDifference != 0 &&
            (login.perm(Perm.revenue).read ||
                widget.appointment.userIsOperator))
          InfoBar(
            title: Row(
              spacing: 5,
              children: [
                Txt(txt(paymentDifference > 0
                    ? txt("underpaid")
                    : txt("overpaid"))),
                MoneyDisplay(
                    "${paymentDifference.abs().toStringAsFixed(2)} ${currency()}"),
              ],
            ),
            content: Txt(txt("includesOtherAppointments")),
            severity: InfoBarSeverity.warning,
            isLong: true,
          ),
        const Divider(direction: Axis.horizontal),
        Checkbox(
          checked: widget.appointment.isDone,
          onChanged: (checked) {
            setState(() {
              widget.appointment.isDone = checked == true;
              if (widget.appointment.isDone) {
                widget.appointment.isNoShow = false;
              }
            });
          },
          content: Txt(txt("isDone")),
        ),
        Checkbox(
          checked: widget.appointment.isNoShow,
          onChanged: (checked) {
            setState(() {
              widget.appointment.isNoShow = checked == true;
              if (widget.appointment.isNoShow) {
                widget.appointment.isDone = false;
              }
            });
          },
          content: Txt(txt("isNoShow")),
        ),
        widget.appointment.hasLabwork
            ? _buildLabworkSection()
            : HyperlinkButton(
                style: ButtonStyle(
                    textStyle: WidgetStatePropertyAll(
                        FluentTheme.of(context).typography.caption)),
                onPressed: () {
                  setState(() {
                    widget.appointment.hasLabwork = true;
                  });
                },
                child: Row(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Icon(FluentIcons.manufacturing),
                    const SizedBox(width: 15),
                    SizedBox(
                        width: 200,
                        child: Txt(txt("addLabwork"), softWrap: true))
                  ],
                ),
              ),
      ].map((e) => [e, const SizedBox(height: 10)]).expand((e) => e).toList(),
    );
  }

  Widget _buildOtherAppointmentsFlyout(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 2),
      child: AppointmentsHistoryFlyout(
        title: txt("otherAppointments"),
        exclude: widget.appointment,
        patient: widget.appointment.patient!,
      ),
    );
  }

  Widget _buildLabworkSection() {
    return LabWorkEditor(
        appointment: widget.appointment,
        onDelete: () {
          setState(() {
            widget.appointment.hasLabwork = false;
          });
        });
  }
}

class _PrescriptionDetails extends StatefulWidget {
  final Appointment appointment;
  const _PrescriptionDetails(this.appointment);

  @override
  State<_PrescriptionDetails> createState() => _PrescriptionDetailsState();
}

class _PrescriptionDetailsState extends State<_PrescriptionDetails> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InfoBar(
          isLong: true,
          title: Txt(txt('prescriptionsTabInfo')),
          action: Button(
            onPressed: () {
              routes.navigate('prescriptions');
            },
            child: Txt(txt('openPrescriptionsCatalog')),
          ),
        ),
        const SizedBox(height: 12),
        InfoLabel(
          label: "${txt("prescription")}:",
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final raw in widget.appointment.prescriptions)
                Button(
                  onPressed: null,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Txt(
                          PrescriptionLine.parse(raw).toDisplay(),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        icon: const Icon(FluentIcons.cancel, size: 12),
                        onPressed: () {
                          setState(() {
                            widget.appointment.prescriptions = List<String>.from(
                                widget.appointment.prescriptions)
                              ..remove(raw);
                            widget.appointment.isDone = true;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              Button(
                onPressed: () async {
                  final line = await showAddPrescriptionDialog(context);
                  if (line == null || !mounted) return;
                  setState(() {
                    widget.appointment.prescriptions = [
                      ...widget.appointment.prescriptions,
                      line,
                    ];
                    widget.appointment.isDone = true;
                  });
                },
                child: ButtonContent(
                  WindowsIcons.add,
                  txt('addPrescription'),
                ),
              ),
            ],
          ),
        ),
        if (widget.appointment.prescriptions.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(
                style: filledButtonStyle(Colors.grey),
                child: ButtonContent(
                  FluentIcons.print,
                  txt("printPrescription"),
                ),
                onPressed: () {
                  printingPrescription(
                    context,
                    widget.appointment.prescriptions
                        .map((p) => PrescriptionLine.parse(p).toDisplay())
                        .toList(),
                    widget.appointment.patient?.title ?? "",
                    widget.appointment.patient?.age.toString() ?? "",
                    widget.appointment.patient?.link ?? "",
                  );
                },
              ),
              Button(
                child: ButtonContent(
                  FluentIcons.office_chat,
                  txt('sendOnWhatsApp'),
                ),
                onPressed: () {
                  final patient = widget.appointment.patientID == null
                      ? null
                      : patients.get(widget.appointment.patientID!);
                  if (patient == null) return;
                  ClinicWhatsApp.sendPrescription(
                    appointment: widget.appointment,
                    patient: patient,
                  );
                },
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class AppointmentsHistoryFlyout extends StatefulWidget {
  const AppointmentsHistoryFlyout(
      {super.key, required this.patient, required this.exclude, this.title});

  final Patient patient;
  final Appointment exclude;
  final String? title;

  @override
  State<AppointmentsHistoryFlyout> createState() =>
      _AppointmentsHistoryFlyoutState();
}

class _AppointmentsHistoryFlyoutState extends State<AppointmentsHistoryFlyout> {
  final otherAppointmentsFlyout = FlyoutController();

  @override
  void dispose() {
    otherAppointmentsFlyout.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FlyoutTarget(
      controller: otherAppointmentsFlyout,
      child: Tooltip(
        message: txt("otherAppointments"),
        child: IconButton(
          style: ButtonStyle(
              backgroundColor: WidgetStatePropertyAll(
            FluentTheme.of(context).inactiveColor.withAlpha(30),
          )),
          icon: Row(
            spacing: 10,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(WindowsIcons.history),
              if (widget.title != null) Txt(widget.title!),
            ],
          ),
          onPressed: () async {
            await flyoutFocusFix(context);
            otherAppointmentsFlyout.showFlyout(
              barrierDismissible: true,
              dismissWithEsc: true,
              builder: (context) {
                return FlyoutContent(
                    useAcrylic: false,
                    elevation: 15,
                    padding: EdgeInsetsGeometry.zero,
                    constraints:
                        const BoxConstraints(maxHeight: 300, maxWidth: 340),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                spacing: 5,
                                children: [
                                  Icon(WindowsIcons.history,
                                      size: 16,
                                      color: FluentTheme.of(context)
                                          .typography
                                          .bodyStrong!
                                          .color),
                                  Txt("${txt("otherAppointments")} (${widget.patient.allAppointments.length - 1})",
                                      style: FluentTheme.of(context)
                                          .typography
                                          .bodyStrong),
                                ],
                              ),
                              Text(
                                widget.patient.title,
                                style: const TextStyle(fontSize: 11),
                              )
                            ],
                          ),
                        ),
                        const Divider(),
                        Flexible(
                          child: SingleChildScrollView(
                            child: PatientAppointments(widget.patient,
                                readOnly: true,
                                excludedAppointment: widget.exclude,
                                hide: const [
                                  AppointmentSections.doctors,
                                  AppointmentSections.appointmentNumber,
                                  AppointmentSections.patient,
                                  AppointmentSections.pay,
                                  AppointmentSections.timeDifference,
                                  AppointmentSections.openAppointmentButton,
                                  AppointmentSections.paymentSummary,
                                ]),
                          ),
                        ),
                        const Divider(),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          child: Row(
                            spacing: 5,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              FilledButton(
                                style: filledButtonStyle(Colors.blue),
                                onPressed: () {
                                  Navigator.pop(context);
                                  WidgetsBinding.instance
                                      .addPostFrameCallback((_) {
                                    openPatient(widget.patient, 2);
                                  });
                                },
                                child: ButtonContent(
                                  WindowsIcons.calendar,
                                  txt("viewAllAppointments"),
                                  size: 13,
                                ),
                              ),
                              FilledButton(
                                style: filledButtonStyle(Colors.grey),
                                onPressed: () => Navigator.pop(context),
                                child: ButtonContent(
                                  WindowsIcons.cancel,
                                  txt("close"),
                                  size: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ));
              },
            );
          },
        ),
      ),
    );
  }
}

class LabWorkEditor extends StatefulWidget {
  final Appointment appointment;
  final VoidCallback? onDelete;
  const LabWorkEditor({super.key, required this.appointment, this.onDelete});
  @override
  State<LabWorkEditor> createState() => _LabWorkEditorState();
}

class _LabWorkEditorState extends State<LabWorkEditor> {
  final labNameController = TextEditingController();
  final labOrderNotesController = TextEditingController();

  @override
  void dispose() {
    labNameController.dispose();
    labOrderNotesController.dispose();
    transcriptionEditCounter.unObserve(_updateWhenTranscriptionOccurs);
    super.dispose();
  }

  void _fillControllers() {
    labNameController.text = widget.appointment.labName;
    labOrderNotesController.text = widget.appointment.labworkNotes;
  }

  void _updateWhenTranscriptionOccurs(_) {
    if (mounted) {
      setState(_fillControllers);
    }
  }

  @override
  void initState() {
    super.initState();
    _fillControllers();
    transcriptionEditCounter.observe(_updateWhenTranscriptionOccurs);
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    final color = widget.appointment.labworkReceived
        ? theme.accentColor
        : Colors.warningPrimaryColor;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: chatDentInnerCard(ChatDentPalette.of(context)).copyWith(
        border: Border.all(color: color),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Txt(
                txt("labworks"),
                style: theme.typography.bodyStrong,
              ),
              if (widget.onDelete != null)
                Tooltip(
                  message: txt("delete"),
                  child: IconButton(
                    icon: const Icon(WindowsIcons.delete),
                    onPressed: () {
                      widget.onDelete!();
                    },
                  ),
                )
            ],
          ),
          const SizedBox(height: 5),
          const Divider(),
          const SizedBox(height: 5),
          Row(
            children: [
              Row(
                children: [
                  const Icon(FluentIcons.manufacturing, size: 20),
                  const SizedBox(width: 5),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    child: Txt(
                      txt("laboratory"),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 5),
              Expanded(
                child: AutoSuggestBox<String>(
                  key: WK.fieldLabworkLabName,
                  decoration: WidgetStatePropertyAll(BoxDecoration(
                      color: Colors.transparent,
                      border: Border.all(color: Colors.transparent))),
                  clearButtonEnabled: false,
                  placeholder: "${txt("laboratory")}...",
                  noResultsFoundBuilder: (context) => Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Txt(txt("noSuggestions")),
                  ),
                  onChanged: (text, reason) {
                    widget.appointment.labName = text;
                  },
                  controller: labNameController,
                  items: appointments.labs
                      .map((name) =>
                          AutoSuggestBoxItem<String>(value: name, label: name))
                      .toList(),
                ),
              )
            ],
          ),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormBox(
                  prefix: const Icon(WindowsIcons.quick_note),
                  key: WK.fieldLabworkLabName,
                  decoration: WidgetStatePropertyAll(BoxDecoration(
                      color: Colors.transparent,
                      border: Border.all(color: Colors.transparent))),
                  placeholder: "${txt("orderNotes")}...",
                  maxLines: null,
                  controller: labOrderNotesController,
                  onChanged: (value) {
                    widget.appointment.labworkNotes = value;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Checkbox(
            checked: widget.appointment.labworkReceived,
            onChanged: (v) =>
                setState(() => widget.appointment.labworkReceived = v ?? false),
            content: Txt(txt("deliveredToPatient")),
          ),
        ],
      ),
    );
  }
}
