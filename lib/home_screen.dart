import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import 'look.dart';
import 'notifications.dart';
import 'sky_data.dart';
import 'sky_view.dart';
import 'star_sheet.dart';
import 'wishes.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _telescope = Telescope();
  final _store = WishStore();
  final _sky = GlobalKey<SkyViewState>();

  List<BrightStar> _brightStars = [];
  List<ExplodingStar> _explodingStars = [];
  List<Wish> _wishes = [];
  Set<String> _knownStars = {};
  Map<String, String> _names = {};

  bool _loading = true;
  String? _error;
  ExplodingStar? _banner;

  Timer? _refreshTimer;
  Timer? _bannerTimer;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _bannerTimer?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    final brightStars = await loadBrightStars();
    final wishes = await _store.load();
    final known = await _store.knownStars();
    final names = await _store.starNames();
    setState(() {
      _brightStars = brightStars;
      _wishes = wishes;
      _knownStars = known;
      _names = names;
    });
    await _refresh(firstTime: true);
    _refreshTimer = Timer.periodic(const Duration(minutes: 5), (_) => _refresh());
    await Notifications.start(onOpened: _openFromNotification, onArrived: _refresh);
  }

  Future<void> _openFromNotification(String? starId) async {
    await _refresh();
    final star = _explodingStars.where((s) => s.id == starId).firstOrNull;
    if (star != null && mounted) _openStar(star);
  }

  Future<void> _refresh({bool firstTime = false}) async {
    List<ExplodingStar> stars;
    try {
      stars = await _telescope.explodingStars();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = "can't reach the telescope… trying again soon";
      });
      return;
    }
    if (!mounted) return;

    final fresh = stars.where((s) => !_knownStars.contains(s.id)).toList();
    final neverOpenedBefore = _knownStars.isEmpty;

    setState(() {
      _explodingStars = stars;
      _loading = false;
      _error = null;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final sky = _sky.currentState;
      if (sky == null) return;
      if (firstTime && stars.isNotEmpty) {
        sky.lookAt(fresh.isNotEmpty ? fresh.first : stars.first, instant: true);
      }
      if (fresh.isEmpty) return;
      final toExplode = neverOpenedBefore ? [fresh.first] : fresh.take(5).toList();
      if (!firstTime) sky.lookAt(toExplode.first);
      for (var i = 0; i < toExplode.length; i++) {
        sky.explode(toExplode[i], delay: 0.8 + i * 0.9);
      }
      Future.delayed(const Duration(milliseconds: 900), () => _showBanner(toExplode.first));
    });

    _knownStars.addAll(stars.map((s) => s.id));
    await _store.saveKnownStars(_knownStars);
  }

  void _showBanner(ExplodingStar star) {
    if (!mounted) return;
    setState(() => _banner = star);
    _bannerTimer?.cancel();
    _bannerTimer = Timer(const Duration(seconds: 10), () {
      if (mounted) setState(() => _banner = null);
    });
  }

  Future<void> _openStar(ExplodingStar star) async {
    setState(() => _banner = null);
    _sky.currentState?.lookAt(star);
    final result = await showStarSheet(
      context,
      star,
      _telescope,
      name: _names[star.id],
      onRename: (name) {
        setState(() => _names = {..._names, star.id: name});
        _store.saveStarNames(_names);
      },
    );
    if (result == null || !mounted) return;

    final wish = Wish(text: result.text, starId: star.id, madeAt: DateTime.now(), lightYears: result.lightYears);
    setState(() => _wishes = [..._wishes, wish]);
    await _store.save(_wishes);
    _sky.currentState?.sendWish(star);

    await Future.delayed(const Duration(milliseconds: 1800));
    if (!mounted) return;
    final lightYears = result.lightYears;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: paper,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: const BorderSide(color: stickerYellow, width: 1.5),
        ),
        duration: const Duration(seconds: 5),
        content: Text(
          lightYears == null
              ? 'your wish is on its way…'
              : 'your wish is on its way…\nit will get there in about ${lightYearsText(lightYears)} years',
          style: const TextStyle(color: ink, fontSize: 17, height: 1.4),
        ),
      ),
    );
  }

  void _openWishes() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WishesPage(
          wishes: _wishes,
          names: _names,
          onChanged: (wishes) {
            setState(() => _wishes = wishes);
            _store.save(wishes);
          },
        ),
      ),
    );
  }

  String get _status {
    if (_loading) return 'looking up at the sky…';
    if (_error != null) return _error!;
    final today = _explodingStars.where((s) => s.isNew).length;
    if (today == 0) return '${_explodingStars.length} stars exploded this week';
    if (today == 1) return '1 star exploded today';
    return '$today stars exploded today';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: SkyView(
              key: _sky,
              brightStars: _brightStars,
              explodingStars: _explodingStars,
              names: _names,
              onStarTap: _openStar,
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 10, 16, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Text('wishing sky', style: TextStyle(color: paper, fontSize: 32)),
                            SizedBox(width: 8),
                            Icon(Icons.nightlight_round, color: stickerYellow, size: 22),
                          ],
                        ),
                        Text(_status, style: TextStyle(color: paper.withValues(alpha: 0.65), fontSize: 17)),
                      ],
                    ),
                  ),
                  _WishesTag(count: _wishes.length, onTap: _openWishes),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 14, 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (_explodingStars.any((s) => s.isNew))
                      _TodayList(
                        stars: _explodingStars.where((s) => s.isNew).toList(),
                        names: _names,
                        onTap: _openStar,
                      ),
                    const SizedBox(height: 12),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: ScaleTransition(scale: Tween(begin: 0.9, end: 1.0).animate(animation), child: child),
                      ),
                      child: _banner == null
                          ? const SizedBox.shrink()
                          : _ExplosionNote(
                              key: ValueKey(_banner!.id),
                              star: _banner!,
                              onTap: () => _openStar(_banner!),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TodayList extends StatefulWidget {
  const _TodayList({required this.stars, required this.names, required this.onTap});

  final List<ExplodingStar> stars;
  final Map<String, String> names;
  final ValueChanged<ExplodingStar> onTap;

  @override
  State<_TodayList> createState() => _TodayListState();
}

class _TodayListState extends State<_TodayList> {
  bool _open = true;

  String _shortAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 60) return '${max(diff.inMinutes, 1)}m ago';
    return '${diff.inHours}h ago';
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 215,
      child: PaperNote(
        angle: 1.2,
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _open = !_open),
              child: Row(
                children: [
                  Text("today's booms (${widget.stars.length})", style: const TextStyle(color: ink, fontSize: 18)),
                  const Spacer(),
                  Icon(_open ? Icons.expand_more : Icons.expand_less, color: pencil, size: 20),
                ],
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              alignment: Alignment.topCenter,
              child: !_open
                  ? const SizedBox(width: double.infinity)
                  : ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 180),
                      child: ListView.builder(
                        shrinkWrap: true,
                        padding: const EdgeInsets.only(top: 4),
                        itemCount: widget.stars.length,
                        itemBuilder: (context, index) {
                          final star = widget.stars[index];
                          return InkWell(
                            onTap: () => widget.onTap(star),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      widget.names[star.id] ?? star.id,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: ink, fontSize: 16),
                                    ),
                                  ),
                                  Text(_shortAgo(star.firstSeen), style: const TextStyle(color: pencil, fontSize: 15)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WishesTag extends StatelessWidget {
  const _WishesTag({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Transform.rotate(
        angle: 0.06,
        child: Container(
          margin: const EdgeInsets.only(top: 6),
          padding: const EdgeInsets.fromLTRB(12, 6, 14, 6),
          decoration: BoxDecoration(
            color: paper,
            borderRadius: BorderRadius.circular(4),
            boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 6, offset: Offset(1, 3))],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.star_rounded, color: crayonPink, size: 18),
              const SizedBox(width: 4),
              Text('my wishes ($count)', style: const TextStyle(color: ink, fontSize: 16)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExplosionNote extends StatelessWidget {
  const _ExplosionNote({super.key, required this.star, required this.onTap});

  final ExplodingStar star;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: PaperNote(
        angle: -1.5,
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
        child: Row(
          children: [
            const Icon(Icons.auto_awesome, color: crayonPink, size: 28),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('a star just exploded!', style: TextStyle(color: ink, fontSize: 21)),
                  Text('tap to make a wish', style: const TextStyle(color: pencil, fontSize: 16)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
