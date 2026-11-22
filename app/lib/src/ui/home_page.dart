import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app.dart';
import '../services/eyedropper_service.dart';
import '../state/checker_controller.dart';
import '../theme.dart';
import 'widgets/alternatives_panel.dart';
import 'widgets/color_panel.dart';
import 'widgets/common.dart';
import 'widgets/explanation_card.dart';
import 'widgets/ratio_card.dart';
import 'widgets/recent_pairs.dart';
import 'widgets/results_section.dart';

const websiteUrl = 'https://color-contrast.joemazzone.net';
const repoUrl = 'https://github.com/MrMazzone/color-contrast-checker';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _picking = false;

  Future<void> _pickFromScreen(ColorRole role) async {
    if (_picking) return;
    final scope = AppScope.read(context);
    setState(() => _picking = true);
    final outcome = await scope.eyedropper.pick(
      hideWindow: scope.settings.hideWindowWhilePicking,
    );
    if (!mounted) return;
    setState(() => _picking = false);
    switch (outcome) {
      case Picked(:final color):
        scope.checker.setColor(role, color, keepAlpha: true);
        SemanticsService.sendAnnouncement(
          View.of(context),
          '${role.label} set to ${color.toHex()}',
          TextDirection.ltr,
        );
      case PickCancelled():
        break;
      case PickFailed(:final message):
        showMessage(context, message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.read(context);
    final isMac = Platform.isMacOS;

    return CallbackShortcuts(
      bindings: {
        SingleActivator(
          LogicalKeyboardKey.digit1,
          control: !isMac,
          meta: isMac,
        ): () =>
            _pickFromScreen(ColorRole.foreground),
        SingleActivator(
          LogicalKeyboardKey.digit2,
          control: !isMac,
          meta: isMac,
        ): () =>
            _pickFromScreen(ColorRole.background),
        SingleActivator(
          LogicalKeyboardKey.keyX,
          control: !isMac,
          meta: isMac,
          shift: true,
        ): scope.checker.swap,
        SingleActivator(
          LogicalKeyboardKey.keyC,
          control: !isMac,
          meta: isMac,
          shift: true,
        ): () => copyWithFeedback(
          context,
          scope.checker.buildReport(),
          label: 'contrast report',
        ),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                ListenableBuilder(
                  listenable: scope.settings,
                  builder: (context, _) => _TopBar(
                    onCopyReport: () => copyWithFeedback(
                      context,
                      scope.checker.buildReport(),
                      label: 'contrast report',
                    ),
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) =>
                        constraints.maxWidth >= 1080
                        ? _WideLayout(onPick: _pickFromScreen)
                        : _NarrowLayout(
                            onPick: _pickFromScreen,
                            sideBySide: constraints.maxWidth >= 720,
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SwapButton extends StatelessWidget {
  const _SwapButton({this.vertical = true});

  final bool vertical;

  @override
  Widget build(BuildContext context) {
    final checker = AppScope.read(context).checker;
    final shortcut = Platform.isMacOS ? '⌘⇧X' : 'Ctrl+Shift+X';
    return Center(
      child: IconButton.outlined(
        tooltip: 'Swap colors ($shortcut)',
        onPressed: checker.swap,
        style: IconButton.styleFrom(
          backgroundColor: context.colors.surface,
          side: BorderSide(color: context.colors.border),
        ),
        icon: Icon(
          vertical ? Icons.swap_vert_rounded : Icons.swap_horiz_rounded,
        ),
      ),
    );
  }
}

class _WideLayout extends StatelessWidget {
  const _WideLayout({required this.onPick});

  final void Function(ColorRole) onPick;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 420,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 8, 12, 24),
            children: [
              ColorPanel(
                role: ColorRole.foreground,
                onPickFromScreen: () => onPick(ColorRole.foreground),
              ),
              const SizedBox(height: 4),
              const _SwapButton(),
              const SizedBox(height: 4),
              ColorPanel(
                role: ColorRole.background,
                onPickFromScreen: () => onPick(ColorRole.background),
              ),
              const SizedBox(height: 16),
              const RecentPairs(),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 8, 24, 24),
            children: const [
              RatioCard(),
              SizedBox(height: 16),
              ResultsSection(),
              SizedBox(height: 16),
              AlternativesPanel(),
              SizedBox(height: 16),
              ExplanationCard(),
            ],
          ),
        ),
      ],
    );
  }
}

class _NarrowLayout extends StatelessWidget {
  const _NarrowLayout({required this.onPick, required this.sideBySide});

  final void Function(ColorRole) onPick;
  final bool sideBySide;

  @override
  Widget build(BuildContext context) {
    final fg = ColorPanel(
      role: ColorRole.foreground,
      onPickFromScreen: () => onPick(ColorRole.foreground),
    );
    final bg = ColorPanel(
      role: ColorRole.background,
      onPickFromScreen: () => onPick(ColorRole.background),
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        if (sideBySide)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: fg),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: _SwapButton(vertical: false),
                ),
                Expanded(child: bg),
              ],
            ),
          )
        else ...[
          fg,
          const SizedBox(height: 4),
          const _SwapButton(),
          const SizedBox(height: 4),
          bg,
        ],
        const SizedBox(height: 16),
        const RatioCard(),
        const SizedBox(height: 16),
        const ResultsSection(),
        const SizedBox(height: 16),
        const AlternativesPanel(),
        const SizedBox(height: 16),
        const RecentPairs(),
        const SizedBox(height: 16),
        const ExplanationCard(),
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onCopyReport});

  final VoidCallback onCopyReport;

  @override
  Widget build(BuildContext context) {
    final settings = AppScope.read(context).settings;
    final c = context.colors;
    final isMac = Platform.isMacOS;

    final (themeIcon, themeLabel, nextMode) = switch (settings.themeMode) {
      ThemeMode.system => (
        Icons.brightness_auto_rounded,
        'System theme',
        ThemeMode.light,
      ),
      ThemeMode.light => (
        Icons.light_mode_rounded,
        'Light theme',
        ThemeMode.dark,
      ),
      ThemeMode.dark => (
        Icons.dark_mode_rounded,
        'Dark theme',
        ThemeMode.system,
      ),
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 14, 16, 10),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: Image.asset(
              'assets/images/app_icon.png',
              width: 34,
              height: 34,
              semanticLabel: 'Color Contrast Checker',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Color Contrast Checker', style: context.text.titleLarge),
                Text(
                  'WCAG 2.1 · AA & AAA',
                  style: context.text.labelMedium?.copyWith(
                    color: c.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Copy report (${isMac ? '⌘⇧C' : 'Ctrl+Shift+C'})',
            onPressed: onCopyReport,
            icon: const Icon(Icons.assignment_rounded),
          ),
          IconButton(
            tooltip: '$themeLabel — click to change',
            onPressed: () => settings.themeMode = nextMode,
            icon: Icon(themeIcon),
          ),
          MenuAnchor(
            menuChildren: [
              ListenableBuilder(
                listenable: settings,
                builder: (context, _) => CheckboxMenuButton(
                  value: settings.hideWindowWhilePicking,
                  onChanged: (v) => settings.hideWindowWhilePicking = v ?? true,
                  child: const Text(
                    'Hide this window while using the eyedropper',
                  ),
                ),
              ),
              const Divider(),
              MenuItemButton(
                leadingIcon: const Icon(Icons.public_rounded, size: 20),
                onPressed: () => launchUrl(Uri.parse(websiteUrl)),
                child: const Text('Website'),
              ),
              MenuItemButton(
                leadingIcon: const Icon(Icons.code_rounded, size: 20),
                onPressed: () => launchUrl(Uri.parse(repoUrl)),
                child: const Text('Source code on GitHub'),
              ),
              MenuItemButton(
                leadingIcon: const Icon(Icons.info_outline_rounded, size: 20),
                onPressed: () => _showAbout(context),
                child: const Text('About'),
              ),
            ],
            builder: (context, menu, _) => IconButton(
              tooltip: 'Settings and about',
              onPressed: () => menu.isOpen ? menu.close() : menu.open(),
              icon: const Icon(Icons.more_vert_rounded),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAbout(BuildContext context) async {
    String version = '';
    try {
      final info = await PackageInfo.fromPlatform();
      version = info.version;
    } catch (_) {}
    if (!context.mounted) return;
    showAboutDialog(
      context: context,
      applicationName: 'Color Contrast Checker',
      applicationVersion: version,
      applicationIcon: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.asset('assets/images/app_icon.png', width: 56, height: 56),
      ),
      applicationLegalese: '© 2026 Joe Mazzone · MIT License',
      children: [
        const SizedBox(height: 16),
        const Text(
          'Check color pairs against WCAG 2.1 contrast requirements and pick '
          'colors from anywhere on your screen. Works offline; nothing you '
          'check leaves your computer.',
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            TextButton(
              onPressed: () => launchUrl(Uri.parse(websiteUrl)),
              child: const Text('color-contrast.joemazzone.net'),
            ),
          ],
        ),
      ],
    );
  }
}
