# Hardcore Badge — client addon

Renames the server's permanent **Hardcore indicator buff** so that it no longer
reads **"Death Touch"** (with the skull-and-crossbones GM icon) on the buff
frame and in its tooltip. With the addon installed the badge shows as
**Hardcore** with a matching icon and a tooltip that explains what the flag
means:

> **Hardcore**
> You have chosen the Hardcore path.
> One life only: if you die, you stay dead.
> This badge is permanent and cannot be removed.
> /hardcore - status, /hardcore help - options

## Why an addon, and not a server-side fix

The server marks a Hardcore character with a permanent, effect-less aura whose
spell id is `SPELL_PLAYER_HARDCORE_INDICATOR = 5`
(`src/game/Objects/Player.h`, applied by `Player::UpdateHardcoreIndicator()`).

That id is not arbitrary, and it is also the reason the buff is called
"Death Touch":

* The spell id has to exist in the **client's own** `Spell.dbc`, otherwise the
  client silently drops the aura from the buff frame (this is why the earlier
  custom spell id 65001 never rendered on 1.12.1 clients).
* `spell_template` entry 5 in this core is therefore a copy of Blizzard's
  unused GM test spell *"Death Touch"* (`spellIconId 1324`, instakill effect
  removed, `customFlags 4` so it lands in the buff row instead of the debuff
  row, permanent duration).
* An aura packet carries only the spell id, the flags, the caster level and the
  duration. **Name, rank, icon and description always come from the client's
  Spell.dbc** — there is no spell-query opcode the server could answer, so no
  `spell_template` edit can rename what 1.12.1 / 1.14 clients display. (The
  migrations `20260927120000`/`20260927130000` keep the server-side row
  self-documenting, but only the client build decides the label.)

Consequently the relabeling has to happen where the label is produced: in the
client UI. That is what this addon does — it is cosmetic only. Everything that
matters gameplay wise (the aura itself, its permanence, the `.hardcore`
command) is server-side and works with no addon installed.

## Two client builds — pick the one matching your game client

The 1.12.1 and 1.14.2 UIs are not source compatible (Lua 5.0 `this` handlers
and `GetPlayerBuff*` vs. Lua 5.1, `self`, `UnitAura`, `hooksecurefunc` and the
taint system), so the addon ships as two separate, client-specific builds that
do exactly the same thing:

| Client                              | Folder to install                  | TOC `## Interface` |
|-------------------------------------|------------------------------------|--------------------|
| Vanilla WoW **1.12.1** (build 5875) | `addons/Hardcore/1.12.1/Hardcore/` | `11200`            |
| Classic Era **1.14.2** (build 42597)| `addons/Hardcore/1.14.2/Hardcore/` | `11402`            |

Do not mix them: the 1.12.1 file will error on 1.14 and vice versa.

## Installation

Copy the **inner** `Hardcore` folder of the matching build into the game's
`Interface/AddOns` directory, so that you end up with:

```
<World of Warcraft>/Interface/AddOns/Hardcore/
├── Hardcore.toc
└── Hardcore.lua
```

Log in (or `/reload`). On a Hardcore character the chat shows once:
`[Hardcore] badge active - shown as "Hardcore" instead of the client's own
spell 5 name (/hardcore help)`.

## Usage

* `/hardcore` (or `/hardcore status`) — sends `.hardcore status` to the server
  (the core intercepts the dot-command, it is never broadcast as chat) and
  reports whether the badge aura was found in your buff list.
* `/hardcore on` / `/hardcore off` — enable or disable the relabeling. With
  `off` the buff shows the client's own name and icon again.
* `/hardcore name <text>` — badge title shown in the tooltip (default
  `Hardcore`). Per character, saved between sessions.
* `/hardcore icon <skull|scream|soulgem|auto|Interface\Icons\...>` — badge
  icon. `auto` keeps whatever icon the client draws for the aura.
* `/hardcore match <name or texture>` — extra key used to recognize the badge
  (see Troubleshooting).
* `/hardcore reset` — restore the defaults.
* `/hardcore debug` — client build, addon version, resolved indicator spell
  name and a dump of every buff with its spell id, texture and duration.
* `/hardcore help` — command list.

## Server requirements

* This core with the Hardcore system (`.hardcore` command table; `status` and
  `ssf` are `SEC_PLAYER`).
* `PlayerCommands = 1` in `mangosd.conf` (default) so that players may use
  dot-commands from chat.
* `spell_template` entry 5 shaped as the indicator aura and made non-cancelable:
  migrations `20260926130000_world.sql` (permanent dummy aura, `customFlags 4`
  = `SPELL_CUSTOM_POSITIVE`, so the client puts it in the buff row),
  `20260927130000_world.sql` (`SPELL_ATTR_NO_AURA_CANCEL`, and `spellIconId`
  back to the value the client's Spell.dbc actually has, 1324) and
  `20260926130001_characters.sql` (purge of the retired custom spell 65001).

## How it works (per build)

Both builds identify the badge and then dress the button: swap the icon
texture, hide Blizzard's stack count and duration text, and replace the
tooltip. Recognition is locale independent in the normal case — the spell id on
1.14, the icon texture the client draws for spell 5 on 1.12 — with the
localized DBC name and any `/hardcore match` key as fallbacks for patched or
exotic clients.

**1.12.1** (`1.12.1/Hardcore/Hardcore.lua`, Lua 5.0 / vanilla UI)

* The vanilla UI does not expose a buff's spell id (`GetPlayerBuff` returns
  only an internal buff index), so the badge is recognized by the **icon
  texture** the client draws for spell 5
  (`Interface\Icons\INV_Misc_Bone_HumanSkull_01`) — textures are locale
  independent — preferring a *permanent* match (`GetPlayerBuffTimeLeft < 0`,
  which is what the server badge always is).
* Fallback for clients that re-iconed spell 5: the **localized name** read from
  a hidden scanning tooltip (`GameTooltip:SetPlayerBuff`), matched against the
  known translations of "Death Touch" (en/de/fr/es/ru) plus any
  `/hardcore match` keys. Only permanent auras are inspected, so this costs a
  handful of tooltip lookups at most. A name match also *learns* the texture,
  so later scans stay on the cheap path.
* Icon: wraps the global `BuffButton_Update()` and re-dresses the button whose
  `this.buffIndex` is the badge.
* Tooltip: the vanilla `BuffButtonTemplate` builds its tooltip inline in XML
  (`OnEnter`), so the `OnEnter` handlers of `BuffButton0..31` are replaced with
  one that shows the badge tooltip for the badge and Blizzard's own two lines
  (`SetOwner` + `SetPlayerBuff`) for everything else. `BuffButton_OnUpdate()`
  is wrapped so Blizzard's per-frame tooltip refresh does not overwrite it.
* `/hardcore` sends `.hardcore status` synchronously from the slash command.

**1.14.2** (`1.14.2/Hardcore/Hardcore.lua`, Lua 5.1 / Classic Era UI)

* Recognition is exact: `UnitAura()` returns the spell id (10th value), so the
  badge is `spellId == 5`. Fallbacks: the name `GetSpellInfo(5)` gives on this
  client, then texture + permanent-duration for exotic clients.
* Nothing from Blizzard is replaced (that would taint the buff frame):
  `hooksecurefunc` post-hooks on `AuraButton_Update` (dress the button after
  Blizzard drew it), on `BuffFrame_Update` (repaint) and on
  `GameTooltip:SetUnitAura` (rewrite the tooltip lines — covers both the
  button's `OnEnter` and Classic Era's periodic refresh in
  `AuraButton_OnUpdate`).
* `SendChatMessage(..., "SAY")` requires a hardware event on this client, so
  the `.hardcore status` query is only ever sent from inside the slash command.

## Troubleshooting

* *The buff still says "Death Touch"* — the addon for your client is not
  installed/enabled, or you installed the other build (check `/hardcore
  debug`, it prints the client build the addon expects). Third-party buff
  frames (pfUI, VCB, Elkano's, ...) replace Blizzard's buff buttons; this addon
  only dresses Blizzard's own `BuffButton`s. With such an addon the badge still
  works, it just keeps the client's label there.
* *`/hardcore debug` says "buff index NOT FOUND" on a Hardcore character* —
  your client draws spell 5 with a different icon and name. Read the buff dump
  from `/hardcore debug`, pick the badge line and add its name or texture with
  `/hardcore match <name or texture>`; the addon then recognizes it (and learns
  its texture automatically on the next login).
* *`/hardcore` prints nothing from the server* — `PlayerCommands = 1` must be
  set in `mangosd.conf`, and typing `.hardcore status` in /say must work.
* *You want the vanilla label back* — `/hardcore off`, or `/hardcore icon auto`
  to keep only the rename.
