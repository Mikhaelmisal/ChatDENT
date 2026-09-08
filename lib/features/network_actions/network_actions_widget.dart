import 'package:chatdent/app/chatdent_theme.dart';
import 'package:chatdent/core/multi_stream_builder.dart';
import 'package:chatdent/features/login/login_controller.dart';
import 'package:chatdent/features/network_actions/network_actions_controller.dart';
import 'package:chatdent/features/network_actions/errors_list_widget.dart';
import 'package:chatdent/common_widgets/transitions/pulse.dart';
import 'package:chatdent/common_widgets/transitions/rotate.dart';
import 'package:chatdent/features/settings/settings_stores.dart';
import 'package:chatdent/services/launch.dart';
import 'package:chatdent/services/network.dart';
import 'package:chatdent/services/notifications/static_notifications.dart';
import 'package:chatdent/services/whatsapp_status.dart';
import 'package:fluent_ui/fluent_ui.dart';

class NetworkActions extends StatelessWidget {
  const NetworkActions({super.key});
  @override
  Widget build(BuildContext context) {
    whatsappStatus.ensurePolling();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: MStreamBuilder(
          streams: [
            networkActions.isSyncing.stream,
            loginCtrl.proceededOffline.stream,
            network.isOnline.stream,
            localSettings.stream,
            launch.open.stream,
            networkActions.hasErrors.stream,
            networkActions.errorPulse.stream,
            whatsappStatus.link.stream,
            staticNotifications.revision.stream,
          ],
          builder: (context, _) {
            return Row(
              spacing: 4,
              mainAxisSize: MainAxisSize.min,
              children: [
                ...networkActions.actions
                    .where((action) => action.hidden != true)
                    .map(
                      (action) => _buildActionItem(context, action),
                    )
              ],
            );
          }),
    );
  }

  Widget _buildActionItem(BuildContext context, NetworkAction action) {
    final isErrorAction =
        networkActions.hasErrors() && action.activeColor == Colors.red;

    Widget iconWidget = _buildActionIcon(context, action, isErrorAction);

    if (isErrorAction) {
      iconWidget = PulseWrapper(
        key: ValueKey("errorPulse_${networkActions.errorPulse()}"),
        pulse: true,
        child: iconWidget,
      );
    }

    if (isErrorAction) {
      iconWidget = FlyoutTarget(
        controller: errorsFlyoutController,
        child: iconWidget,
      );
    }

    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        iconWidget,
        if (action.badge != null) _buildBadge(action),
      ],
    );
  }

  Widget _buildActionIcon(
    BuildContext context,
    NetworkAction action,
    bool isErrorAction,
  ) {
    final p = ChatDentPalette.of(context);
    return RotatingWrapper(
      key: Key(action.hashCode.toString()),
      rotate: action.animate == true && action.processing == true,
      child: Tooltip(
        message: action.tooltip,
        child: HoverButton(
          onPressed: action.disabled == true ? null : action.onPressed,
          builder: (context, states) {
            final hovered = states.isHovered || states.isPressed;
            return Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isErrorAction
                    ? action.activeColor
                    : hovered
                        ? p.stone.withValues(alpha: 0.05)
                        : Colors.transparent,
              ),
              child: IconTheme(
                data: IconThemeData(
                  size: 18,
                  color: isErrorAction ? Colors.white : p.stone,
                ),
                child: action.icon,
              ),
            );
          },
        ),
      ),
    );
  }

  Positioned _buildBadge(NetworkAction action) {
    return Positioned(
      bottom: -2,
      right: -2,
      child: Container(
        height: 14,
        width: 14,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(50),
          boxShadow: kElevationToShadow[2],
        ),
        child: Center(
            child: Text(action.badge ?? "",
                style: const TextStyle(fontSize: 10, color: Colors.grey))),
      ),
    );
  }
}
