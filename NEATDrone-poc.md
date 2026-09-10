# NEATDrone — Proof of Concept

## Current playable prototype (2026-09-10)

The sections below retain the staged experiment design. This status describes
the implemented combat loop; Phase 2 darkness and hearing remain future work.
See [README](README.md) for controls, builds and test commands.

- The fixed arena has four rooms and four entrances. Each wave chooses one
  shared entrance and one alert room. Drones spawn outside the visible arena
  and use fixed ingress before handing movement over to NEAT.
- A wave starts with eight drones. One reinforcement arrives from the same
  entrance every 15 seconds. The next wave starts only when no drones remain
  alive; a final kill takes priority over a reinforcement due on that tick.
  Player position survives wave transitions and hardware intermissions.
- Every 60 seconds, OTA evaluates the current policies and assigns offspring
  networks to living drones. Position, health and motion survive the update.
  Each updated drone shows `Updated` for two seconds. Evaluation scores reset;
  drones killed since the previous evaluation contribute once, without revival.
- Both timers continue across waves and measure active simulation time. Pauses
  and hardware intermissions stop them. OTA does not advance the wave-based
  hardware unlock schedule or alter the frozen laboratory deployment.
- Drones have 3 HP; bullets deal 1 damage and travel at most 250 pixels.
  Melee deals 2 damage. Living drones cannot overlap. Acceleration is limited
  to 1200 px/s² and body turning to 540 degrees/s; vision still covers 360 degrees.
- Staying within 18 pixels of an anchor while an objective is available incurs
  an idle penalty of 3 points/s after two seconds of grace. Ingress, attacking
  in contact and movement blocked by another drone are exempt. OTA lets this
  penalty affect selection while the drone is still alive.
- New hardware opens a 15-second Master AI intermission with short internal
  thoughts, a progress bar and real background training. Only fully evaluated
  training generations are adopted. The AI is curious about the player and
  still wants to eliminate them. Training is a head start, not proof of mastery.
- Desktop and single-threaded browser exports use the same rules. The itch.io
  upload artifact is `build/NEATDrone-itch-web.zip`.

Basic behavior update: combat now starts with 120-pixel, wall-occluded player
vision and a pretrained population for both alert navigation and pursuit.
The first vision upgrade expands range to 300 pixels without adding inputs or
changing distance normalization. Projectile perception remains the next upgrade.
Direct sight temporarily suppresses the stale area report in network observations;
the area report returns when sight is lost. All movement still comes from NEAT.
Navigation progress weight is now 0.08, visual pursuit 0.35 (capped at ±60),
and player contact rewards 16. Search, injury and death terms remain in place.

Implementation update (2026-09-10): Stage C now exposes the nearest visible player
bullet's direction, normalized distance, velocity and presence (six inputs; 19 total).
Range is 300 pixels and walls occlude bullets. P queues this upgrade at a generation
boundary; the default automatic unlock is generation 10, after player vision.
Movement remains entirely controlled by NEAT. The firing laboratory gives every
genome independent shots from a stationary player beside the alert area.

Navigation fitness now rewards first progress to the alert boundary, arrival once,
and capped exploration of new cells inside the area. It does not reward further
progress toward the center; player visibility suppresses navigation rewards.
Damage costs 12 per health point and death costs an additional 35.
The bundled navigation population was retrained with this objective.
See [initial projectile experiment](docs/projectile-results.md) for measured limits:
projectile perception works, but useful combat evasion has not yet been demonstrated.

## 1. Purpose

This POC is intentionally tiny.

Its purpose is to verify that NEAT-controlled robots can evolve useful movement and combat behavior before building the larger NEATDrone game architecture.

The prototype should initially test learning in clear, isolated stages.

---

## 2. Arena

- Top-down 2D arena shooter.
- Single fixed-screen arena.
- Camera does not follow the player.
- Arena contains solid walls/boundaries.
- Robots spawn outside the player's immediate view / at arena entry locations.
- No scrolling level is required.
- Simple primitive graphics are sufficient.

Suggested visuals:

- Player: simple shape
- Robots: circles/balls
- Projectiles: small dots/lines
- Alert area: debug-visible circle
- Walls: simple rectangles

The alert circle can be hidden later but should remain visible during development.

---

## 3. Player Controls

```text
WASD        Move
Mouse       Aim
Left Mouse  Shoot
Right Mouse Melee
```

Exact mouse buttons can be changed later.

The player needs:

- movement
- health
- ranged attack
- melee attack

No inventory, weapon selection, reload system, abilities, or progression is required for the first POC.

---

## 4. Robot Basics

Robots:

- are simple circular bodies
- have health
- move in 2D
- damage the player through physical contact
- can be killed by bullets
- can be killed by melee
- start combat with pretrained pursuit and 120-pixel player vision
- initially have no hearing

The navigation laboratory still starts without vision and with random networks
to measure learning independently of the bundled combat baseline.

There must be no hard-coded player pursuit.

---

## 5. Master AI Alert Area

The POC includes one extremely simple Master AI mechanic.

A circular trigger area exists in the arena.

When the player enters the area, the Master AI informs the robots about that **area**, not the player's exact position.

Possible NEAT inputs:

```text
target_direction_x
target_direction_y
target_distance
```

These values describe the center of the alerted area.

The intended behavior is for evolution to discover that moving toward this signal is useful.

The signal never supplies the player's exact location. Direct player perception
requires short-range sight with no intervening wall, and takes priority over the signal.

This is the first test of the separation between:

- Master AI strategic information
- NEAT robot behavior

---

## 6. Initial Robot Inputs

Keep the first network deliberately small.

Suggested initial inputs:

```text
wall_front
wall_left
wall_right

target_direction_x
target_direction_y
target_distance

velocity_x
velocity_y
```

Exact wall sensing implementation can use short raycasts or equivalent collision-distance sensors.

Important:

**Wall sensing must not automatically avoid walls.**

The sensors only report that a wall exists. The neural network decides movement.

If a robot drives into a wall, the game must not automatically turn it away. It can remain stuck until its network produces another movement direction.

Evolution should therefore be capable of discovering that changing direction when a wall is detected improves fitness.

---

## 7. Initial Robot Outputs

```text
move_x
move_y
```

Clamp/normalize movement as required by the game engine.

No attack output is needed initially because robot contact itself damages the player.

---

## 8. Initial Fitness

The exact weights are experimental.

Start with a small number of understandable components rather than a complicated fitness function.

Candidate components:

```text
+ survival time
+ useful distance travelled
+ movement toward active alert area
+ reaching active alert area
+ damage dealt to player

- prolonged wall contact / being stuck
- death
```

Avoid making `distance travelled` strong enough that running randomly around the arena becomes a better strategy than pursuing the target.

Record fitness components separately in debug output so it is possible to see why a genome succeeds.

---

## 9. Evolution / Waves

Each wave represents an evaluation/generation step or contains enough evaluated individuals to create the next generation.

Combat also evaluates policies at each minute's OTA boundary while bodies remain
alive. A combat wave and a policy evaluation are therefore separate events.
Hardware unlocks still follow completed waves, not the number of OTA evaluations.

The exact population size should remain configurable.

Requirements:

- preserve champion genomes
- mutate/crossover surviving genomes using NEAT
- show generation number
- show best fitness
- show average fitness
- allow rapid restart/testing

During development, simulation speed should ideally be adjustable so many generations can be tested quickly.

---

## 10. POC Upgrade Schedule

For this first experiment, upgrades do **not** need the final Master AI scoring system.

Unlock them after predetermined generations/waves so each learning problem can be tested independently.

### Stage A — Movement and alert area

Example: Waves 1–3+

Available information:

- wall sensors
- velocity
- Master AI alert-area signal

Target behavior:

1. Robots stop wasting large amounts of time against walls.
2. Robots learn to move through the arena.
3. Robots begin moving toward the Master AI alert area.

Do not proceed until this produces a measurable improvement.

---

## 11. Vision Upgrade

After basic navigation works, introduce simple player perception.

New inputs:

```text
player_direction_x
player_direction_y
player_distance
```

Only provide these when the player is visible according to the chosen basic vision model.

Do not add a hard-coded pursuit state.

Target behavior:

**Robots learn that approaching the perceived player can lead to contact damage and higher fitness.**

Expected progression:

```text
Master AI alert
    ↓
robot approaches approximate area
    ↓
player becomes visible
    ↓
NEAT learns to pursue player
```

---

## 12. Projectile Detection Upgrade

Once pursuit works, give robots information about nearby player projectiles.

Possible inputs:

```text
projectile_direction_x
projectile_direction_y
projectile_distance
projectile_velocity_x
projectile_velocity_y
```

Prefer information about the nearest/relevant projectile rather than an arbitrarily large list of projectiles.

Do **not** provide:

```text
projectile_is_dangerous = true
```

Robots that repeatedly remain in projectile trajectories should die and receive lower fitness. Evolution should determine whether movement relative to projectile observations improves survival.

POC success:

**Observable projectile avoidance emerges without a hard-coded dodge routine.**

---

## 13. Melee Learning Test

The player can perform a short-range melee attack from the beginning.

Initially, no special `player_is_melee_attacking` input is required.

Robots can potentially learn from information already available, especially:

```text
player_distance
relative movement
```

Robots that blindly remain at extremely short range may be killed by melee and receive poor fitness.

Do not force a desired solution.

Interesting outcomes could include:

- approach and retreat behavior
- circling
- short contact attacks followed by withdrawal
- unpredictable movement near melee range

The purpose is to see what evolution discovers.

---

## 14. Debugging / Visualization

Evolutionary behavior is difficult to debug without visibility.

The POC should display at least:

```text
Generation
Wave
Population size
Alive robots
Best fitness
Average fitness
```

Useful optional debug visualization:

- wall sensor rays
- player-vision ray/direction
- projectile sensor information
- alert-area target vector
- current robot fitness
- genome/species identifier

Robots can temporarily use visual variation to identify genomes/species/champion descendants during testing.

This is debug functionality, not final game presentation.

---

## 15. POC Success Criteria

Do not judge the POC by graphics or content quantity.

### Milestone 1

After evolution, robots demonstrably become better at avoiding prolonged wall collisions and navigating the arena.

### Milestone 2

Robots demonstrably learn to approach the Master AI alert area.

### Milestone 3

After vision is introduced, robots demonstrably learn to pursue the player.

### Milestone 4

After projectile sensing is introduced, at least some evolved populations demonstrate meaningful projectile avoidance.

### Milestone 5

Melee produces an evolutionary pressure that changes close-range behavior without a hard-coded melee response.

If these work, the architecture is promising enough to expand into the full NEATDrone design.

---

## 16. Explicitly Out of Scope

Do not add these until the basic POC works:

- full facility levels
- scrolling camera
- final graphics
- sound system
- full telemetry-driven Master AI dialogue (scripted upgrade thoughts exist)
- adaptive upgrade scoring
- night vision
- thermal vision
- advanced microphone categories
- mines
- grenades
- object signatures
- object recognition
- multiple robot classes
- complex weapons
- inventory
- procedural levels
- campaign progression

These belong to the Master Plan, not the first implementation.

---

## 17. Immediate Implementation Goal

Build the smallest playable loop:

```text
Fixed arena
    ↓
WASD + mouse player
    ↓
shoot + melee
    ↓
NEAT robot population
    ↓
wall sensors
    ↓
Master AI alert circle
    ↓
fitness evaluation
    ↓
next generation
```

Then run enough generations to answer the first question:

**Do the robots learn to navigate walls and move toward the area indicated by the Master AI?**

Nothing else is required before that works.

---

## 18. POC Phase 2 — Darkness, Sound and Occlusion

Phase 2 begins only after the basic movement/alert-area test is working well enough to demonstrate measurable learning.

The purpose of Phase 2 is to introduce **imperfect perception** without yet implementing the full final upgrade system.

The arena gains three new environmental concepts:

- dark areas
- sound-producing areas/events
- solid obstacles that block line of sight

The Master AI also begins receiving simple telemetry about the conditions under which robots are destroyed.

### 18.1 Darkness zones

Add clearly defined dark regions to the arena.

The darkness system can initially be binary:

```text
is_dark = true / false
```

A robot without night vision cannot visually perceive the player while the player is inside darkness, even if the player would otherwise be inside its vision range.

The important first telemetry event is:

```text
EVENT: ROBOT_DESTROYED
player_was_in_darkness = true / false
```

The Master AI records this information. For the first POC, it does not yet need to calculate the final dynamic upgrade score from it.

Example debug telemetry:

```text
robot_kills_total = 18
robot_kills_while_player_dark = 11
```

Later this event can contribute to upgrades such as Night Vision and Thermal Vision.

### 18.2 Sound zones

Add fixed areas on the floor that generate a sound event when the player steps on or moves across them.

Examples could represent:

- metal flooring
- loose debris
- water
- machinery zones

For the POC they do not need unique gameplay graphics or realistic acoustics.

A sound event should contain only simple sensory information, for example:

```text
position
strength
category
```

Initial categories may use the shared non-semantic vocabulary:

```text
KLANG
SHIII
PLATS
ZHUUU
KOPKOP
```

The first implementation may use only one or two categories if that keeps the test simpler.

### 18.3 Gunshot sound

Every player shot creates a sound event at the firing position.

The sound is separate from the projectile itself.

This is important because a future robot may be able to hear the shot without seeing either the player or projectile.

Example:

```text
EVENT: SOUND
source_position = player_position
category = KLANG   # placeholder POC category
strength = 1.0
```

The exact category can be changed later.

### 18.4 Robot hearing upgrade

At a predetermined Phase 2 wave, robots gain hearing inputs.

Start with a deliberately weak hearing model:

```text
sound_direction_x
sound_direction_y
sound_strength
```

Do not tell NEAT what produced the sound.

Later in the POC, advanced hearing may add the sound-category inputs.

Target behavior:

- robots begin investigating useful sound events
- gunshots may reveal the player's approximate location
- environmental sounds may attract robots even when they are not useful

False reactions are desirable. The robot should have to learn which audible patterns correlate with useful outcomes.

### 18.5 Vision and line-of-sight obstacles

Add interior walls/obstacles that robots cannot see through.

Player vision detection must require a real line-of-sight test.

A robot's vision should therefore depend on:

1. player being inside vision range
2. player being inside the robot's allowed field of view, if a field of view is used
3. no opaque obstacle being between robot and player
4. lighting conditions being compatible with the robot's currently available vision hardware

The robot must never receive player position through a wall simply because the player is nearby.

These obstacles should still use the existing wall sensing/collision system for navigation.

### 18.6 Suggested Phase 2 upgrade order

Use predetermined waves at first. Exact wave numbers remain configurable.

```text
Phase 2A
- dark zones exist
- Master AI logs whether the player was in darkness during robot deaths
- robots still cannot see in darkness

Phase 2B
- basic vision with real line of sight
- interior obstacles block vision

Phase 2C
- floor sound zones
- gunshots generate sound events
- basic hearing becomes available

Phase 2D
- optional sound categories become available

Phase 2E
- night vision becomes available
```

Night vision should only expose information to NEAT. It must not introduce a hard-coded pursuit behavior.

### 18.7 Phase 2 success criteria

Phase 2 is successful when at least some of the following can be observed across generations:

- robots use line of sight rather than tracking the player through walls
- losing visual contact affects their behavior
- robots begin moving toward useful sounds
- robots can be distracted by irrelevant sounds
- darkness provides a meaningful advantage before night vision exists
- after night-vision inputs are introduced, evolution gradually reduces that advantage
- Master AI telemetry correctly records robot deaths where the player was in darkness

The goal is not polished combat. The goal is to prove that new sensory inputs can be introduced progressively and that NEAT can discover useful behavior from them.
