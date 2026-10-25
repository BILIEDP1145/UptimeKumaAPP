/// Flattens the small amount of HTML Kuma allows in incident bodies.
///
/// The status page API hands back markup (`<h4>…</h4>`, `<br>`, entities). A
/// plain `Text` widget renders the tags verbatim, which looked like the content
/// was missing entirely — it was there, dressed as markup.
String stripKumaHtml(String raw) {
  if (raw.isEmpty) return raw;
  var text = raw;

  // Block-level tags become line breaks before the generic tag strip.
  text = text.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
  text = text.replaceAll(
    RegExp(r'</(p|div|h[1-6]|li|tr|blockquote)>', caseSensitive: false),
    '\n',
  );
  text = text.replaceAll(RegExp(r'<h[1-6][^>]*>', caseSensitive: false), '\n');
  text = text.replaceAll(RegExp(r'<li[^>]*>', caseSensitive: false), '• ');
  text = text.replaceAll(RegExp(r'<[^>]+>'), '');

  const entities = {
    '&nbsp;': ' ',
    '&amp;': '&',
    '&lt;': '<',
    '&gt;': '>',
    '&quot;': '"',
    '&#39;': "'",
    '&apos;': "'",
  };
  entities.forEach((entity, value) => text = text.replaceAll(entity, value));

  // Collapse the padding the tag replacements introduce.
  text = text.replaceAll(RegExp(r'[ \t]+\n'), '\n');
  text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
  return text.trim();
}
