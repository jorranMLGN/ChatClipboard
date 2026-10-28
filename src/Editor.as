// Snippet editor with rich text tools.
// Trackmania chat has no rich text of its own, only format codes like $f00 and $o. The editor
// remembers what is selected in the text box, and the toolbar puts codes around that selection
// as "$<$f00...$>", so the formatting doesn't leak into the rest of the text.

const array<string> COLOR_NAMES = { "White", "Gray", "Black", "Red", "Orange", "Yellow", "Green", "Cyan", "Blue", "Pink" };
const array<string> COLOR_CODES = { "$fff", "$888", "$000", "$f00", "$f80", "$ff0", "$0f0", "$0ff", "$00f", "$f0f" };

const array<string> STYLE_NAMES = { "Bold", "Italic", "Wide", "Narrow", "Caps", "Shadow" };
const array<string> STYLE_CODES = { "$o", "$i", "$w", "$n", "$t", "$s" };

const string HEX_DIGITS = "0123456789abcdef";

// Better Chat cuts messages off after this many bytes
const int MAX_MESSAGE_LENGTH = 2000;

// g_editIndex is -1 when adding a new snippet
bool g_editorOpen = false;
int g_editIndex = -1;
string g_editName = "";
string g_editText = "";
string g_editGroup = "";
bool g_editFavorite = false;
bool g_editMultiLine = false;
string g_editIcon = "";
VirtualKey g_editHotkey = VirtualKey::None;

// Selection in g_editText as byte offsets, from the last frame the text box was active.
// Clicking a toolbar button deactivates the text box, so this is what the button works on.
int g_selStart = 0;
int g_selEnd = 0;

// After a toolbar action the text box gets focus back with this selection
bool g_refocus = false;
int g_restoreStart = -1;
int g_restoreEnd = -1;

// Text before each toolbar action; the text box's own undo doesn't see changes made from code
array<string> g_undo;

vec3 g_customColor = vec3(1.0f, 0.5f, 0.0f);
vec3 g_gradientFrom = vec3(1.0f, 0.0f, 0.0f);
vec3 g_gradientTo = vec3(0.0f, 0.0f, 1.0f);

void OpenEditor(int index)
{
	g_editIndex = index;
	if (index < 0) {
		g_editName = "";
		g_editText = "";
		g_editGroup = "";
		g_editFavorite = false;
		g_editHotkey = VirtualKey::None;
		g_editMultiLine = false;
		g_editIcon = "";
	} else {
		g_editName = g_snippets[index].name;
		g_editText = g_snippets[index].text;
		g_editGroup = g_snippets[index].group;
		g_editFavorite = g_snippets[index].favorite;
		g_editHotkey = g_snippets[index].hotkey;
		g_editMultiLine = g_snippets[index].multiLine;
		g_editIcon = g_snippets[index].icon;
	}
	g_capturingHotkey = false;
	g_selStart = g_selEnd = int(g_editText.Length);
	g_restoreStart = -1;
	g_undo.RemoveRange(0, g_undo.Length);
	g_editorOpen = true;
}

void EditorTextCallback(UI::InputTextCallbackData@ data)
{
	if (data.EventFlag != UI::InputTextFlags::CallbackAlways) {
		return;
	}
	if (g_restoreStart >= 0) {
		data.SelectionStart = g_restoreStart;
		data.SelectionEnd = g_restoreEnd;
		data.CursorPos = g_restoreEnd;
		g_restoreStart = -1;
	}
	// The selection can run backwards when it was made from right to left
	g_selStart = Math::Min(data.SelectionStart, data.SelectionEnd);
	g_selEnd = Math::Max(data.SelectionStart, data.SelectionEnd);
}

bool HasSelection()
{
	return g_selEnd > g_selStart;
}

string SelectedText()
{
	// An out of range SubStr throws, which would stop the plugin
	int start = Math::Clamp(g_selStart, 0, int(g_editText.Length));
	int end = Math::Clamp(g_selEnd, start, int(g_editText.Length));
	return g_editText.SubStr(start, end - start);
}

void ReplaceSelection(const string &in replacement, bool selectResult)
{
	g_undo.InsertLast(g_editText);

	int start = Math::Clamp(g_selStart, 0, int(g_editText.Length));
	int end = Math::Clamp(g_selEnd, start, int(g_editText.Length));
	g_editText = g_editText.SubStr(0, start) + replacement + g_editText.SubStr(end);

	g_selStart = selectResult ? start : start + int(replacement.Length);
	g_selEnd = start + int(replacement.Length);
	g_restoreStart = g_selStart;
	g_restoreEnd = g_selEnd;
	g_refocus = true;
}

// Formats the selection, or inserts the code at the cursor so the text typed after it gets it
void ApplyCode(const string &in code)
{
	if (HasSelection()) {
		ReplaceSelection("$<" + code + SelectedText() + "$>", true);
	} else {
		ReplaceSelection(code, false);
	}
}

void ApplyLink()
{
	if (HasSelection()) {
		ReplaceSelection("$l" + SelectedText() + "$l", true);
	} else {
		ReplaceSelection("$l", false);
	}
}

void ClearFormatting()
{
	if (!HasSelection()) {
		g_selStart = 0;
		g_selEnd = int(g_editText.Length);
	}
	ReplaceSelection(PlainText(SelectedText()), true);
}

void Undo()
{
	g_editText = g_undo[g_undo.Length - 1];
	g_undo.RemoveLast();
	g_selStart = g_selEnd = int(g_editText.Length);
	g_restoreStart = g_selStart;
	g_restoreEnd = g_selEnd;
	g_refocus = true;
}

// Text without format codes, with literal dollar signs escaped again
string PlainText(const string &in text)
{
	return Text::StripFormatCodes(text).Replace("$", "$$");
}

string ColorCode(const vec3 &in color)
{
	return "$" + HexDigit(color.x) + HexDigit(color.y) + HexDigit(color.z);
}

string HexDigit(float channel)
{
	int value = int(Math::Round(Math::Clamp(channel, 0.0f, 1.0f) * 15.0f));
	return HEX_DIGITS.SubStr(value, 1);
}

// Gives every character its own color, fading from one color to the other. Only color codes in
// the text are replaced; other formatting such as bold, italics and links stays where it was.
string MakeGradient(const string &in text, const vec3 &in from, const vec3 &in to)
{
	auto pieces = GradientPieces(text);

	int visibleCount = 0;
	for (uint i = 0; i < pieces.Length; i++) {
		if (pieces[i].visible) {
			visibleCount++;
		}
	}

	string result = "$<";
	string lastCode = "";
	int visibleIndex = 0;
	for (uint i = 0; i < pieces.Length; i++) {
		if (!pieces[i].visible) {
			result += pieces[i].text;
			// $z and $> also reset the color, so the next character needs its code again
			string codeText = pieces[i].text.ToLower();
			if (codeText == "$z" || codeText == "$>") {
				lastCode = "";
			}
			continue;
		}
		float t = visibleCount > 1 ? float(visibleIndex) / float(visibleCount - 1) : 0.0f;
		string code = ColorCode(from + (to - from) * t);
		// Spaces don't show a color, and with only 16 steps per channel neighbours often match
		if (pieces[i].text != " " && code != lastCode) {
			result += code;
			lastCode = code;
		}
		result += pieces[i].text;
		visibleIndex++;
	}
	return result + "$>";
}

class GradientPiece
{
	string text;
	// false for format codes, which are kept but don't get a color of their own
	bool visible;

	GradientPiece(const string &in text, bool visible)
	{
		this.text = text;
		this.visible = visible;
	}
}

// Splits text into what a gradient works on: visible characters (with variables like {map} as
// one piece, because a color code inside a variable would stop it from being filled in) and the
// format codes around them. Color codes are dropped here, since the gradient replaces them.
array<GradientPiece@> GradientPieces(const string &in text)
{
	array<GradientPiece@> pieces;
	int i = 0;
	while (i < text.Length) {
		if (text[i] == 0x24 && i + 1 < text.Length) {
			uint8 code = text[i + 1];
			if (code == 0x24) {
				// $$ is a visible dollar sign
				pieces.InsertLast(GradientPiece("$$", true));
				i += 2;
			} else if (IsHexDigit(code)) {
				// Old color code: up to three hex digits, dropped
				int digits = 1;
				while (digits < 3 && i + 1 + digits < text.Length && IsHexDigit(text[i + 1 + digits])) {
					digits++;
				}
				i += 1 + digits;
			} else if ((code | 0x20) == 0x67) {
				// $g resets the color, dropped as well
				i += 2;
			} else {
				// Any other code is kept as it is; a link keeps its [url] too
				int length = 2;
				uint8 lower = code | 0x20;
				bool isLink = lower == 0x6c || lower == 0x68 || lower == 0x70;
				if (isLink && i + 2 < text.Length && text[i + 2] == 0x5b) {
					int close = text.SubStr(i + 2).IndexOf("]");
					length = close < 0 ? text.Length - i : close + 3;
				}
				pieces.InsertLast(GradientPiece(text.SubStr(i, length), false));
				i += length;
			}
			continue;
		}

		int length = VariableLengthAt(text, i);
		if (length == 0) {
			// One UTF-8 character: a lead byte plus its continuation bytes, which look like 10xxxxxx
			length = 1;
			while (i + length < text.Length && (text[i + length] & 0xC0) == 0x80) {
				length++;
			}
		}
		pieces.InsertLast(GradientPiece(text.SubStr(i, length), true));
		i += length;
	}
	return pieces;
}

// Length of the variable that starts at index, or 0 if there is none
int VariableLengthAt(const string &in text, int index)
{
	for (uint v = 0; v < VARIABLES.Length; v++) {
		int length = VARIABLES[v].Length;
		if (index + length <= text.Length && text.SubStr(index, length) == VARIABLES[v]) {
			return length;
		}
	}
	return 0;
}

bool ColorSwatch(const string &in code, const string &in id, const string &in tooltip)
{
	vec4 color = CodeToColor(code);
	// Hovering mixes in some white, so even black and dark blue show a change
	vec4 hovered = color + (vec4(1, 1, 1, 1) - color) * 0.3f;
	UI::PushStyleColor(UI::Col::Button, color);
	UI::PushStyleColor(UI::Col::ButtonHovered, hovered);
	UI::PushStyleColor(UI::Col::ButtonActive, color);
	float size = UI::GetFrameHeight();
	bool clicked = UI::Button("##" + id, vec2(size, size));
	UI::PopStyleColor(3);
	if (UI::IsItemHovered()) {
		UI::SetTooltip(tooltip);
	}
	return clicked;
}

// "$f80" to an opaque color
vec4 CodeToColor(const string &in code)
{
	return vec4(HexValue(code[1]) / 15.0f, HexValue(code[2]) / 15.0f, HexValue(code[3]) / 15.0f, 1.0f);
}

int HexValue(uint8 c)
{
	if (c >= 0x30 && c <= 0x39) {
		return c - 0x30;
	}
	if (c >= 0x61 && c <= 0x66) {
		return c - 0x61 + 10;
	}
	if (c >= 0x41 && c <= 0x46) {
		return c - 0x41 + 10;
	}
	return 0;
}

void ToolbarLabel(const string &in text)
{
	UI::AlignTextToFramePadding();
	UI::TextDisabled(text);
	UI::SameLine(80 * UI::GetScale());
}

void RenderEditorToolbar()
{
	string target = HasSelection() ? "the selection" : "the cursor";

	ToolbarLabel("Color");
	for (uint i = 0; i < COLOR_CODES.Length; i++) {
		if (ColorSwatch(COLOR_CODES[i], "color" + i, COLOR_NAMES[i] + " (" + COLOR_CODES[i] + ") at " + target)) {
			ApplyCode(COLOR_CODES[i]);
		}
		UI::SameLine();
	}
	UI::NewLine();

	// Its own row, so the picker isn't mistaken for one of the fixed colors above
	ToolbarLabel("Custom");
	g_customColor = UI::InputColor3("##custom", g_customColor, UI::ColorEditFlags::NoInputs | UI::ColorEditFlags::NoLabel);
	if (UI::IsItemHovered()) {
		UI::SetTooltip("Click to pick a color");
	}
	UI::SameLine();
	string customCode = ColorCode(g_customColor);
	UI::AlignTextToFramePadding();
	UI::TextDisabled(customCode);
	if (UI::IsItemHovered()) {
		UI::SetTooltip("The format code for this color, as it goes into the message.\nTrackmania colors have 16 steps per channel, so the picked color is rounded to the nearest one.");
	}
	UI::SameLine();
	// The drop on the button has the picked color, so it shows what Use will apply
	if (DarkButton(Text::OpenplanetFormatCodes(customCode) + Icons::Tint + "\\$z Use##custom", "Apply " + customCode + " at " + target)) {
		ApplyCode(customCode);
	}

	ToolbarLabel("Style");
	for (uint i = 0; i < STYLE_CODES.Length; i++) {
		if (DarkButton(STYLE_NAMES[i] + "##style" + i, STYLE_NAMES[i] + " (" + STYLE_CODES[i] + ") at " + target)) {
			ApplyCode(STYLE_CODES[i]);
		}
		UI::SameLine();
	}
	if (DarkButton("Link", HasSelection() ? "Make the selection a link" : "Insert $l at the cursor")) {
		ApplyLink();
	}

	ToolbarLabel("Gradient");
	g_gradientFrom = UI::InputColor3("##gradientFrom", g_gradientFrom, UI::ColorEditFlags::NoInputs | UI::ColorEditFlags::NoLabel);
	UI::SameLine();
	UI::Text(Icons::ArrowRight);
	UI::SameLine();
	g_gradientTo = UI::InputColor3("##gradientTo", g_gradientTo, UI::ColorEditFlags::NoInputs | UI::ColorEditFlags::NoLabel);
	UI::SameLine();
	UI::BeginDisabled(!HasSelection());
	if (DarkButton("Apply##gradient", HasSelection() ? "Fade the selection between the two colors" : "Select some text first")) {
		ReplaceSelection(MakeGradient(SelectedText(), g_gradientFrom, g_gradientTo), true);
	}
	UI::EndDisabled();

	ToolbarLabel("Insert");
	for (uint i = 0; i < VARIABLES.Length; i++) {
		if (DarkButton(VARIABLES[i] + "##variable" + i, VARIABLE_HELP[i] + "\n\\$888Filled in when the snippet is sent")) {
			ReplaceSelection(VARIABLES[i], false);
		}
		UI::SameLine();
	}
	UI::NewLine();

	ToolbarLabel("");
	if (DarkButton("Clear formatting", HasSelection() ? "Remove all codes from the selection" : "Remove all codes from the text")) {
		ClearFormatting();
	}
	UI::SameLine();
	UI::BeginDisabled(g_undo.Length == 0);
	if (DarkButton(Icons::Undo + " Undo", "Undo the last toolbar change")) {
		Undo();
	}
	UI::EndDisabled();
}

// Free text, so a new group is made by typing its name; the arrow picks an existing one
void RenderGroupField()
{
	auto groups = GetGroups();
	ToolbarLabel("Group");
	// Leave room for the arrow that picks an existing group
	UI::SetNextItemWidth(-UI::GetFrameHeight() - UI::GetStyleVarVec2(UI::StyleVar::ItemSpacing).x);
	g_editGroup = UI::InputText("##group", g_editGroup);
	if (UI::IsItemHovered()) {
		UI::SetTooltip("Snippets with the same group are listed together. Leave empty for none.");
	}
	UI::SameLine();
	UI::BeginDisabled(groups.Length == 0);
	if (UI::BeginCombo("##pickGroup", "", UI::ComboFlags::NoPreview)) {
		if (UI::Selectable("(none)", g_editGroup == "")) {
			g_editGroup = "";
		}
		for (uint i = 0; i < groups.Length; i++) {
			if (UI::Selectable(groups[i], g_editGroup == groups[i])) {
				g_editGroup = groups[i];
			}
		}
		UI::EndCombo();
	}
	UI::EndDisabled();
}

void SaveEditor(const string &in name)
{
	// A key sends one snippet, so whoever had it before loses it
	auto previousOwner = HotkeyOwner(g_editHotkey, g_editIndex);
	if (previousOwner !is null) {
		previousOwner.hotkey = VirtualKey::None;
	}

	Snippet@ snippet;
	if (g_editIndex < 0) {
		@snippet = Snippet(name, "");
		g_snippets.InsertLast(snippet);
	} else {
		@snippet = g_snippets[g_editIndex];
	}
	snippet.name = name;
	// A chat message is a single line, so new lines only stay when each line is sent separately
	string text = g_editText.Replace("\r", "");
	snippet.text = g_editMultiLine ? text : text.Replace("\n", " ");
	snippet.multiLine = g_editMultiLine;
	snippet.icon = g_editIcon;
	snippet.group = g_editGroup.Trim();
	snippet.favorite = g_editFavorite;
	snippet.hotkey = g_editHotkey;

	SaveSnippets();
	g_editorOpen = false;
	g_capturingHotkey = false;
}

void RenderHotkeyField()
{
	string label;
	if (g_capturingHotkey) {
		label = "Press a key... (Escape: none)";
	} else {
		label = Icons::KeyboardO + " " + KeyName(g_editHotkey);
	}
	ToolbarLabel("Hotkey");
	if (g_capturingHotkey
		? ColoredButton(label + "###hotkey", HUE_BLUE, "")
		: DarkButton(label + "###hotkey", "Click, then press the key that should send this snippet")) {
		g_capturingHotkey = !g_capturingHotkey;
	}

	auto owner = HotkeyOwner(g_editHotkey, g_editIndex);
	if (owner !is null) {
		UI::SameLine();
		UI::Text("\\$f80" + Icons::ExclamationTriangle + " Used by \"" + owner.name + "\"; saving moves it here.");
	}
}

// A small bar with formatting buttons that pops up above selected text.
// Openplanet doesn't say where the selection is on screen, so the bar goes where the mouse was
// released after selecting, or above the text box when selecting with the keyboard.
bool g_selectionBarVisible = false;
vec2 g_selectionBarAnchor;
// From the previous frame: clicking the bar deactivates the text box, which would otherwise hide it
bool g_mouseOverSelectionBar = false;
// Size of the bar last frame, to center it before it is drawn
vec2 g_selectionBarSize;

void UpdateSelectionBar(bool textBoxActive, const vec2 &in textBoxPos)
{
	if (!HasSelection()) {
		g_selectionBarVisible = false;
		return;
	}
	if (textBoxActive) {
		if (UI::IsMouseDown() && !g_mouseOverSelectionBar) {
			// Still dragging out the selection
			g_selectionBarVisible = false;
			return;
		}
		if (!g_selectionBarVisible) {
			// Releasing the mouse ends a mouse selection, and the mouse is then at its end
			bool selectedWithMouse = UI::IsMouseReleased();
			g_selectionBarAnchor = selectedWithMouse ? UI::GetMousePos() : textBoxPos + vec2(UI::GetContentRegionAvail().x / 2, 0);
		}
		g_selectionBarVisible = true;
		return;
	}
	// The text box lost focus: keep the bar only while it's being used or refocusing after a click
	g_selectionBarVisible = g_selectionBarVisible && (g_mouseOverSelectionBar || g_refocus);
}

void RenderSelectionBar()
{
	if (!g_selectionBarVisible || !g_editorOpen) {
		g_mouseOverSelectionBar = false;
		return;
	}

	// A separate window would end up behind the focused editor, and focusing it would end the
	// text selection. As a child drawn last inside the editor it is always on top and gets the clicks.
	// It is centered above the anchor using last frame's size, and kept inside the editor window.
	float scale = UI::GetScale();
	vec2 windowPos = UI::GetWindowPos();
	vec2 windowSize = UI::GetWindowSize();
	vec2 barPos = g_selectionBarAnchor - vec2(g_selectionBarSize.x / 2, g_selectionBarSize.y + 10 * scale);
	barPos.x = Math::Clamp(barPos.x, windowPos.x, Math::Max(windowPos.x, windowPos.x + windowSize.x - g_selectionBarSize.x));
	barPos.y = Math::Max(barPos.y, windowPos.y);

	vec2 cursor = UI::GetCursorPos();
	UI::SetCursorScreenPos(barPos);
	// Opaque, so the text box behind it doesn't show through
	vec4 background = UI::GetStyleColor(UI::Col::PopupBg);
	background.w = 1.0f;
	UI::PushStyleColor(UI::Col::ChildBg, background);
	UI::PushStyleVar(UI::StyleVar::WindowPadding, vec2(6, 6));
	UI::PushStyleVar(UI::StyleVar::ItemSpacing, vec2(3, 3));
	UI::PushStyleVar(UI::StyleVar::ChildRounding, 6.0f);
	int childFlags = UI::ChildFlags::AutoResizeX | UI::ChildFlags::AutoResizeY | UI::ChildFlags::Borders | UI::ChildFlags::AlwaysUseWindowPadding;
	if (UI::BeginChild("selectionBar", vec2(0, 0), childFlags, UI::WindowFlags::NoScrollbar)) {
		for (uint i = 0; i < COLOR_CODES.Length; i++) {
			if (ColorSwatch(COLOR_CODES[i], "barColor" + i, COLOR_NAMES[i])) {
				ApplyCode(COLOR_CODES[i]);
			}
			UI::SameLine();
		}
		string customCode = ColorCode(g_customColor);
		if (DarkButton(Text::OpenplanetFormatCodes(customCode) + Icons::Tint + "##barCustom", "Custom color " + customCode)) {
			ApplyCode(customCode);
		}

		// Short labels; the tooltips name them
		const array<string> labels = { "B", "\\$iI", "W", "N", "Aa", "S" };
		for (uint i = 0; i < STYLE_CODES.Length; i++) {
			if (i > 0) {
				UI::SameLine();
			}
			if (DarkButton(labels[i] + "##barStyle" + i, STYLE_NAMES[i])) {
				ApplyCode(STYLE_CODES[i]);
			}
		}
		UI::SameLine();
		if (DarkButton("Link##barLink", "Make the selection a link")) {
			ApplyLink();
		}
		UI::SameLine();
		string gradientLabel = Text::OpenplanetFormatCodes(ColorCode(g_gradientFrom)) + Icons::Tint
			+ Text::OpenplanetFormatCodes(ColorCode(g_gradientTo)) + Icons::Tint + "##barGradient";
		if (DarkButton(gradientLabel, "Gradient with the colors from the toolbar")) {
			ReplaceSelection(MakeGradient(SelectedText(), g_gradientFrom, g_gradientTo), true);
		}
		UI::SameLine();
		if (DarkButton(Icons::Times + "##barClear", "Clear formatting")) {
			ClearFormatting();
		}

		vec2 pos = UI::GetWindowPos();
		g_selectionBarSize = UI::GetWindowSize();
		vec2 mouse = UI::GetMousePos();
		g_mouseOverSelectionBar = mouse.x >= pos.x && mouse.x <= pos.x + g_selectionBarSize.x
			&& mouse.y >= pos.y && mouse.y <= pos.y + g_selectionBarSize.y;
	}
	UI::EndChild();
	UI::PopStyleVar(3);
	UI::PopStyleColor();

	// Back to where the editor's layout was, so the bar doesn't move anything else
	UI::SetCursorPos(cursor);
	UI::Dummy(vec2(0, 0));
}

void RenderEditorWindow()
{
	if (!g_editorOpen) {
		return;
	}

	string title = g_editIndex < 0 ? "New snippet" : "Edit snippet";
	UI::SetNextWindowSize(580, 560, UI::Cond::FirstUseEver);
	UI::SetNextWindowSizeConstraints(460, 300, 10000, 10000);
	UI::PushStyleVar(UI::StyleVar::WindowPadding, vec2(10, 10));
	bool open = UI::Begin(Icons::Pencil + " " + title + "###ChatClipboardEditor", g_editorOpen);
	if (open) {
		UI::SeparatorTextOpenplanet("Details");
		ToolbarLabel("Name");
		UI::SetNextItemWidth(-1);
		g_editName = UI::InputText("##name", g_editName);
		RenderGroupField();
		ToolbarLabel("Icon");
		g_editIcon = IconPicker("snippetIcon", g_editIcon);
		RenderHotkeyField();
		ToolbarLabel("");
		g_editFavorite = UI::Checkbox(Icons::Star + " Favorite (shown in the quick bar)", g_editFavorite);
		ToolbarLabel("");
		g_editMultiLine = UI::Checkbox(Icons::List + " Send each line as a separate message (max " + MAX_LINES + ")", g_editMultiLine);
		if (UI::IsItemHovered()) {
			UI::SetTooltip("Chat messages are one line. With this on, every line you type with Enter is sent as its own message, with a pause in between (see the settings).");
		}

		UI::SeparatorTextOpenplanet("Message");
		RenderEditorToolbar();
		UI::Dummy(vec2(0, 2));

		if (g_refocus) {
			UI::SetKeyboardFocusHere();
			g_refocus = false;
		}
		vec2 textBoxPos = UI::GetCursorScreenPos();
		g_editText = UI::InputTextMultiline("##text", g_editText, vec2(-1, 110),
			UI::InputTextFlags(UI::InputTextFlags::WordWrap | UI::InputTextFlags::CallbackAlways),
			UI::InputTextCallback(EditorTextCallback));
		UpdateSelectionBar(UI::IsItemActive(), textBoxPos);

		auto lines = MessageLines(g_editText, g_editMultiLine);
		int longest = 0;
		for (uint i = 0; i < lines.Length; i++) {
			longest = Math::Max(longest, int(lines[i].Length));
		}
		bool tooLong = longest > MAX_MESSAGE_LENGTH;
		bool tooManyLines = int(lines.Length) > MAX_LINES;
		string counter = (tooLong ? "\\$f80" : "") + longest + " / " + MAX_MESSAGE_LENGTH;
		if (g_editMultiLine) {
			counter = (tooManyLines ? "\\$f80" : "") + lines.Length + " / " + MAX_LINES + " messages\\$z\\$888, longest " + counter;
		}
		UI::TextDisabled(counter);
		if (UI::IsItemHovered()) {
			UI::SetTooltip("Length including format codes. Longer messages get cut off in chat.");
		}

		UI::SeparatorTextOpenplanet("Preview");
		ChatPreview("preview", ExpandVariables(g_editText), g_editMultiLine);
		UI::Dummy(vec2(0, 4));

		string name = g_editName.Trim();
		auto existing = FindSnippet(name);
		bool nameTaken = existing !is null && (g_editIndex < 0 || existing !is g_snippets[g_editIndex]);
		bool valid = name != "" && g_editText.Trim() != "" && !nameTaken && !tooLong && !tooManyLines;

		// Ctrl+Enter also leaves the text box without adding a new line, so it can save from there
		bool focused = UI::IsWindowFocused(UI::FocusedFlags::RootAndChildWindows);
		bool ctrl = UI::IsKeyDown(UI::Key::LeftCtrl) || UI::IsKeyDown(UI::Key::RightCtrl);
		bool saveKey = focused && ctrl && (UI::IsKeyPressed(UI::Key::Enter) || UI::IsKeyPressed(UI::Key::KeypadEnter));
		bool cancelKey = focused && UI::IsKeyPressed(UI::Key::Escape) && !g_escapeUsed && !g_capturingHotkey;
		g_escapeUsed = false;

		UI::BeginDisabled(!valid);
		if (ColoredButton(Icons::Check + " Save", HUE_GREEN, "Ctrl+Enter") || (valid && saveKey)) {
			SaveEditor(name);
		}
		UI::EndDisabled();
		UI::SameLine();
		if (DarkButton(Icons::Times + " Cancel", "Escape") || cancelKey) {
			g_editorOpen = false;
		}
		if (nameTaken) {
			UI::SameLine();
			UI::AlignTextToFramePadding();
			UI::Text("\\$f80" + Icons::ExclamationTriangle + " A snippet with this name already exists.");
		} else if (tooLong) {
			UI::SameLine();
			UI::AlignTextToFramePadding();
			UI::Text("\\$f80" + Icons::ExclamationTriangle + " Too long for one chat message.");
		} else if (tooManyLines) {
			UI::SameLine();
			UI::AlignTextToFramePadding();
			UI::Text("\\$f80" + Icons::ExclamationTriangle + " At most " + MAX_LINES + " lines, one message each.");
		}

		// Last, so it's drawn on top of everything else in the editor
		RenderSelectionBar();
	}
	UI::End();
	// Pushed before Begin, so it can only be popped after End
	UI::PopStyleVar();

}
