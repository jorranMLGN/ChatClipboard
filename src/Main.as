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

// After sending, the buttons wait S_SendCooldown ms: a double click shouldn't send the same
// message twice, and servers can mute you for spamming
// Nothing can be sent before this time, which also covers all lines of a multi-line snippet
uint64 g_nextSendTime = 0;
// Messages still to send for a multi-line snippet
array<string> g_sendQueue;
// For the progress shown while a multi-line snippet is being sent
string g_sendingName;
int g_sendTotal = 0;

bool CanSendNow()
{
	return Time::Now >= g_nextSendTime;
}

// Messages only go out during a match: Better Chat drops them while a map loads or between maps
bool CanChat()
{
	return IsOnServer() && GetApp().CurrentPlayground !is null;
}

void SendSnippet(Snippet@ snippet, bool toTeam = false)
{
	if (!CanSendNow() || !CanChat()) {
		return;
	}

	auto lines = MessageLines(snippet.text, snippet.multiLine);
	// The editor allows at most MAX_LINES; an edited file could have more
	int count = Math::Min(int(lines.Length), MAX_LINES);
	for (int i = 0; i < count; i++) {
		// The game sends messages starting with "/t " to your team only
		g_sendQueue.InsertLast((toTeam ? "/t " : "") + ExpandVariables(lines[i]));
	}
	g_sendingName = snippet.name;
	g_sendTotal = count;
	g_nextSendTime = Time::Now + uint64(count - 1) * uint64(S_LineDelay) + uint64(S_SendCooldown);
	startnew(CoroutineFunc(SendQueueAsync));

	snippet.uses++;
	// Only the count changed, so the chat commands don't need rebuilding
	WriteSnippets();
}

// Better Chat only sends a message on the next frame, so sending lines back to back would
// overwrite each other; they go out one by one with a pause in between
void SendQueueAsync()
{
	while (g_sendQueue.Length > 0) {
		BetterChat::SendChatMessage(g_sendQueue[0]);
		g_sendQueue.RemoveAt(0);
		if (g_sendQueue.Length > 0) {
			sleep(S_LineDelay);
		}
	}
}

// Drops the lines that weren't sent yet; the sleeping coroutine finds the queue empty and stops
void StopSending()
{
	g_sendQueue.RemoveRange(0, g_sendQueue.Length);
	g_nextSendTime = Time::Now + uint64(S_SendCooldown);
}

// "Sending "Gears": 2 of 4" with a turning hourglass and a stop button, while lines are queued
void RenderSendProgress()
{
	// Only multi-line snippets wait between messages; a single message goes out right away
	if (g_sendQueue.Length == 0 || g_sendTotal <= 1) {
		return;
	}
	// Openplanet has no animated spinner, so cycle through the hourglass icons
	const array<string> HOURGLASS = { Icons::HourglassStart, Icons::HourglassHalf, Icons::HourglassEnd };
	string icon = HOURGLASS[uint((Time::Now / 400) % HOURGLASS.Length)];
	int sent = g_sendTotal - int(g_sendQueue.Length);

	UI::AlignTextToFramePadding();
	UI::Text("\\$fd0" + icon + "\\$z Sending \"" + g_sendingName + "\": " + sent + " of " + g_sendTotal);
	UI::SameLine();
	if (DarkButton(Icons::Times + " Stop##stopSending", "Don't send the remaining lines")) {
		StopSending();
	}
}

// Your team: 0 on servers without teams (such as time attack), 1 for blue, 2 for red.
// Team messages only arrive in team modes, so the team option is disabled otherwise.
uint LocalTeam()
{
	auto app = GetApp();
	auto playground = app.CurrentPlayground;
	auto network = cast<CTrackManiaNetwork>(app.Network);
	if (playground is null || network is null || network.PlayerInfo is null) {
		return 0;
	}
	string login = network.PlayerInfo.Login;
	for (uint i = 0; i < playground.Players.Length; i++) {
		auto player = cast<CSmPlayer>(playground.Players[i]);
		if (player !is null && player.User !is null && player.User.Login == login) {
			return player.EdClan;
		}
	}
	return 0;
}

// The "Send to team" entry of the send menus; disabled when you're not in a team
bool TeamMenuItem()
{
	bool inTeam = LocalTeam() > 0;
	return UI::MenuItem(inTeam ? "Send to team" : "Send to team (no teams here)", "", false, inTeam);
}

void CopySnippet(Snippet@ snippet)
{
	IO::SetClipboard(ExpandVariables(snippet.text));
	if (S_CopyNotification) {
		BetterChat::AddSystemLine("$<$0f0Clipboard:$> copied \"" + snippet.name + "\".");
	}
}
