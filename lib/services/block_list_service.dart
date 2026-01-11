import 'package:shared_preferences/shared_preferences.dart';

class BlockListService {
  static const String _blacklistKey = 'blacklist_numbers';
  static const String _whitelistKey = 'whitelist_numbers';

  Future<void> addToBlacklist(String number) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_blacklistKey) ?? [];
    if (!list.contains(number)) {
      list.add(number);
      await prefs.setStringList(_blacklistKey, list);
    }
  }

  Future<void> addToWhitelist(String number) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_whitelistKey) ?? [];
    if (!list.contains(number)) {
      list.add(number);
      await prefs.setStringList(_whitelistKey, list);
    }
  }

  Future<void> removeFromLists(String number) async {
    final prefs = await SharedPreferences.getInstance();
    final black = prefs.getStringList(_blacklistKey) ?? [];
    final white = prefs.getStringList(_whitelistKey) ?? [];
    black.remove(number);
    white.remove(number);
    await prefs.setStringList(_blacklistKey, black);
    await prefs.setStringList(_whitelistKey, white);
  }

  Future<bool> isBlacklisted(String number) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_blacklistKey) ?? [];
    return list.contains(number);
  }

  Future<bool> isWhitelisted(String number) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_whitelistKey) ?? [];
    return list.contains(number);
  }
}
