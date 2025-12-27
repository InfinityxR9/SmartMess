class MealSlotInfo {
  final String type;
  final String label;
  final String window;

  const MealSlotInfo({
    required this.type,
    required this.label,
    required this.window,
  });
}

MealSlotInfo? getCurrentMealSlot([DateTime? now]) {
  final current = now ?? DateTime.now();
  final hour = current.hour;
  final minute = current.minute;

  if ((hour == 7 && minute >= 30) || (hour > 7 && hour < 9) || (hour == 9 && minute < 30)) {
    return const MealSlotInfo(
      type: 'breakfast',
      label: 'Breakfast',
      window: '7:30-9:30',
    );
  }

  if (hour == 12 || hour == 13 || (hour == 14 && minute == 0)) {
    return const MealSlotInfo(
      type: 'lunch',
      label: 'Lunch',
      window: '12:00-14:00',
    );
  }

  if ((hour == 19 && minute >= 30) || (hour > 19 && hour < 21) || (hour == 21 && minute < 30)) {
    return const MealSlotInfo(
      type: 'dinner',
      label: 'Dinner',
      window: '19:30-21:30',
    );
  }

  return null;
}

String formatMealLabel(String mealType) {
  switch (mealType) {
    case 'breakfast':
      return 'Breakfast';
    case 'lunch':
      return 'Lunch';
    case 'dinner':
      return 'Dinner';
    default:
      return mealType.toUpperCase();
  }
}
