// Chat Clipboard: saved chat messages you can send or copy with one click.

void Main()
{
	LoadSnippets();
	BetterChat::RegisterCommand("clipboard", ClipboardCommand());
	RegisterSnippetCommands();
}

void OnDestroy()
{
	BetterChat::UnregisterCommand("clipboard");
	UnregisterSnippetCommands();
}

void OnSettingsChanged()
{
	RegisterSnippetCommands();
}

void Render()
{
	RenderBetterChatButton();
	RenderQuickBar();

	if (!S_WindowOpen) {
		return;
	}
	if (!S_ShowWithoutOverlay && !UI::IsOverlayShown()) {
		return;
	}
	RenderClipboardWindow();
	RenderEditorWindow();
}

UI::InputBlocking OnKeyPress(bool down, VirtualKey key)
{
	if (!down) {
		return UI::InputBlocking::DoNothing;
	}
	return HandleKeyPress(key);
}

void RenderMenu()
{
	if (UI::BeginMenu(Icons::Clipboard + " Chat Clipboard")) {
		if (UI::MenuItem("Clipboard window", "", S_WindowOpen)) {
			S_WindowOpen = !S_WindowOpen;
		}
		if (UI::MenuItem("Quick bar", "", S_QuickBar)) {
			S_QuickBar = !S_QuickBar;
		}
		UI::EndMenu();
	}
}

// "/clipboard" opens the window, "/clipboard <name>" sends that snippet.
class ClipboardCommand : BetterChat::ICommand
{
	string Icon()
	{
		return Icons::Clipboard;
	}

	string Description()
	{
		return "Open the chat clipboard, or send a snippet with /clipboard <name>.";
	}

	void Run(const string &in text)
	{
		// BetterChat passes the whole input line, including "/clipboard"
		int space = text.IndexOf(" ");
		string arg = space < 0 ? "" : text.SubStr(space + 1).Trim();

		if (arg == "") {
			S_WindowOpen = true;
			return;
		}

		auto snippet = FindSnippet(arg);
		if (snippet is null) {
			BetterChat::AddSystemLine("$<$f80Clipboard:$> no snippet named \"" + arg + "\".");
			return;
		}
		SendSnippet(snippet);
	}
}

// A double click shouldn't send the same message twice; servers can mute you for spamming
const uint64 SEND_COOLDOWN = 1500;
uint64 g_lastSendTime = 0;

bool CanSendNow()
{
	return g_lastSendTime == 0 || Time::Now - g_lastSendTime >= SEND_COOLDOWN;
}

void SendSnippet(Snippet@ snippet, bool toTeam = false)
{
	if (!CanSendNow()) {
		return;
	}
	g_lastSendTime = Time::Now;
	// The game sends messages starting with "/t " to your team only
	BetterChat::SendChatMessage((toTeam ? "/t " : "") + ExpandVariables(snippet.text));

	snippet.uses++;
	// Only the count changed, so the chat commands don't need rebuilding
	WriteSnippets();
}

void CopySnippet(Snippet@ snippet)
{
	IO::SetClipboard(ExpandVariables(snippet.text));
	BetterChat::AddSystemLine("$<$0f0Clipboard:$> copied \"" + snippet.name + "\".");
}
