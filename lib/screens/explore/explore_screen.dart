import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/nearby_venue.dart';
import '../../models/nearby_game.dart';
import '../../models/nearby_post.dart';
import '../../repositories/geo_repository.dart';
import '../../services/location_service.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final GeoRepository _geoRepo = GeoRepository();
  final LocationService _locationService = LocationService();

  double _radiusKm = 5.0;
  double? _lat;
  double? _lng;
  bool _locationLoading = true;

  // Venues
  List<NearbyVenue> _venues = [];
  bool _venuesLoading = false;
  String? _venuesError;

  // Games
  List<NearbyGame> _games = [];
  bool _gamesLoading = false;
  String? _gamesError;

  // Posts
  List<NearbyPost> _posts = [];
  bool _postsLoading = false;
  String? _postsError;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    final loc = await _locationService.getCurrentLocation();
    setState(() {
      _lat = loc.lat;
      _lng = loc.lng;
      _locationLoading = false;
    });
    _loadAll();
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadVenues(), _loadGames(), _loadPosts()]);
  }

  Future<void> _loadVenues() async {
    if (_lat == null || _lng == null) return;
    setState(() {
      _venuesLoading = true;
      _venuesError = null;
    });
    try {
      final results = await _geoRepo.getNearbyVenues(
        lat: _lat!,
        lng: _lng!,
        radiusMeters: _radiusKm * 1000,
      );
      setState(() {
        _venues = results;
        _venuesLoading = false;
      });
    } catch (e) {
      setState(() {
        _venuesError = 'Failed to load venues';
        _venuesLoading = false;
      });
    }
  }

  Future<void> _loadGames() async {
    if (_lat == null || _lng == null) return;
    setState(() {
      _gamesLoading = true;
      _gamesError = null;
    });
    try {
      final results = await _geoRepo.getNearbyGames(
        lat: _lat!,
        lng: _lng!,
        radiusMeters: _radiusKm * 1000,
      );
      setState(() {
        _games = results;
        _gamesLoading = false;
      });
    } catch (e) {
      setState(() {
        _gamesError = 'Failed to load games';
        _gamesLoading = false;
      });
    }
  }

  Future<void> _loadPosts() async {
    if (_lat == null || _lng == null) return;
    setState(() {
      _postsLoading = true;
      _postsError = null;
    });
    try {
      final results = await _geoRepo.getNearbyPosts(
        lat: _lat!,
        lng: _lng!,
        radiusMeters: _radiusKm * 1000,
      );
      setState(() {
        _posts = results;
        _postsLoading = false;
      });
    } catch (e) {
      setState(() {
        _postsError = 'Failed to load posts';
        _postsLoading = false;
      });
    }
  }

  Widget _buildRadiusSlider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Text('Radius: '),
          Expanded(
            child: Slider(
              value: _radiusKm,
              min: 1,
              max: 25,
              divisions: 24,
              label: '${_radiusKm.toInt()} km',
              onChanged: (value) {
                setState(() => _radiusKm = value);
              },
              onChangeEnd: (_) => _loadAll(),
            ),
          ),
          Text('${_radiusKm.toInt()} km'),
        ],
      ),
    );
  }

  Widget _buildVenuesTab() {
    return RefreshIndicator(
      onRefresh: _loadVenues,
      child: _venuesLoading
          ? const Center(child: CircularProgressIndicator())
          : _venuesError != null
          ? ListView(
              children: [
                const SizedBox(height: 120),
                Center(child: Text(_venuesError!)),
              ],
            )
          : _venues.isEmpty
          ? ListView(
              children: const [
                SizedBox(height: 120),
                Center(child: Text('No venues found nearby')),
              ],
            )
          : ListView.builder(
              itemCount: _venues.length,
              itemBuilder: (context, index) {
                final v = _venues[index];
                return ListTile(
                  leading: Text(
                    v.isIndoor == true ? '🏠' : '🌳',
                    style: const TextStyle(fontSize: 24),
                  ),
                  title: Text(v.nameEn),
                  subtitle: Text(
                    [if (v.district != null) v.district, v.city].join(', '),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(v.distanceLabel),
                      if (v.minPricePerHour != null)
                        Text(
                          'AED ${v.minPricePerHour!.toStringAsFixed(0)}/hr',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildGamesTab() {
    final dateFormat = DateFormat('EEE d MMM · HH:mm');
    return RefreshIndicator(
      onRefresh: _loadGames,
      child: _gamesLoading
          ? const Center(child: CircularProgressIndicator())
          : _gamesError != null
          ? ListView(
              children: [
                const SizedBox(height: 120),
                Center(child: Text(_gamesError!)),
              ],
            )
          : _games.isEmpty
          ? ListView(
              children: const [
                SizedBox(height: 120),
                Center(child: Text('No games found nearby')),
              ],
            )
          : ListView.builder(
              itemCount: _games.length,
              itemBuilder: (context, index) {
                final g = _games[index];
                return ListTile(
                  title: Text(g.title),
                  subtitle: Text(dateFormat.format(g.startAt)),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(g.distanceLabel),
                      if (g.capacity != null)
                        Text(
                          '${g.capacity} players',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildPostsTab() {
    return RefreshIndicator(
      onRefresh: _loadPosts,
      child: _postsLoading
          ? const Center(child: CircularProgressIndicator())
          : _postsError != null
          ? ListView(
              children: [
                const SizedBox(height: 120),
                Center(child: Text(_postsError!)),
              ],
            )
          : _posts.isEmpty
          ? ListView(
              children: const [
                SizedBox(height: 120),
                Center(child: Text('No posts found nearby')),
              ],
            )
          : ListView.builder(
              itemCount: _posts.length,
              itemBuilder: (context, index) {
                final p = _posts[index];
                return ListTile(
                  title: Text(
                    p.body ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Row(
                    children: [
                      Text('❤️ ${p.likeCount}'),
                      const SizedBox(width: 12),
                      Text('💬 ${p.commentCount}'),
                      const SizedBox(width: 12),
                      Text(
                        DateFormat.yMMMd().format(p.createdAt),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  trailing: Text(
                    '${(p.distanceMeters / 1000).toStringAsFixed(1)} km',
                  ),
                );
              },
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_locationLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Explore'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Venues'),
              Tab(text: 'Games'),
              Tab(text: 'Posts'),
            ],
          ),
        ),
        body: Column(
          children: [
            _buildRadiusSlider(),
            Expanded(
              child: TabBarView(
                children: [
                  _buildVenuesTab(),
                  _buildGamesTab(),
                  _buildPostsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
