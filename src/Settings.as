enum SortMode
{
	Manual,
	MostUsed,
	Name
}

[Setting category="General" name="Show window without overlay" description="Keep the clipboard window visible while playing, without opening the Openplanet overlay (F3)."]
bool S_ShowWithoutOverlay = true;

[Setting category="General" name="Toggle window key" description="Key that opens and closes the clipboard window. Set to None to turn it off. It does nothing while you're typing."]
VirtualKey S_ToggleKey = VirtualKey::None;

[Setting category="General" name="Wait after sending (ms)" description="How long the send buttons stay disabled after a message, so a double click doesn't send it twice." min=500 max=5000]
int S_SendCooldown = 1500;

[Setting category="General" name="Message when copying" description="Show a line in Better Chat when a snippet is copied to the clipboard."]
bool S_CopyNotification = true;

[Setting category="General" name="Pause between lines (ms)" description="For snippets that send each line as a separate message: the wait between those messages. Too short can look like spam to servers." min=1000 max=5000]
int S_LineDelay = 1500;

[Setting category="General" name="Snippet hotkeys" description="Send a snippet with the hotkey set in its editor. Hotkeys do nothing while you're typing."]
bool S_Hotkeys = true;

[Setting category="Quick bar" name="Show quick bar" description="A small bar with your favorite snippets, to send them with one click while playing."]
bool S_QuickBar = true;

[Setting category="Quick bar" name="Show without overlay" description="Keep the quick bar visible while playing. It can only be moved while the overlay is shown."]
bool S_QuickBarWithoutOverlay = true;

[Setting category="Quick bar" name="Icons only" description="Show only the icon on buttons of snippets that have one; the name is in the tooltip."]
bool S_QuickBarIconsOnly = false;

[Setting category="Quick bar" name="Vertical" description="Stack the buttons instead of putting them side by side."]
bool S_QuickBarVertical = false;

[Setting category="Quick bar" name="Background opacity" min=0 max=1]
float S_QuickBarOpacity = 0.6f;

[Setting category="Better Chat" name="Command prefix" description="Start of every snippet command, e.g. 'clip-' gives /clip-gears. Letters, digits, - and _ only; it can't be empty, so commands never replace Better Chat's own."]
string S_CommandPrefix = "clip-";

[Setting category="Better Chat" name="Chat command per snippet" description="Register a command like /clip-gears for every snippet, so snippets show up in Better Chat's command suggestions."]
bool S_SnippetCommands = true;

[Setting category="Better Chat" name="Button in Better Chat" description="Add a clipboard button below the buttons on the left of the Better Chat window (visible while the overlay is shown)."]
bool S_BetterChatButton = true;

[Setting hidden]
bool S_WindowOpen = false;

[Setting hidden]
bool S_EditMode = false;

[Setting hidden]
bool S_CompactView = false;

[Setting hidden]
SortMode S_SortMode = SortMode::Manual;
