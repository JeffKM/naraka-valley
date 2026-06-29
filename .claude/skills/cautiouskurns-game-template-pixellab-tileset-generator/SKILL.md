---
name: pixellab-tileset-generator
description: Generate placeholder tilemaps using PixelLab MCP for top-down, sidescroller, or isometric games. Supports terrain transitions, connected tileset chaining, and Godot import workflow. Use this when the user wants to create tileset assets for their game.
domain: art
type: generator
version: 1.0.0
allowed-tools:
  - mcp__pixellab__create_topdown_tileset
  - mcp__pixellab__get_topdown_tileset
  - mcp__pixellab__list_topdown_tilesets
  - mcp__pixellab__delete_topdown_tileset
  - mcp__pixellab__create_sidescroller_tileset
  - mcp__pixellab__get_sidescroller_tileset
  - mcp__pixellab__list_sidescroller_tilesets
  - mcp__pixellab__delete_sidescroller_tileset
  - mcp__pixellab__create_isometric_tile
  - mcp__pixellab__get_isometric_tile
  - mcp__pixellab__list_isometric_tiles
  - mcp__pixellab__delete_isometric_tile
  - Read
  - Glob
  - Bash
  - AskUserQuestion
---

# PixelLab Tileset Generator Skill

This skill generates placeholder tilemaps and tilesets using the PixelLab MCP service through an **interactive workflow**, supporting top-down, sidescroller, and isometric tile types with terrain transitions and connected tileset chaining.

## Workflow Context

| Field | Value |
|-------|-------|
| **Assigned Agent** | asset-artist |
| **Sprint Phase** | Phase B (Implementation) |
| **Directory Scope** | `assets/` |
| **Workflow Reference** | See `docs/agent-team-workflow.md` |

---

## When to Use This Skill

Invoke this skill when the user:
- Asks to "create tiles" or "generate a tileset"
- Says "I need terrain tiles for my game"
- Wants to create ground, grass, water, or platform tiles
- Says "make placeholder tiles with PixelLab"
- Needs tilesets for world maps or combat grids
- Wants to create connected terrain transitions (water→beach→grass)

---

## Project Art Direction Context

### Blood & Gold Art Style Guidelines

**Setting:** Dark Fantasy (Low Magic) - The Shattered Kingdoms
**Tile Usage:** World map terrain, combat grid tiles, dungeon floors
**Tone:** Gritty, medieval, war-torn

**Recommended Tile Sizes:**
| Use Case | Tile Size | Notes |
|----------|-----------|-------|
| World Map | 16x16 | Standard overworld tiles |
| Combat Grid | 32x32 | Larger for tactical visibility |
| Dungeon | 16x16 or 32x32 | Match combat or world scale |
| Platformer | 16x16 | Standard sidescroller tiles |

**Default Style Settings (Blood & Gold Consistency):**
```
outline: "single color outline" or "lineless"
shading: "basic shading" or "medium shading"
detail: "medium detail"
view: "high top-down" (world map) or "low top-down" (combat)
```

**Terrain Types by Region:**
- **Ironmark (North):** Snow, frozen lakes, stone roads, pine forests
- **Silvermere (South):** Grasslands, rivers, cobblestone, farmland
- **Thornwood (West):** Dense forest, swamps, moss-covered stone
- **Sunspire (East):** Desert sand, oasis water, sandstone paths
- **Ashenvale (Center):** Corrupted earth, dead grass, ashen stone
- **Generic:** Dirt paths, water, grass, stone walls

---

## Tileset Types Overview

### 1. Top-Down Tilesets (Wang Tilesets)
**Best for:** World maps, combat grids, tactical games
**Output:** 16-23 tiles with corner-based autotiling
**Features:** Terrain transitions, seamless tiling, elevation support

### 2. Sidescroller Tilesets
**Best for:** 2D platformers, side-view games
**Output:** Platform tiles with edges and surfaces
**Features:** Transparent backgrounds, decorative top layers

### 3. Isometric Tiles
**Best for:** Isometric games, individual assets
**Output:** Single isometric block/tile
**Features:** Various shapes (thin tile, thick tile, block)

---

## Interactive Workflow

### Phase 1: Tileset Type Selection

**Start by asking:**

```
I'll help you create tileset assets using PixelLab! First, what type of tileset do you need?

**Tileset Type:**
- [ ] Top-Down (Wang tileset) - For world maps, tactical combat grids
- [ ] Sidescroller - For 2D platformer games
- [ ] Isometric Tile - For isometric games, individual blocks

**Tip:** Top-down tilesets are most common for RPGs like Blood & Gold.
```

**Wait for user response before proceeding.**

---

### Phase 2: Terrain Definition

**For Top-Down Tilesets:**

```
Great! Let's define the terrain types for your tileset.

**Base/Lower Terrain:**
What is the lower or base terrain? (The terrain that appears "underneath")
Examples: ocean water, dirt, grass, stone floor, snow

Your lower terrain: _______

**Upper/Elevated Terrain:**
What is the upper or elevated terrain? (The terrain that appears "on top")
Examples: sandy beach, green grass, cobblestone path, forest floor

Your upper terrain: _______

**Transition Description (Optional):**
How should the terrains blend together?
Examples: "wet sand with foam", "muddy grass", "crumbling stone edge"

Leave blank for automatic transitions, or describe: _______

**Transition Size:**
How prominent should the transition be?
- [ ] 0.0 - No transition (hard edge)
- [ ] 0.25 - Light transition
- [ ] 0.5 - Medium transition (Recommended)
- [ ] 1.0 - Full tile transition (23 tiles, includes center variants)
```

**For Sidescroller Tilesets:**

```
Let's define your platform tiles.

**Platform Material:**
What is the main platform surface made of?
Examples: stone brick, wooden planks, metal grating, dirt

Your platform material: _______

**Surface Layer:**
What decorates the top of platforms?
Examples: grass, snow cover, moss, none

Your surface layer: _______

**Surface Coverage:**
How much of the platform top should the surface cover?
- [ ] 0.0 - No surface (just platform material)
- [ ] 0.25 - Light coverage
- [ ] 0.5 - Heavy coverage
```

**For Isometric Tiles:**

```
Let's define your isometric tile.

**Tile Description:**
Describe what this tile represents.
Examples: grass on top of dirt, stone brick wall, wooden crate, water

Your tile description: _______

**Tile Shape:**
What thickness should the tile be?
- [ ] thin tile (~10% canvas height) - Flat surfaces
- [ ] thick tile (~25% height) - Medium depth
- [ ] block (~50% height) - Full 3D blocks
```

**Wait for user response before proceeding.**

---

### Phase 3: Technical Specifications

```
Now let's set the technical details:

**Tile Size:**
- [ ] 16x16 pixels (Recommended - standard for pixel art)
- [ ] 32x32 pixels (Larger, more detail)
- [ ] Custom: _______

**Camera View:** (Top-down only)
- [ ] high top-down (Recommended - classic RPG view)
- [ ] low top-down (More angled, shows more vertical detail)
```

**Wait for user response before proceeding.**

---

### Phase 4: Art Style Configuration

```
Let's match the art style to Blood & Gold:

**Detail Level:**
- [ ] low detail (Simple, clean)
- [ ] medium detail (Recommended - balanced)
- [ ] highly detailed (Complex textures)

**Shading:**
- [ ] flat shading (No shadows)
- [ ] basic shading (Recommended - subtle depth)
- [ ] medium shading (More depth)
- [ ] detailed shading (Complex lighting)
- [ ] highly detailed shading (Maximum depth)

**Outline:**
- [ ] single color outline (Black edges)
- [ ] selective outline (Outline where needed)
- [ ] lineless (Recommended for tiles - no outline)

**Prompt Adherence:**
How strictly should PixelLab follow your description?
- [ ] 5 (More creative freedom)
- [ ] 8 (Recommended - balanced)
- [ ] 15 (Very strict adherence)
```

**Wait for user response before proceeding.**

---

### Phase 5: Connected Tileset Chaining (Optional)

```
Do you want to create a CONNECTED tileset chain?

Connected tilesets share common terrain types for seamless transitions:
- Ocean → Beach (beach becomes lower terrain for next set)
- Beach → Grass (grass becomes lower terrain for next set)
- Grass → Forest

**Options:**
- [ ] No - Just create a single tileset
- [ ] Yes - I want to chain this with existing tilesets
- [ ] Yes - This is the START of a new chain

**If chaining with existing tilesets:**
Which tileset should this connect to?
[Call mcp__pixellab__list_topdown_tilesets to show options]

I'll use the base tile ID from that tileset to ensure seamless transitions.
```

---

### Phase 6: Review & Generate

**Present summary before generating:**

```
Here's the tileset I'll create:

**Tileset Summary:**
- Type: [Top-Down / Sidescroller / Isometric]
- Lower Terrain: [description]
- Upper Terrain: [description]
- Transition: [description or "automatic"]
- Transition Size: [0.0 / 0.25 / 0.5 / 1.0]

**Technical Settings:**
- Tile Size: [X]x[Y] pixels
- View: [high/low top-down]
- Output: [16 or 23] tiles

**Art Style:**
- Detail: [level]
- Shading: [complexity]
- Outline: [style]
- Text Guidance: [value]

**Chaining:**
- [Standalone / Connected to: tileset_name]

**Estimated Generation Time:** ~100 seconds

Ready to generate? [Yes / Modify settings]
```

---

### Phase 7: Execute Generation

**For Top-Down Tilesets:**

```gdscript
# Use mcp__pixellab__create_topdown_tileset with:
{
  "lower_description": "[lower terrain]",
  "upper_description": "[upper terrain]",
  "transition_description": "[transition or null]",
  "transition_size": [0.0-1.0],
  "tile_size": {"width": 16, "height": 16},
  "view": "[high top-down / low top-down]",
  "detail": "[detail level]",
  "shading": "[shading level]",
  "outline": "[outline style]",
  "text_guidance_scale": [1-20],
  "lower_base_tile_id": "[optional - for chaining]",
  "upper_base_tile_id": "[optional - for chaining]"
}
```

**For Sidescroller Tilesets:**

```gdscript
# Use mcp__pixellab__create_sidescroller_tileset with:
{
  "lower_description": "[platform material]",
  "transition_description": "[surface layer]",
  "transition_size": [0.0-0.5],
  "tile_size": {"width": 16, "height": 16},
  "detail": "[detail level]",
  "shading": "[shading level]",
  "outline": "[outline style]",
  "text_guidance_scale": [1-20],
  "base_tile_id": "[optional - for chaining]"
}
```

**For Isometric Tiles:**

```gdscript
# Use mcp__pixellab__create_isometric_tile with:
{
  "description": "[tile description]",
  "size": [16-64],
  "tile_shape": "[thin tile / thick tile / block]",
  "detail": "[detail level]",
  "shading": "[shading level]",
  "outline": "[outline style]",
  "text_guidance_scale": [1-20]
}
```

**After submission:**

```
Tileset generation queued!

**Job Details:**
- Tileset ID: [ID from response]
- Type: [Tileset type]
- Status: Processing
- Estimated Time: ~100 seconds

**Next Steps:**
1. The tileset generates asynchronously
2. Ask me to "check tileset status" or wait ~2 minutes
3. Once complete, I'll show download links and import instructions

**Tip:** You can queue multiple tilesets while waiting!
```

---

## Status Checking & Download

**When checking status:**

```
# For top-down tilesets:
mcp__pixellab__get_topdown_tileset(tileset_id)

# For sidescroller tilesets:
mcp__pixellab__get_sidescroller_tileset(tileset_id, include_example_map=true)

# For isometric tiles:
mcp__pixellab__get_isometric_tile(tile_id)
```

**When complete, provide:**

```
Tileset Complete!

**Download Links:**
- PNG Tileset: [URL]
- Metadata JSON: [URL]
- [For sidescroller: Example Map: [URL]]

**Base Tile IDs for Chaining:**
- Lower terrain base tile: [ID] - Use as upper_base_tile_id for next tileset
- Upper terrain base tile: [ID] - Use as lower_base_tile_id for next tileset

**Tile Layout:**
[Describe the tile arrangement for autotiling setup]

**Godot Import Instructions:**
[See Godot Import section below]
```

---

## Connected Tileset Workflow

**Creating a terrain chain (example: Ocean → Beach → Grass → Forest):**

### Step 1: Ocean to Beach
```
Lower: "deep ocean water with waves"
Upper: "sandy beach"
Transition: "wet sand with foam"
→ Save beach base tile ID
```

### Step 2: Beach to Grass (using beach ID)
```
Lower: "sandy beach"
Lower Base Tile ID: [ID from step 1]  ← This ensures visual consistency!
Upper: "green grass meadow"
Transition: "sandy grass with scattered sand"
→ Save grass base tile ID
```

### Step 3: Grass to Forest (using grass ID)
```
Lower: "green grass meadow"
Lower Base Tile ID: [ID from step 2]
Upper: "dense forest floor with leaves"
Transition: "grass with fallen leaves"
```

**Benefits of Chaining:**
- Consistent color palette across terrain types
- Seamless transitions when different tilesets meet
- Professional-looking world maps

---

## Terrain Presets by Game Type

### Blood & Gold - Combat Grid
```
Preset: "Battlefield Grass"
Lower: "dirt and mud"
Upper: "trampled grass"
Transition: "muddy grass"
Size: 32x32
View: low top-down
```

### Blood & Gold - World Map
```
Preset: "Kingdom Roads"
Lower: "green grass meadow"
Upper: "cobblestone road"
Transition: "grass growing through stone cracks"
Size: 16x16
View: high top-down
```

### Blood & Gold - Dungeon
```
Preset: "Stone Dungeon"
Lower: "dark stone floor"
Upper: "cracked ancient tiles"
Transition: "broken tile edges"
Size: 32x32
View: high top-down
```

### Ashenvale (Corrupted)
```
Preset: "Corrupted Lands"
Lower: "dead gray earth"
Upper: "corrupted purple grass"
Transition: "dying vegetation with purple veins"
```

---

## Godot Import Instructions

### Top-Down Tileset Import

1. **Download the tileset PNG and metadata JSON**

2. **Create folder structure:**
   ```
   assets/tilesets/
   ├── terrain/
   │   ├── grass_to_water.png
   │   ├── grass_to_water.json
   │   └── grass_to_water.tres  (TileSet resource)
   ```

3. **Create TileSet in Godot:**
   - Create new TileSet resource
   - Add texture (the PNG)
   - Set tile size (16x16 or 32x32)
   - Configure terrain sets for autotiling

4. **Wang Tile Setup:**
   The metadata JSON includes tile mapping for Godot's terrain system:
   - Configure corner-based terrain
   - Map each tile to its terrain corners
   - Enable autotiling in TileMap

### Sidescroller Tileset Import

1. **Download PNG and example map (optional)**

2. **Import as Atlas:**
   - Add to TileSet as texture
   - Set tile size
   - Mark physics collision shapes for platforms

3. **Setup Platform Tiles:**
   - Top tiles: Walkable surface
   - Middle tiles: Fill/background
   - Edge tiles: Left/right caps

### Isometric Tile Import

1. **Individual tiles work as standalone sprites**

2. **For TileMap:**
   - Configure isometric tile shape in TileMap
   - Set tile size matching your isometric ratio
   - Consider using y-sort for proper depth

---

## Quick Generation (Skip Interactive)

If user provides details upfront, generate directly:

**Example:**
```
User: "Create a grass to water tileset, 16x16, high top-down"

Skip to generation with:
- lower_description: "deep blue water"
- upper_description: "green grass meadow"
- transition_description: "muddy shoreline with reeds"
- transition_size: 0.5
- tile_size: {"width": 16, "height": 16}
- view: "high top-down"
- detail: "medium detail"
- shading: "basic shading"
- outline: "lineless"
- text_guidance_scale: 8
```

---

## Error Handling

**If generation fails:**
1. Check PixelLab service status
2. Simplify terrain descriptions
3. Reduce text_guidance_scale for more creative freedom
4. Check subscription/credits status

**If tiles don't match:**
1. Increase text_guidance_scale for stricter adherence
2. Add more specific transition descriptions
3. Try different shading/detail levels
4. Use base tile IDs from successful tilesets for consistency

**If transitions look wrong:**
1. Adjust transition_size (0.25 vs 0.5 vs 1.0)
2. Add explicit transition_description
3. Ensure lower/upper descriptions are visually distinct

---

## Example Invocations

User: "Create terrain tiles for my world map"
User: "I need grass to water transition tiles"
User: "Make platformer tiles for a forest level"
User: "Generate dungeon floor tiles"
User: "Create a tileset chain for beach to forest"
User: "I need isometric blocks for buildings"

---

## Reference: List Existing Tilesets

```
# Check what tilesets already exist:
mcp__pixellab__list_topdown_tilesets(limit=20)
mcp__pixellab__list_sidescroller_tilesets(limit=20)
mcp__pixellab__list_isometric_tiles(limit=20)
```

Use existing tilesets as references for style consistency or for chaining.
