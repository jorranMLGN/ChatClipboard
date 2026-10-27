# Chat Clipboard

An [Openplanet](https://openplanet.dev/) plugin for Trackmania 2020 that keeps the chat messages you send often (greetings, tips you keep explaining, links) and sends them with one click, a hotkey or a chat command.

Requires [Better Chat](https://openplanet.dev/plugin/betterchat).

## Sending snippets

- **Quick bar**: a small bar with your favorite snippets, visible while you play. Click a button to send, right click to send to your team. Move it while the overlay (F3) is open.
- **Hotkeys**: give a snippet a key in its editor (F5 for "GG", for example). Hotkeys do nothing while you're typing.
- **Chat commands**: every snippet gets a command like `/clip-gg` or `/clip-action-keys`. Type `/` and part of the name to find it in Better Chat's suggestions, with a preview. `/clipboard <name>` works too, and `/clipboard` opens the window.
- **The clipboard window**: send, copy or edit any snippet. Open it with the button in Better Chat, the Openplanet menu (**Plugins → Chat Clipboard**), `/clipboard` or the toggle key from the settings.

Sending waits 1.5 seconds between messages, so a double click can't send twice, and only works on a server.

## Organizing

- **Groups** list snippets under collapsible headings, e.g. "Tips" and "Chat".
- **Favorites** (the star) go in the quick bar. The star in the toolbar shows only favorites.
- **Sorting**: manual order, most used first, or by name. Each snippet shows how often it was sent.
- **Compact view** shows only the names; hover a name to see the text.
- **Edit mode** adds buttons to duplicate, reorder and delete. Deleting asks for a second click, and can be undone for 10 seconds.
- The filter box searches names, groups and text.

## Editor

Trackmania chat uses format codes such as `$f00` (red), `$o` (bold) and `$l` (link). The editor writes them for you:

- Select text and click a color, style or **Link** to format just that part. It is wrapped in `$<...$>` so the rest of the text keeps its own formatting. Without a selection, the code is inserted at the cursor.
- Pick any color with the color picker and click **Use**.
- **Gradient** fades the selected text from one color to another, letter by letter.
- **Insert** adds a variable that is filled in when the snippet is sent: `{map}`, `{author}`, `{player}`, `{server}` or `{time}`.
- **Clear formatting** removes all codes from the selection (or the whole text); **Undo** reverts the last toolbar change.

The preview shows the message as it will look in chat, with variables filled in. The counter shows the length including codes; Better Chat cuts messages off after 2000 characters, so longer snippets can't be saved. Press **Ctrl+Enter** to save and **Escape** to cancel.

## Settings

Under **Settings → Chat Clipboard**:

- **General**: show the window without the overlay, a key to toggle the window, turn snippet hotkeys on or off.
- **Quick bar**: show it, show it without the overlay, vertical layout, background opacity.
- **Better Chat**: the `/clip-` commands and the button in Better Chat's sidebar.

## Storage

Snippets are saved to `OpenplanetNext/PluginStorage/ChatClipboard/chat_clipboard.json`. In edit mode, the folder button opens that folder. Files from older versions are converted automatically. If the file can't be read, a copy is kept as `chat_clipboard.json.bak` before the defaults are loaded.

## Development

```
src/
  Main.as              entry points, /clipboard command, sending and copying
  Settings.as          plugin settings
  Snippets.as          snippet model, loading and saving
  Variables.as         {map}, {author}... placeholders
  Hotkeys.as           snippet hotkeys, toggle key, picking a key in the editor
  Style.as             shared button and preview styles
  Interface.as         clipboard window
  Editor.as            snippet editor with formatting toolbar
  QuickBar.as          the favorites bar
  SnippetCommands.as   a /clip-<name> chat command per snippet
  BetterChatButton.as  button in Better Chat's sidebar (or top right of the chat if the sidebar is full)
```

Better Chat has no API for extra buttons. `BetterChatButton.as` calls `UI::Begin()` with Better Chat's window title, which makes ImGui append to that window. This relies on Better Chat rendering before this plugin, and on its sidebar layout (6 buttons, 5 in big chat); check it after Better Chat updates. It can be turned off in the settings.

Run `./build.ps1` to create `dist/ChatClipboard.op`, or `./build.ps1 -Install` to also copy it to your Openplanet plugins folder. Unsigned plugins only load with Openplanet's signature mode set to **Developer**.

## License

[MIT](LICENSE)
