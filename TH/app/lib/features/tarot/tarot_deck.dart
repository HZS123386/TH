part of 'tarot_page.dart';

abstract interface class _TarotCard {
  String get artwork;
  ({String name, String meaning}) reading(AppLocalizations s);
}

final List<_TarotCard> _tarotDeck = List.unmodifiable([
  ..._Arcana.values,
  for (final suit in _Suit.values)
    for (var rank = 0; rank < 14; rank++) _MinorArcana(suit, rank),
]);

enum _Suit {
  wands,
  cups,
  swords,
  pentacles;

  String label(AppLocalizations s) => switch (this) {
    _Suit.wands => s.tarotSuitWands,
    _Suit.cups => s.tarotSuitCups,
    _Suit.swords => s.tarotSuitSwords,
    _Suit.pentacles => s.tarotSuitPentacles,
  };

  List<String> meanings(AppLocalizations s) => switch (this) {
    _Suit.wands => [
      s.tarotWandsAceMeaning,
      s.tarotWandsTwoMeaning,
      s.tarotWandsThreeMeaning,
      s.tarotWandsFourMeaning,
      s.tarotWandsFiveMeaning,
      s.tarotWandsSixMeaning,
      s.tarotWandsSevenMeaning,
      s.tarotWandsEightMeaning,
      s.tarotWandsNineMeaning,
      s.tarotWandsTenMeaning,
      s.tarotWandsPageMeaning,
      s.tarotWandsKnightMeaning,
      s.tarotWandsQueenMeaning,
      s.tarotWandsKingMeaning,
    ],
    _Suit.cups => [
      s.tarotCupsAceMeaning,
      s.tarotCupsTwoMeaning,
      s.tarotCupsThreeMeaning,
      s.tarotCupsFourMeaning,
      s.tarotCupsFiveMeaning,
      s.tarotCupsSixMeaning,
      s.tarotCupsSevenMeaning,
      s.tarotCupsEightMeaning,
      s.tarotCupsNineMeaning,
      s.tarotCupsTenMeaning,
      s.tarotCupsPageMeaning,
      s.tarotCupsKnightMeaning,
      s.tarotCupsQueenMeaning,
      s.tarotCupsKingMeaning,
    ],
    _Suit.swords => [
      s.tarotSwordsAceMeaning,
      s.tarotSwordsTwoMeaning,
      s.tarotSwordsThreeMeaning,
      s.tarotSwordsFourMeaning,
      s.tarotSwordsFiveMeaning,
      s.tarotSwordsSixMeaning,
      s.tarotSwordsSevenMeaning,
      s.tarotSwordsEightMeaning,
      s.tarotSwordsNineMeaning,
      s.tarotSwordsTenMeaning,
      s.tarotSwordsPageMeaning,
      s.tarotSwordsKnightMeaning,
      s.tarotSwordsQueenMeaning,
      s.tarotSwordsKingMeaning,
    ],
    _Suit.pentacles => [
      s.tarotPentaclesAceMeaning,
      s.tarotPentaclesTwoMeaning,
      s.tarotPentaclesThreeMeaning,
      s.tarotPentaclesFourMeaning,
      s.tarotPentaclesFiveMeaning,
      s.tarotPentaclesSixMeaning,
      s.tarotPentaclesSevenMeaning,
      s.tarotPentaclesEightMeaning,
      s.tarotPentaclesNineMeaning,
      s.tarotPentaclesTenMeaning,
      s.tarotPentaclesPageMeaning,
      s.tarotPentaclesKnightMeaning,
      s.tarotPentaclesQueenMeaning,
      s.tarotPentaclesKingMeaning,
    ],
  };
}

class _MinorArcana implements _TarotCard {
  const _MinorArcana(this.suit, this.rank);
  final _Suit suit;
  final int rank;

  @override
  String get artwork =>
      'assets/images/tarot/${suit.name}-${(rank + 1).toString().padLeft(2, '0')}.jpg';

  @override
  ({String name, String meaning}) reading(AppLocalizations s) {
    final ranks = [
      s.tarotRankAce,
      s.tarotRankTwo,
      s.tarotRankThree,
      s.tarotRankFour,
      s.tarotRankFive,
      s.tarotRankSix,
      s.tarotRankSeven,
      s.tarotRankEight,
      s.tarotRankNine,
      s.tarotRankTen,
      s.tarotRankPage,
      s.tarotRankKnight,
      s.tarotRankQueen,
      s.tarotRankKing,
    ];
    return (
      name: s.tarotMinorName(suit.label(s), ranks[rank]),
      meaning: suit.meanings(s)[rank],
    );
  }
}
