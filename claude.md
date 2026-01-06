# Bike Game - Development Standards

## Project Structure
```
res://
├── scenes/           # .tscn files
│   ├── bike/         # Bike scenes
│   ├── stages/       # Stage scenes (stage_1.tscn, etc.)
│   ├── hub/          # Hub scene
│   └── ui/           # UI scenes
├── scripts/          # .gd files
│   ├── bike/         # Bike-related scripts
│   ├── systems/      # Core systems (economy, run_manager, etc.)
│   ├── ui/           # UI scripts
│   └── autoload/     # Singleton scripts
├── resources/        # .tres files (bike stats, upgrade data)
├── assets/           # Art, audio (future)
└── tests/            # GUT test files
```

## Godot Version
- **Godot 4.5** with Forward+ renderer

## Testing with GUT
- Install GUT addon for unit/integration tests
- Test files: `res://tests/test_*.gd`
- Run: `godot --headless -s addons/gut/gut_cmdline.gd`
- Required coverage: Economy calculations, bike stats, run state

## Code Standards
- Use static typing: `var speed: float = 0.0`
- Prefix private vars with underscore: `var _internal_state`
- Signals use past tense: `signal stage_cleared`, `signal run_failed`
- Constants in SCREAMING_SNAKE_CASE
- Use `class_name` for reusable classes

## Linting
- Use gdlint (via pip): `pip install gdtoolkit`
- Run: `gdlint scripts/`
- Format: `gdformat scripts/`

## Scene Standards
- One root node per scene
- Use `%UniqueNames` for important nodes accessed via code
- Prefer composition over inheritance

## Controls
- **W**: Accelerate (bike moves forward when held)
- **S**: Brake
- **A/D**: Steer left/right
- **Mouse**: Controls camera orientation; forward direction follows mouse look

## Game Architecture

### Autoload Singletons
| Name | Path | Purpose |
|------|------|---------|
| GameManager | `scripts/autoload/game_manager.gd` | Overall game state |
| Economy | `scripts/autoload/economy.gd` | Wallet, Pot, transactions |
| RunManager | `scripts/autoload/run_manager.gd` | Current run state, stage progression |
| BikeData | `scripts/autoload/bike_data.gd` | Bike stats, upgrades |

### Economy Constants
- Base Pot Unit: 100
- Reward Curve: [0, 1, 3, 8, 20, 50, 120, 300, 750] (index = stage)
- Upgrade Tier Costs: [150, 450, 1200, 3000, 7500]

### Bike Stats (1-10 scale)
- Top Speed, Acceleration, Handling, Stability, Jump Efficiency
- Upgrades add +0.5 per tier to respective stat
