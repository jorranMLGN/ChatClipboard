# Chat Clipboard: notes for AI assistants

Openplanet plugin (AngelScript) for Trackmania 2020. Depends on Better Chat. See README.md for features and file layout.

## Facts that are easy to get wrong

- Openplanet compiles every `.as` file in the plugin folder; there is no include/import step.
- Trackmania chat uses `$f00`-style format codes. Openplanet UI text uses `\$f00` instead, so convert with `Text::OpenplanetFormatCodes()` before drawing snippet text. Don't write a custom color parser.
- Better Chat's `ICommand::Run(text)` receives the whole input line, including `/clipboard`.
- `Render()` draws even when the overlay is hidden; `RenderInterface()` only draws when it is shown. This plugin uses `Render()` plus the `S_ShowWithoutOverlay` setting.
- Don't add or remove items in `g_snippets` while looping over it to draw; collect the change and apply it after the loop.
- Call `SaveSnippets()` after every change. There is no separate save button. It also rebuilds the `/clip-<name>` commands, because Better Chat reads a command's description only once.
- The editor's toolbar works on the selection remembered by `EditorTextCallback`, and only changes `g_editText` while the text box is inactive (clicking a button deactivates it). ImGui ignores changes to the string while the box is active.
- Combining enum flags with `|` gives an `int`; wrap it (`UI::InputTextFlags(...)`) where a function takes the enum type.
- The storage format is `{"snippets":[{"name", "text", "group", "favorite", "hotkey", "uses"}]}`. Fields with default values are left out, and every field but `name` and `text` is optional when loading. Keep reading the old `color` field for 1.0 files.
- `SaveSnippets()` writes the file and rebuilds the chat commands; `WriteSnippets()` only writes the file, for changes that don't affect names or texts (favorite, uses).
- Keys go through `HandleKeyPress` in `Hotkeys.as`. Check `UI::WantCaptureKeyboard()` before acting on a key, so typing never triggers anything.
- `BetterChatButton.as` appends to Better Chat's window by calling `UI::Begin("Better Chat")` again. It depends on Better Chat's window title and sidebar button count; update both if Better Chat changes.
- Check API names against `OpenplanetNext/OpenplanetCore.json` and Better Chat's `src/Export.as`/`src/ExportShared.as` rather than guessing.

## Style

Tabs, braces on their own line for functions and classes, `S_` prefix for settings, `g_` for globals. Matches Better Chat.
