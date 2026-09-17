import 'package:flutter/material.dart';

import '../app/app_theme.dart';

Route<T> appPageRoute<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  final reduceMotion = MediaQuery.disableAnimationsOf(context);
  final duration = reduceMotion ? Duration.zero : context.motion.transition;
  return PageRouteBuilder<T>(
    pageBuilder: (context, animation, secondaryAnimation) => builder(context),
    transitionDuration: duration,
    reverseTransitionDuration: duration,
    transitionsBuilder: (context, animation, secondaryAnimation, child) =>
        FadeTransition(opacity: animation, child: child),
  );
}

/// Clean, modern page container with consistent padding and bounce physics.
class PageBody extends StatelessWidget {
  const PageBody({
    required this.children,
    super.key,
    this.padding,
    this.controller,
    this.bottomPadding = 28,
  });

  final List<Widget> children;
  final EdgeInsetsGeometry? padding;
  final ScrollController? controller;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListView(
        controller: controller,
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding:
            padding ??
            EdgeInsets.fromLTRB(
              context.spacing.lg,
              context.spacing.lg,
              context.spacing.lg,
              bottomPadding + MediaQuery.of(context).padding.bottom + 96,
            ),
        children: children,
      ),
    );
  }
}

/// Elevated card with soft shadow and subtle border — base for most surfaces.
class PSCard extends StatelessWidget {
  const PSCard({
    required this.child,
    super.key,
    this.padding,
    this.onTap,
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final decoration = BoxDecoration(
      color: color ?? scheme.surface,
      borderRadius: context.shapes.card,
      border: Border.all(color: scheme.outlineVariant, width: 1),
      boxShadow: [
        BoxShadow(
          color: scheme.shadow.withValues(
            alpha: scheme.brightness == Brightness.light ? 0.06 : 0.18,
          ),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
        BoxShadow(
          color: scheme.shadow.withValues(
            alpha: scheme.brightness == Brightness.light ? 0.03 : 0.10,
          ),
          blurRadius: 2,
          offset: const Offset(0, 1),
        ),
      ],
    );

    final content = Padding(
      padding: padding ?? EdgeInsets.all(context.spacing.lg),
      child: child,
    );

    if (onTap == null) {
      // Non-interactive: simple decorated container is fine (no ink needed).
      return Container(decoration: decoration, child: content);
    }
    // Interactive: use Ink + InkWell so splash is not hidden by the decoration.
    return Material(
      color: Colors.transparent,
      borderRadius: context.shapes.card,
      child: Ink(
        decoration: decoration,
        child: InkWell(
          onTap: onTap,
          borderRadius: context.shapes.card,
          child: content,
        ),
      ),
    );
  }
}

class EmptyStateCard extends StatelessWidget {
  const EmptyStateCard({
    required this.icon,
    required this.title,
    required this.message,
    super.key,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PSCard(
      padding: EdgeInsets.all(context.spacing.xl),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, color: scheme.onPrimaryContainer, size: 32),
          ),
          SizedBox(height: context.spacing.lg),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: context.spacing.sm),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          if (action != null) ...[
            SizedBox(height: context.spacing.lg),
            action!,
          ],
        ],
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.action});

  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(
      top: context.spacing.xl,
      bottom: context.spacing.md,
    ),
    child: Row(
      children: [
        Text(
          text,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            letterSpacing: 0.8,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Divider(
            color: Theme.of(
              context,
            ).colorScheme.outlineVariant.withValues(alpha: 0.6),
          ),
        ),
        if (action != null) ...[SizedBox(width: context.spacing.sm), action!],
      ],
    ),
  );
}

/// Section header with title + subtitle used on main screens.
class PageHeader extends StatelessWidget {
  const PageHeader({
    required this.title,
    required this.subtitle,
    super.key,
    this.trailing,
    this.icon,
  });

  final String title;
  final String subtitle;
  final Widget? trailing;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null) ...[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: scheme.onPrimaryContainer, size: 22),
          ),
          SizedBox(width: context.spacing.md),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                  height: 1.1,
                ),
              ),
              SizedBox(height: context.spacing.xs),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) ...[
          SizedBox(width: context.spacing.md),
          trailing!,
        ],
      ],
    );
  }
}

class AppListTile extends StatelessWidget {
  const AppListTile({
    required this.leading,
    required this.title,
    super.key,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.enabled = true,
  });

  final IconData leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PSCard(
      padding: EdgeInsets.symmetric(
        horizontal: context.spacing.lg,
        vertical: context.spacing.md,
      ),
      onTap: enabled ? onTap : null,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: enabled
                  ? scheme.primaryContainer
                  : scheme.surfaceContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              leading,
              color: enabled
                  ? scheme.onPrimaryContainer
                  : scheme.onSurfaceVariant,
              size: 20,
            ),
          ),
          SizedBox(width: context.spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: enabled ? null : scheme.onSurfaceVariant,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            SizedBox(width: context.spacing.sm),
            trailing!,
          ],
        ],
      ),
    );
  }
}

/// Pill badge used for status.
class StatusPill extends StatelessWidget {
  const StatusPill({
    required this.label,
    required this.icon,
    super.key,
    this.color,
  });

  final String label;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = color ?? scheme.secondaryContainer;
    final fg = color == null ? scheme.onSecondaryContainer : scheme.onPrimary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

/// Separated column with consistent gap — fixes history blending issue.
class SeparatedColumn extends StatelessWidget {
  const SeparatedColumn({
    required this.children,
    super.key,
    this.gap = 12,
    this.separator,
  });

  final List<Widget> children;
  final double gap;
  final Widget? separator;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        for (var i = 0; i < children.length; i++) ...[
          children[i],
          if (i != children.length - 1) separator ?? SizedBox(height: gap),
        ],
      ],
    );
  }
}

/// Soft divider with spacing.
class SoftDivider extends StatelessWidget {
  const SoftDivider({super.key, this.indent = 0});

  final double indent;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(horizontal: indent),
    child: Divider(
      height: 1,
      thickness: 1,
      color: Theme.of(
        context,
      ).colorScheme.outlineVariant.withValues(alpha: 0.7),
    ),
  );
}
