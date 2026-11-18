import sys
import re
import os


def _section(content: str, heading: str):
    """Returns the body of `## [<heading>]` or None when absent."""
    pattern = r'## \[' + re.escape(heading) + r'\].*?\n(.*?)(?=\n## \[|\Z)'
    match = re.search(pattern, content, re.DOTALL)
    return match.group(1).strip() if match else None


def extract_changelog(version_tag: str) -> int:
    """Writes release_notes.md and returns a process exit code.

    A pre-release tag (`v1.2.0-beta.1`) has no section of its own in
    CHANGELOG.md: the entry belongs to the eventual `1.2.0`. It uses the
    `[Unreleased]` section when present, otherwise writes an empty body so the
    `body_path` the release step requires still exists, and lets
    `generate_release_notes` fill it from the commit range.

    A stable tag without a section is a real mistake in the changelog, so it
    fails the job instead of publishing a release with no notes.
    """
    clean_ver = version_tag.lstrip('v').strip()
    is_pre_release = '-' in clean_ver

    if not os.path.exists('CHANGELOG.md'):
        print('ERRO: CHANGELOG.md nao encontrado.')
        return 2

    with open('CHANGELOG.md', 'r', encoding='utf-8') as f:
        content = f.read()

    if is_pre_release:
        base_ver = clean_ver.split('-')[0]
        notes = _section(content, 'Unreleased')
        if notes is None:
            notes = _section(content, base_ver)

        if notes is None:
            notes = ''
            print(
                f'Pre-release {clean_ver}: sem secao [Unreleased]; '
                'corpo vazio, generate_release_notes preenche.'
            )
        else:
            print(f'Pre-release {clean_ver}: usando as notas de {base_ver}.')

        with open('release_notes.md', 'w', encoding='utf-8') as out:
            out.write(notes + '\n' if notes else '')
        return 0

    notes = _section(content, clean_ver)
    if notes is None:
        print(f'ERRO: versao {clean_ver} nao encontrada em CHANGELOG.md')
        return 2

    with open('release_notes.md', 'w', encoding='utf-8') as out:
        out.write(notes + '\n')
    print(f'Notas extraidas para {clean_ver}')
    return 0


if __name__ == '__main__':
    tag = sys.argv[1] if len(sys.argv) > 1 else ''
    sys.exit(extract_changelog(tag))