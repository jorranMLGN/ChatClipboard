# Openplanet submission

Texts and checklist for submitting Chat Clipboard at https://openplanet.dev/plugins/admin/new.
This file is not part of the plugin build.

## Name

Chat Clipboard

## Short description

Save the chat messages you send often and send them with one click, a hotkey or a chat command.

## Plugin page description

> Requires [Better Chat](https://openplanet.dev/plugin/betterchat).

Chat Clipboard keeps the messages you type again and again (greetings, tips you keep explaining, links) and sends them for you.

**Send a snippet**
- **Quick bar**: your favorite snippets as buttons, visible while you play. Right click a button to send to your team.
- **Hotkeys**: give a snippet its own key, like F5 for "GG". Hotkeys never fire while you're typing.
- **Chat commands**: every snippet gets a command such as `/clip-gg`, shown in Better Chat's command suggestions with a preview.
- **Clipboard window**: open it from the button in Better Chat, the Plugins menu or `/clipboard`.

**Write it once, nicely**
- Select text and click a color or style; the editor writes the format codes for you.
- Color picker and letter-by-letter **gradients**.
- **Variables** filled in when you send: `{map}`, `{author}`, `{player}`, `{server}`, `{time}`.
- Live preview, and a length counter so messages don't get cut off.

**Keep it tidy**
- Groups, favorites, sorting by most used or by name, compact view and a filter.
- Duplicate, reorder and delete in edit mode, with undo for deletes.

A short cooldown stops a double click from sending the same message twice.

## AI disclosure

Openplanet's plugin terms ask you to disclose AI use during review and in the AI classification settings, and plugins that are mostly AI generated may be refused. Edit this text so it matches what you did:

> The code of this plugin was written with Claude Code, Anthropic's AI coding agent (model: Claude Opus 5.5), under my direction. I decided on the features and design, reviewed all of the code and tested it in game.

## Checklist (Nederlands)

- [ ] Plugin getest in de game: snelbalk, sneltoetsen, `/clip-` commando's, editor (kleuren, gradient, variabelen), knop in Better Chat.
- [ ] `info.toml`: naam, auteur en versie kloppen. Geen `siteid` invullen; dat doet Openplanet na goedkeuring.
- [ ] Bouwen met `./build.ps1` en `dist/ChatClipboard.op` uploaden. Dat bestand bevat alleen `info.toml` en `src/`.
- [ ] Screenshots maken van het venster, de editor en de snelbalk. Geen AI-gemaakte thumbnail gebruiken; die zijn niet toegestaan.
- [ ] AI-gebruik opgeven in het inzendformulier en bij de AI-classificatie op de site.
- [ ] Optioneel: broncode op GitHub zetten en de link toevoegen.
- [ ] Na goedkeuring de `siteid` van de pluginpagina in `info.toml` zetten, zodat updates via de plugin manager werken.
