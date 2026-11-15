# Yarrow and chamomile, real game, 1 Nov 2026 (Kathreen)
Commit 68ca99f0 (warm cream heads, darker stems). Rig `look_rig.sh --cam first`, yarrow at 53302,68423 facing N; chamomile at 53326.7,68442.2 facing S.
- real/yarrow.png: white drift at the foot of a trunk, in shade. Reads clearly as white flowers from 5 to 10 m; heads still look like cool grey-white faceted confetti, no warm tint visible in shade. Stems not visible at this distance (no glassy stems seen). Rating 3.5 of 5.
- real/chamomile.png: left edge shows white daisies; the white petals carry a grey-blue speckle (leaf texture or per-face normals on the petals), not a clean white. Yellow neighbours (arnica, dandelion) read well. Rating 3 of 5.
- Offline sheets (`*_offline.png`) use plain materials and cannot judge shade colour (rated for shape only).
Next fix if Dave says No: petals use the bark/leaf material with a texture; give daisy and umbel heads an unlit or smooth-normal flat material (flora_view.gd, tell Kathleen).
