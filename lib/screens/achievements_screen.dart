import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../providers/language_provider.dart';
import '../providers/achievement_provider.dart';

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen>
    with TickerProviderStateMixin {
  final Map<String, AnimationController> _animControllers = {};
  final Map<String, Animation<double>> _scaleAnims = {};

  @override
  void initState() {
    super.initState();
    final provider = context.read<AchievementProvider>();
    final newlyEarned = provider.newlyEarned;

    for (final ach in AchievementProvider.achievements) {
      if (newlyEarned.contains(ach.id)) {
        final ctrl = AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 900),
        );
        _animControllers[ach.id] = ctrl;
        _scaleAnims[ach.id] = Tween<double>(begin: 0.4, end: 1.0).animate(
          CurvedAnimation(parent: ctrl, curve: Curves.elasticOut),
        );
        ctrl.forward();
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      provider.clearNewlyEarned();
    });
  }

  @override
  void dispose() {
    for (final ctrl in _animControllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LanguageProvider>();
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tr('Rozetlerim')),
        centerTitle: true,
      ),
      body: Consumer<AchievementProvider>(
        builder: (context, provider, _) {
          final earnedCount = provider.earned.length;
          final total = AchievementProvider.achievements.length;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Kazanılan Rozetler',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$earnedCount / $total rozet',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                        SizedBox(
                          width: 48,
                          height: 48,
                          child: CircularProgressIndicator(
                            value: total > 0 ? earnedCount / total : 0,
                            strokeWidth: 6,
                            backgroundColor: Theme.of(context)
                                .colorScheme
                                .surfaceVariant,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.82,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                  ),
                  itemCount: AchievementProvider.achievements.length,
                  itemBuilder: (context, index) {
                    final ach = AchievementProvider.achievements[index];
                    final isEarned = provider.isEarned(ach.id);
                    final prog = provider.getProgress(ach.progressKey);
                    final scaleAnim = _scaleAnims[ach.id];

                    Widget card = _AchievementCard(
                      ach: ach,
                      isEarned: isEarned,
                      progress: prog,
                    );

                    if (scaleAnim != null) {
                      card = ScaleTransition(scale: scaleAnim, child: card);
                    }

                    return card;
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AchievementCard extends StatefulWidget {
  final AchievementDef ach;
  final bool isEarned;
  final int progress;

  const _AchievementCard({
    required this.ach,
    required this.isEarned,
    required this.progress,
  });

  @override
  State<_AchievementCard> createState() => _AchievementCardState();
}

class _AchievementCardState extends State<_AchievementCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glowCtrl;
  late final Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _glow = Tween<double>(begin: 0.25, end: 0.9).animate(
      CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut),
    );
    if (widget.isEarned) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (!MediaQuery.of(context).disableAnimations) {
          _glowCtrl.repeat(reverse: true);
        } else {
          _glowCtrl.value = 1.0;
        }
      });
    }
  }

  @override
  void didUpdateWidget(_AchievementCard old) {
    super.didUpdateWidget(old);
    if (widget.isEarned && !old.isEarned) {
      if (!MediaQuery.of(context).disableAnimations) {
        _glowCtrl.repeat(reverse: true);
      }
    }
  }

  @override
  void dispose() {
    _glowCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final clampedProgress = widget.progress.clamp(0, widget.ach.requirement);
    final progressFraction = widget.ach.requirement > 0
        ? clampedProgress / widget.ach.requirement
        : 1.0;

    final bgColor = widget.isEarned
        ? colorScheme.primaryContainer
        : colorScheme.surfaceVariant.withOpacity(0.5);
    final textColor = widget.isEarned
        ? colorScheme.onPrimaryContainer
        : colorScheme.onSurfaceVariant;
    final progressBarColor =
        widget.isEarned ? colorScheme.primary : colorScheme.outline;

    return AnimatedBuilder(
      animation: _glow,
      builder: (context, child) {
        return Container(
          decoration: widget.isEarned
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.primary.withOpacity(
                          _glow.value * 0.35),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                )
              : null,
          child: child,
        );
      },
      child: Card(
        color: bgColor,
        elevation: widget.isEarned ? 3 : 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                children: [
                  ColorFiltered(
                    colorFilter: widget.isEarned
                        ? const ColorFilter.mode(
                            Colors.transparent,
                            BlendMode.multiply,
                          )
                        : const ColorFilter.matrix([
                            0.2126,
                            0.7152,
                            0.0722,
                            0,
                            0,
                            0.2126,
                            0.7152,
                            0.0722,
                            0,
                            0,
                            0.2126,
                            0.7152,
                            0.0722,
                            0,
                            0,
                            0,
                            0,
                            0,
                            0.5,
                            0,
                          ]),
                    child: Text(
                      widget.ach.emoji,
                      style: const TextStyle(fontSize: 44),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.ach.name,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: textColor,
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.ach.description,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: textColor.withOpacity(0.7),
                        ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progressFraction,
                      minHeight: 5,
                      backgroundColor: colorScheme.surface,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(progressBarColor),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$clampedProgress/${widget.ach.requirement} ${widget.ach.unit}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: textColor,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
