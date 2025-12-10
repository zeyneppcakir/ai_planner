class EmailPolicy {
  // küçük harfe çevirip kontrol edeceğiz
  static const bannedLocalPartSubstrings = <String>{
    // örnekler — kendi listenle değiştir
    'kotuornek1', 'kotuornek2', 'argo1', 'argo2',
  };

  // opsiyonel yani izinli domain kısıtı (istemiyorsan boş set bırak)
  static const allowedDomains = <String>{
    'gmail.com',
    'outlook.com',
    'icloud.com',
    'yahoo.com',
  };

  static String? validate(String input, {bool checkDomain = false}) {
    final email = input.trim();
    if (email.isEmpty) return 'E-posta gerekli';

    final emailRe =
        RegExp(r'^[A-Za-z0-9._%+\-]{3,64}@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$');
    if (!emailRe.hasMatch(email)) return 'Geçersiz e-posta biçimi';

    final parts = email.split('@');
    final local = parts.first.toLowerCase();
    final domain = parts.last.toLowerCase();

    for (final bad in bannedLocalPartSubstrings) {
      if (bad.isNotEmpty && local.contains(bad)) {
        return 'Bu e-posta kullanıcı adı uygun değil';
      }
    }

    if (checkDomain && !allowedDomains.contains(domain)) {
      return 'Bu e-posta sağlayıcısı desteklenmiyor';
    }

    if (local.startsWith('.') || local.endsWith('.') || local.contains('..')) {
      return 'E-posta kullanıcı adı hatalı';
    }

    return null;
  }
}
