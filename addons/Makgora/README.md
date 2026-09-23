# Mak'gora (Duel to the Death) — client addon

Adds a **"Challenge to Mak'gora"** entry directly below **"Duel"** in the
right-click menu of players (target frame, party frames — and raid frames on
1.14). Choosing it sends the server command `.makgora challenge <name>` on the
SAY channel; the server intercepts the dot-command (it is never broadcast as
chat) and immediately sends the target a **regular duel request**. The duel is
flagged as Mak'gora: it plays exactly like a normal duel, but the loser really
dies. For Hardcore characters that death is permanent.

## Two client builds — pick the one matching your game client

The 1.12.1 and 1.14.2 UIs are not source compatible (Lua 5.0 `this` handlers
and frame *names* in `UIDROPDOWNMENU_INIT_MENU` vs. Lua 5.1, `self`, frame
*objects*, `hooksecurefunc` and the taint system), so the addon ships as two
separate, client-specific builds that do exactly the same thing:

| Client                                   | Folder to install                     | TOC `## Interface` |
|------------------------------------------|---------------------------------------|--------------------|
| Vanilla WoW **1.12.1** (build 5875)       | `addons/Makgora/1.12.1/Makgora/`      | `11200`            |
| Classic Era **1.14.2** (build 42597)      | `addons/Makgora/1.14.2/Makgora/`      | `11402`            |

Do not mix them: the 1.12.1 file will error on 1.14 and vice versa.

## Installation

Copy the **inner** `Makgora` folder of the matching build into the game's
`Interface/AddOns` directory, so that you end up with:

```
<World of Warcraft>/Interface/AddOns/Makgora/
├── Makgora.toc
└── Makgora.lua
```

Log in (or `/reload`). The chat shows `[Mak'gora] v2.0 loaded (...)`.
Right-click any friendly player or bot:
**Whisper / Inspect / Trade / Follow / Duel / Challenge to Mak'gora**.

## Usage

* **Right-click menu → Challenge to Mak'gora** — challenges that player/bot.
  The target instantly receives the normal duel request popup (the flag is
  planted and the 3-second countdown runs like any duel). Bots answer on their
  own; real players click *Accept* or *Decline* on the popup.
* `/makgora` (or `/mak`) — challenge your current target.
* `/makgora <name>` — challenge a player by name.
* `/makgora accept` / `/makgora decline` — answer a pending challenge by
  command (the duel popup does the same thing).
* `/makgora status` — your Mak'gora record.
* `/makgora help` — command list.

The entry is hidden for yourself, NPCs and hostile players, and is greyed out
when the target is out of duel range (same rules as the Duel button). The
server additionally enforces: both alive, not in combat, not already dueling,
within 30 yards, dueling allowed in the area.

## Server requirements

* This core with the Mak'gora system (`.makgora` command table, `SEC_PLAYER`).
* `PlayerCommands = 1` in `mangosd.conf` (default) so that players may use
  dot-commands from chat.

## How it works (per build)

**1.12.1** (`1.12.1/Makgora/Makgora.lua`)
* Registers `UnitPopupButtons["MAKGORA"] = { text = ..., dist = 3 }` and
  inserts `"MAKGORA"` right after `"DUEL"` in `UnitPopupMenus["PLAYER"]` and
  `["PARTY"]`.
* Wraps `UnitPopup_HideButtons` to hide the entry for non-cooperative units
  (Blizzard's function only knows its own keys).
* Wraps `UnitPopup_OnClick`: reads the clicked entry from `this.value` and the
  owning dropdown via `getglobal(UIDROPDOWNMENU_INIT_MENU)` (a frame *name* on
  1.12), sends the command and otherwise chains to the original handler.

**1.14.2** (`1.14.2/Makgora/Makgora.lua`)
* Same menu registration for `PLAYER`, `PARTY` and `RAID_PLAYER`.
* Never replaces Blizzard functions (protected actions such as Follow/Target in
  the same menu would become tainted): uses `hooksecurefunc` post-hooks on
  `UnitPopup_HideButtons` (visibility) and `UnitPopup_OnClick` (the original
  simply falls through for the unknown value, then the hook sends the command).
  `UIDROPDOWNMENU_INIT_MENU` is the dropdown frame object here.
* `SendChatMessage(..., "SAY")` requires a hardware event on this client; the
  send happens synchronously inside the click / slash command, never from a
  timer.

## Troubleshooting

* *Nothing happens when clicking the entry* — make sure you installed the
  build for your client (see the load message in chat) and that
  `PlayerCommands = 1` on the server. Typing `.makgora challenge <name>` in
  /say must work; if it does, the addon path works too.
* *"Mak'gora duels are not permitted in this area"* — same restriction as
  normal duels (no capital cities / instances).
* *A bot declines* — bots refuse below `AiPlayerbot.BotAcceptDuelMinimumLevel`
  or when their health is under `AiPlayerbot.BotAcceptMakgoraMinimumHealth`
  (default 50%, 0 = always accept). The bot says why.
