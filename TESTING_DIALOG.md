# Testing the NPC Dialog System

## Quick Start Guide

The NPC dialog system has been added to Breakpoint. Here's how to test it:

## Testing in Godot Editor

1. **Open the project** in Godot Engine 4.5+

2. **Run the main scene** (scenes/main.tscn)

3. **Find an NPC character**:
   - Look for character units on the map (Barbarian, Knight, Ranger, Rogue, or Mage)
   - These characters should have a CharacterBrain component with an npc_id

4. **Interact with the NPC**:
   - Click on the NPC to select it (you'll see a yellow selection ring)
   - Press **E** or **Space** key to start the conversation
   - A dialog panel will appear at the bottom of the screen

5. **Have a conversation**:
   - Watch the text appear with a typewriter effect
   - Press **Space** or click **Continue** to advance
   - When response options appear, click one to choose your reply
   - Some choices may cost resources or improve your relationship

## What to Test

### Basic Functionality
- [ ] Can select NPC characters
- [ ] Dialog panel appears when pressing E/Space
- [ ] Text displays with typewriter effect
- [ ] Can click Continue button
- [ ] Response buttons appear and work
- [ ] Dialog ends properly

### Dialog Content
- [ ] NPCs have different dialog based on relationship
- [ ] Friendly NPCs offer help
- [ ] Neutral NPCs provide information
- [ ] Hostile NPCs require persuasion
- [ ] Dialog choices affect resources (check HUD)

### UI/UX
- [ ] Dialog panel is readable
- [ ] Text scrolls smoothly
- [ ] Response buttons are clickable
- [ ] Continue button works
- [ ] Can press Space to advance
- [ ] Panel closes when dialog ends

## Troubleshooting

### "No NPC to talk to" / Nothing happens
- Make sure you've selected a character unit (not just a tile)
- Check if the character has an NPC ID assigned
- Some units might not be NPCs (player-controlled units)

### Dialog panel doesn't appear
- Check the console for error messages
- Verify DialogPanel is in the scene tree
- Ensure PlayerInteractionController has dialog_panel_path set

### Responses don't work
- Check if DialogManager is created properly
- Verify response buttons are being created
- Look for errors in the console

## Known Limitations

- Currently only character units can be NPCs
- Relationship values are hardcoded (0.5 neutral)
- Limited dialog content (3 conversation types)
- No character portraits yet
- No voice acting

## Future Enhancements

Ideas for improving the dialog system:
- Add character portraits to dialog panel
- Implement quest system integration
- Save dialog progress
- Add more varied dialog content
- Include dialog choices that affect faction relationships
- Add skill checks (persuasion, intimidation)
- Voice acting support

## Filing Issues

If you encounter bugs or have suggestions:
1. Check existing issues on GitHub
2. Create a new issue with:
   - Clear description of the problem
   - Steps to reproduce
   - Expected vs actual behavior
   - Screenshots if applicable
   - Console error messages

## Code Overview

Key files to review:
- `scripts/dialog_manager.gd` - Core dialog logic
- `scripts/dialog_library.gd` - Dialog content creation
- `scripts/ui/dialog_panel.gd` - UI controller
- `scenes/ui/dialog_panel.tscn` - UI layout
- `scripts/player_interaction_controller.gd` - Integration

Happy testing!
