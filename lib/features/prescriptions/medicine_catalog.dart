import 'dart:convert';

import 'package:chatdent/features/settings/settings_model.dart';
import 'package:chatdent/features/settings/settings_stores.dart';

/// Clinic medicine catalog (searchable when writing prescriptions).
class MedicineCatalog {
  static const settingId = 'med_catalog____';

  static const defaultMedicines = <String>[
    'Amoxicillin 500 mg',
    'Amoxicillin 250 mg',
    'Amoxyclav 625 mg',
    'Metronidazole 400 mg',
    'Azithromycin 500 mg',
    'Ciprofloxacin 500 mg',
    'Ibuprofen 400 mg',
    'Diclofenac 50 mg',
    'Paracetamol 500 mg',
    'Paracetamol 650 mg',
    'Aceclofenac 100 mg',
    'Pantoprazole 40 mg',
    'Omeprazole 20 mg',
    'Ranitidine 150 mg',
    'Chlorhexidine mouthwash 0.2%',
    'Povidone iodine gargle',
    'Hexidine mouthwash',
    'Dexamethasone 0.5 mg',
    'Prednisolone 5 mg',
    'Cetirizine 10 mg',
    'Multivitamin',
    'Calcium + Vitamin D3',
    'Vitamin B complex',
    'ORS / Electrolyte powder',
    'Tramadol 50 mg',
    'Ketorolac 10 mg',
    'Mefenamic acid 250 mg',
    'Serratiopeptidase 10 mg',
    'Local anesthetic gel',
    'Antifungal (Clotrimazole) oral paint',
  ];

  static List<String> load() {
    final raw = globalSettings.get(settingId).value.trim();
    if (raw.isEmpty) return List<String>.from(defaultMedicines);
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        final list = decoded
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList();
        if (list.isEmpty) return List<String>.from(defaultMedicines);
        return list;
      }
    } catch (_) {}
    return List<String>.from(defaultMedicines);
  }

  static void save(List<String> medicines) {
    final cleaned = medicines
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    globalSettings.set(Setting.fromJson({
      'id': settingId,
      'value': jsonEncode(cleaned),
    }));
  }

  static void addMedicine(String name) {
    final n = name.trim();
    if (n.isEmpty) return;
    final list = load();
    if (list.any((e) => e.toLowerCase() == n.toLowerCase())) return;
    list.add(n);
    save(list);
  }

  static void removeMedicine(String name) {
    final list = load()
      ..removeWhere((e) => e.toLowerCase() == name.trim().toLowerCase());
    save(list);
  }

  static void resetToDefaults() => save(List<String>.from(defaultMedicines));

  static List<String> search(String query) {
    final q = query.trim().toLowerCase();
    final all = load();
    if (q.isEmpty) return all;
    return all.where((e) => e.toLowerCase().contains(q)).toList();
  }
}
