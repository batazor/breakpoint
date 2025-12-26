# NPC Dialog System

## Overview

The NPC Dialog System allows players to have interactive conversations with NPCs in the game. The system supports branching dialog trees, response options, and can affect game state through dialog choices.

## Usage

### For Players

1. **Start a Dialog**: 
   - Click on an NPC character to select them
   - Press **E** or **Space** to initiate conversation
   
2. **During Dialog**:
   - Read the dialog text as it appears with a typewriter effect
   - Press **Space** or click **Continue** to advance through dialog without choices
   - Click on a response option to choose your reply
   - Your choices may affect relationships, resources, or unlock new dialog options

3. **End Dialog**:
   - Dialog ends automatically when the conversation concludes
   - Press **Esc** to close the dialog panel early (if needed)

### For Developers

#### Creating Dialog Content

Dialog content is created using the `DialogLibrary` class which provides pre-made dialog trees based on NPC relationships:

```gdscript
# Get a dialog tree for an NPC
var dialog_tree = DialogLibrary.get_npc_dialog(npc, relationship)

# Start the dialog
dialog_manager.start_dialog(npc.id, dialog_tree)
```

#### Dialog Structure

**DialogTree**: A complete conversation
- `id`: Unique identifier
- `title`: Display name
- `dialogs`: Dictionary of DialogLine objects
- `start_dialog_id`: Entry point (default: "start")

**DialogLine**: A single piece of dialog
- `speaker_name`: Who is speaking
- `text`: What they say
- `responses`: Array of player response options
- `next_dialog_id`: Next dialog if no responses
- `auto_advance`: Automatically advance to next line

**DialogResponse**: A player response option
- `text`: Response text shown to player
- `next_dialog_id`: Which dialog follows this response
- `effect`: Game effect (e.g., "add_gold:10")
- `relationship_change`: Impact on NPC relationship
- `condition`: Optional condition to show this response

#### Creating Custom Dialog

```gdscript
# Create a new dialog tree
var tree = DialogTree.new()
tree.id = "custom_dialog"
tree.start_dialog_id = "greeting"

# Create a greeting dialog
var greeting = DialogLine.new()
greeting.speaker_name = "Village Elder"
greeting.text = "Welcome, traveler! How can I help you?"

# Add response options
var response1 = DialogResponse.new()
response1.text = "Tell me about this village."
response1.next_dialog_id = "village_info"

var response2 = DialogResponse.new()
response2.text = "I need supplies."
response2.next_dialog_id = "supplies"
response2.effect = "add_gold:-5"  # Costs 5 gold

greeting.responses = [response1, response2]

# Add to tree
tree.add_dialog("greeting", greeting)

# Create follow-up dialogs...
var village_info = DialogLine.new()
village_info.speaker_name = "Village Elder"
village_info.text = "Our village has stood here for generations..."
village_info.next_dialog_id = ""  # Ends conversation

tree.add_dialog("village_info", village_info)
```

## Dialog Effects

Effects are applied when a response is chosen. Format: `"effect_type:value"`

Supported effects:
- `add_gold:X` - Add/remove gold (use negative for cost)
- `add_food:X` - Add/remove food
- `add_coal:X` - Add/remove coal

Example:
```gdscript
response.effect = "add_gold:10"  # Give player 10 gold
response.effect = "add_food:-5"  # Take 5 food from player
```

## Relationship-Based Dialog

The `DialogLibrary` automatically creates different dialog based on relationship value:

- **Friendly (≥0.7)**: Helpful NPCs, offers assistance, may give resources
- **Neutral (0.3-0.7)**: Polite but distant, provides basic information
- **Hostile (≤0.3)**: Unfriendly NPCs, requires persuasion or payment to cooperate

## Integration with Game Systems

The dialog system integrates with:

1. **FactionSystem**: Retrieves NPC data
2. **PlayerInteractionController**: Handles dialog triggering
3. **DialogManager**: Manages dialog state and flow
4. **DialogPanel**: Displays UI and handles user input

## Files

- `scripts/dialog_line.gd` - Dialog line resource
- `scripts/dialog_response.gd` - Response option resource
- `scripts/dialog_tree.gd` - Dialog tree container
- `scripts/dialog_manager.gd` - Dialog state management
- `scripts/dialog_library.gd` - Pre-made dialog content
- `scripts/ui/dialog_panel.gd` - UI controller
- `scenes/ui/dialog_panel.tscn` - UI scene

## Future Enhancements

Potential improvements for the dialog system:

- [ ] Save/load dialog state
- [ ] Quest integration
- [ ] Conditional dialog based on player progress
- [ ] Voice acting support
- [ ] Dialog history/log viewer
- [ ] Character portraits
- [ ] Animated character expressions
- [ ] Dialog choices affecting faction relationships
- [ ] Skill checks (persuasion, intimidation, etc.)
