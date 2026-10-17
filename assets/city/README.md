# ORVETHRA – Mobile city ground textures

Place the two optimized textures supplied in chat into this directory,
using the **exact filenames**:

- `orvethra_cobblestone_mobile.webp` — cobblestone roads and central square, 1024×344
- `orvethra_grass_mobile.webp` — green fields and lawns, 512×512

`scripts/city_preview.gd` loads these assets when present. The optimized
city material uses a **single texture fetch per shaded pixel**, mipmapping and
world-space repetition, without building extra 3D tiles or colliders.
The original procedural materials remain as fallback until these files are
committed. Roads, collision, Greg's paths, quests and camera are unchanged.

Target: Godot 4.3 Compatibility / OpenGL ES 3.0, ARM64, 30 FPS.
