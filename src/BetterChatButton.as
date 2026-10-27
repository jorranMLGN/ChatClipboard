// Better Chat has no API for extra buttons, so we add one to the bottom of its sidebar ourselves.
// ImGui lets a second Begin() with the same title append widgets to a window that was already
// drawn this frame. This only works because Better Chat (our dependency) renders before us.

void RenderBetterChatButton()
{
	if (!S_BetterChatButton || !IsOnServer()) {
		return;
	}
	// Better Chat only draws its sidebar while the overlay is shown
	if (!UI::IsOverlayShown()) {
		return;
	}

	// Normal and big chat are separate windows with a different number of sidebar buttons
	AppendSidebarButton("Better Chat", 6, false);
	AppendSidebarButton("Better Chat##Big", 5, true);
}

// Same check Better Chat uses: its window only exists while connected to a server
bool IsOnServer()
{
	auto serverInfo = cast<CGameCtnNetServerInfo>(GetApp().Network.ServerInfo);
	return serverInfo !is null && serverInfo.ServerLogin != "";
}

void AppendSidebarButton(const string &in windowTitle, int buttonsAbove, bool temporaryWindow)
{
	// If Better Chat didn't draw this window this frame, our Begin() is the first one and these
	// flags apply: the window stays empty, transparent and click-through, so nothing shows up.
	int flags = UI::WindowFlags::NoDecoration | UI::WindowFlags::NoInputs
		| UI::WindowFlags::NoFocusOnAppearing | UI::WindowFlags::NoBringToFrontOnFocus;
	// Big chat is never saved by Better Chat either; the normal chat must keep its saved position
	if (temporaryWindow) {
		flags |= UI::WindowFlags::NoSavedSettings;
	}

	UI::SetNextWindowBgAlpha(0.0f);
	UI::Begin(windowTitle, flags);

	vec2 contentMin = UI::GetWindowContentRegionMin();
	vec2 contentMax = UI::GetWindowContentRegionMax();
	float slot = UI::GetFrameHeightWithSpacing();
	vec2 pos = contentMin + vec2(0, buttonsAbove * slot);

	// Better Chat always leaves the cursor below its chat area. If the cursor is still at the
	// top, Better Chat didn't draw this window.
	bool drawnByBetterChat = UI::GetCursorPos().y > contentMin.y + 1;
	// Content below the window's edge would give the chat a scrollbar
	bool fits = pos.y + UI::GetFrameHeight() <= contentMax.y;

	if (drawnByBetterChat && fits) {
		UI::SetCursorPos(pos);
		ClipboardToggleButton();
	} else if (drawnByBetterChat) {
		// The sidebar is full (the default chat height only fits Better Chat's own buttons), so
		// put the button in the top right corner of the chat area instead. Better Chat starts its
		// chat area 40px right of the sidebar; using the same cursor position and id appends to
		// that child window with the same size.
		UI::SetCursorPos(contentMin + vec2(40, 0) * UI::GetScale());
		UI::BeginChild("ChatContainer");
		float width = UI::GetFrameHeight() * 1.5f;
		// Screen coordinates, so the chat's scroll position doesn't matter. The content region's
		// right edge excludes the scrollbar; the chat never scrolls horizontally.
		vec2 childPos = UI::GetWindowPos();
		UI::SetCursorScreenPos(vec2(childPos.x + UI::GetWindowContentRegionMax().x - width, childPos.y));
		ClipboardToggleButton(vec2(width, UI::GetFrameHeight()));
		UI::EndChild();
	}

	UI::End();
}

void ClipboardToggleButton(const vec2 &in size = vec2())
{
	// Same colors as Better Chat's own toggle buttons
	bool clicked = S_WindowOpen
		? UI::ButtonColored(Icons::Clipboard + "##ChatClipboard", 0.33f, 0.6f, 0.6f, size)
		: UI::ButtonColored(Icons::Clipboard + "##ChatClipboard", 0.78f, 0.0f, 0.12f, size);
	if (clicked) {
		S_WindowOpen = !S_WindowOpen;
	}
	if (UI::IsItemHovered()) {
		UI::SetTooltip("Chat Clipboard");
	}
}
