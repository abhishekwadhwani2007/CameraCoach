import 'package:flutter/material.dart';

// ManualControlsRow — the compact camera-settings display shown in PRO mode.
// The larger ManualControlsPanel (expandable picker UI) was removed because
// it had zero callers in the app. Only this row widget is used, by bottom_bar.dart.
class ManualControlsRow extends StatelessWidget {
  final String iso;
  final String shutter;
  final String wb;
  final double ev;
  final String mf;

  const ManualControlsRow({
    super.key,
    required this.iso,
    required this.shutter,
    required this.wb,
    required this.ev,
    required this.mf,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      ('ISO', iso),
      ('SS', shutter),
      ('WB', wb),
      ('EV', ev >= 0 ? '+${ev.toStringAsFixed(1)}' : ev.toStringAsFixed(1)),
      ('MF', mf),
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: items
          .map(
            (item) => Container(
              width: 52,
              height: 52,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black54,
                border: Border.all(color: Colors.white24),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    item.$1,
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.$2,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}
