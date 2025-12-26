# City Screen UI Layout

## Visual Layout (ASCII Diagram)

```
┌────────────────────────────────────────────────────────────────────────┐
│                         City Management                                │
│                  Build and manage city buildings                       │
│              Food: 120    Coal: 40    Gold: 60                        │
├────────────────────────────────────────────────────────────────────────┤
│                                                                        │
│  ┌─── Available Buildings ──────────┐  │  ┌─ Construction Queue ──┐ │
│  │                                   │  │  │                        │ │
│  │  ┌─────────┐  ┌─────────┐       │  │  │  Building: Market      │ │
│  │  │ Archery │  │Barracks │       │  │  │  (5.2h remaining)      │ │
│  │  │ Range   │  │         │       │  │  │                        │ │
│  │  │         │  │         │       │  │  │  Queued: Blacksmith    │ │
│  │  │ 💰+5/hr │  │ 🍎-5/hr │       │  │  │  (5.0h remaining)      │ │
│  │  │Cost:    │  │Cost:    │       │  │  │                        │ │
│  │  │30/20/40 │  │40/30/50 │       │  │  │  Queued: Church        │ │
│  │  │ [Build] │  │ [Build] │       │  │  │  (10.0h remaining)     │ │
│  │  └─────────┘  └─────────┘       │  │  │                        │ │
│  │                                   │  │  │                        │ │
│  │  ┌─────────┐  ┌─────────┐       │  │  │                        │ │
│  │  │Blacksmith│ │ Church  │       │  │  │                        │ │
│  │  │         │  │         │       │  │  │                        │ │
│  │  │⛏️-3/hr  │  │ 💰+3/hr │       │  │  │                        │ │
│  │  │💰+8/hr  │  │         │       │  │  │                        │ │
│  │  │Cost:    │  │Cost:    │       │  │  │                        │ │
│  │  │25/40/35 │  │20/25/60 │       │  │  │                        │ │
│  │  │ [Build] │  │ [Build] │       │  │  │                        │ │
│  │  └─────────┘  └─────────┘       │  │  │                        │ │
│  │                                   │  │  │                        │ │
│  │  ┌─────────┐  ┌─────────┐       │  │  │                        │ │
│  │  │ Small   │  │ Large   │       │  │  │                        │ │
│  │  │ House   │  │ House   │       │  │  │                        │ │
│  │  │         │  │         │       │  │  │                        │ │
│  │  │🍎-2/hr  │  │🍎-3/hr  │       │  │  │                        │ │
│  │  │         │  │💰+2/hr  │       │  │  │                        │ │
│  │  │Cost:    │  │Cost:    │       │  │  │                        │ │
│  │  │15/10/10 │  │25/20/30 │       │  │  │                        │ │
│  │  │ [Build] │  │ [Build] │       │  │  │                        │ │
│  │  └─────────┘  └─────────┘       │  │  │                        │ │
│  │                                   │  │  │                        │ │
│  │  ┌─────────┐  ┌─────────┐       │  │  │                        │ │
│  │  │ Market  │  │ Tavern  │       │  │  │                        │ │
│  │  │         │  │         │       │  │  │                        │ │
│  │  │💰+15/hr │  │🍎-4/hr  │       │  │  │                        │ │
│  │  │         │  │💰+12/hr │       │  │  │                        │ │
│  │  │Cost:    │  │Cost:    │       │  │  │                        │ │
│  │  │30/25/45 │  │20/15/35 │       │  │  │                        │ │
│  │  │ [Build] │  │ [Build] │       │  │  │                        │ │
│  │  └─────────┘  └─────────┘       │  │  │                        │ │
│  │                                   │  │  │                        │ │
│  └───────────────────────────────────┘  │  └────────────────────────┘ │
│                                                                        │
├────────────────────────────────────────────────────────────────────────┤
│                           [Close (C)]                                  │
└────────────────────────────────────────────────────────────────────────┘
```

## Legend

- 🍎 = Food
- ⛏️ = Coal  
- 💰 = Gold
- +X/hr = Production per hour
- -X/hr = Consumption per hour
- Cost format: Food/Coal/Gold

## UI Elements

### Header Section
- **Title**: "City Management"
- **Subtitle**: "Build and manage city buildings"
- **Resources**: Shows current amounts of Food, Coal, Gold

### Left Panel - Available Buildings
- **Grid Layout**: 2 columns of building cards
- **Building Card Contents**:
  - Building name
  - Icon/preview
  - Resource production/consumption per hour
  - Build cost (Food/Coal/Gold)
  - Build button
- **Scrollable**: If more than 8 buildings

### Right Panel - Construction Queue
- **List Layout**: Vertical list of queued buildings
- **Queue Item Contents**:
  - Status: "Building" or "Queued"
  - Building name
  - Remaining time in hours
- **Updates**: Automatically updates as buildings complete

### Footer
- **Close Button**: Returns to main game view (also C key)

## Color Scheme

Following the existing UI pattern from other panels:
- **Background**: Dark semi-transparent (#1a1a1a with alpha)
- **Panel**: Slightly lighter (#2a2a2a)
- **Text**: Light gray (#e0e0e0)
- **Accent**: Blue (#4a90e2) for interactive elements
- **Production (positive)**: Green (#4ade80)
- **Consumption (negative)**: Red (#ef4444)
- **Disabled**: Gray (#6b7280)

## Interaction Flow

1. **Opening**:
   - Press C key from anywhere in game
   - City screen appears with semi-transparent overlay
   - Background game is still visible but dimmed

2. **Browsing Buildings**:
   - Scroll through available buildings
   - Hover over building card shows tooltip with details
   - Building cards show if affordable (green tint) or not (red tint)

3. **Queuing Construction**:
   - Click "Build" button on building card
   - Resources are immediately deducted
   - Building appears in construction queue
   - If resources insufficient, shows error notification

4. **Monitoring Queue**:
   - First item shows "Building" with countdown
   - Other items show "Queued" 
   - Queue processes automatically over time
   - Completed buildings are removed from queue

5. **Closing**:
   - Click Close button or press C key again
   - Screen fades out, returns to main game

## Responsive Design

- **Minimum Size**: 800x600 panel
- **Center Aligned**: Panel centered on screen
- **Scalable**: Adjusts to different screen resolutions
- **Font Sizes**: 
  - Title: 24pt
  - Headers: 16pt
  - Body: 14pt
  - Details: 12pt

## Accessibility

- **Keyboard Navigation**: C key to toggle, Esc to close
- **Clear Hierarchy**: Visual hierarchy with headers and sections
- **Color Blind Friendly**: Icons supplement colors
- **High Contrast**: Dark background with light text
- **Tooltips**: Additional info on hover
