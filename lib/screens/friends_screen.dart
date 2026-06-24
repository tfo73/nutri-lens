import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:provider/provider.dart';
import '../providers/profile_provider.dart';
import '../services/device_id_service.dart';
import '../l10n/app_localizations.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _addFriendCtrl = TextEditingController();
  String _searchQuery = '';
  String? _myUserId;

  @override
  void initState() {
    super.initState();
    _loadMyId();
  }

  Future<void> _loadMyId() async {
    try {
      final uid = await DeviceIdService.instance.ensureFirebaseUser();
      if (mounted) {
        setState(() {
          _myUserId = uid.length > 8 ? uid.substring(0, 8).toUpperCase() : uid.toUpperCase();
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _addFriendCtrl.dispose();
    super.dispose();
  }

  void _confirmAddFriend(UserProfile user) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('Arkadaş Ekle')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              child: Text(user.name[0], style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 16),
            Text(user.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            Text('ID: ${user.id}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 12),
            Text(context.tr('Bu kişiyi arkadaş olarak eklemek istiyor musunuz?'), textAlign: TextAlign.center),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.tr('Vazgeç'))),
          ElevatedButton(
            onPressed: () {
              context.read<ProfileProvider>().addFriend(user);
              Navigator.pop(ctx);
              _addFriendCtrl.clear();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Arkadaş eklendi!')));
            },
            child: Text(context.tr('Evet, Ekle')),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(String id, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('Arkadaşı Sil')),
        content: Text(context.tr('{} arkadaşlıktan çıkarılsın mı?').replaceFirst('{}', name)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.tr('Vazgeç'))),
          TextButton(
            onPressed: () {
              context.read<ProfileProvider>().removeFriend(id);
              Navigator.pop(ctx);
            },
            child: Text(context.tr('Sil'), style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _searchAndAddFriend(String id, ProfileProvider provider) async {
    final cleanId = id.trim();
    if (cleanId.isNotEmpty) {
      final user = await provider.findUserById(cleanId);
      if (user != null) {
        if (mounted) _confirmAddFriend(user);
      } else {
        if (mounted) _showCenterError(context.tr('Böyle bir ID bulunamadı.'));
      }
    }
  }

  void _showCenterError(String message) {
    showDialog(
      context: context,
      builder: (ctx) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            margin: const EdgeInsets.all(32),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 20,
                )
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 40),
                const SizedBox(height: 16),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(context.tr('Tamam')),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProfileProvider>();
    final friends = provider.friends;
    final filtered = friends.where((f) {
      final q = _searchQuery.toLowerCase();
      return f.name.toLowerCase().contains(q) || f.id.toLowerCase().contains(q);
    }).toList();

    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Arkadaşlar')),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Search
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: context.tr('Ara...'),
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Theme.of(context).cardColor,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
          
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_outline, size: 64, color: cs.primary.withValues(alpha: 0.5)),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty ? context.tr('Arkadaşlarını ekle') : context.tr('Sonuç bulunamadı'),
                          style: const TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final friend = filtered[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Slidable(
                          key: ValueKey(friend.id),
                          startActionPane: ActionPane(
                            motion: const ScrollMotion(),
                            children: [
                              SlidableAction(
                                onPressed: (_) => provider.toggleFavoriteFriend(friend.id),
                                backgroundColor: Colors.orange,
                                foregroundColor: Colors.white,
                                icon: friend.isFavorite ? Icons.star : Icons.star_border,
                                label: friend.isFavorite ? context.tr('Sabitlendi') : context.tr('Favori'),
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ],
                          ),
                          endActionPane: ActionPane(
                            motion: const ScrollMotion(),
                            children: [
                              SlidableAction(
                                onPressed: (_) => _showDeleteConfirmation(friend.id, friend.name),
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                icon: Icons.delete,
                                label: context.tr('Sil'),
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ],
                          ),
                          child: _FriendCard(friend: friend),
                        ),
                      );
                    },
                  ),
          ),
          
          // My ID Box
          if (_myUserId != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cs.primary.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      context.tr('Senin arkadaş ID: '),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                    Text(
                      _myUserId!,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: cs.primary,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 16),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _myUserId!));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('ID Kopyalandı!')),
                        );
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      color: cs.primary,
                    ),
                  ],
                ),
              ),
            ),

          // Add Friend
          Container(
            padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).padding.bottom + 16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -5))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _addFriendCtrl,
                        decoration: InputDecoration(
                          hintText: context.tr('Arkadaş ID girin...'),
                          filled: true,
                          fillColor: isDark ? Colors.black26 : Colors.grey[100],
                          border: OutlineInputBorder(
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(12),
                              topRight: Radius.circular(12),
                            ),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        onSubmitted: (v) => _searchAndAddFriend(v, provider),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: () => _searchAndAddFriend(_addFriendCtrl.text, provider),
                      icon: const Icon(Icons.add),
                      style: IconButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FriendCard extends StatelessWidget {
  final UserProfile friend;
  const _FriendCard({required this.friend});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: cs.primary.withValues(alpha: 0.1),
                      child: Text(friend.name[0], style: TextStyle(color: cs.primary, fontWeight: FontWeight.bold)),
                    ),
                    if (friend.isFavorite)
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Icon(Icons.star, size: 14, color: Colors.orange),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(friend.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('ID: ${friend.id}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _infoCell(Icons.cake_outlined, context.tr('Yaş'), friend.age.toString())),
                Expanded(child: _infoCell(Icons.straighten_outlined, context.tr('Boy'), context.tr('{} cm').replaceFirst('{}', friend.height.toStringAsFixed(0)))),
                Expanded(child: _infoCell(Icons.monitor_weight_outlined, context.tr('Kilo'), context.tr('{} kg').replaceFirst('{}', friend.weight.toStringAsFixed(1)))),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _infoCell(Icons.flag_outlined, context.tr('Hedef'), context.tr(friend.goalLabel))),
                Expanded(child: _infoCell(friend.gender == Gender.female ? Icons.female : Icons.male, context.tr('Cinsiyet'), friend.gender == Gender.female ? context.tr('Kadın') : context.tr('Erkek'))),
                Expanded(child: _infoCell(Icons.directions_run_outlined, context.tr('Aktivite'), context.tr(friend.activityLabel))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoCell(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 14, color: const Color(0xFF58A6FF)),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 9, color: Color(0xFF8B949E))),
              Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }
}
