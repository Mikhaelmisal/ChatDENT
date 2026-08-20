import 'package:chatdent/features/leads/lead_model.dart';
import 'package:chatdent/utils/india_phone.dart';

class LeadCsvImportResult {
  final List<Lead> leads;
  final int skippedEmpty;
  final int skippedDuplicate;

  const LeadCsvImportResult({
    required this.leads,
    this.skippedEmpty = 0,
    this.skippedDuplicate = 0,
  });

  int get imported => leads.length;
}

String _normHeader(String raw) {
  return raw
      .replaceAll('\uFEFF', '')
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[\s_\-/]+'), '');
}

String? _mapField(String header) {
  switch (_normHeader(header)) {
    case 'name':
    case 'fullname':
    case 'fullName':
    case 'title':
    case 'patientname':
    case 'leadname':
    case 'contactname':
      return 'title';
    case 'phone':
    case 'phonenumber':
    case 'mobile':
    case 'whatsapp':
    case 'contact':
    case 'tel':
    case 'telephone':
      return 'phone';
    case 'email':
    case 'mail':
    case 'emailaddress':
      return 'email';
    case 'source':
    case 'platform':
    case 'channel':
    case 'leadsource':
      return 'source';
    case 'campaign':
    case 'ad':
    case 'adname':
    case 'campaignname':
    case 'form':
      return 'campaign';
    case 'interest':
    case 'treatment':
    case 'service':
    case 'inquiry':
    case 'enquiry':
      return 'interest';
    case 'notes':
    case 'note':
    case 'comment':
    case 'comments':
    case 'message':
      return 'notes';
    case 'stage':
    case 'status':
      return 'stage';
    default:
      return null;
  }
}

String _normalizeSource(String raw) {
  final v = raw.trim().toLowerCase();
  if (v.contains('facebook') || v == 'fb' || v == 'meta') {
    return LeadSource.facebook;
  }
  if (v.contains('instagram') || v == 'ig') return LeadSource.instagram;
  if (v.contains('google')) return LeadSource.google;
  if (v.contains('walk')) return LeadSource.walkIn;
  if (v.contains('manual')) return LeadSource.manual;
  if (v.isEmpty) return LeadSource.manual;
  return raw.trim();
}

String _normalizeStage(String raw) {
  final v = raw.trim().toLowerCase();
  if (v.isEmpty) return LeadStage.newLead;
  for (final stage in LeadStage.all) {
    if (v == stage) return stage;
  }
  if (v.contains('contact')) return LeadStage.contacted;
  if (v.contains('interest')) return LeadStage.interested;
  if (v.contains('schedul') || v.contains('book')) {
    return LeadStage.scheduled;
  }
  if (v.contains('convert') || v.contains('patient')) {
    return LeadStage.converted;
  }
  if (v.contains('lost') || v.contains('dead') || v.contains('spam')) {
    return LeadStage.lost;
  }
  if (v.contains('new')) return LeadStage.newLead;
  return LeadStage.newLead;
}

/// Parses a CSV of ad / form leads. Extra columns are ignored.
/// Rows without a name and without a usable phone are skipped.
LeadCsvImportResult parseLeadsCsv(
  String csv, {
  Set<String> existingPhones = const {},
}) {
  final rows = _parseCsv(csv.replaceAll('\uFEFF', ''));
  if (rows.isEmpty) {
    return const LeadCsvImportResult(leads: []);
  }

  final headers = rows.first;
  final fieldIndex = <String, int>{};
  for (var i = 0; i < headers.length; i++) {
    final field = _mapField(headers[i]);
    if (field != null && !fieldIndex.containsKey(field)) {
      fieldIndex[field] = i;
    }
  }

  if (!fieldIndex.containsKey('title') && !fieldIndex.containsKey('phone')) {
    return const LeadCsvImportResult(leads: []);
  }

  final seen = {...existingPhones};
  final leads = <Lead>[];
  var skippedEmpty = 0;
  var skippedDuplicate = 0;

  for (var r = 1; r < rows.length; r++) {
    final row = rows[r];
    String cell(String field) {
      final i = fieldIndex[field];
      if (i == null || i >= row.length) return '';
      return row[i].trim();
    }

    final name = cell('title');
    final phoneRaw = cell('phone');
    if (name.isEmpty && phoneRaw.isEmpty) {
      skippedEmpty++;
      continue;
    }

    final phones = Lead.phonesFromStored(phoneRaw);
    final phoneKey = phones
        .map((p) => '${p.countryCode}${p.nsn}')
        .join('');
    if (phoneKey.isNotEmpty && seen.contains(phoneKey)) {
      skippedDuplicate++;
      continue;
    }
    if (phoneKey.isNotEmpty) seen.add(phoneKey);

    final local = IndiaPhone.localDigitsFrom(phoneRaw);
    leads.add(Lead.fromJson({
      if (name.isNotEmpty) 'title': name,
      if (phones.isNotEmpty)
        'phone': IndiaPhone.isCompleteLocal(local)
            ? IndiaPhone.persist(local)
            : phoneKey,
      if (cell('email').isNotEmpty) 'email': cell('email'),
      'source': _normalizeSource(cell('source')),
      if (cell('campaign').isNotEmpty) 'campaign': cell('campaign'),
      if (cell('interest').isNotEmpty) 'interest': cell('interest'),
      if (cell('notes').isNotEmpty) 'notes': cell('notes'),
      'stage': _normalizeStage(cell('stage')),
    }));
  }

  return LeadCsvImportResult(
    leads: leads,
    skippedEmpty: skippedEmpty,
    skippedDuplicate: skippedDuplicate,
  );
}

List<List<String>> _parseCsv(String csv) {
  final rows = <List<String>>[];
  final currentRow = <String>[];
  final currentField = StringBuffer();
  var inQuotes = false;
  var i = 0;
  final n = csv.length;

  void endField() {
    currentRow.add(currentField.toString());
    currentField.clear();
  }

  void endRow() {
    endField();
    if (currentRow.any((c) => c.trim().isNotEmpty)) {
      rows.add(List<String>.from(currentRow));
    }
    currentRow.clear();
  }

  while (i < n) {
    final c = csv[i];
    if (!inQuotes) {
      if (c == '"') {
        inQuotes = true;
        i++;
      } else if (c == ',') {
        endField();
        i++;
      } else if (c == '\n') {
        endRow();
        i++;
      } else if (c == '\r') {
        if (i + 1 < n && csv[i + 1] == '\n') i++;
        endRow();
        i++;
      } else {
        currentField.write(c);
        i++;
      }
    } else if (c == '"') {
      if (i + 1 < n && csv[i + 1] == '"') {
        currentField.write('"');
        i += 2;
      } else {
        inQuotes = false;
        i++;
      }
    } else {
      currentField.write(c);
      i++;
    }
  }

  if (currentField.isNotEmpty || currentRow.isNotEmpty) {
    endRow();
  }
  return rows;
}
