# Mak'gora (Duel to the Death)

Adds a **"Challenge to Mak'gora"** entry to the right-click unit menu of
players. Choosing it sends the `.makgora challenge <name>` SAY message, which
the server core turns into a duel-to-the-death challenge.

## Supported clients

| Client line                 | Interface |
|-----------------------------|-----------|
| Vanilla / Classic WoW 1.12.1 | 11200    |
| Classic WoW 1.14.2 (build 42597) | 11402 |

The `.toc` lists both (`## Interface: 11200,11402`), so a single addon folder
works on either client — no separate builds needed.

## Installation

Copy the whole `Makgora` folder into the game's `Interface/AddOns` directory:

```
<World of Warcraft>/Interface/AddOns/Makgora/
├── Makgora.toc
├── Makgora.lua
└── README.md
```

Log in (or run `/reload`) and right-click any player:
**Chat / Inspect / Duel / Challenge to Mak'gora**.

## How it works

* Registers a `MAKGORA` entry in `UnitPopupButtons` and injects it directly
  after `DUEL` in the `PLAYER`, `FRIEND`, `PARTY` and `RAID_PLAYER` unit
  popup menus.
* Hooks `UnitPopup_OnClick`; when the `MAKGORA` entry is picked it sends
  `.makgora challenge <name>` on the SAY channel.
