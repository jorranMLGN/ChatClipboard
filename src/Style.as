// Shared look for the plugin's windows. Button colors match Better Chat's sidebar buttons.

const float HUE_RED = 0.0f;
const float HUE_GREEN = 0.33f;
const float HUE_BLUE = 0.58f;

// Background of the preview box, close to Better Chat's chat window
const vec4 PREVIEW_BG = vec4(0.0f, 0.0f, 0.0f, 0.35f);

// Width of the small square-ish action buttons, so a column of them lines up
float ActionButtonWidth()
{
	return UI::GetFrameHeight() * 1.3f;
}

bool ColoredButton(const string &in label, float hue, const string &in tooltip, const vec2 &in size = vec2())
{
	bool clicked = UI::ButtonColored(label, hue, 0.6f, 0.6f, size);
	if (tooltip != "" && UI::IsItemHovered(UI::HoveredFlags::AllowWhenDisabled)) {
		UI::SetTooltip(tooltip);
	}
	return clicked;
}

bool DarkButton(const string &in label, const string &in tooltip, const vec2 &in size = vec2())
{
	bool clicked = UI::ButtonColored(label, 0.78f, 0.0f, 0.12f, size);
	if (tooltip != "" && UI::IsItemHovered(UI::HoveredFlags::AllowWhenDisabled)) {
		UI::SetTooltip(tooltip);
	}
	return clicked;
}

bool ToggleButton(bool on, const string &in label, const string &in tooltip)
{
	return on ? ColoredButton(label, HUE_GREEN, tooltip) : DarkButton(label, tooltip);
}

void BoldText(const string &in text)
{
	UI::PushFont(UI::Font::DefaultBold);
	UI::Text(text);
	UI::PopFont();
}

// Shows Trackmania-formatted text the way it will look in chat, on a dark background
void ChatPreview(const string &in id, const string &in text)
{
	UI::PushStyleColor(UI::Col::ChildBg, PREVIEW_BG);
	UI::PushStyleVar(UI::StyleVar::ChildRounding, 4.0f);
	UI::BeginChild(id, vec2(0, 0), UI::ChildFlags::AutoResizeY | UI::ChildFlags::AlwaysUseWindowPadding);
	if (text == "") {
		UI::TextDisabled("Nothing to preview yet");
	} else {
		UI::TextWrapped(Text::OpenplanetFormatCodes(text));
	}
	UI::EndChild();
	UI::PopStyleVar();
	UI::PopStyleColor();
}
