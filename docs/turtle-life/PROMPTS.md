# Turtle animation asset prompts

Tool: built-in `image_gen.imagegen`, transparent_background=true. No CLI fallback, no external runtime dependency.
Reference: `Sources/NotchQuota/Resources/storybook-turtle.png`, inspected before generation. Preserve the original gouache turtle identity, not the panda's 3D finish.

The following shared specification and scene instructions describe the production prompt set used for the five source PNGs:

## Shared specification

Use case: identity-preserve. Production full-body desktop-pet animation sprite sheet. Exactly 16 complete poses in a regular square 4×4 transparent PNG grid, ordered left to right then top to bottom. Same left-facing three-quarter camera, olive shell with ochre polygon borders, warm buttery yellow face, rosy cheeks, dark eyes and four short speckled feet. Preserve delicate textured gouache storybook illustration. Constant body scale, generous transparent cell gutters and consistent ground line. No text, labels, grid lines, background, floor or cast shadow. Natural four-legged anatomy, no human hands, no disconnected decorative particles, no clipping.

## Walk — source-walk.png

Single graceful crawling cycle in place. Shell stays centered. Frames 1–4 left front foot reaches forward as right front foot pushes back, with rear feet in counterphase. Frames 5–8 transfer weight and lift toes. Frames 9–12 take the opposite stride. Frames 13–16 settle back to the initial pose. Head subtly extends and nods; do not simulate movement by sliding the entire still character. No props.

## Home — source-home.png

Go home into own shell and nap. Frames 1–3 happy turtle yawns and lowers eyelids. Frames 4–6 neck retracts into the front shell opening and front feet tuck inside. Frames 7–9 head becomes barely visible and all feet tuck in. Frames 10–12 shell rests with a small sleeping face visible inside. Frames 13–16 turtle wakes and extends head and legs. Keep shell size constant; never shrink the whole animal or draw a separate house.

## Read — source-read.png

A small cream-page teal hardcover book sits in front, touching the feet. Frames 1–3 reach for and open the cover. Frames 4–6 lower head and eyes to read. Frames 7–11 use a front foot to lift one page upright and turn it to the other side. Frames 12–14 lean closer and read contentedly. Frames 15–16 close the cover and raise head. No readable page text; do not hide the face.

## Drink — source-drink.png

A tiny pale-blue shallow ceramic cup with a handle touches the front foot. Frames 1–3 notice the cup, extend neck and place front foot on rim. Frames 4–6 tilt head down with visibly bending neck and foreleg. Frames 7–10 mouth reaches water at the rim, sipping with contentedly closed eyelids. Frames 11–13 raise head. Frames 14–16 relax and nudge cup with front foot. No floating cup, no upright human-like drinking pose.

## Swim — source-swim.png

Replaces the discarded bath concept per user direction. Exact built-in generation prompt: [SWIM-PROMPT.md](SWIM-PROMPT.md). Compact natural river, paddling feet, turning and climbing onto the bank; no washing props.
