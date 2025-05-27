import 'package:flutter/material.dart';
import '../../utils/constants.dart';

class CustomCard extends StatelessWidget {
  final Widget child;
  final String? title;
  final Widget? titleWidget;
  final Widget? trailing;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final double elevation;
  final double borderRadius;
  final Color? backgroundColor;
  final Color? shadowColor;
  final bool hasBorder;
  final Color? borderColor;
  final double borderWidth;

  const CustomCard({
    super.key,
    required this.child,
    this.title,
    this.titleWidget,
    this.trailing,
    this.onTap,
    this.padding = const EdgeInsets.all(AppConstants.defaultPadding),
    this.margin = const EdgeInsets.only(bottom: AppConstants.defaultPadding),
    this.elevation = AppConstants.defaultElevation,
    this.borderRadius = AppConstants.defaultBorderRadius,
    this.backgroundColor,
    this.shadowColor,
    this.hasBorder = false,
    this.borderColor,
    this.borderWidth = 1.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Card(
      margin: margin,
      elevation: elevation,
      shadowColor: shadowColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
        side: hasBorder
            ? BorderSide(
                color: borderColor ?? theme.dividerColor,
                width: borderWidth,
              )
            : BorderSide.none,
      ),
      color: backgroundColor ?? theme.cardColor,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null || titleWidget != null || trailing != null)
              Padding(
                padding: EdgeInsets.only(
                  left: padding.horizontal / 2,
                  right: padding.horizontal / 2,
                  top: padding.vertical / 2,
                  bottom: title != null || titleWidget != null ? padding.vertical / 4 : 0,
                ),
                child: Row(
                  children: [
                    if (titleWidget != null)
                      Expanded(child: titleWidget!)
                    else if (title != null)
                      Expanded(
                        child: Text(
                          title!,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    if (trailing != null) trailing!,
                  ],
                ),
              ),
            Padding(
              padding: EdgeInsets.only(
                left: padding.horizontal / 2,
                right: padding.horizontal / 2,
                bottom: padding.vertical / 2,
                top: title != null || titleWidget != null ? 0 : padding.vertical / 2,
              ),
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}

extension EdgeInsetsGeometryExtension on EdgeInsetsGeometry {
  double get horizontal {
    if (this is EdgeInsets) {
      final edgeInsets = this as EdgeInsets;
      return edgeInsets.horizontal;
    }
    return 16.0; // Default value
  }

  double get vertical {
    if (this is EdgeInsets) {
      final edgeInsets = this as EdgeInsets;
      return edgeInsets.vertical;
    }
    return 16.0; // Default value
  }
}
