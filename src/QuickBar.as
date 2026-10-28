// A small window with the favorite snippets, to send them with one click while playing.

void RenderQuickBar()
{
	if (!S_QuickBar || !IsOnServer()) {
		return;
	}
	if (!S_QuickBarWithoutOverlay && !UI::IsOverlayShown()) {
		return;
	}

	array<Snippet@> favorites;
	for (uint i = 0; i < g_snippets.Length; i++) {
		if (g_snippets[i].favorite) {
			favorites.InsertLast(g_snippets[i]);
		}
	}
	if (favorites.Length == 0) {
		return;
	}

	int flags = UI::WindowFlags::NoTitleBar | UI::WindowFlags::AlwaysAutoResize | UI::WindowFlags::NoScrollbar
		| UI::WindowFlags::NoCollapse | UI::WindowFlags::NoFocusOnAppearing | UI::WindowFlags::NoDocking;
	// Like Better Chat, it can only be moved while the overlay is shown, so it can't be dragged by accident
	if (!UI::IsOverlayShown()) {
		flags |= UI::WindowFlags::NoMove;
	}

	UI::SetNextWindowPos(20, 300, UI::Cond::FirstUseEver);
	UI::SetNextWindowBgAlpha(S_QuickBarOpacity);
	UI::PushStyleVar(UI::StyleVar::WindowPadding, vec2(6, 6));
	UI::PushStyleVar(UI::StyleVar::ItemSpacing, vec2(4, 4));
	if (UI::Begin("Chat Clipboard Quick Bar", flags)) {
		// All buttons dim while the send cooldown runs, which also shows the message went out
		UI::BeginDisabled(!CanSendNow() || !CanChat());
		for (uint i = 0; i < favorites.Length; i++) {
			if (i > 0 && !S_QuickBarVertical) {
				UI::SameLine();
			}
			RenderQuickBarButton(favorites[i], i);
		}
		UI::EndDisabled();
		RenderSendProgress();
	}
	UI::End();
	UI::PopStyleVar(2);
}

void RenderQuickBarButton(Snippet@ snippet, uint index)
{
	UI::PushID("quick" + index);

	bool iconOnly = S_QuickBarIconsOnly && snippet.icon != "";
	string tooltip = Text::OpenplanetFormatCodes(ExpandVariables(snippet.text));
	if (iconOnly) {
		// The button doesn't show the name, so the tooltip starts with it
		tooltip = snippet.name + "\n" + tooltip;
	}
	if (snippet.hotkey != VirtualKey::None) {
		tooltip += "\n\\$888Hotkey: " + KeyName(snippet.hotkey);
	}
	tooltip += "\n\\$888Right click: send to team";

	if (DarkButton(iconOnly ? snippet.icon : IconPrefix(snippet) + snippet.name, tooltip)) {
		SendSnippet(snippet);
	}
	if (UI::BeginPopupContextItem("sendMenu")) {
		if (UI::MenuItem("Send to everyone")) {
			SendSnippet(snippet);
		}
		if (TeamMenuItem()) {
			SendSnippet(snippet, true);
		}
		UI::EndPopup();
	}

	UI::PopID();
}
