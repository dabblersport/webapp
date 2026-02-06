import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class GameCreationSuccessScreen extends StatefulWidget {
  final Map<String, dynamic> gameData;
  final VoidCallback onCreateAnother;
  final VoidCallback onViewGame;
  final VoidCallback onGoHome;

  const GameCreationSuccessScreen({
    super.key,
    required this.gameData,
    required this.onCreateAnother,
    required this.onViewGame,
    required this.onGoHome,
  });

  @override
  State<GameCreationSuccessScreen> createState() =>
      _GameCreationSuccessScreenState();
}

class _GameCreationSuccessScreenState extends State<GameCreationSuccessScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late AnimationController _slideController;

  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );

    _startAnimations();
  }

  void _startAnimations() async {
    await Future.delayed(const Duration(milliseconds: 200));
    _scaleController.forward();

    await Future.delayed(const Duration(milliseconds: 300));
    _fadeController.forward();

    await Future.delayed(const Duration(milliseconds: 200));
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Column(
                    children: [
                      _buildSuccessAnimation(),
                      const SizedBox(height: 32),

                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: Column(
                          children: [
                            const Text(
                              'Game Created Successfully! 🎉',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),

                            Text(
                              'Your "${widget.gameData['title']}" game is now live and ready for players to join!',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      SlideTransition(
                        position: _slideAnimation,
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child: _buildGameSummaryCard(),
                        ),
                      ),

                      const SizedBox(height: 24),

                      SlideTransition(
                        position: _slideAnimation,
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child: _buildShareSection(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SlideTransition(
                position: _slideAnimation,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: _buildActionButtons(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessAnimation() {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.green[50],
          border: Border.all(color: Colors.green[300]!, width: 3),
        ),
        child: Icon(Icons.check_circle, size: 60, color: Colors.green[600]),
      ),
    );
  }

  Widget _buildGameSummaryCard() {
    final sport = widget.gameData['sport'] ?? 'Game';
    final date = widget.gameData['date'] as DateTime?;
    final time = widget.gameData['time'];
    final maxPlayers = widget.gameData['maxPlayers'] ?? 10;
    final venue = widget.gameData['venue'];

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.sports_soccer,
                    color: Colors.blue[600],
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.gameData['title'] ?? '$sport Game',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        sport,
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),

            _buildInfoRow(Icons.calendar_today, _formatDate(date)),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.access_time, time ?? 'Time not set'),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.people, '$maxPlayers max players'),

            if (venue != null) ...[
              const SizedBox(height: 8),
              _buildInfoRow(Icons.location_city, venue['name'] ?? 'Venue'),
            ],

            const SizedBox(height: 16),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.visibility, color: Colors.green[600], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your game is now visible to other players and they can start joining!',
                      style: TextStyle(
                        color: Colors.green[600],
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShareSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Spread the Word!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            Text(
              'Share your game to get more players to join',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildShareButton(
                  icon: Icons.link,
                  label: 'Copy Link',
                  color: Colors.blue,
                  onTap: _copyGameLink,
                ),
                _buildShareButton(
                  icon: Icons.message,
                  label: 'Text',
                  color: Colors.green,
                  onTap: _shareViaText,
                ),
                _buildShareButton(
                  icon: Icons.email,
                  label: 'Email',
                  color: Colors.orange,
                  onTap: _shareViaEmail,
                ),
                _buildShareButton(
                  icon: Icons.share,
                  label: 'More',
                  color: Colors.purple,
                  onTap: _shareViaOther,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShareButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: widget.onViewGame,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'View My Game',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: widget.onCreateAnother,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Create Another',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                onPressed: widget.onGoHome,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Go Home',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: Colors.grey[700], fontSize: 14),
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Date not set';

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final gameDate = DateTime(date.year, date.month, date.day);

    if (gameDate == today) {
      return 'Today, ${_formatDateString(date)}';
    } else if (gameDate == tomorrow) {
      return 'Tomorrow, ${_formatDateString(date)}';
    } else {
      return _formatDateString(date);
    }
  }

  String _formatDateString(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return '${weekdays[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}';
  }

  void _copyGameLink() {
    final gameId = widget.gameData['bookingId'] ?? 'GAME123';
    final link = 'https://dabbler.app/games/$gameId';

    Clipboard.setData(ClipboardData(text: link)).then((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Game link copied to clipboard!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    });
  }

  void _shareViaText() {
    final title = widget.gameData['title'] ?? 'Game';
    final date = _formatDate(widget.gameData['date']);
    final time = widget.gameData['time'] ?? 'Time TBD';
    final gameId = widget.gameData['bookingId'] ?? 'GAME123';
    final link = 'https://dabbler.app/games/$gameId';

    final message =
        'Hey! I created a $title on $date at $time. Want to join? $link';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Would open text app with: $message'),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _shareViaEmail() {
    final sport = widget.gameData['sport'] ?? 'Game';
    final subject =
        'Join my $sport game: ${widget.gameData['title'] ?? 'Game'}';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Would open email app with subject: $subject'),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _shareViaOther() {
    final title = widget.gameData['title'] ?? 'Game';
    final date = _formatDate(widget.gameData['date']);
    final time = widget.gameData['time'] ?? 'Time TBD';
    final gameId = widget.gameData['bookingId'] ?? 'GAME123';
    final link = 'https://dabbler.app/games/$gameId';

    final message = 'Join my $title on $date at $time! $link';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Would open share sheet with: $message'),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
