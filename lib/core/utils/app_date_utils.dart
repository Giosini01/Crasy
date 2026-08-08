abstract final class AppDateUtils {
  static int calculateAge(DateTime birthDate, {DateTime? now}) {
    final today = _dateOnly(now ?? DateTime.now());
    final birth = _dateOnly(birthDate);

    var age = today.year - birth.year;
    final hasHadBirthday =
        today.month > birth.month ||
        (today.month == birth.month && today.day >= birth.day);

    if (!hasHadBirthday) {
      age--;
    }

    return age;
  }

  static DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }
}
