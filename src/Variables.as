// Placeholders that are filled in when a snippet is sent or copied, e.g. "Nice map, {author}!"

const array<string> VARIABLES = { "{map}", "{author}", "{player}", "{server}", "{time}" };
const array<string> VARIABLE_HELP = {
	"Name of the current map",
	"Nickname of the map's author",
	"Your own name",
	"Name of the server",
	"Current time, e.g. 21:45"
};

string ExpandVariables(const string &in text)
{
	// Most snippets don't use variables; skip the lookups for those
	if (!text.Contains("{")) {
		return text;
	}

	string result = text;
	auto app = GetApp();
	auto map = app.RootMap;

	// Map and server names have their own colors; $< $> keeps those from leaking into the rest
	if (result.Contains("{map}")) {
		result = result.Replace("{map}", map is null ? "" : "$<" + string(map.MapName) + "$>");
	}
	if (result.Contains("{author}")) {
		result = result.Replace("{author}", map is null ? "" : "$<" + string(map.AuthorNickName) + "$>");
	}
	if (result.Contains("{player}")) {
		auto player = app.LocalPlayerInfo;
		result = result.Replace("{player}", player is null ? "" : string(player.Name));
	}
	if (result.Contains("{server}")) {
		auto server = cast<CGameCtnNetServerInfo>(app.Network.ServerInfo);
		result = result.Replace("{server}", server is null ? "" : "$<" + string(server.ServerName) + "$>");
	}
	if (result.Contains("{time}")) {
		result = result.Replace("{time}", Time::FormatString("%H:%M"));
	}
	return result;
}
