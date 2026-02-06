enum BadgeTier {
  bronze,
  silver,
  gold,
  platinum,
  diamond;

  String get displayName {
    switch (this) {
      case BadgeTier.bronze:
        return 'Bronze';
      case BadgeTier.silver:
        return 'Silver';
      case BadgeTier.gold:
        return 'Gold';
      case BadgeTier.platinum:
        return 'Platinum';
      case BadgeTier.diamond:
        return 'Diamond';
    }
  }

  int get points {
    switch (this) {
      case BadgeTier.bronze:
        return 0;
      case BadgeTier.silver:
        return 1000;
      case BadgeTier.gold:
        return 5000;
      case BadgeTier.platinum:
        return 15000;
      case BadgeTier.diamond:
        return 50000;
    }
  }

  double get multiplier {
    switch (this) {
      case BadgeTier.bronze:
        return 1.0;
      case BadgeTier.silver:
        return 1.2;
      case BadgeTier.gold:
        return 1.5;
      case BadgeTier.platinum:
        return 1.8;
      case BadgeTier.diamond:
        return 2.0;
    }
  }

  static BadgeTier fromPoints(int points) {
    if (points >= BadgeTier.diamond.points) return BadgeTier.diamond;
    if (points >= BadgeTier.platinum.points) return BadgeTier.platinum;
    if (points >= BadgeTier.gold.points) return BadgeTier.gold;
    if (points >= BadgeTier.silver.points) return BadgeTier.silver;
    return BadgeTier.bronze;
  }
}
