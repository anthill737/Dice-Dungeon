Drop imported music tracks for the Godot port here and reference them from `res://assets/audio/music_manifest.json`.

Recommended pattern:
- One cue per game context, such as `music_main_menu`, `music_shop`, `music_combat`, `music_game_over`, and `music_victory`
- Optional room-specific cues using names like `room_119_exploration`, `room_music_chamber`, `tag_rest_exploration`, or `difficulty_hard_combat`
- Prefer looping `.ogg` tracks for background music
