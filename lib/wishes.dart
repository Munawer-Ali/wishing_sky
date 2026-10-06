import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'look.dart';
import 'sky_data.dart';

class Wish {
  Wish({required this.text, required this.starId, required this.madeAt, this.lightYears});

  factory Wish.fromJson(Map<String, dynamic> json) {
    return Wish(
      text: json['text'] as String,
      starId: json['starId'] as String,
      madeAt: DateTime.parse(json['madeAt'] as String),
      lightYears: (json['lightYears'] as num?)?.toDouble(),
    );
  }

  final String text;
  final String starId;
  final DateTime madeAt;
  final double? lightYears;

  Map<String, dynamic> toJson() => {
    'text': text,
    'starId': starId,
    'madeAt': madeAt.toIso8601String(),
    'lightYears': lightYears,
  };
}

class WishStore {
  static const _wishesKey = 'wishes';
  static const _knownStarsKey = 'known_stars';
  static const _namesKey = 'star_names';

  Future<List<Wish>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_wishesKey) ?? [];
    return [for (final s in saved) Wish.fromJson(jsonDecode(s) as Map<String, dynamic>)];
  }

  Future<void> save(List<Wish> wishes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_wishesKey, [for (final w in wishes) jsonEncode(w.toJson())]);
  }

  Future<Set<String>> knownStars() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_knownStarsKey) ?? []).toSet();
  }

  Future<void> saveKnownStars(Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_knownStarsKey, ids.toList());
  }

  Future<Map<String, String>> starNames() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_namesKey);
    if (saved == null) return {};
    return Map<String, String>.from(jsonDecode(saved) as Map);
  }

  Future<void> saveStarNames(Map<String, String> names) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_namesKey, jsonEncode(names));
  }
}

class WishesPage extends StatefulWidget {
  const WishesPage({super.key, required this.wishes, required this.names, required this.onChanged});

  final List<Wish> wishes;
  final Map<String, String> names;
  final ValueChanged<List<Wish>> onChanged;

  @override
  State<WishesPage> createState() => _WishesPageState();
}

class _WishesPageState extends State<WishesPage> {
  late final List<Wish> _wishes = [...widget.wishes];

  void _remove(Wish wish) {
    setState(() => _wishes.remove(wish));
    widget.onChanged(_wishes);
  }

  @override
  Widget build(BuildContext context) {
    final newestFirst = _wishes.reversed.toList();
    return Scaffold(
      backgroundColor: ceilingTop,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: paper,
        title: const Text('my wishes', style: TextStyle(fontSize: 28)),
      ),
      body: newestFirst.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'no wishes yet…\nfind a yellow star and make one',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: paper.withValues(alpha: 0.5), fontSize: 20, height: 1.5),
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
              itemCount: newestFirst.length,
              separatorBuilder: (_, _) => const SizedBox(height: 26),
              itemBuilder: (context, index) {
                final wish = newestFirst[index];
                return Dismissible(
                  key: ValueKey(wish.madeAt.toIso8601String()),
                  direction: DismissDirection.endToStart,
                  onDismissed: (_) => _remove(wish),
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 24),
                    child: Icon(Icons.delete_outline, color: paper.withValues(alpha: 0.5)),
                  ),
                  child: _WishNote(wish: wish, name: widget.names[wish.starId], angle: index.isEven ? -1.2 : 1.0),
                );
              },
            ),
    );
  }
}

class _WishNote extends StatelessWidget {
  const _WishNote({required this.wish, required this.name, required this.angle});

  final Wish wish;
  final String? name;
  final double angle;

  @override
  Widget build(BuildContext context) {
    final lightYears = wish.lightYears;
    return PaperNote(
      angle: angle,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Dear star,', style: TextStyle(color: pencil, fontSize: 17)),
          Text(wish.text, style: const TextStyle(color: ink, fontSize: 22, height: 1.35)),
          const SizedBox(height: 10),
          Text('${name ?? wish.starId} · ${timeAgo(wish.madeAt)}', style: const TextStyle(color: pencil, fontSize: 15)),
          if (lightYears != null)
            Text(
              'gets there in about ${lightYearsText(lightYears)} years',
              style: const TextStyle(color: crayonPink, fontSize: 15),
            ),
        ],
      ),
    );
  }
}
