import sys
import re
import os

def extract_changelog(version_tag: str):
    clean_ver = version_tag.lstrip('v').strip()
    if not os.path.exists('CHANGELOG.md'):
        print('CHANGELOG.md not found.')
        return

    with open('CHANGELOG.md', 'r', encoding='utf-8') as f:
        content = f.read()

    pattern = r'## \[' + re.escape(clean_ver) + r'\].*?\n(.*?)(?=\n## \[|\Z)'
    match = re.search(pattern, content, re.DOTALL)
    if match:
        notes = match.group(1).strip()
        with open('release_notes.md', 'w', encoding='utf-8') as out:
            out.write(notes + '\n')
        print(f'Successfully extracted changelog for {clean_ver}')
    else:
        print(f'Version {clean_ver} not found in CHANGELOG.md')

if __name__ == '__main__':
    tag = sys.argv[1] if len(sys.argv) > 1 else ''
    extract_changelog(tag)
