import 'package:flutter/material.dart';

class ProfileAvatar extends StatefulWidget {
  final String? imageUrl;
  final double size;
  final bool isOwnProfile;
  final bool showEditOverlay;
  final VoidCallback? onTap;
  final VoidCallback? onEditTap;
  final bool showUploadProgress;
  final double uploadProgress;
  final bool hasError;

  const ProfileAvatar({
    super.key,
    this.imageUrl,
    this.size = 80,
    this.isOwnProfile = false,
    this.showEditOverlay = true,
    this.onTap,
    this.onEditTap,
    this.showUploadProgress = false,
    this.uploadProgress = 0.0,
    this.hasError = false,
  });

  @override
  State<ProfileAvatar> createState() => _ProfileAvatarState();
}

class _ProfileAvatarState extends State<ProfileAvatar>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _animationController.forward(),
      onTapUp: (_) => _animationController.reverse(),
      onTapCancel: () => _animationController.reverse(),
      onTap: widget.onTap,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Stack(
          children: [
            Hero(
              tag: 'profile-avatar-${widget.imageUrl ?? 'placeholder'}',
              child: Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: widget.hasError
                        ? Colors.red
                        : Theme.of(context).primaryColor,
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color:
                          (widget.hasError
                                  ? Colors.red
                                  : Theme.of(context).primaryColor)
                              .withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipOval(child: _buildAvatarContent(context)),
              ),
            ),

            // Upload progress indicator
            if (widget.showUploadProgress) _buildUploadProgress(context),

            // Error indicator
            if (widget.hasError) _buildErrorIndicator(context),

            // Edit overlay for own profile
            if (widget.isOwnProfile && widget.showEditOverlay)
              _buildEditOverlay(context),

            // Loading indicator
            if (_isLoading) _buildLoadingIndicator(context),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarContent(BuildContext context) {
    if (widget.imageUrl?.isNotEmpty == true) {
      return Image.network(
        widget.imageUrl!,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          setState(() => _isLoading = true);
          return _buildPlaceholder(context, showLoading: true);
        },
        errorBuilder: (context, error, stackTrace) {
          return _buildPlaceholder(context, isError: true);
        },
      );
    } else {
      return _buildPlaceholder(context);
    }
  }

  Widget _buildPlaceholder(
    BuildContext context, {
    bool showLoading = false,
    bool isError = false,
  }) {
    setState(() => _isLoading = false);

    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isError
              ? [Colors.red[100]!, Colors.red[200]!]
              : [Colors.grey[200]!, Colors.grey[300]!],
        ),
      ),
      child: showLoading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : Icon(
              isError ? Icons.error_outline : Icons.person,
              size: widget.size * 0.4,
              color: isError ? Colors.red[600] : Colors.grey[600],
            ),
    );
  }

  Widget _buildUploadProgress(BuildContext context) {
    return Positioned.fill(
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.black54,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: widget.size * 0.4,
                height: widget.size * 0.4,
                child: CircularProgressIndicator(
                  value: widget.uploadProgress,
                  strokeWidth: 3,
                  backgroundColor: Colors.white.withOpacity(0.3),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${(widget.uploadProgress * 100).round()}%',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: widget.size * 0.1,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorIndicator(BuildContext context) {
    return Positioned(
      top: 0,
      right: 0,
      child: Container(
        width: widget.size * 0.25,
        height: widget.size * 0.25,
        decoration: const BoxDecoration(
          color: Colors.red,
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.error, color: Colors.white, size: widget.size * 0.12),
      ),
    );
  }

  Widget _buildEditOverlay(BuildContext context) {
    return Positioned(
      bottom: 0,
      right: 0,
      child: GestureDetector(
        onTap: widget.onEditTap,
        child: Container(
          width: widget.size * 0.3,
          height: widget.size * 0.3,
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            Icons.camera_alt,
            color: Colors.white,
            size: widget.size * 0.15,
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator(BuildContext context) {
    return Positioned.fill(
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.black26,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: SizedBox(
            width: widget.size * 0.3,
            height: widget.size * 0.3,
            child: const CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}

// Extension to provide additional avatar variants
extension ProfileAvatarVariants on ProfileAvatar {
  static Widget small({
    String? imageUrl,
    bool isOnline = false,
    VoidCallback? onTap,
  }) {
    return Builder(
      builder: (context) => Stack(
        children: [
          ProfileAvatar(
            imageUrl: imageUrl,
            size: 40,
            showEditOverlay: false,
            onTap: onTap,
          ),
          if (isOnline)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }

  static Widget large({
    String? imageUrl,
    bool isOwnProfile = false,
    VoidCallback? onTap,
    VoidCallback? onEditTap,
  }) {
    return ProfileAvatar(
      imageUrl: imageUrl,
      size: 120,
      isOwnProfile: isOwnProfile,
      onTap: onTap,
      onEditTap: onEditTap,
    );
  }

  static Widget withBadge({
    String? imageUrl,
    required String badge,
    Color badgeColor = Colors.orange,
    VoidCallback? onTap,
  }) {
    return Builder(
      builder: (context) => Stack(
        children: [
          ProfileAvatar(
            imageUrl: imageUrl,
            size: 60,
            showEditOverlay: false,
            onTap: onTap,
          ),
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: badgeColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white, width: 1),
              ),
              child: Text(
                badge,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
