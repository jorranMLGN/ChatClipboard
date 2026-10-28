// Every snippet gets its own Better Chat command, like "/clip-gears", so it shows up in the
// command autocompletion while typing in chat. Better Chat reads a command's description once
// when it is registered, so the commands are rebuilt whenever the snippets change.

array<string> g_snippetCommands;

class SnippetCommand : BetterChat::ICommand
{
	Snippet@ m_snippet;

	SnippetCommand(Snippet@ snippet)
	{
		@m_snippet = snippet;
	}

	string Icon()
	{
		return m_snippet.icon == "" ? Icons::Clipboard : m_snippet.icon;
	}

	string Description()
	{
		return Shorten(Text::StripFormatCodes(m_snippet.text).Replace("\n", " / "), 60);
	}

	void Run(const string &in text)
	{
		SendSnippet(m_snippet);
	}
}

void RegisterSnippetCommands()
{
	UnregisterSnippetCommands();
	if (!S_SnippetCommands) {
		return;
	}

	for (uint i = 0; i < g_snippets.Length; i++) {
		string name = CommandName(g_snippets[i].name);
		// Names that differ only in punctuation end up the same; the first snippet wins
		if (name == "" || g_snippetCommands.Find(name) >= 0) {
			continue;
		}
		BetterChat::RegisterCommand(name, SnippetCommand(g_snippets[i]));
		g_snippetCommands.InsertLast(name);
	}
}

void UnregisterSnippetCommands()
{
	for (uint i = 0; i < g_snippetCommands.Length; i++) {
		BetterChat::UnregisterCommand(g_snippetCommands[i]);
	}
	g_snippetCommands.RemoveRange(0, g_snippetCommands.Length);
}

// "Action Keys" becomes "clip-action-keys". Better Chat only accepts letters, digits, - and _.
string CommandName(const string &in snippetName)
{
	string lower = snippetName.ToLower();
	string slug = "";
	for (int i = 0; i < lower.Length; i++) {
		uint8 c = lower[i];
		bool letter = c >= 0x61 && c <= 0x7A;
		bool digit = c >= 0x30 && c <= 0x39;
		if (letter || digit) {
			slug += lower.SubStr(i, 1);
		} else if (slug != "" && !slug.EndsWith("-")) {
			slug += "-";
		}
	}
	if (slug.EndsWith("-")) {
		slug = slug.SubStr(0, slug.Length - 1);
	}
	return slug == "" ? "" : CommandPrefix() + slug;
}

// The prefix from the settings with anything Better Chat doesn't accept left out. It is never
// empty: without one, a snippet named "Version" would replace Better Chat's own /version.
string CommandPrefix()
{
	string prefix = "";
	string lower = S_CommandPrefix.ToLower();
	for (int i = 0; i < lower.Length; i++) {
		uint8 c = lower[i];
		bool allowed = (c >= 0x61 && c <= 0x7A) || (c >= 0x30 && c <= 0x39) || c == 0x2D || c == 0x5F;
		if (allowed) {
			prefix += lower.SubStr(i, 1);
		}
	}
	return prefix == "" ? "clip-" : prefix;
}

string Shorten(const string &in text, int maxBytes)
{
	if (text.Length <= maxBytes) {
		return text;
	}
	// Don't cut a UTF-8 character in half
	int cut = maxBytes;
	while (cut > 0 && (text[cut] & 0xC0) == 0x80) {
		cut--;
	}
	return text.SubStr(0, cut) + "...";
}
