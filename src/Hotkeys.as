// Keys that send a snippet, the key that toggles the window, and picking a key in the editor.

// Set while the editor waits for the user to press the key for a snippet
bool g_capturingHotkey = false;
// The Escape that removed a hotkey shouldn't also close the editor
bool g_escapeUsed = false;

bool IsMouseButton(VirtualKey key)
{
	return key == VirtualKey::LButton || key == VirtualKey::RButton || key == VirtualKey::Mbutton
		|| key == VirtualKey::XButton1 || key == VirtualKey::XButton2;
}

UI::InputBlocking HandleKeyPress(VirtualKey key)
{
	if (g_capturingHotkey && !IsMouseButton(key)) {
		g_capturingHotkey = false;
		// Escape removes the hotkey instead of assigning Escape
		g_escapeUsed = key == VirtualKey::Escape;
		g_editHotkey = g_escapeUsed ? VirtualKey::None : key;
		return UI::InputBlocking::Block;
	}

	// Never act on keys while the user is typing, e.g. in Better Chat's input or a text box here
	if (UI::WantCaptureKeyboard()) {
		return UI::InputBlocking::DoNothing;
	}

	if (S_ToggleKey != VirtualKey::None && key == S_ToggleKey) {
		S_WindowOpen = !S_WindowOpen;
		return UI::InputBlocking::Block;
	}

	if (!S_Hotkeys || !IsOnServer()) {
		return UI::InputBlocking::DoNothing;
	}
	for (uint i = 0; i < g_snippets.Length; i++) {
		if (g_snippets[i].hotkey == key) {
			SendSnippet(g_snippets[i]);
			return UI::InputBlocking::Block;
		}
	}
	return UI::InputBlocking::DoNothing;
}

string KeyName(VirtualKey key)
{
	return key == VirtualKey::None ? "None" : tostring(key);
}

// The snippet that already uses this key, apart from the one at skipIndex
Snippet@ HotkeyOwner(VirtualKey key, int skipIndex)
{
	if (key == VirtualKey::None) {
		return null;
	}
	for (uint i = 0; i < g_snippets.Length; i++) {
		if (int(i) != skipIndex && g_snippets[i].hotkey == key) {
			return g_snippets[i];
		}
	}
	return null;
}
