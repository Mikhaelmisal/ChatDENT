import 'package:chatdent/app/chatdent_theme.dart';
import 'package:chatdent/app/routes.dart';
import 'package:chatdent/common_widgets/current_account.dart';
import 'package:chatdent/common_widgets/money_display.dart';
import 'package:chatdent/common_widgets/screen_command_bar.dart';
import 'package:chatdent/core/model.dart';
import 'package:chatdent/core/multi_stream_builder.dart';
import 'package:chatdent/features/appointments/appointments_store.dart';
import 'package:chatdent/features/appointments/open_appointment_panel.dart';
import 'package:chatdent/features/dashboard/dashboard_controller.dart';
import 'package:chatdent/features/expenses/expenses_store.dart';
import 'package:chatdent/features/expenses/open_expense_panel.dart';
import 'package:chatdent/features/labwork/labworks_ctrl.dart';
import 'package:chatdent/features/leads/leads_store.dart';
import 'package:chatdent/features/patients/open_patient_panel.dart';
import 'package:chatdent/features/settings/settings_stores.dart';
import 'package:chatdent/services/launch.dart';
import 'package:chatdent/services/localization/locale.dart';
import 'package:chatdent/services/network.dart';
import 'package:chatdent/services/login.dart';
import 'package:chatdent/utils/constants.dart';
import 'package:chatdent/widget_keys.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:intl/intl.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  String get mode {
    return login.isAdmin
        ? txt("modeAdmin")
        : network.isOnline()
            ? txt("modeUser")
            : txt("modeOffline");
  }

  String get dashboardMessage {
    final onceStable =
        network.isOnline() ? "" : " ${txt("onceConnectionIsStable")}.";

    final restriction = (login.isAdmin && network.isOnline())
        ? txt("unRestrictedAccess")
        : txt("restrictedAccess");

    return "${txt("youAreCurrentlyIn")} $mode. ${txt("youHave")} $restriction.$onceStable";
  }

  @override
  Widget build(BuildContext context) {
    final p = ChatDentPalette.of(context);
    return ColoredBox(
      color: p.canvas,
      child: MStreamBuilder(
          streams: [
            appointments.observableMap.stream,
            expenses.observableMap.stream,
            leads.observableMap.stream,
          ],
          builder: (context, asyncSnapshot) {
            final colors = ChatDentPalette.of(context);
            return Stack(
              key: WK.dashboardScreen,
              children: [
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 46),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTopSquares(context),
                        Container(
                          height: 36,
                          decoration: topBarDecoration(context, Colors.grey),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          alignment: AlignmentDirectional.centerStart,
                          child: Txt(
                            DateFormat.yMMMMd(locale.s.$code)
                                .format(DateTime.now()),
                            style: TextStyle(
                              fontSize: 14,
                              color: colors.stone,
                            ),
                          ),
                        ),
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, listConstraints) {
                              final listHeight = listConstraints.maxHeight;
                              return ColoredBox(
                                color: colors.canvas,
                                child: ListView(
                                  scrollDirection: Axis.horizontal,
                                  children: [
                                    if (login.perm(Perm.patients).some &&
                                        login.perm(Perm.appointments).some)
                                      _buildDashboardList(
                                        context: context,
                                        height: listHeight,
                                        icon: FluentIcons.contact_card,
                                        onPressed: () =>
                                            routes.navigate("calendar"),
                                        title: txt("patientsToday"),
                                        items: dashboardCtrl.todayAppointments
                                            .map((e) => _dashboardListTile(
                                                  onPressed: () =>
                                                      openAppointment(e, 0),
                                                  item: e,
                                                  time: DF.time(e.date),
                                                  subtitle:
                                                      "${e.subtitleLine1.isNotEmpty ? "${e.subtitleLine1}\n" : ""}${e.subtitleLine2}",
                                                ))
                                            .toList(),
                                      ),
                                    if (login.perm(Perm.patients).some &&
                                        login.perm(Perm.appointments).some)
                                      _buildDashboardList(
                                        context: context,
                                        height: listHeight,
                                        icon: FluentIcons.add_event,
                                        onPressed: () =>
                                            routes.navigate("calendar"),
                                        title: txt("newPatientsToday"),
                                        items: dashboardCtrl.newPatientsToday
                                            .map((e) {
                                          final a = e.allAppointments.first;
                                          return _dashboardListTile(
                                            onPressed: () => openPatient(e, 2),
                                            item: e,
                                            subtitle:
                                                "${a.subtitleLine1.isNotEmpty ? "${a.subtitleLine1}\n" : ""}${a.subtitleLine2}",
                                          );
                                        }).toList(),
                                      ),
                                    if (login.perm(Perm.patients).some &&
                                        login.perm(Perm.appointments).some)
                                      _buildDashboardList(
                                        context: context,
                                        height: listHeight,
                                        icon: FluentIcons.repair,
                                        onPressed: () =>
                                            routes.navigate("labworks"),
                                        title:
                                            "${txt("labworks")} (${txt("due")})",
                                        items: labworks.due
                                            .map((e) => _dashboardListTile(
                                                  onPressed: () =>
                                                      openPatient(e.patient, 2),
                                                  item: e,
                                                  subtitle:
                                                      "${DateTime.now().difference(e.date).inDays} ${txt("daysAgo")}",
                                                ))
                                            .toList(),
                                      ),
                                    if (login.perm(Perm.patients).some &&
                                        login.perm(Perm.appointments).some)
                                      _buildDashboardList(
                                        context: context,
                                        height: listHeight,
                                        icon: FluentIcons.repair,
                                        onPressed: () =>
                                            routes.navigate("labworks"),
                                        title:
                                            "${txt("labworks")} (${txt("undelivered")})",
                                        items: labworks.notDeliveredPatients
                                            .map((e) => _dashboardListTile(
                                                  onPressed: () =>
                                                      openPatient(e, 2),
                                                  item: e,
                                                  subtitle:
                                                      "${DateTime.now().difference(e.doneAppointments.lastOrNull?.date ?? e.allAppointments.last.date).inDays} ${txt("daysAgo")}",
                                                ))
                                            .toList(),
                                      ),
                                    if (login.perm(Perm.expenses).some)
                                      _buildDashboardList(
                                        context: context,
                                        height: listHeight,
                                        icon: FluentIcons.payment_card,
                                        onPressed: () =>
                                            routes.navigate("expenses"),
                                        title:
                                            "${txt("expenses")} (${txt("due")})",
                                        items: expenses.suppliers
                                            .where((x) => x.duePayments > 0)
                                            .map((e) => _dashboardListTile(
                                                  onPressed: () {
                                                    openExpenses(
                                                      expenses.ordersPerSupplier[
                                                          e.id]!,
                                                      e.supplierName,
                                                      e.id,
                                                    );
                                                  },
                                                  name: e.supplierName,
                                                  leading: Icon(
                                                    FluentIcons
                                                        .folder_horizontal,
                                                    size: 18,
                                                    color: colors.muted,
                                                  ),
                                                  subtitle:
                                                      "${e.duePayments} ${currency()}",
                                                ))
                                            .toList(),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: _builCommandBar(context),
                ),
              ],
            );
          }),
    );
  }

  String _initials(String title) {
    final parts = title.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    final a = parts[0].isNotEmpty ? parts[0].substring(0, 1) : '';
    final b = parts[1].isNotEmpty ? parts[1].substring(0, 1) : '';
    return (a + b).toUpperCase();
  }

  Widget _dashboardListTile({
    required VoidCallback onPressed,
    Model? item,
    String? name,
    String? subtitle,
    String? time,
    Widget? leading,
  }) {
    final label = name ?? item?.title ?? '';
    return HoverButton(
      onPressed: onPressed,
      builder: (context, states) {
        final p = ChatDentPalette.of(context);
        final color = item?.color ?? p.border;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(vertical: 1),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: states.isHovered
                ? p.stone.withValues(alpha: 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              leading ??
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      _initials(label),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: p.stone,
                      ),
                    ),
                  ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            label,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: p.stone,
                            ),
                          ),
                        ),
                        if (time != null)
                          Text(
                            time,
                            style: TextStyle(
                              fontSize: 11,
                              color: p.muted,
                            ),
                          ),
                      ],
                    ),
                    if (subtitle != null && subtitle.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 11,
                            height: 1.25,
                            color: p.muted,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDashboardList({
    required BuildContext context,
    required double height,
    required String title,
    required List<Widget> items,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    const double colWidth = 265;
    final p = ChatDentPalette.of(context);

    return Container(
      width: colWidth,
      height: height,
      decoration: BoxDecoration(
        color: p.card,
        border: const BorderDirectional(
          end: BorderSide(color: Color(0x33000000)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: colWidth,
            padding: const EdgeInsets.all(10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Txt(
                    title,
                    style: TextStyle(
                      fontFamily: ChatDentFonts.ui,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: p.stone,
                    ),
                  ),
                ),
                HoverButton(
                  onPressed: onPressed,
                  builder: (context, states) {
                    return Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: states.isHovered
                            ? p.stone.withValues(alpha: 0.05)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Icon(icon, size: 18, color: p.stone),
                    );
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(5, 0, 5, 8),
              child: items.isEmpty
                  ? Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: p.emptyFill,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Txt(
                          txt("noResultsFound"),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: p.muted,
                          ),
                        ),
                      ),
                    )
                  : ListView(children: items),
            ),
          ),
        ],
      ),
    );
  }

  Widget _builCommandBar(BuildContext context) {
    return ScreenCommandBar(
      mainButton: _topWelcomingText(context),
      otherButtons: [if (!launch.isDemo) const LogoutButton()],
    );
  }

  Tooltip _topWelcomingText(BuildContext context) {
    final p = ChatDentPalette.of(context);
    return Tooltip(
      message: dashboardMessage,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(
          spacing: 10,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              FluentIcons.medical,
              size: 18,
              color: p.stone,
            ),
            Txt(
              "${"${txt("hello")},"} ${login.currentName}",
              style: TextStyle(
                fontFamily: ChatDentFonts.ui,
                fontSize: 13,
                color: p.stone,
              ),
            ),
            Txt(
              mode,
              style: TextStyle(
                fontFamily: ChatDentFonts.ui,
                fontSize: 11,
                color: p.fluentBlue,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopSquares(BuildContext context) {
    final p = ChatDentPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(15, 16, 15, 20),
      child: Row(
        children: [
          if (login.perm(Perm.appointments).some)
            dashboardSquare(
              background: p.purpleAccent,
              shadowColor: const Color(0xFF800080),
              iconColor: p.purpleIcon,
              valueColor: p.purpleText,
              labelColor: p.purpleLabel,
              icon: FluentIcons.goto_today,
              title: dashboardCtrl.todayAppointments.length.toString(),
              subtitle: txt("appointmentsToday"),
            ),
          if (login.perm(Perm.patients).some)
            dashboardSquare(
              background: p.blueAccent,
              shadowColor: const Color(0xFF0078D4),
              iconColor: p.blueIcon,
              valueColor: p.blueText,
              labelColor: p.blueLabel,
              icon: FluentIcons.people,
              title: dashboardCtrl.newPatientsToday.length.toString(),
              subtitle: txt("newPatientsToday"),
            ),
          if (login.perm(Perm.revenue).read)
            dashboardSquare(
              background: p.tealAccent,
              shadowColor: const Color(0xFF008080),
              iconColor: p.tealIcon,
              valueColor: p.tealText,
              labelColor: p.tealLabel,
              icon: FluentIcons.payment_card,
              title:
                  "${dashboardCtrl.paymentsToday.toStringAsFixed(2)} ${currency()}",
              subtitle: txt("paymentsMadeToday"),
              isMoney: true,
            ),
          if (login.perm(Perm.leads).some || login.isAdmin)
            dashboardSquare(
              background: p.amberAccent,
              shadowColor: const Color(0xFFEA580C),
              iconColor: p.amberIcon,
              valueColor: p.amberText,
              labelColor: p.amberLabel,
              icon: FluentIcons.headset,
              title: dashboardCtrl.newLeadsToday.length.toString(),
              subtitle: txt("newLeadsToday"),
            ),
        ],
      ),
    );
  }

  Widget dashboardSquare({
    required Color background,
    required Color shadowColor,
    required Color iconColor,
    required Color valueColor,
    required Color labelColor,
    required IconData icon,
    required String title,
    required String subtitle,
    bool isMoney = false,
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 16),
        child: Container(
          height: 90,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(5),
            boxShadow: chatDentStatShadow(shadowColor),
          ),
        padding: const EdgeInsets.all(8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(width: 8),
            Icon(icon, color: iconColor, size: 32),
            Container(
              width: 1,
              height: 40,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              color: iconColor.withValues(alpha: 0.3),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: isMoney
                        ? MoneyDisplay(
                            title,
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              height: 1.1,
                              color: valueColor,
                            ),
                          )
                        : Text(
                            title,
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              height: 1.1,
                              color: valueColor,
                            ),
                          ),
                  ),
                  const SizedBox(height: 2),
                  Txt(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: labelColor,
                      fontStyle: FontStyle.italic,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }
}
