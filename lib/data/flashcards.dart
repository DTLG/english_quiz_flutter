class Flashcard {
  const Flashcard({
    required this.english,
    required this.ukrainian,
    required this.example,
  });

  final String english;
  final String ukrainian;
  final String example;
}

const List<Flashcard> flashcards = [
  Flashcard(
    english: 'ticket',
    ukrainian: 'квиток',
    example: 'I need to buy a ticket for the train.',
  ),
  Flashcard(
    english: 'luggage',
    ukrainian: 'багаж',
    example: 'Where can I collect my luggage?',
  ),
  Flashcard(
    english: 'passenger',
    ukrainian: 'пасажир',
    example: 'Every passenger must wear a seatbelt.',
  ),
  Flashcard(
    english: 'flight',
    ukrainian: 'рейс',
    example: 'Our flight was delayed by one hour.',
  ),
  Flashcard(
    english: 'customs',
    ukrainian: 'митниця',
    example: 'We walked through customs quickly.',
  ),
];

