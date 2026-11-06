# tester-engine (files only, never merge to main)

Tester engine for David4: the Godot 4.7.2 headless build with Voxel Tools 1.7 for Linux x86_64, plus Python wheels.

Unpack the engine:

    xz -dk godot-4.7.2-voxel1.7-linux-headless.xz
    chmod +x godot-4.7.2-voxel1.7-linux-headless

Install the Python packages offline (pip picks the wheel for your Python, 3.10 to 3.13):

    python3 -m pip install --no-index --find-links wheels numpy zstandard

Check your Python version first with `python3 --version`.
