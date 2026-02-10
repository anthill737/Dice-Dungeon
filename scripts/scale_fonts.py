"""Batch replace hardcoded font sizes with scale_font() calls across game files."""
import re
import os

os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# Files to process and the game reference they use
files_config = {
    'dice_dungeon_explorer.py': 'self',
    'explorer/combat.py': 'self.game',
    'explorer/inventory_display.py': 'self.game',
    'explorer/inventory_equipment.py': 'self.game',
    'explorer/inventory_pickup.py': 'self.game',
    'explorer/inventory_usage.py': 'self.game',
    'explorer/store.py': 'self.game',
    'explorer/ui_character_menu.py': 'self.game',
    'explorer/ui_dialogs.py': 'self.game',
    'explorer/lore.py': 'self.game',
    'explorer/quests.py': 'self.game',
    'explorer/tutorial.py': 'self.game',
    'explorer/save_system.py': 'self.game',
}

total_replacements = 0

# Pattern: font=('FontName', <integer>, ...) where integer is NOT already in scale_font()
pattern = r"(font=\('(?:Arial|Georgia)',\s*)(\d+)((?:,\s*'[^']*')?\s*\))"

for filepath, ref in files_config.items():
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()

        def make_replacer(game_ref):
            def replace_font(match):
                prefix = match.group(1)
                size = match.group(2)
                suffix = match.group(3)
                return f'{prefix}{game_ref}.scale_font({size}){suffix}'
            return replace_font

        replacer = make_replacer(ref)

        lines = content.split('\n')
        new_lines = []
        file_count = 0
        for line in lines:
            if 'scale_font' not in line:
                new_line, n = re.subn(pattern, replacer, line)
                file_count += n
                new_lines.append(new_line)
            else:
                new_lines.append(line)

        new_content = '\n'.join(new_lines)

        if file_count > 0:
            with open(filepath, 'w', encoding='utf-8') as f:
                f.write(new_content)
            print(f'{filepath}: {file_count} replacements')
            total_replacements += file_count
        else:
            print(f'{filepath}: 0 replacements (all already scaled)')

    except FileNotFoundError:
        print(f'{filepath}: FILE NOT FOUND')
    except Exception as e:
        print(f'{filepath}: ERROR - {e}')

print(f'\nTotal: {total_replacements} font replacements across all files')
