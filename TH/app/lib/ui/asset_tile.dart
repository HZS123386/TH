import 'package:flutter/material.dart';

class AssetTile extends StatelessWidget {
  const AssetTile(
    this.asset, {
    required this.column,
    this.row = 0,
    this.rows = 1,
    this.cellRatio = 1,
    this.alignment = Alignment.center,
    super.key,
  });

  final String asset;
  final int column, row, rows;
  final double cellRatio;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    const width = 300.0;
    final height = width / cellRatio;
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        alignment: alignment,
        child: SizedBox(
          width: width,
          height: height,
          child: ClipRect(
            child: OverflowBox(
              alignment: Alignment(column == 0 ? -1 : 1, row == 0 ? -1 : 1),
              minWidth: width * 2,
              maxWidth: width * 2,
              minHeight: height * rows,
              maxHeight: height * rows,
              child: Image.asset(
                asset,
                fit: BoxFit.fill,
                excludeFromSemantics: true,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
