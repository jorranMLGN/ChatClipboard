// Icons a snippet can show in front of its name. Only standard FontAwesome icons that other
// Openplanet plugins use too: an icon name that doesn't exist stops the whole plugin from compiling.

const array<string> SNIPPET_ICONS = {
	Icons::Comment, Icons::HandPeaceO, Icons::ThumbsOUp, Icons::ThumbsODown, Icons::Heart, Icons::SmileO,
	Icons::Star, Icons::Trophy, Icons::FlagCheckered, Icons::Flag, Icons::Car, Icons::Road,
	Icons::Gamepad, Icons::Bolt, Icons::Bullseye, Icons::Crosshairs, Icons::Map, Icons::Globe,
	Icons::Sun, Icons::SnowflakeO, Icons::Tree, Icons::Eye, Icons::InfoCircle, Icons::QuestionCircle,
	Icons::ExclamationTriangle, Icons::Book, Icons::University, Icons::Wrench, Icons::Cog, Icons::Magic,
	Icons::ClockO, Icons::Hourglass, Icons::Bell, Icons::Envelope, Icons::User, Icons::Users,
	Icons::Hashtag, Icons::Tag, Icons::Heartbeat, Icons::Money, Icons::Camera, Icons::VideoCamera,
	Icons::ExternalLink, Icons::Github, Icons::Twitch, Icons::YoutubePlay, Icons::Plane, Icons::PaintBrush
};

const int ICONS_PER_ROW = 8;

// The icon plus a space, or nothing when the snippet has no icon
string IconPrefix(Snippet@ snippet)
{
	return snippet.icon == "" ? "" : snippet.icon + " ";
}

// A button showing the chosen icon that opens a grid to pick one; returns the (new) icon
string IconPicker(const string &in id, const string &in current)
{
	string result = current;
	string label = current == "" ? "None" : current;
	if (DarkButton(label + "###" + id, "Pick an icon to show in front of the name")) {
		UI::OpenPopup(id + "Popup");
	}

	if (UI::BeginPopup(id + "Popup")) {
		float size = UI::GetFrameHeight() * 1.3f;
		for (uint i = 0; i < SNIPPET_ICONS.Length; i++) {
			if (i % ICONS_PER_ROW != 0) {
				UI::SameLine();
			}
			bool selected = SNIPPET_ICONS[i] == current;
			bool clicked = selected
				? ColoredButton(SNIPPET_ICONS[i] + "##icon" + i, HUE_BLUE, "", vec2(size, size))
				: DarkButton(SNIPPET_ICONS[i] + "##icon" + i, "", vec2(size, size));
			if (clicked) {
				result = SNIPPET_ICONS[i];
				UI::CloseCurrentPopup();
			}
		}
		if (DarkButton(Icons::Times + " No icon", "")) {
			result = "";
			UI::CloseCurrentPopup();
		}
		UI::EndPopup();
	}
	return result;
}
