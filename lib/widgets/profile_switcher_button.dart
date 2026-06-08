import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/profile_provider.dart';
import '../screens/profile_screen.dart';

class ProfileSwitcherButton extends StatelessWidget {
  const ProfileSwitcherButton({super.key});

  static const List<Color> _avatarColors = [
    Color(0xFF7EE787),
    Color(0xFF58A6FF),
    Color(0xFFE91E63),
    Color(0xFFF0A500),
    Color(0xFF9C27B0),
    Color(0xFF00BCD4),
    Color(0xFFF85149),
    Color(0xFF8B949E),
  ];

  Color _colorForId(String id) {
    final hash = id.codeUnits.fold(0, (prev, e) => prev + e);
    return _avatarColors[hash % _avatarColors.length];
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  void _showSwitcher(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Consumer<ProfileProvider>(
          builder: (ctx, provider, _) => _ProfileSwitcherSheet(
            provider: provider,
            colorForId: _colorForId,
            initials: _initials,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ProfileProvider>(
      builder: (context, provider, _) {
        final profile = provider.activeProfile;
        final name = profile?.name ?? '';
        final color = profile != null ? _colorForId(profile.id) : Colors.grey;
        final label = _initials(name);

        return GestureDetector(
          onTap: () => _showSwitcher(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: color,
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ProfileSwitcherSheet extends StatelessWidget {
  final ProfileProvider provider;
  final Color Function(String id) colorForId;
  final String Function(String name) initials;

  const _ProfileSwitcherSheet({
    required this.provider,
    required this.colorForId,
    required this.initials,
  });

  @override
  Widget build(BuildContext context) {
    final profiles = provider.profiles;
    final activeId = provider.activeProfileId;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.asset(
                      'assets/icon/icon.webp',
                      width: 24,
                      height: 24,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'LensEat',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const Divider(),
            ...profiles.map((profile) {
              final isActive = profile.id == activeId;
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: colorForId(profile.id),
                  child: Text(
                    initials(profile.name),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(
                  profile.name,
                  style: TextStyle(
                    fontWeight:
                        isActive ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                subtitle: Text(profile.goalLabel),
                trailing: isActive
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : null,
                onTap: isActive
                    ? null
                    : () async {
                        final name = profile.name;
                        await provider.switchProfile(profile.id);
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content:
                                  Text('$name\'in profiline geçildi'),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      },
              );
            }),
            const Divider(),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFF58A6FF),
                child: Icon(Icons.add, color: Colors.white),
              ),
              title: const Text(
                'Yeni Profil Ekle +',
                style: TextStyle(
                  color: Color(0xFF58A6FF),
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () {
                // Navigator.pop sonrası context geçersiz olacağı için
                // önce pop ederek modalı kapat, sonra rootNavigator ile push yap
                final nav = Navigator.of(context, rootNavigator: true);
                nav.pop();
                nav.push(
                  MaterialPageRoute(
                    builder: (_) => const ProfileScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
