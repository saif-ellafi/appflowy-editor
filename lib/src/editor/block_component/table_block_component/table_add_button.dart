import 'package:appflowy_editor/src/editor/block_component/table_block_component/table_action_handler.dart';
import 'package:flutter/material.dart';

class TableActionButton extends StatelessWidget {
  const TableActionButton({
    super.key,
    required this.width,
    required this.height,
    required this.padding,
    required this.onPressed,
    required this.icon,
    this.visible = false,
  });

  final double width, height;
  final EdgeInsetsGeometry padding;
  final Function onPressed;
  final Widget icon;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      width: width,
      height: height,
      alignment: Alignment.center,
      child: visible
          ? GestureDetector(
              onTap: () => onPressed(),
              child: tableChromeChip(
                context,
                child: const Icon(Icons.add, size: 12),
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}
