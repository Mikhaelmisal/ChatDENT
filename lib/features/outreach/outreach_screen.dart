import 'package:chatdent/common_widgets/contact_buttons.dart';
import 'package:chatdent/common_widgets/item_title.dart';
import 'package:chatdent/common_widgets/no_items_found.dart';
import 'package:chatdent/core/multi_stream_builder.dart';
import 'package:chatdent/features/appointments/appointments_store.dart';
import 'package:chatdent/features/leads/lead_model.dart';
import 'package:chatdent/features/leads/leads_store.dart';
import 'package:chatdent/features/leads/open_lead_panel.dart';
import 'package:chatdent/features/outreach/campaign_settings.dart';
import 'package:chatdent/features/patients/open_patient_panel.dart';
import 'package:chatdent/features/patients/patients_store.dart';
import 'package:chatdent/services/localization/locale.dart';
import 'package:fluent_ui/fluent_ui.dart';

class OutreachScreen extends StatelessWidget {
  const OutreachScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MStreamBuilder(
      streams: [
        patients.observableMap.stream,
        appointments.observableMap.stream,
        leads.observableMap.stream,
      ],
      builder: (context, _) => const _OutreachPage(),
    );
  }
}

class _OutreachPage extends StatefulWidget {
  const _OutreachPage();

  @override
  State<_OutreachPage> createState() => _OutreachPageState();
}

class _OutreachPageState extends State<_OutreachPage> {
  int tab = 0;

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage(
      header: PageHeader(title: Txt(txt('outreachDashboard'))),
      content: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: CommandBar(
              primaryItems: [
                CommandBarButton(
                  onPressed: () => setState(() => tab = 0),
                  label: Txt(txt('birthdays')),
                  icon: const Icon(FluentIcons.birthday_cake),
                ),
                CommandBarButton(
                  onPressed: () => setState(() => tab = 1),
                  label: Txt(txt('reviewFollowUp')),
                  icon: const Icon(FluentIcons.favorite_star),
                ),
                CommandBarButton(
                  onPressed: () => setState(() => tab = 2),
                  label: Txt(txt('rescheduleRequested')),
                  icon: const Icon(FluentIcons.date_time),
                ),
                CommandBarButton(
                  onPressed: () => setState(() => tab = 3),
                  label: Txt(txt('interestedQueue')),
                  icon: const Icon(FluentIcons.phone),
                ),
              ],
            ),
          ),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    switch (tab) {
      case 1:
        return const _ReviewsTab();
      case 2:
        return const _RescheduleTab();
      case 3:
        return const _InterestedTab();
      default:
        return const _BirthdaysTab();
    }
  }
}

class _BirthdaysTab extends StatelessWidget {
  const _BirthdaysTab();

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final rows = patients.present.values.where((p) {
      if (!p.hasFullBirthDate || p.phonesString.isEmpty) return false;
      final days = daysUntilBirthday(p.birthAsDate, now);
      return days != null && days <= 14 && p.birthdayMsgYear != now.year;
    }).toList()
      ..sort((a, b) => (daysUntilBirthday(a.birthAsDate, now) ?? 99)
          .compareTo(daysUntilBirthday(b.birthAsDate, now) ?? 99));

    if (rows.isEmpty) return const NoItemsFound();
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: rows.length,
      itemBuilder: (context, i) {
        final p = rows[i];
        final days = daysUntilBirthday(p.birthAsDate, now) ?? 0;
        return ListTile(
          leading: ItemTitle(item: p),
          title: Text(p.title),
          subtitle: Text(
              days == 0 ? txt('birthdayToday') : '${txt('daysAway')}: $days'),
          trailing: p.phone.isEmpty
              ? null
              : PhoneNumberButton(phoneNumbers: p.phone),
          onPressed: () => openPatient(p),
        );
      },
    );
  }
}

class _ReviewsTab extends StatelessWidget {
  const _ReviewsTab();

  @override
  Widget build(BuildContext context) {
    final rows = patients.present.values.where((p) {
      if (p.reviewDone || p.phonesString.isEmpty) return false;
      if (p.reviewAskCount >= 3) return false;
      return p.doneAppointments.isNotEmpty;
    }).toList();
    if (rows.isEmpty) return const NoItemsFound();
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: rows.length,
      itemBuilder: (context, i) {
        final p = rows[i];
        return ListTile(
          leading: ItemTitle(item: p),
          title: Text(p.title),
          subtitle: Text('${txt('reviewAsked')}: ${p.reviewAskCount}/3'),
          trailing: Button(
            onPressed: () {
              p.reviewDone = true;
              patients.set(p);
            },
            child: Txt(txt('markReviewDone')),
          ),
          onPressed: () => openPatient(p),
        );
      },
    );
  }
}

class _RescheduleTab extends StatelessWidget {
  const _RescheduleTab();

  @override
  Widget build(BuildContext context) {
    final rows = appointments.present.values
        .where((a) => a.rescheduleRequested && a.archived != true)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    if (rows.isEmpty) return const NoItemsFound();
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: rows.length,
      itemBuilder: (context, i) {
        final a = rows[i];
        return ListTile(
          title: Text(a.title),
          subtitle: Text(a.date.toString()),
          trailing: Button(
            onPressed: () {
              a.rescheduleRequested = false;
              appointments.set(a);
            },
            child: Txt(txt('done')),
          ),
        );
      },
    );
  }
}

class _InterestedTab extends StatelessWidget {
  const _InterestedTab();

  @override
  Widget build(BuildContext context) {
    final rows = leads.present.values
        .where((l) => l.stage == LeadStage.interested)
        .toList();
    if (rows.isEmpty) return const NoItemsFound();
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: rows.length,
      itemBuilder: (context, i) {
        final l = rows[i];
        return ListTile(
          title: Text(l.title.isEmpty ? l.phonesString : l.title),
          subtitle: Text(l.phonesString),
          trailing: l.phone.isEmpty
              ? null
              : PhoneNumberButton(phoneNumbers: l.phone),
          onPressed: () => openLead(l),
        );
      },
    );
  }
}
