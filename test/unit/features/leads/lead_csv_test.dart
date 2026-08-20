import 'package:chatdent/features/leads/lead_csv.dart';
import 'package:chatdent/features/leads/lead_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseLeadsCsv', () {
    test('imports friendly ad-export headers', () {
      const csv = 'Full name,Phone number,Email,Source,Campaign,Interest,Notes\n'
          'Ravi Kumar,9876543210,ravi@example.com,Facebook,Spring,Cleaning,From form\n'
          'Meera Shah,+91 91234 56789,,Instagram,Whitening,Whitening,\n';

      final result = parseLeadsCsv(csv);
      expect(result.imported, 2);
      expect(result.leads.first.title, 'Ravi Kumar');
      expect(result.leads.first.phonesString, '919876543210');
      expect(result.leads.first.source, LeadSource.facebook);
      expect(result.leads.first.campaign, 'Spring');
      expect(result.leads[1].title, 'Meera Shah');
      expect(result.leads[1].source, LeadSource.instagram);
    });

    test('skips empty rows and duplicate phones', () {
      const csv = 'name,phone\n'
          'One,9876543210\n'
          'Two,9876543210\n'
          ',\n'
          'Three,9123456789\n';

      final result = parseLeadsCsv(csv);
      expect(result.imported, 2);
      expect(result.skippedDuplicate, 1);
      expect(result.leads.map((l) => l.title), ['One', 'Three']);
    });

    test('skips phones already in the clinic', () {
      const csv = 'name,phone\nAsha,9876543210\n';
      final result = parseLeadsCsv(
        csv,
        existingPhones: {'919876543210'},
      );
      expect(result.imported, 0);
      expect(result.skippedDuplicate, 1);
    });

    test('ignores extra columns and maps stage aliases', () {
      const csv =
          'name,phone,status,foo,bar\nNeha,9988776655,booked,x,y\n';
      final result = parseLeadsCsv(csv);
      expect(result.imported, 1);
      expect(result.leads.single.stage, LeadStage.scheduled);
    });
  });
}
