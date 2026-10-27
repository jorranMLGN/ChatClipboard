string g_filter = "";
bool g_favoritesOnly = false;
int g_armedDelete = -1;

// Changes to the list are collected while drawing and applied afterwards, so indices stay valid
int g_moveFrom = -1;
int g_moveTo = -1;
int g_deleteIndex = -1;
int g_duplicateIndex = -1;

// The last deleted snippet, so it can be put back for a while
Snippet@ g_deleted = null;
int g_deletedIndex = -1;
uint64 g_deletedTime = 0;
const uint64 UNDO_DELETE_TIME = 10000;

const array<string> SORT_NAMES = { "Manual order", "Most used first", "By name" };

bool IconButton(const string &in icon, const string &in tooltip)
{
	bool clicked = UI::Button(icon);
	if (UI::IsItemHovered()) {
		UI::SetTooltip(tooltip);
	}
	return clicked;
}

bool MatchesFilter(Snippet@ snippet)
{
	if (g_favoritesOnly && !snippet.favorite) {
		return false;
	}
	if (g_filter == "") {
		return true;
	}
	string needle = g_filter.ToLower();
	return snippet.name.ToLower().Contains(needle)
		|| snippet.group.ToLower().Contains(needle)
		|| Text::StripFormatCodes(snippet.text).ToLower().Contains(needle);
}

// Groups in the order they first appear; "" (no group) is left out
array<string> GetGroups()
{
	array<string> groups;
	for (uint i = 0; i < g_snippets.Length; i++) {
		string group = g_snippets[i].group;
		if (group != "" && groups.Find(group) < 0) {
			groups.InsertLast(group);
		}
	}
	return groups;
}

// The nearest snippet in the same group before (step -1) or after (step 1) index, or -1
int NeighbourInGroup(int index, int step)
{
	string group = g_snippets[index].group;
	for (int i = index + step; i >= 0 && i < int(g_snippets.Length); i += step) {
		if (g_snippets[i].group == group) {
			return i;
		}
	}
	return -1;
}

// Whether a should be listed before b in the current sort mode
bool SortsBefore(Snippet@ a, Snippet@ b)
{
	if (S_SortMode == SortMode::MostUsed && a.uses != b.uses) {
		return a.uses > b.uses;
	}
	if (S_SortMode == SortMode::Name) {
		return a.name.ToLower() < b.name.ToLower();
	}
	return false;
}

// Indices of the snippets in a group that match the filter, in display order
array<int> VisibleIndices(const string &in group)
{
	array<int> result;
	for (uint i = 0; i < g_snippets.Length; i++) {
		if (g_snippets[i].group == group && MatchesFilter(g_snippets[i])) {
			result.InsertLast(int(i));
		}
	}
	// Insertion sort keeps equal snippets in manual order; the lists are short
	for (uint i = 1; i < result.Length; i++) {
		int current = result[i];
		int j = int(i) - 1;
		while (j >= 0 && SortsBefore(g_snippets[current], g_snippets[result[j]])) {
			result[j + 1] = result[j];
			j--;
		}
		result[j + 1] = current;
	}
	return result;
}

bool CanReorder()
{
	// Moving swaps with the neighbour in the full list, which would be confusing when the list
	// is sorted differently or neighbours are hidden
	return S_SortMode == SortMode::Manual && g_filter == "" && !g_favoritesOnly;
}

void RenderClipboardWindow()
{
	UI::SetNextWindowSize(560, 480, UI::Cond::FirstUseEver);
	UI::SetNextWindowSizeConstraints(420, 200, 10000, 10000);
	UI::PushStyleVar(UI::StyleVar::WindowPadding, vec2(10, 10));
	bool open = UI::Begin(Icons::Clipboard + " Chat Clipboard###ChatClipboard", S_WindowOpen);
	if (open) {
		RenderToolbar();
		RenderUndoDelete();
		UI::Dummy(vec2(0, 2));
		if (g_snippets.Length == 0) {
			RenderEmptyState();
		} else {
			RenderSnippetList();
		}
	}
	UI::End();
	// Pushed before Begin, so it can only be popped after End
	UI::PopStyleVar();
}

void RenderToolbar()
{
	if (ColoredButton(Icons::Plus + " New", HUE_GREEN, "Add a new snippet")) {
		OpenEditor(-1);
	}
	UI::SameLine();
	if (ToggleButton(S_EditMode, Icons::Cogs + " Edit", "Show buttons to duplicate, reorder and delete snippets")) {
		S_EditMode = !S_EditMode;
		g_armedDelete = -1;
	}
	if (S_EditMode) {
		UI::SameLine();
		if (DarkButton(Icons::FolderOpen, "Open the folder with chat_clipboard.json, e.g. to make a backup")) {
			OpenExplorerPath(IO::FromStorageFolder(""));
		}
	}

	UI::SameLine();
	if (ToggleButton(g_favoritesOnly, Icons::Star, "Only show favorites")) {
		g_favoritesOnly = !g_favoritesOnly;
	}
	UI::SameLine();
	if (DarkButton(Icons::ListOl, "Sorting: " + SORT_NAMES[int(S_SortMode)] + "\n\\$888Click to change")) {
		S_SortMode = SortMode((int(S_SortMode) + 1) % int(SORT_NAMES.Length));
	}
	UI::SameLine();
	if (ToggleButton(S_CompactView, Icons::List, "Compact view: hide the text, show it when hovering the name")) {
		S_CompactView = !S_CompactView;
	}

	UI::SameLine();
	UI::AlignTextToFramePadding();
	UI::TextDisabled(Icons::Search);
	UI::SameLine();
	UI::SetNextItemWidth(-1);
	g_filter = UI::InputText("##filter", g_filter);
	if (UI::IsItemHovered()) {
		UI::SetTooltip("Filter by name, group or text");
	}
}

void RenderUndoDelete()
{
	if (g_deleted is null || Time::Now - g_deletedTime > UNDO_DELETE_TIME) {
		return;
	}
	UI::AlignTextToFramePadding();
	UI::TextDisabled("Deleted \"" + g_deleted.name + "\".");
	UI::SameLine();
	if (ColoredButton(Icons::Undo + " Undo", HUE_BLUE, "Put the snippet back")) {
		int index = Math::Min(g_deletedIndex, int(g_snippets.Length));
		g_snippets.InsertAt(index, g_deleted);
		if (g_editIndex >= index) {
			g_editIndex++;
		}
		@g_deleted = null;
		SaveSnippets();
	}
}

void RenderEmptyState()
{
	UI::Dummy(vec2(0, 20));
	UI::TextDisabled("No snippets yet.");
	UI::TextDisabled("Click \"" + Icons::Plus + " New\" to save a message you send often.");
}

void RenderSnippetList()
{
	g_moveFrom = g_moveTo = g_deleteIndex = g_duplicateIndex = -1;

	// Snippets without a group come first, without a header
	int shown = RenderSnippetTable("");
	auto groups = GetGroups();
	for (uint i = 0; i < groups.Length; i++) {
		auto indices = VisibleIndices(groups[i]);
		if (indices.Length == 0) {
			continue;
		}
		shown += int(indices.Length);
		UI::SetNextItemOpen(true, UI::Cond::FirstUseEver);
		// The part after ### is the id, so the count can change without collapsing the header
		if (UI::CollapsingHeader(groups[i] + "  \\$888" + indices.Length + "###group_" + groups[i])) {
			RenderSnippetTable(groups[i]);
		}
	}

	if (shown == 0) {
		UI::Dummy(vec2(0, 10));
		UI::TextDisabled(g_favoritesOnly && g_filter == ""
			? "No favorites yet. Click " + Icons::Star + " next to a snippet to add it."
			: "No snippets match \"" + g_filter + "\".");
	}

	ApplyListChanges();
}

// Draws the snippets of one group and returns how many there were
int RenderSnippetTable(const string &in group)
{
	auto indices = VisibleIndices(group);
	if (indices.Length == 0) {
		return 0;
	}

	UI::PushStyleVar(UI::StyleVar::CellPadding, vec2(8, S_CompactView ? 3 : 6));
	if (!UI::BeginTable("snippets##" + group, 2, UI::TableFlags::RowBg | UI::TableFlags::PadOuterX)) {
		UI::PopStyleVar();
		return int(indices.Length);
	}
	UI::TableSetupColumn("Snippet", UI::TableColumnFlags::WidthStretch);
	UI::TableSetupColumn("Actions", UI::TableColumnFlags::WidthFixed);

	for (uint i = 0; i < indices.Length; i++) {
		RenderSnippetRow(indices[i]);
	}

	UI::EndTable();
	UI::PopStyleVar();
	return int(indices.Length);
}

void RenderSnippetRow(int index)
{
	auto snippet = g_snippets[index];
	bool onServer = IsOnServer();
	vec2 buttonSize = vec2(ActionButtonWidth(), 0);

	UI::PushID("snippet" + index);
	UI::TableNextRow();

	UI::TableNextColumn();
	if (snippet.favorite) {
		UI::Text("\\$fd0" + Icons::Star);
		UI::SameLine();
	}
	BoldText(snippet.name);
	if (S_CompactView && UI::IsItemHovered()) {
		UI::SetTooltip(Text::OpenplanetFormatCodes(snippet.text));
	}
	RenderBadges(snippet);
	if (!S_CompactView) {
		UI::TextWrapped(Text::OpenplanetFormatCodes(snippet.text));
	}

	UI::TableNextColumn();
	UI::BeginDisabled(!onServer || !CanSendNow());
	string sendTooltip = onServer ? "Send to chat\n\\$888Right click: send to team" : "Join a server to send messages";
	if (ColoredButton(Icons::PaperPlane, HUE_GREEN, sendTooltip, buttonSize)) {
		SendSnippet(snippet);
	}
	UI::EndDisabled();
	if (onServer && UI::BeginPopupContextItem("sendMenu")) {
		if (UI::MenuItem("Send to everyone")) {
			SendSnippet(snippet);
		}
		if (UI::MenuItem("Send to team")) {
			SendSnippet(snippet, true);
		}
		UI::EndPopup();
	}
	UI::SameLine();
	if (ColoredButton(Icons::Copy, HUE_BLUE, "Copy to clipboard", buttonSize)) {
		CopySnippet(snippet);
	}
	UI::SameLine();
	if (DarkButton(Icons::Pencil, "Edit", buttonSize)) {
		OpenEditor(index);
	}
	UI::SameLine();
	string starTooltip = snippet.favorite ? "Remove from favorites" : "Add to favorites (shown in the quick bar)";
	bool starClicked = snippet.favorite
		? ColoredButton(Icons::Star, 0.13f, starTooltip, buttonSize)
		: DarkButton(Icons::Star, starTooltip, buttonSize);
	if (starClicked) {
		snippet.favorite = !snippet.favorite;
		WriteSnippets();
	}

	if (S_EditMode) {
		RenderEditModeButtons(index, buttonSize);
	}

	UI::PopID();
}

// Small grey details after the name: chat command, hotkey and how often it was sent
void RenderBadges(Snippet@ snippet)
{
	string command = CommandName(snippet.name);
	if (S_SnippetCommands && g_snippetCommands.Find(command) >= 0) {
		UI::SameLine();
		UI::TextDisabled("/" + command);
	}
	if (snippet.hotkey != VirtualKey::None) {
		UI::SameLine();
		UI::TextDisabled(Icons::KeyboardO + " " + KeyName(snippet.hotkey));
	}
	if (snippet.uses > 0) {
		UI::SameLine();
		UI::TextDisabled(Icons::PaperPlane + " " + snippet.uses);
		if (UI::IsItemHovered()) {
			UI::SetTooltip("Sent " + snippet.uses + (snippet.uses == 1 ? " time" : " times"));
		}
	}
}

void RenderEditModeButtons(int index, const vec2 &in buttonSize)
{
	if (DarkButton(Icons::Plus, "Duplicate", buttonSize)) {
		g_duplicateIndex = index;
	}
	UI::SameLine();

	string reorderHint = CanReorder() ? "" : "\n\\$888Only in manual order, without filters";
	int above = NeighbourInGroup(index, -1);
	UI::BeginDisabled(!CanReorder() || above < 0);
	if (DarkButton(Icons::ChevronUp, "Move up" + reorderHint, buttonSize)) {
		g_moveFrom = index;
		g_moveTo = above;
	}
	UI::EndDisabled();
	UI::SameLine();
	int below = NeighbourInGroup(index, 1);
	UI::BeginDisabled(!CanReorder() || below < 0);
	if (DarkButton(Icons::ChevronDown, "Move down" + reorderHint, buttonSize)) {
		g_moveFrom = index;
		g_moveTo = below;
	}
	UI::EndDisabled();
	UI::SameLine();

	// Delete needs a second click so a misclick can't throw a snippet away
	bool armed = g_armedDelete == index;
	bool deleteClicked = armed
		? ColoredButton(Icons::Trash, HUE_RED, "Click again to delete", buttonSize)
		: DarkButton(Icons::Trash, "Delete", buttonSize);
	if (deleteClicked) {
		if (armed) {
			g_deleteIndex = index;
		} else {
			g_armedDelete = index;
		}
	}
}

void ApplyListChanges()
{
	if (g_moveFrom >= 0) {
		// Swap the two snippets; anything between them belongs to other groups and stays put
		auto moved = g_snippets[g_moveFrom];
		@g_snippets[g_moveFrom] = g_snippets[g_moveTo];
		@g_snippets[g_moveTo] = moved;
		g_armedDelete = -1;
		// Keep the editor on the same snippet
		if (g_editIndex == g_moveFrom) {
			g_editIndex = g_moveTo;
		} else if (g_editIndex == g_moveTo) {
			g_editIndex = g_moveFrom;
		}
		SaveSnippets();
	}
	if (g_duplicateIndex >= 0) {
		auto original = g_snippets[g_duplicateIndex];
		Snippet@ copy = Snippet(UniqueName(original.name + " copy"), original.text, original.group);
		copy.favorite = original.favorite;
		// Two snippets can't share a hotkey
		g_snippets.InsertAt(g_duplicateIndex + 1, copy);
		if (g_editIndex > g_duplicateIndex) {
			g_editIndex++;
		}
		SaveSnippets();
	}
	if (g_deleteIndex >= 0) {
		@g_deleted = g_snippets[g_deleteIndex];
		g_deletedIndex = g_deleteIndex;
		g_deletedTime = Time::Now;
		g_snippets.RemoveAt(g_deleteIndex);
		g_armedDelete = -1;
		if (g_editIndex == g_deleteIndex) {
			g_editorOpen = false;
			g_editIndex = -1;
		} else if (g_editIndex > g_deleteIndex) {
			g_editIndex--;
		}
		SaveSnippets();
	}
}

// "Gears copy", then "Gears copy 2", "Gears copy 3"...
string UniqueName(const string &in name)
{
	string result = name;
	for (int n = 2; FindSnippet(result) !is null; n++) {
		result = name + " " + n;
	}
	return result;
}
