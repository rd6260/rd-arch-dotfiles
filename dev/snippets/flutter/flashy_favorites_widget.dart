Widget _buildArtWork() {
  return Container(
    decoration: BoxDecoration(
      gradient: RadialGradient(
        center: Alignment.topLeft,
        radius: 1.5,
        colors: [
          Colors.pink.shade300,
          Colors.red.shade400,
          Color(Settings.primaryColor),
          Colors.purple.shade800,
        ],
        stops: const [0.0, 0.3, 0.7, 1.0],
      ),
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.pink.withOpacity(0.5),
          blurRadius: 20,
          spreadRadius: 2,
          offset: const Offset(0, 8),
        ),
        BoxShadow(
          color: Colors.purple.withOpacity(0.3),
          blurRadius: 40,
          spreadRadius: 4,
          offset: const Offset(0, 16),
        ),
      ],
      border: Border.all(
        width: 2,
        color: Colors.white.withOpacity(0.3),
      ),
    ),
    child: Stack(
      alignment: Alignment.center,
      children: [
        // Background glow effect
        Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              colors: [
                Colors.white.withOpacity(0.2),
                Colors.transparent,
              ],
            ),
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        // Main heart icon
        Icon(
          Icons.favorite_rounded,
          color: Colors.white,
          size: 32,
          shadows: [
            Shadow(
              color: Colors.pink.withOpacity(0.8),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        // Sparkle overlay
        Positioned(
          top: 8,
          right: 8,
          child: Icon(
            Icons.auto_awesome,
            color: Colors.white.withOpacity(0.7),
            size: 12,
          ),
        ),
      ],
    ),
  );
}
