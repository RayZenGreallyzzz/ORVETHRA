# ORVETHRA Map Builder v0.1 — Android

Separate editing app; not the game itself. Godot 4.6 Compatibility renderer (OpenGL ES). Optimized *targets* for IT-801C (A523, 4 GB RAM); real device validation still needed.

**Camera**: drag on free world surface with one finger to orbit; pinch to zoom. On PC right mouse drag and mouse wheel.

**Placing**: choose a prefab, press "Поставить", tap the ground. Use "Выбрать" then "Переместить" and tap another location. Buttons rotate, resize, duplicate or delete.

**Your models**: "Модель GLB" opens the Android system picker (SAF, Godot 4.6). Supports .glb files only, not .blend/.fbx. Limits: up to 8 MB per GLB, 18,000 mesh triangles, max 4 unique models, 70 placed objects total. Prevents some common RAM overloads; cannot guarantee crash-free operation. Images/textures inside GLB can still be resource-heavy.

**Save**: autosave locally every ~1.5 sec after changes. Save / resume. "Экспорт карты" -> `.orvmap` (ZIP with world.json + any custom GLB files), can later reopen in Map Builder. "Экспорт GLB" -> combined 3D scene, import this file into the existing ORVETHRA Godot game project as a 3D level mesh.

Godot game scene still needs gameplay collisions, spawn points, scripts, navmesh, etc: GLB only contains geometry and hierarchy. To use the map, copy the exported GLB into `assets/maps/`, import via Godot, instantiate in a 3D scene, then add collision shapes for buildings/ground.

**Android caveat**: Native file picker is implemented with Storage Access Framework on Godot >=4.6. If file import/export fails on a device, report the screenshot/log; a successful Github export does not prove Android SAF compatibility. Export directly to Documents/Downloads. Avoid importing huge scenes or non-GLB files.

**Privacy**: no account, no network requests, no storage-wide permissions. Local file access through Android picker. This is an early functional prototype, not a full Blender replacement.
