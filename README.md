# SkyObby

A complete, playable Roblox obby that is **built entirely from code** — no parts placed by hand. Clone it, sync it into Roblox Studio, press Play.

Ten stages, checkpoints that survive respawns, coins, a hazard on every stage, a small upgrade shop, and DataStore saving so players keep their stage and coins between sessions.

---

## What's inside

```
default.project.json      Rojo project file (maps folders to Roblox services)
src/
  shared/Config.lua       All tuning: stage count, prices, colours
  server/Main.server.lua  Builds the course, runs checkpoints/coins/shop/saving
  client/Main.client.lua  HUD: stage + coin counters, shop panel, toasts
```

| Stage | Obstacle |
| --- | --- |
| 1, 5, 9 | Rotating red bar sweeping the platform |
| 2, 6, 10 | Sliding platform across the gap |
| 3, 7 | Three stepping pillars |
| 4, 8 | Hazard blocks to weave around |

Every stage has a green checkpoint pad and three floating coins. Fall off and you respawn at your last checkpoint.

---

## Run it (pick one)

### Option A — Rojo (recommended, keeps the repo as the source of truth)

1. Install [Roblox Studio](https://create.roblox.com/start) (free) and [Rojo](https://rojo.space) (`aftman install`, or download the binary).
2. In a terminal, from this folder:
   ```
   rojo serve
   ```
3. In Studio: open a new **Baseplate** place → install the Rojo plugin → **Connect**.
4. Press **Play**. The course builds itself in front of the lobby.

Changes you make in Studio to files under `src/` sync both ways, so you can commit from Studio back into Git.

### Option B — Build a place file and open it

```
rojo build -o SkyObby.rbxlx
```

Double-click the `.rbxlx` to open it in Studio.

### Option C — No tools at all (manual paste)

1. Open Studio → new Baseplate.
2. In **Explorer**, insert a `Folder` into `ReplicatedStorage` and name it `Shared`.
3. Insert a `ModuleScript` into `Shared`, name it `Config`, paste `src/shared/Config.lua`.
4. Insert a `Script` into `ServerScriptService`, paste `src/server/Main.server.lua`.
5. Insert a `LocalScript` into `StarterPlayer > StarterPlayerScripts`, paste `src/client/Main.client.lua`.
6. Press Play.

Delete the default baseplate part if you like — the game makes its own floor.

---

## Publish it (so other people can play)

1. **File → Publish to Roblox As…** in Studio, create a new experience.
2. Fill in the name, description, icon and thumbnail in the Creator Hub.
3. Set the game to **Public** and pick your audience tier (see costs below).
4. Share the link. Done — Roblox hosts the servers for free.

## Costs

- **Building and publishing: free.** Studio, the Luau language, and server hosting cost nothing, at any scale.
- **Releasing to everyone (all ages):** Roblox asks for one of — 2 consecutive months of Roblox Plus/Premium, **or** a one-time **refundable 1,000 Robux** publishing fee. Releasing only to 16+ / Trusted Friends is free. The 1,000 Robux fee is refunded if the game keeps 25 highly engaged players for 60 days.
- **Earning money:** optional. Game passes and developer products pay you 70% of the Robux spent. Cashing out (DevEx) needs at least **30,000 earned Robux**, a verified email, and you must be 13+; the rate is about $0.0038 per Robux (~$114 per 30,000).

So: nothing to pay to make and ship this. Money only appears if you decide to monetise, and only after you have players.

---

## Easy things to change

All in `src/shared/Config.lua`:

| Setting | Effect |
| --- | --- |
| `Course.StageCount` | More or fewer stages |
| `Course.StageSpacing` | How far apart platforms are (bigger = harder jumps) |
| `Course.HeightStep` | How much the course climbs |
| `Economy.CoinsPerPickup` | Coins per pickup |
| `Shop.Speed.Price` etc. | Upgrade prices |
| `Palette` | Every colour in the game |

---

## Ideas for v2

- **Kill bricks that move** — add a `movers` entry for a hazard part.
- **Timed stages** — a countdown per stage, with a leaderboard via `DataStoreService:GetOrderedDataStore`.
- **Game passes** — sell a "skip stage" or a double-coins pass through the Creator Hub, then check `MarketplaceService:UserOwnsGamePassAsync`.
- **More obstacle kinds** — a `variant == 4` branch in the stage loop; the pattern repeats every four stages today.
- **Sounds and music** — `SoundService` plus a `Sound` in `ReplicatedStorage`.

## Notes

- DataStore calls are wrapped in `pcall`, so the game still runs in Studio without API access enabled — data just won't persist. To test saving: **Game Settings → Security → Enable Studio Access to API Services**.
- Stage spawn uses `Model:PivotTo`, so it works with both R6 and R15 avatars.

## License

MIT — use it, ship it, sell what you build on top of it.
