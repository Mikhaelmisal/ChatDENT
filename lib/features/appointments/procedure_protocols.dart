class ProcedureFieldDef {
  final String id;
  final String labelKey;
  final String placeholder;
  const ProcedureFieldDef({
    required this.id,
    required this.labelKey,
    required this.placeholder,
  });
}

class ProcedureStepDef {
  final String id;
  final String titleKey;
  final List<ProcedureFieldDef> fields;
  const ProcedureStepDef({
    required this.id,
    required this.titleKey,
    this.fields = const [],
  });
}

class ProcedureProtocol {
  final String titleKey;
  final List<ProcedureStepDef> steps;
  const ProcedureProtocol({
    required this.titleKey,
    required this.steps,
  });
}

class ToothProcedureProgress {
  String label;
  int done;
  Map<String, String> fields;

  ToothProcedureProgress({
    required this.label,
    this.done = 0,
    Map<String, String>? fields,
  }) : fields = fields ?? {};

  factory ToothProcedureProgress.fromJson(Map<String, dynamic> json) {
    final rawFields = json['fields'];
    return ToothProcedureProgress(
      label: (json['label'] ?? '').toString(),
      done: (json['done'] as num?)?.toInt() ?? 0,
      fields: rawFields is Map
          ? rawFields.map((k, v) => MapEntry(k.toString(), v.toString()))
          : {},
    );
  }

  Map<String, dynamic> toJson() => {
        'label': label,
        'done': done,
        if (fields.isNotEmpty) 'fields': fields,
      };
}

const _wl = ProcedureFieldDef(
  id: 'workingLength',
  labelKey: 'workingLength',
  placeholder: 'mm',
);
const _gpNo = ProcedureFieldDef(
  id: 'gpNumber',
  labelKey: 'gpNumber',
  placeholder: 'e.g. 30',
);
const _gpDia = ProcedureFieldDef(
  id: 'gpDiameter',
  labelKey: 'gpDiameter',
  placeholder: 'e.g. 0.06',
);

final Map<String, ProcedureProtocol> procedureProtocols = {
  'rCT': const ProcedureProtocol(
    titleKey: 'procTitleRCT',
    steps: [
      ProcedureStepDef(id: 'access', titleKey: 'stepAccessOpening'),
      ProcedureStepDef(
        id: 'bmp',
        titleKey: 'stepBmp',
        fields: [_wl],
      ),
      ProcedureStepDef(
        id: 'obturation',
        titleKey: 'stepObturation',
        fields: [_gpNo, _gpDia],
      ),
      ProcedureStepDef(id: 'por', titleKey: 'stepPor'),
      ProcedureStepDef(id: 'crownCutting', titleKey: 'stepCrownCutting'),
      ProcedureStepDef(id: 'scan', titleKey: 'stepMeasurementsScan'),
      ProcedureStepDef(id: 'cement', titleKey: 'stepCrownCementation'),
    ],
  ),
  're-RCT': const ProcedureProtocol(
    titleKey: 're-RCT',
    steps: [
      ProcedureStepDef(id: 'access', titleKey: 'stepAccessRestRemoval'),
      ProcedureStepDef(id: 'gpRemoval', titleKey: 'stepGpRemoval'),
      ProcedureStepDef(id: 'bmp', titleKey: 'stepBmp', fields: [_wl]),
      ProcedureStepDef(
        id: 'obturation',
        titleKey: 'stepObturation',
        fields: [_gpNo, _gpDia],
      ),
      ProcedureStepDef(id: 'por', titleKey: 'stepPor'),
      ProcedureStepDef(id: 'crownCutting', titleKey: 'stepCrownCutting'),
      ProcedureStepDef(id: 'scan', titleKey: 'stepMeasurementsScan'),
      ProcedureStepDef(id: 'cement', titleKey: 'stepCrownCementation'),
    ],
  ),
  'extraction': const ProcedureProtocol(
    titleKey: 'extraction',
    steps: [
      ProcedureStepDef(id: 'la', titleKey: 'stepAnaesthesia'),
      ProcedureStepDef(id: 'exo', titleKey: 'stepElevationExtraction'),
      ProcedureStepDef(id: 'haemo', titleKey: 'stepHaemostasis'),
      ProcedureStepDef(id: 'instr', titleKey: 'stepPostExoInstructions'),
    ],
  ),
  'filling': const ProcedureProtocol(
    titleKey: 'filling',
    steps: [
      ProcedureStepDef(id: 'caries', titleKey: 'stepIsolationCaries'),
      ProcedureStepDef(id: 'cavity', titleKey: 'stepCavityPrep'),
      ProcedureStepDef(id: 'restore', titleKey: 'stepRestorationPlaced'),
      ProcedureStepDef(id: 'finish', titleKey: 'stepFinishOcclusion'),
    ],
  ),
  'pulpotomy': const ProcedureProtocol(
    titleKey: 'pulpotomy',
    steps: [
      ProcedureStepDef(id: 'access', titleKey: 'stepAccessOpening'),
      ProcedureStepDef(id: 'medicament', titleKey: 'stepPulpMedicament'),
      ProcedureStepDef(id: 'restore', titleKey: 'stepRestorationPlaced'),
    ],
  ),
  'ortho': const ProcedureProtocol(
    titleKey: 'ortho',
    steps: [
      ProcedureStepDef(id: 'records', titleKey: 'stepOrthoRecords'),
      ProcedureStepDef(id: 'bond', titleKey: 'stepOrthoBonding'),
      ProcedureStepDef(id: 'wire', titleKey: 'stepOrthoActivation'),
      ProcedureStepDef(id: 'instr', titleKey: 'stepInstructionsGiven'),
    ],
  ),
  'whitening': const ProcedureProtocol(
    titleKey: 'whitening',
    steps: [
      ProcedureStepDef(id: 'shade', titleKey: 'stepShadeRecorded'),
      ProcedureStepDef(id: 'apply', titleKey: 'stepWhiteningApplied'),
      ProcedureStepDef(id: 'done', titleKey: 'stepWhiteningDone'),
    ],
  ),
  'clean': const ProcedureProtocol(
    titleKey: 'clean',
    steps: [
      ProcedureStepDef(id: 'scale', titleKey: 'stepScaling'),
      ProcedureStepDef(id: 'polish', titleKey: 'stepPolishing'),
      ProcedureStepDef(id: 'ohi', titleKey: 'stepOhi'),
    ],
  ),
  'implant': const ProcedureProtocol(
    titleKey: 'implant',
    steps: [
      ProcedureStepDef(id: 'plan', titleKey: 'stepImplantPlanning'),
      ProcedureStepDef(id: 'place', titleKey: 'stepImplantPlaced'),
      ProcedureStepDef(id: 'abut', titleKey: 'stepHealingAbutment'),
      ProcedureStepDef(id: 'restore', titleKey: 'stepImplantRestored'),
    ],
  ),
  'surgery': const ProcedureProtocol(
    titleKey: 'surgery',
    steps: [
      ProcedureStepDef(id: 'flap', titleKey: 'stepAnaesthesiaFlap'),
      ProcedureStepDef(id: 'sx', titleKey: 'stepSurgicalProcedure'),
      ProcedureStepDef(id: 'suture', titleKey: 'stepSuturing'),
      ProcedureStepDef(id: 'instr', titleKey: 'stepPostOpInstructions'),
    ],
  ),
  'crown': const ProcedureProtocol(
    titleKey: 'crown',
    steps: [
      ProcedureStepDef(id: 'prep', titleKey: 'stepToothPrep'),
      ProcedureStepDef(id: 'scan', titleKey: 'stepImpressionScan'),
      ProcedureStepDef(id: 'temp', titleKey: 'stepTemporaryCrown'),
      ProcedureStepDef(id: 'cement', titleKey: 'stepCrownCementation'),
    ],
  ),
  'veneer': const ProcedureProtocol(
    titleKey: 'veneer',
    steps: [
      ProcedureStepDef(id: 'prep', titleKey: 'stepVeneerPrep'),
      ProcedureStepDef(id: 'scan', titleKey: 'stepImpressionScan'),
      ProcedureStepDef(id: 'temp', titleKey: 'stepTemporariesPlaced'),
      ProcedureStepDef(id: 'bond', titleKey: 'stepVeneerBonded'),
    ],
  ),
  'overlay': const ProcedureProtocol(
    titleKey: 'overlay',
    steps: [
      ProcedureStepDef(id: 'prep', titleKey: 'stepToothPrep'),
      ProcedureStepDef(id: 'scan', titleKey: 'stepImpressionScan'),
      ProcedureStepDef(id: 'cement', titleKey: 'stepOverlayCemented'),
    ],
  ),
  'temporary': const ProcedureProtocol(
    titleKey: 'temporary',
    steps: [
      ProcedureStepDef(id: 'place', titleKey: 'stepTemporaryPlaced'),
      ProcedureStepDef(id: 'occ', titleKey: 'stepOcclusionChecked'),
    ],
  ),
  'bridge': const ProcedureProtocol(
    titleKey: 'bridge',
    steps: [
      ProcedureStepDef(id: 'prep', titleKey: 'stepAbutmentPrep'),
      ProcedureStepDef(id: 'scan', titleKey: 'stepImpressionScan'),
      ProcedureStepDef(id: 'temp', titleKey: 'stepTemporaryBridge'),
      ProcedureStepDef(id: 'cement', titleKey: 'stepBridgeCemented'),
    ],
  ),
  'abutment': const ProcedureProtocol(
    titleKey: 'abutment',
    steps: [
      ProcedureStepDef(id: 'prep', titleKey: 'stepAbutmentPrep'),
      ProcedureStepDef(id: 'scan', titleKey: 'stepImpressionScan'),
    ],
  ),
  'pontic': const ProcedureProtocol(
    titleKey: 'pontic',
    steps: [
      ProcedureStepDef(id: 'space', titleKey: 'stepPonticSpace'),
      ProcedureStepDef(id: 'fit', titleKey: 'stepPonticFitted'),
    ],
  ),
  'other': const ProcedureProtocol(
    titleKey: 'other',
    steps: [
      ProcedureStepDef(id: 'done', titleKey: 'stepProcedureCompleted'),
    ],
  ),
};

ProcedureProtocol protocolFor(String label) {
  return procedureProtocols[label] ?? procedureProtocols['other']!;
}

void syncAppointmentProcedureProgress(
  Map<String, String> teeth,
  Map<String, ToothProcedureProgress> progress,
) {
  progress.removeWhere((iso, _) => !teeth.containsKey(iso));
  for (final e in teeth.entries) {
    final cur = progress[e.key];
    if (cur == null || cur.label != e.value) {
      progress[e.key] = ToothProcedureProgress(label: e.value);
    } else {
      final maxDone = protocolFor(e.value).steps.length;
      if (cur.done > maxDone) cur.done = maxDone;
    }
  }
}
