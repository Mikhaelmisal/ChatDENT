/// Extra notes shown on **patient Dental Notes** only (findings + planned work).
/// Visit progress belongs in Operative Details, not here.
const Map<String, List<String>> txExtraNoteChoices = {
  'missing': [
    'Tooth missing. Space present.',
    'Tooth missing. Adjacent drift noted.',
    'Congenitally missing.',
    'Previously extracted. Replacement advised.',
  ],
  'caries': [
    'Occlusal caries. Restoration advised.',
    'Proximal caries. Restoration advised.',
    'Cervical / root caries. Restoration / Extraction advised.',
    'Deep caries. Pulp assessment / RCT advised.',
    'Recurrent caries Pulp assessment / RCT advised.',
  ],
  'fractured': [
    'Enamel fracture. Restoration advised.',
    'Crown fracture involving dentin. Restoration advised.',
    'Fracture involving pulp. RCT / extraction advised.',
    'Root fracture. Extraction / surgical assessment advised.',
    'Avulsed tooth. Splinting advised.',
  ],
  'mobility': [
    'Grade I mobility. Periodontal review advised.',
    'Grade II mobility. Splinting / periodontal treatment advised.',
    'Grade III mobility. Extraction advised.',
  ],
  'recession': [
    'Gingival recession noted. Oral hygiene reinforced.',
    'Recession with sensitivity. Desensitising / graft discussed.',
    'Recession with bone loss. OPG advised & Periodontal review.',
  ],
  'rroot': [
    'OverRetained root. Extraction advised.',
    'OverRetained root. Surgical removal advised.',
    'OverRetained root. Monitor if asymptomatic.',
  ],
  'rprimary': [
    'Retained primary tooth. Extraction advised.',
    'Retained primary tooth. Monitor eruption of successor.',
  ],
  'malposition': [
    'Rotated / malpositioned. Orthodontic evaluation advised.',
    'Crowding noted. Orthodontic evaluation advised.',
    'Tipped tooth. Restoration / ortho discussed.',
  ],
  'ortho': [
    'Aligners advised.',
    'Aligners in treatment.',
    'Braces advised.',
    'Orthodontic treatment in progress.',
    'Appliance advised.',
    'Retainers advised / in retention.',
  ],
  'impacted': [
    'Impacted. Surgical assessment advised.',
    'Impacted with pain. Removal advised.',
    'Pericoronitis seen. Operculectomy advised.',
    'Impacted. Monitor if asymptomatic.',
  ],
  'filling': [
    'Existing filling. Monitor.',
    'Defective filling. Replacement advised.',
    'Filling advised.',
  ],
  'rCT': [
    'RCT treated tooth. Monitor.',
    'RCT indicated.',
    'Incomplete RCT. Completion advised.',
  ],
  'implant': [
    'Implant present. Monitor.',
    'Re-implant surgery advised.',
    'Implant indicated. Planning / CBCT advised.',
    'Implant with issues. Review advised.',
  ],
  'crown': [
    'Existing crown. Monitor.',
    'Crown indicated.',
    'Defective crown. Replacement advised.',
  ],
  'veneer': [
    'Existing veneer. Monitor.',
    'Veneer indicated.',
    'Veneer debonded / defective. Review advised.',
  ],
  'overlay': [
    'Existing onlay / overlay. Monitor.',
    'Onlay / overlay indicated.',
    'Defective onlay / overlay. Replacement advised.',
  ],
  'bridge': [
    'Existing bridge. Monitor.',
    'Bridge indicated. Abutments to be assessed.',
    'Defective bridge. Replacement advised.',
  ],
  'abutment': [
    'Bridge abutment. Monitor.',
  ],
  'pontic': [
    'Bridge pontic. Monitor.',
    'Pontic space. Bridge advised.',
  ],
};

List<String> extraNoteChoicesFor(String label) =>
    txExtraNoteChoices[label] ?? const [];
