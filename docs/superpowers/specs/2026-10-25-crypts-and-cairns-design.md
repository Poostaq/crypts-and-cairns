# Crypts & Cairns — Floor 1 MVP Design

**Date:** 2026-10-25

**Status:** Approved design baseline, revision 2

**Target:** Godot 4, desktop browsers, single-player, turn-based pixel-art roguelike

## 1. Product statement

> A turn-based simulation of living in a game-like world that revolves around diving into a labyrinth.

*Crypts & Cairns* recreates the experience of the fictional game underlying *Surviving the Game as a Barbarian*, interpreted through the manhwa's lived-world consequences: bodily injury, survival needs, autonomous companions, taxation, institutions, social risk, and permanent death.

The player is a native explorer, not a transported version of a protected character. The game deliberately retains recognizable structural mechanics while using original characters, specific histories, dialogue, artwork, creature expression, artifacts, locations, and plot events.

## 2. Source posture and originality controls

The project deliberately occupies a source-inspired grey area and does not claim guaranteed legal safety. It prioritizes fidelity to the fictional game's systems while preventing accidental reuse of protected expression.

### 2.1 Naming policy

Generic fantasy vocabulary may remain unchanged when it is descriptive rather than source-identifying. Allowed examples include goblin, knight, mage, adventurer, labyrinth, essence, rift, soul level, rank, and monster. Source-specific proper nouns, named institutions, characters, proprietary creatures, artifacts, and events require original alternatives.

A non-exported naming registry will record:

- The reference concept and source confidence.
- Prohibited source terminology.
- The approved project term.
- A rationale showing how the project version differs.
- Manual review status for possible one-to-one mappings.

Automated release checks scan gameplay content, resource IDs, filenames, UI strings, localization files, and the final export manifest for prohibited terminology. Manual review covers renamed equivalents that string scanning cannot detect.

Protected character names, dialogue, artwork, plot sequences, proprietary creature designs, and one-to-one textual or visual reproduction of artifacts and floor events are prohibited. Deliberate structural fidelity—such as Floor 1 retaining four cardinal routes and a central navigation landmark—is permitted when its names, inhabitants, event logic, art, and authored challenges are original. Marketplace and trademark searches are required before public release.

The naming registry, source references, tests, and design/legal documentation must not be included in the Web export.

### 2.2 Provenance ledger

Each adapted mechanic is classified as one of:

- **Officially confirmed:** stated by an official publisher or official series page.
- **Community-referenced:** summarized by a community source that cites a specific novel or manhwa chapter.
- **Inference:** a design interpretation from incomplete evidence.
- **Original adaptation:** created for this game.

Community summaries are evidence, not instructions or unquestionable canon. The working ledgers are maintained in `docs/design/naming-registry.md` and `docs/design/source-provenance.md`.

## 3. Platform and presentation

- Godot 4 with a pinned engine version.
- GDScript only; no C#, GDExtension, or native-only runtime dependencies.
- Compatibility renderer and single-threaded Web export.
- Desktop Chromium and Firefox are primary browser targets.
- Keyboard and mouse are the MVP input targets.
- Unified top-down square grid for exploration and combat.
- Eight-direction movement with blocked corner cutting.
- Detailed 32×48 character sprites with visible gear, wounds, and racial silhouettes.
- Each labyrinth region has its own palette and lighting identity.
- Integer-scaled pixel viewport; presentation scaling never affects authoritative coordinates.

## 4. World and economic pressure

Caerfaldon is the last warded city in a world made uninhabitable by an ancient blight. Its population survives because labyrinth creatures leave **aetherstones**, which alchemists convert into food, fuel, metal, medicine, and building material.

Every adult owes a recurring citizenship levy. Missing it escalates through loss of explorer privileges, confiscation, outlaw status, and eventual execution. The labyrinth is therefore an economic necessity rather than an optional adventure.

Market prices respond to expedition outcomes. Disastrous openings raise food and medicine costs; productive cycles increase equipment supply and reduce selected commodity prices.

The MVP contains one dense, explorable district. Its location, scheduling, navigation, and service systems are designed to expand into a multi-district city without replacement.

## 5. Playable peoples and starting disciplines

All six peoples and fourteen project-defined, people-restricted starting disciplines are available in the Floor 1 MVP. The disciplines are original, balanceable adaptation content rather than claimed canonical classes.

| People | Racial system | Starting disciplines |
|---|---|---|
| Hearthborn | Broad access to trained mortal disciplines; no exclusive supernatural racial power | Aura Knight, Arcanist, Elementalist, Ordained |
| Fell-Clans | Exceptional physique, binding oaths, and body imprints | Immortal Vanguard, Blooded Slayer |
| Stonekin | Relic affinity reduces artifact cooldowns and failure risks | Iron Bulwark, Relic Warden |
| Fairfolk | Elemental spirit contracts and exceptional hearing | Spirit Archer, Elemental Envoy |
| Beastkin | Contract, summon, empower, or merge with an ancestral beast | Pact Hunter, Beast Vessel |
| Wyrmblood | Draconic blessing, fear, command-voice, and arc-metal affinity | Arc Lancer, Dreadspeaker |

Race determines culture, generated naming rules, base attributes, available disciplines, equipment aptitudes, dialogue options, and city obligations. Discipline determines starting training and equipment, not the final build. Essences can bend characters into unusual roles without erasing their origin.

The player enters a custom hero name. All non-player explorers use culturally appropriate generated names, histories, traits, goals, and relationships.

## 6. Campaign loop

1. Name the hero and select a people and starting discipline.
2. Prepare in Caerfaldon: recruit autonomous companions, obtain supplies, heal, gather information, negotiate shares, and manage the levy.
3. Enter the labyrinth during its monthly opening.
4. Explore a hybrid-generated floor through action-point turns.
5. Manage combat, light, provisions, water, fatigue, time, injuries, weight, and party morale.
6. Collect aetherstones, discover creatures, complete achievements, and decide whether to absorb rare essences.
7. Enter conditional rifts, seek doors to deeper floors, or survive until floor closure.
8. Return to Caerfaldon, settle contracts, recover, trade, research, and prepare for the next cycle.

The complete campaign ends only when the hero dies or opens the final door at the deepest depth. The MVP permits discovery and opening of Floor 2 doors but does not permit traversal beyond the Floor 1 frontier.

## 7. Attributes and growth

Characters have three headline attribute groups:

- **Body:** strength, agility, flexibility, endurance, carrying capacity, bone strength, recovery, pain tolerance, vision, hearing, scent, and weapon-specific force.
- **Mind:** willpower, perception, concentration, fear resistance, intuition, memory, and resistance to illusion or control.
- **Mystic:** soul power, soul regeneration, elemental affinity, divine affinity, summoning control, and ability potency.

Players can inspect all discovered sub-stats. Exact formulas and undiscovered interactions remain hidden.

Experience is awarded only for a hero's first defeat of a creature species. Variants, named superior creatures, rift guardians, bosses, and selected achievements have separate first-completion entries. Repeated hunting yields resources but not repeated experience.

Each Soul Level raises maximum soul power, opens one essence slot, and slightly improves resistance to soul effects. Increasing requirements force the player to seek diverse creatures and achievements rather than farm one safe encounter.

Selected record feats provide a separate repeatable growth route. A feat only awards experience when the hero establishes a qualifying new record or satisfies a cycle-specific challenge; repeating an unchanged safe action produces nothing.

### 7.1 Distinct rank systems

- **Soul Level:** personal progression earned from first-species defeats and qualifying feats; controls soul power and essence capacity.
- **Adventurer standing:** an appraisal issued by the Adventurers' Lodge from engraved essence power, demonstrated capability, and audited achievements; it controls contracts, party access, and institutional trust.
- **Creature rank:** the Rank 9-to-Rank 1 danger scale used for monsters and encounter planning.

These values may correlate but never substitute for one another.

## 8. Essences

Creatures have a small chance to leave an essence. An essence dissolves after 30 in-world minutes, forcing an immediate decision.

An absorbed essence may grant:

- Positive and negative sub-stats.
- One passive ability.
- One or more active abilities.
- Physical or cosmetic changes.
- Synergies or conflicts with installed essences.

Guardian essences are stronger and may contain additional abilities. Essence capacity is limited by Soul Level. The Caerfaldon sanctuary can remove an essence, but each removal costs more than the last and destroys the removed essence.

Unknown essences initially expose qualitative information. Research, observation, and use reveal exact properties in the Chronicle.

## 9. Creatures and rank structure

Creature danger descends from Rank 9 to Rank 1. Unranked wildlife and hazards may provide resources but no experience or aetherstones.

Creature categories are:

- **Variants:** one species expressed through different combat roles.
- **Superior species:** unusually dangerous creatures for the current region.
- **Rare species:** conditional or rift-exclusive creatures.
- **Named superior variants:** intelligent individuals with distinct histories, essence powers, behaviors, and rewards.

Ranked creature bodies dissolve after death and leave applicable drops. Unranked bodies persist and may provide physical evidence, food, or materials. Blood, environmental damage, and selected physical traces may remain when mechanically relevant. Group size and encounter pressure increase as an expedition approaches floor closure.

## 10. Floor 1

Floor 1 lasts exactly 168 in-world hours. Closure expels surviving explorers who remain on the floor.

The floor is a luminous cave network with a central navigation landmark called the **Cairn Compass** and four cardinal ecosystems:

- **North — Ashcap Warrens:** fungal scavengers, alarms, ambushes, and mechanical traps.
- **East — Razorhound Galleries:** pack predators, scent tracking, pursuit, and open caverns.
- **South — Barrow Deeps:** pallid undead, disease, darkness, and spiritual hazards.
- **West — Delver Hollows:** burrowers, rockfalls, defensive formations, and clay sentinels.

The four routes converge toward distinct Floor 2 doors. The Cairn Compass reveals orientation, elapsed floor time, and which route doors have been activated without exposing the generated layout.

### 10.1 Hybrid generation

Each cycle derives its floor seed from campaign seed, floor number, and monthly cycle. Generation proceeds through:

1. A required landmark graph containing start, monument, regional entrances, and reachable exits.
2. Authored room and corridor chunks selected for the route.
3. Connections satisfying reachability and minimum travel-time constraints.
4. Hazards, camps, water, forage, and navigation landmarks.
5. Creature territories and patrols.
6. Rift availability and hidden conditions.
7. Region-specific loot and encounter budgets.
8. Connectivity, survival-resource, duration, difficulty, and exit validation.

Generation retries a bounded number of times. Exhausted retries load an authored safe layout. Failed seeds are captured as regression fixtures.

### 10.2 Rifts

Rifts are temporary labyrinths inside the floor. They have hidden opening conditions, per-cycle cooldowns, party capacity, exclusive creatures, special environmental rules, a guardian, and improved rewards.

The MVP includes four original rifts:

- Trapworks of the Hollow Crown.
- Moonless Kennel.
- Ossuary of Bells.
- Sunken Foundry.

Only some are available in a cycle. Region-specific signs, rumors, creature behavior, and authored environmental conditions reveal whether a rift is dormant, available, or awaiting another condition. The Cairn Compass does not expose or activate rifts.

## 11. Equipment and Runemarked Relics

Ordinary equipment is purchased, commissioned, repaired, and improved with materials.

Runemarked Relics are unique rule-changing items obtained primarily from rift guardians, rare mimics, and hidden discoveries. Each uses an original identifier, benefit, limitation, and history. They are build-defining tools rather than ordinary vertical upgrades.

Example original effects include an immovable shield that roots its bearer, a torch that reveals hidden doors while attracting spectral threats, and a pack that expands capacity while broadcasting the party's scent.

## 12. Combat contract

Exploration and combat share one grid and ruleset. Hostile awareness exposes full tactical AP controls without transitioning to a separate battle scene. A threat-and-attention model determines target selection from damage, proximity, noise, obstruction, healing, provocation, and protective abilities.

- Initiative is speed-sorted each round.
- Actors receive 12 baseline AP, modified by conditions.
- Orthogonal movement costs 2 AP.
- Diagonal movement costs 3 AP and cannot cut blocked corners.
- Attacks cost AP according to weapon and technique.
- AP deliberately reserved for reactions remains available until its defined expiry point.
- Other unspent AP expires at round end.
- Reactions may interrupt later actors.
- Animation skipping and fast-forwarding never change authoritative outcomes.

Facing, reach, line of sight, cover, elevation, noise, friendly fire, and armor coverage matter.

Damage reduces vitality and may cause bleeding, fractures, concussion, infection, poison, decay, disabled limbs, shock, fear, or permanent scars. A veteran can die from critical trauma, uncontrolled bleeding, falls, or failed retreat.

Combat-system design must resolve initiative ties, initiative snapshot timing, surprise rounds, newly spawned actors, reaction expiry and ordering, AP-altering statuses, incapacitation, timeline UI, and maximum AI presentation duration before implementation of those behaviors.

## 13. Autonomous companions

The active party contains the hero and up to four companions. The player controls only the hero.

Each generated companion has:

- People, discipline, Adventurers' Lodge standing, equipment, and essences.
- Courage, greed, discipline, loyalty, caution, and aggression.
- Personal goals, fears, grudges, relationships, and hidden motives.
- Preferred formations and tactical behavior.
- A negotiated loot share and contractual expectations.

The hero issues high-level orders such as hold formation, guard, focus, conserve soul power, retreat, or break through. Companions interpret them through perception, trust, personality, battlefield awareness, and personal limits.

AI decisions use only what the companion can perceive and what party members have communicated. Candidate actions, planning depth, perception, and pathfinding are bounded and cached for single-threaded Web performance. If no timely legal action exists, the companion guards, retreats toward formation, or waits.

Companions can refuse suicidal commands, panic, save allies, steal, desert, or betray the party. Companion death is permanent.

### 13.1 Wider expedition society

The labyrinth is populated by other autonomous parties rather than existing only for the player's group. The MVP includes neutral teams, rivals, opportunistic raiders, active camps, contested claims, information exchange, requests for aid, and encounters whose outcomes affect later Lodge reports and city relationships.

Expeditions support explicit navigation and camp roles. Parties choose routes, camp sites, sleep schedules, watches, light discipline, and retreat posture. Guides and characters with sensory expertise reduce navigation uncertainty but cannot reveal hidden generation state.

## 14. Caerfaldon district

The MVP district contains:

- Adventurers' Lodge: licensing, standing appraisal, contracts, reports, and party registration.
- Market: supplies, equipment, repairs, appraisal, and dynamic prices.
- Tavern and hiring yard: generated recruits and share negotiation.
- Sanctuary: healing, funerals, spiritual services, and essence removal.
- Archive: purchased information, Chronicle research, and player notes.
- Alchemist: material conversion and essence analysis.
- Lodging: rest, storage, planning, and companion conversations.
- Levy office: deadlines, debts, exemptions, and penalties.
- Portal plaza: monthly entry and expedition assembly.

City actions advance hours or days. NPC schedules and services use the same location abstractions intended for future districts.

## 15. Permanent death and retained knowledge

A campaign has one continuously autosaved hero lineage. Death removes hero progression, equipment, money, relationships, active objectives, and current floor state.

The account-level Chronicle retains only:

- Bestiary observations.
- Confirmed essence properties.
- Recipes and monument combinations.
- Landmark and rift notes.
- Encountered relic descriptions.
- Death records.
- Player-authored notes.

No inherited currency, attributes, equipment, drop bonuses, or other power survives.

## 16. Save integrity and browser storage

Local integrity is friction against accidental rerolls and casual file editing, not tamper-proof security.

The Web platform uses a custom JavaScript/IndexedDB adapter through `JavaScriptBridge` and an HTTPS-hosted custom export shell. A per-installation non-extractable HMAC `CryptoKey` signs native local snapshots.

Snapshots and replays record:

- Game/build version.
- Save-schema version.
- Content-schema version.
- Canonical content hash.
- RNG algorithm version.
- Campaign lineage and sequence number.

The save system uses signed snapshots, monotonic sequence numbers, a bounded hash-chained journal with periodic checkpoints, mirrored death tombstones, and atomic primary/backup writes.

Death blocks input and atomically commits the dead campaign state, Chronicle delta, death record, journal entry, sequence number, and tombstone before the final death presentation. Other actions that change campaign and Chronicle data use the same cross-save transaction rule.

Storage policy:

- IndexedDB unavailable or write test fails: block normal campaigns; allow marked practice mode.
- IndexedDB works but persistent storage is denied: warn about possible eviction, recommend export, and allow play after acknowledgment.
- Persistent storage granted: proceed normally.

Portable exports cannot retain local HMAC trust. Imports receive a new lineage, an informational imported marker, and a new destination signature. No local system can defeat DevTools, client patching, clearing storage, or rollback of the complete origin.

## 17. Architecture

Godot scenes are presentation only. They collect input and animate emitted results but never directly mutate authoritative state.

The command pipeline is:

`Input → Command → Validation → Resolution → Domain events → Autonomous turns → Presentation → Save boundary`

Successful commands mutate a serializable `GameState` and emit ordered events. Rejected commands leave an identical canonical state hash. Injected failures cannot leave partial mutation.

### 17.1 Responsibilities

- `src/domain/`: deterministic rules and serializable state; no scenes or rendering.
- `src/application/`: campaign state machine, command orchestration, knowledge filtering, and view models.
- `src/presentation/`: scenes, tile layers, sprites, animation, HUD, audio, and input.
- `src/platform/`: saves, Web bridge, hashing, browser lifecycle, and platform adapters.
- `content/`: gameplay definitions and presentation references.
- `tests/`: unit, scenario, content, replay, save, Web, and performance tests.
- `web/`: custom export shell and IndexedDB/Web Crypto adapter.
- `docs/design/`: non-exported naming, provenance, deferred-decision, and system documents.

### 17.2 Simulation systems

- Turn and AP engine.
- Combat, armor, wounds, and status effects.
- Companion AI, perception, personality, and orders.
- Campaign clock, levy deadlines, and floor closure.
- First-kill experience, record feats, Soul Levels, essences, relics, and Adventurers' Lodge standing.
- Economy, recruitment, relationships, healing, and city services.
- Hybrid generation and conditional rifts.

### 17.3 Player-visible information boundary

The full simulation contains facts the player must not receive. A knowledge filter creates view models that expose only observed or Chronicle-confirmed information.

Hidden creature powers, exact undiscovered odds, companion motives, unopened rift conditions, off-screen actors, and secret generation state are absent from player-facing view models and logs. Companion AI receives only its perception and communicated party knowledge.

## 18. Content model

Gameplay definitions use reviewable JSON. Godot resources handle visual and audio presentation where editor tooling is useful.

Definitions use stable namespaced IDs such as:

- `people.fell_clan`
- `discipline.fell_clan.immortal_vanguard`
- `monster.ashcap_raider`
- `essence.ashcap_raider`
- `region.depth1.north`
- `rift.depth1.ashcap_trial`

Display text uses localization keys. Definitions are immutable during a campaign. Mutable state stores stable IDs and runtime values, never scene nodes or resource objects.

Authoritative JSON values use integral base units: AP units, ticks, basis points, grams, millilitres, and similar documented units. Fractional authoritative values are rejected. Presentation-only values may become floats after leaving the domain.

Small, versioned validators for each definition family enforce required fields, integral ranges, references, combinations, equipment compatibility, budgets, connectivity, localization coverage, and prohibited terminology. Missing required presentation assets fail release validation; development builds show conspicuous placeholders. Optional assets require declared fallbacks.

Renamed IDs require explicit migration aliases. Save schema, content schema, content manifest, and RNG algorithm are versioned independently.

## 19. Determinism

The project owns a versioned PCG32 random generator. Independent substream seeds derive from a stable hash of campaign seed plus stream ID rather than consumption order. Authoritative streams cover combat, generation, loot, and AI bias. Cosmetic randomness remains presentation-only.

Authoritative calculations use integers or fixed-point integers. Collections are sorted before rule resolution.

A canonical state encoder:

- Emits fields in fixed order.
- Sorts maps and entity lists by stable ID.
- Includes relevant build, schema, content, and RNG versions.
- Excludes caches, view models, animation state, and cosmetic state.
- Contains authoritative primitives only.

State hashes use the canonical encoding. Debug replays contain commands and hashes rather than acting as permanent event-sourced saves.

## 20. Testing

### 20.1 Fast and per-commit tests

- Unit tests for AP, damage, wounds, armor, status effects, experience, essences, inventory, time, and economy.
- Content validation for every definition and reference.
- Invariants: nonnegative AP, unique solid occupancy, dead actors cannot act, and essence capacity cannot be exceeded.
- Fixed-seed combat, companion, generation, and rift scenarios.
- Rejected commands preserve an identical state hash.
- Injected resolution failures cannot partially mutate state.
- A compact generation seed corpus plus all historical regression seeds.
- Save round trips, migrations, and canonical serialization.
- Knowledge-filter tests proving secrets are absent from view models and player logs.
- Companion fixtures proving AI uses permitted perception only.

### 20.2 Scheduled and release tests

- Thousands of generation seeds for reachability, resources, exits, budgets, and fallback behavior.
- Save corruption, stale signatures, broken journal links, sequence disagreement, missing keys, tombstone disagreement, imports, rebinding, interrupted transactions, and cross-save atomicity.
- Main menu, character creation, city, combat, death, and Chronicle scene smoke tests.
- Browser automation for Chromium and Firefox persistence, refresh, suspension, closure, denied storage, import/export, IndexedDB transactions, and CryptoKey retention.
- Animation skipping, refresh after commit, and interrupted presentation must reach the same authoritative state without duplicating effects.
- Keyboard-only use, remapping, text scaling, reduced motion, and non-color status communication.
- Representative encounters and maps against explicit performance budgets.
- Export manifest audit for prohibited terms and non-shipping files.

Completion claims require fresh headless tests, a desktop-editor playthrough, and a Web export smoke test.

## 21. Failure behavior

- Invalid commands return a rejection with no state change.
- Invalid content fails development and release validation.
- Exhausted generation retries use an authored safe floor.
- AI that cannot produce a timely legal action guards, retreats, or waits.
- Missing required presentation assets show placeholders only in development and fail release validation.
- Corrupt saves are preserved for diagnosis and routed to recovery.
- Failed consequential save transactions block further input and show recovery options.
- Browser suspension never advances the turn-based simulation clock.
- Signature or key failures never silently overwrite data; recovery offers discard, marked portable rebind, or a new campaign.

## 22. Accessibility and usability

- Fully remappable keyboard and mouse controls.
- Keyboard-only navigation.
- Scalable interface and text.
- Color-independent icons and labels for every status.
- Reduced-motion mode.
- Adjustable animation and AI playback speed.
- Readable, filterable combat log.
- Detailed death report explaining known causal events without revealing undiscovered secrets.
- Fast-forward never skips required player decisions.

## 23. Floor 1 MVP content target

- Six peoples and fourteen starting disciplines.
- Character creation and cultural name generation.
- One expandable Caerfaldon district with nine services.
- Hero plus up to four autonomous companions.
- Neutral teams, rivals, opportunistic raiders, camps, and contested claims.
- Complete city cycle and 168-hour expedition clock.
- Central Floor 1 zone and four cardinal ecosystems.
- Four base creature families, eight role variants, four superior species, one possible named superior event, and four rift guardians.
- Four conditional rifts.
- Eighteen weapons, shields, or foci.
- Twenty-four armor or accessory items.
- Twelve consumables and survival supplies.
- Sixteen essences, including four guardian essences.
- Eight Runemarked Relics.
- Aetherstones, first-kill experience, Soul Levels, equipment, wounds, and essence capacity.
- Levy, trade, healing, research, recruitment, contracts, funerals, and essence removal.
- Permanent death with knowledge-only persistence.
- Four discoverable doors leading toward Floor 2.
- Desktop-browser Web export.

## 24. Internal delivery milestones

The Floor 1 package is an MVP candidate, not a single engineering milestone.

1. **Foundation:** fixed-seed command replay produces an identical canonical state hash.
2. **Combat:** one complete AP fight runs headlessly and visually.
3. **Expedition:** a generated route passes validation for survivability until forced closure and keeps its intended Floor 2 door reachable, or the authored fallback is used.
4. **Progression:** first-kill experience, equipment, and essence decisions survive reload.
5. **Companions:** one autonomous ally obeys, refuses, retreats, and remains deterministic in scenario fixtures.
6. **City:** a complete levy-to-expedition cycle runs.
7. **Floor 1 content:** every public content definition passes validation and balance smoke tests.
8. **Web hardening:** storage, CryptoKey, import/export, suspension, accessibility, performance, and browser compatibility pass.

Each milestone receives its own implementation plan or clearly bounded plan section with test-first steps and review gates.

## 25. MVP exclusions

- Floors 2–10.
- A fully simulated multi-district city.
- Multiplayer and online leaderboards.
- Cloud-authoritative saves.
- Mobile or touch-first controls.
- Modding support.
- Finalized formulas for systems not currently being implemented.

Expansion seams may exist, but excluded features must not drive unused infrastructure.

## 26. Deferred decision register

The following decisions are resolved in the focused design step immediately before their owning system is implemented:

- **Combat:** speed ties, initiative snapshot timing, surprise, spawned actors, reaction expiry/order, mid-turn AP changes, incapacitation, and presentation-duration limits.
- **Progression credit:** hero kill credit, assists, summons, simultaneous defeats, companion contributions, and record-feat qualification.
- **Floor lifecycle:** closure inside a rift and ascending-floor timer interaction. Floor 1 has no routine early extraction.
- **Death and recovery:** surviving companions, inaccessible hero possessions, and contractual settlement. The hero cannot revive in the MVP.
- **Loot and contracts:** ownership, disputed drops, unpaid shares, and recovered companion property.
- **Endgame:** the original prerequisites and final encounter structure are designed before work begins on Floors 2–10; the MVP assumes no people-associated treasure mapping.
- **Web lifecycle:** multi-tab conflict policy and platform-specific background throttling responses.

The register is a sequencing rule, not permission to implement ambiguous behavior. Each item must be decided and added to its system specification before related code is written.

## 27. Research references

Primary and official pages:

- [Official WEBTOON series page](https://us.webtoons.com/en/fantasy/surviving-the-game-as-a-barbarian/list?title_no=5515)
- [Official Naver web novel listing](https://series.naver.com/novel/detail.series?productNo=6037518)
- [Official Naver webtoon listing](https://series.naver.com/comic/detail.series?productNo=9597018)
- [Godot Web export documentation](https://docs.godotengine.org/en/4.5/tutorials/export/exporting_for_web.html)
- [Godot renderer documentation](https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html)
- [Godot data-path documentation](https://docs.godotengine.org/en/stable/tutorials/io/data_paths.html)
- [MDN Web Crypto](https://developer.mozilla.org/en-US/docs/Web/API/SubtleCrypto)
- [MDN IndexedDB terminology and transactions](https://developer.mozilla.org/en-US/docs/Web/API/IndexedDB_API/Basic_Terminology)
- [MDN Web privacy](https://developer.mozilla.org/en-US/docs/Web/Privacy)

Community references requiring provenance classification:

- [Dungeon & Stone mechanics](https://surviving-the-game-as-a-barbarian.fandom.com/wiki/Dungeon_%26_Stone)
- [Labyrinth](https://surviving-the-game-as-a-barbarian.fandom.com/wiki/Labyrinth)
- [Essences](https://surviving-the-game-as-a-barbarian.fandom.com/wiki/Essence)
- [Numbered items](https://surviving-the-game-as-a-barbarian.fandom.com/wiki/Numbered_Items)
- [Explorers and ranking](https://surviving-the-game-as-a-barbarian.fandom.com/wiki/Explorers)
- [Races](https://surviving-the-game-as-a-barbarian.fandom.com/wiki/Category%3ARaces)
- [City and taxation](https://surviving-the-game-as-a-barbarian.fandom.com/wiki/Rafdonia)
- [Final-gate treasures](https://surviving-the-game-as-a-barbarian.fandom.com/wiki/Genesis_Treasures)

Working review documents:

- [`docs/design/naming-registry.md`](../../design/naming-registry.md)
- [`docs/design/source-provenance.md`](../../design/source-provenance.md)

