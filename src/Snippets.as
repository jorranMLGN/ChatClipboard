class Snippet
{
	string name;
	// Chat text including Trackmania format codes, e.g. "$0f0Good game!"
	string text;
	// Heading the snippet is listed under; "" for none
	string group;
	// Favorites are listed first and show up in the quick bar
	bool favorite = false;
	// Key that sends this snippet; VirtualKey::None for none
	VirtualKey hotkey = VirtualKey::None;
	// How often the snippet was sent, for sorting by most used
	int uses = 0;

	Snippet(const string &in name, const string &in text, const string &in group = "")
	{
		this.name = name;
		this.text = text;
		this.group = group;
	}
}

array<Snippet@> g_snippets;

Snippet@ FindSnippet(const string &in name)
{
	string needle = name.ToLower();
	for (uint i = 0; i < g_snippets.Length; i++) {
		if (g_snippets[i].name.ToLower() == needle) {
			return g_snippets[i];
		}
	}
	return null;
}

string StoragePath()
{
	return IO::FromStorageFolder("chat_clipboard.json");
}

void LoadSnippets()
{
	g_snippets.RemoveRange(0, g_snippets.Length);

	string path = StoragePath();
	if (!IO::FileExists(path)) {
		AddDefaultSnippets();
		SaveSnippets();
		return;
	}

	try {
		auto root = Json::FromFile(path);
		auto list = root["snippets"];
		for (uint i = 0; i < list.Length; i++) {
			g_snippets.InsertLast(SnippetFromJson(list[i]));
		}
	} catch {
		// Keep a copy of the unreadable file so saving doesn't destroy the user's snippets
		error("Could not read " + path + ": " + getExceptionInfo());
		IO::File src(path, IO::FileMode::Read);
		string contents = src.ReadToEnd();
		src.Close();
		IO::File backup(path + ".bak", IO::FileMode::Write);
		backup.Write(contents);
		backup.Close();

		g_snippets.RemoveRange(0, g_snippets.Length);
		AddDefaultSnippets();
	}
}

// Fields added after version 1.0 are optional, so older files still load
Snippet@ SnippetFromJson(Json::Value@ obj)
{
	string name = obj["name"];
	string text = obj["text"];
	// Version 1.0 stored the color separately from the text
	if (obj.HasKey("color")) {
		string color = obj["color"];
		text = color + text;
	}

	Snippet@ snippet = Snippet(name, text);
	if (obj.HasKey("group")) {
		string group = obj["group"];
		snippet.group = group;
	}
	if (obj.HasKey("favorite")) {
		bool favorite = obj["favorite"];
		snippet.favorite = favorite;
	}
	if (obj.HasKey("hotkey")) {
		int hotkey = obj["hotkey"];
		snippet.hotkey = VirtualKey(hotkey);
	}
	if (obj.HasKey("uses")) {
		int uses = obj["uses"];
		snippet.uses = uses;
	}
	return snippet;
}

Json::Value@ SnippetToJson(Snippet@ snippet)
{
	auto obj = Json::Object();
	obj["name"] = snippet.name;
	obj["text"] = snippet.text;
	// Defaults are left out to keep the file readable
	if (snippet.group != "") {
		obj["group"] = snippet.group;
	}
	if (snippet.favorite) {
		obj["favorite"] = true;
	}
	if (snippet.hotkey != VirtualKey::None) {
		obj["hotkey"] = int(snippet.hotkey);
	}
	if (snippet.uses > 0) {
		obj["uses"] = snippet.uses;
	}
	return obj;
}

// Writes the file only; use SaveSnippets when names or texts changed
void WriteSnippets()
{
	auto list = Json::Array();
	for (uint i = 0; i < g_snippets.Length; i++) {
		list.Add(SnippetToJson(g_snippets[i]));
	}

	auto root = Json::Object();
	root["snippets"] = list;
	try {
		Json::ToFile(StoragePath(), root);
	} catch {
		error("Could not save snippets: " + getExceptionInfo());
		UI::ShowNotification("Chat Clipboard", "Could not save your snippets: " + getExceptionInfo(), vec4(0.6f, 0.1f, 0.1f, 1.0f), 10000);
	}
}

void SaveSnippets()
{
	WriteSnippets();
	// Every change to the list ends up here, so this keeps the chat commands up to date
	RegisterSnippetCommands();
}

void AddDefaultSnippets()
{
	g_snippets.InsertLast(Snippet("GG", "$ff0Good game!", "Chat"));
	g_snippets.InsertLast(Snippet("GL HF", "$0f0Good luck, have fun!", "Chat"));
	g_snippets.InsertLast(Snippet("Nice map", "$0ffNice map, {author}!", "Chat"));
	g_snippets.InsertLast(Snippet("Openplanet", "$0ffInstall Openplanet for plugins: $lwww.openplanet.dev", "Links"));
	g_snippets.InsertLast(Snippet("Trackmania.io", "$0ffStats and leaderboards: $lwww.trackmania.io", "Links"));
	g_snippets[0].favorite = true;
	g_snippets[1].favorite = true;
}
