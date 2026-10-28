// Draws Trackmania-formatted text the way the game's chat shows it.
// Openplanet's UI text only understands colors and italics and drops every other format code,
// so bold, wide, narrow, caps, shadow and links are drawn here by hand.

class TextFormat
{
	vec4 color = vec4(1, 1, 1, 1);
	bool bold = false;
	bool italic = false;
	bool wide = false;
	bool narrow = false;
	bool caps = false;
	bool shadow = false;
	bool link = false;
}

class TextRun
{
	string text;
	TextFormat format;
}

// How much wider or narrower $w and $n make the text, roughly matching the game
const float WIDE_FACTOR = 1.35f;
const float NARROW_FACTOR = 0.75f;

bool IsHexDigit(uint8 c)
{
	return (c >= 0x30 && c <= 0x39) || (c >= 0x61 && c <= 0x66) || (c >= 0x41 && c <= 0x46);
}

// Splits text into runs that share one format. Handles colors, $o $i $w $n $m $t $s, $g and $z
// resets, $< $> scopes, links with or without [url], and $$ for a literal dollar sign.
array<TextRun@> ParseFormattedText(const string &in text, const vec4 &in defaultColor)
{
	array<TextRun@> runs;
	array<TextFormat> scopes;
	TextFormat format;
	format.color = defaultColor;
	string pending = "";

	int i = 0;
	while (i < text.Length) {
		if (text[i] != 0x24 || i + 1 >= text.Length) {
			pending += text.SubStr(i, 1);
			i++;
			continue;
		}

		uint8 code = text[i + 1];
		if (code == 0x24) {
			pending += "$";
			i += 2;
			continue;
		}

		// A format code: the text so far keeps the old format
		AddRun(runs, pending, format);
		pending = "";

		if (IsHexDigit(code)) {
			// $rgb; the game also accepts fewer digits, missing ones count as 0
			int digits = 0;
			array<float> channels = { 0, 0, 0 };
			while (digits < 3 && i + 1 + digits < text.Length && IsHexDigit(text[i + 1 + digits])) {
				channels[digits] = HexValue(text[i + 1 + digits]) / 15.0f;
				digits++;
			}
			format.color = vec4(channels[0], channels[1], channels[2], 1);
			i += 1 + digits;
			continue;
		}

		i += 2;
		switch (code | 0x20) {
			case 0x67: format.color = defaultColor; break;          // g
			case 0x6f: format.bold = true; break;                   // o
			case 0x69: format.italic = true; break;                 // i
			case 0x77: format.wide = true; format.narrow = false; break;   // w
			case 0x6e: format.narrow = true; format.wide = false; break;   // n
			case 0x6d: format.wide = false; format.narrow = false; break;  // m
			case 0x74: format.caps = true; break;                   // t
			case 0x73: format.shadow = true; break;                 // s
			case 0x7a: {                                            // z
				TextFormat reset;
				reset.color = defaultColor;
				format = reset;
				break;
			}
			case 0x6c: case 0x68: case 0x70: {                      // l, h, p: links
				format.link = !format.link;
				// $l[url]text: the url isn't shown
				if (i < text.Length && text[i] == 0x5b) {
					int close = text.SubStr(i).IndexOf("]");
					i = close < 0 ? text.Length : i + close + 1;
				}
				break;
			}
			default:
				// $< and $> aren't letters, so check them here
				if (code == 0x3c) {
					scopes.InsertLast(format);
				} else if (code == 0x3e && scopes.Length > 0) {
					format = scopes[scopes.Length - 1];
					scopes.RemoveLast();
				}
				break;
		}
	}
	AddRun(runs, pending, format);
	return runs;
}

void AddRun(array<TextRun@>@ runs, const string &in text, const TextFormat &in format)
{
	if (text == "") {
		return;
	}
	TextRun@ run = TextRun();
	run.text = format.caps ? text.ToUpper() : text;
	run.format = format;
	runs.InsertLast(run);
}

// Single characters, keeping UTF-8 sequences together
array<string> SplitCharacters(const string &in text)
{
	array<string> chars;
	int i = 0;
	while (i < text.Length) {
		int length = 1;
		while (i + length < text.Length && (text[i + length] & 0xC0) == 0x80) {
			length++;
		}
		chars.InsertLast(text.SubStr(i, length));
		i += length;
	}
	return chars;
}

// Words and the spaces between them, so lines can wrap between words
array<string> SplitWords(const string &in text)
{
	array<string> words;
	string current = "";
	bool currentIsSpace = false;
	for (int i = 0; i < text.Length; i++) {
		bool isSpace = text[i] == 0x20;
		if (current != "" && isSpace != currentIsSpace) {
			words.InsertLast(current);
			current = "";
		}
		current += text.SubStr(i, 1);
		currentIsSpace = isSpace;
	}
	if (current != "") {
		words.InsertLast(current);
	}
	return words;
}

UI::Font@ FontFor(const TextFormat &in format)
{
	return format.bold ? UI::Font::DefaultBold : UI::Font::Default;
}

float WidthFactor(const TextFormat &in format)
{
	return format.wide ? WIDE_FACTOR : (format.narrow ? NARROW_FACTOR : 1.0f);
}

float MeasureWord(const string &in word, const TextFormat &in format, float fontSize)
{
	return UI::MeasureString(word, FontFor(format), fontSize).x * WidthFactor(format);
}

void DrawWord(UI::DrawList@ drawList, const vec2 &in pos, const string &in word, const TextFormat &in format, float fontSize)
{
	auto font = FontFor(format);
	// Openplanet draws italics itself when the text starts with its italic code
	string prefix = format.italic ? "\\$i" : "";
	float factor = WidthFactor(format);
	float shadowOffset = UI::GetScale();

	// Wide and narrow text: place every character with stretched or squeezed spacing
	array<string> pieces;
	if (factor == 1.0f) {
		pieces.InsertLast(word);
	} else {
		pieces = SplitCharacters(word);
	}

	float x = pos.x;
	for (uint i = 0; i < pieces.Length; i++) {
		if (format.shadow) {
			drawList.AddText(vec2(x, pos.y) + vec2(shadowOffset, shadowOffset), vec4(0, 0, 0, 0.8f), prefix + pieces[i], font, fontSize);
		}
		drawList.AddText(vec2(x, pos.y), format.color, prefix + pieces[i], font, fontSize);
		x += UI::MeasureString(pieces[i], font, fontSize).x * factor;
	}

	if (format.link) {
		drawList.AddLine(vec2(pos.x, pos.y + fontSize), vec2(x, pos.y + fontSize), format.color, shadowOffset);
	}
}

// Draws the text wrapped to the given width and reserves the space it took in the layout
void FormattedText(const string &in text, float wrapWidth)
{
	// A chat message is one line: new lines are sent as spaces, so show them that way
	string singleLine = text.Replace("\r", "").Replace("\n", " ");
	auto runs = ParseFormattedText(singleLine, UI::GetStyleColor(UI::Col::Text));
	auto drawList = UI::GetWindowDrawList();
	vec2 origin = UI::GetCursorScreenPos();
	float fontSize = UI::GetFontSize();
	float lineHeight = fontSize * 1.3f;

	vec2 pen = vec2(0, 0);
	for (uint r = 0; r < runs.Length; r++) {
		auto words = SplitWords(runs[r].text);
		for (uint w = 0; w < words.Length; w++) {
			bool isSpace = words[w][0] == 0x20;
			float width = MeasureWord(words[w], runs[r].format, fontSize);
			if (pen.x > 0 && pen.x + width > wrapWidth && !isSpace) {
				pen.x = 0;
				pen.y += lineHeight;
			}
			// Spaces at the start of a wrapped line would indent it
			if (isSpace && pen.x == 0 && pen.y > 0) {
				continue;
			}
			DrawWord(drawList, origin + pen, words[w], runs[r].format, fontSize);
			pen.x += width;
		}
	}

	UI::Dummy(vec2(wrapWidth, pen.y + lineHeight));
}
