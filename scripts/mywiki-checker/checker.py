"""Local myWiki policy for the obsidian-thing write hook

| Area | Checks |
| --- | --- |
| Outline | Exactly one H1 (error), heading dash, level jump, flat H2 |
| Callouts | Title, meta label and separator before a nested callout |
| Prose | Paragraph and caption lengths, math spacing, footnotes, self-links |
| Metadata | Profile fields and order, created, summary, host and aliases |
| Vault | Duplicate aliases, tag use, navigation and local attachments |

Keep this file with examples/checker.py. The checker requires vault context for Markdown writes.
The script never changes a note.
"""

import json
import re
import runpy
import sys
from collections import Counter, defaultdict
from datetime import date
from fnmatch import fnmatchcase
from pathlib import Path, PurePosixPath

import yaml
from markdown_it import MarkdownIt
from mdit_py_plugins.dollarmath import dollarmath_plugin
from mdit_py_plugins.footnote import footnote_plugin
from mdit_py_plugins.front_matter import front_matter_plugin
from yaml.nodes import MappingNode, ScalarNode, SequenceNode


EXAMPLE_SCAN = runpy.run_path(str(Path(__file__).resolve().parent / 'examples' / 'checker.py'))['scan']
WIKI = re.compile(r'(!?)\[\[([^\[\]\n]+)\]\]')
WORDS = re.compile(r'[^\W_]+(?:[-’\'][^\W_]+)*')
CALLOUT = re.compile(r'^ {0,3}((?:>[ \t]?)+)\s*\[![^\]\s]+\][+-]?\s*(.*)$')
META_LABEL = re.compile(r'^(?:Пример(?:ы)?|Контрпример|Следствие|Замечание|Упражнение|Мотивировка|'
                        r'Лемма|Теорема|Рецепт|Трюк|Приём|Ключ|Смысл|Почему|Идея|Вывод|Итог|Суть|'
                        r'Пояснение|Критерий|Осторожно|Определение|Доказательство|Задача|Наблюдение|'
                        r'Аналогия|Интуиция|Тонкость|Отрицание)(?:$|\s*[:—–«\"])', re.I)
QUOTE_ONLY = re.compile(r'^ {0,3}(?:>[ \t]*)+$')
NUMERIC_ALIAS = re.compile(r'[+-]?(?:[0-9]+(?:\.[0-9]*)?|\.[0-9]+)(?:e[+-]?[0-9]+)?', re.I)
TAG = re.compile(r'\w+(?:/\w+)*')
SHARED_ALIASES = frozenset()
IGNORED_TAGS = {'excalidraw'}
NAV_KEYS = ('up', 'prev', 'next')
CONTEXT_PROPERTIES = frozenset({'aliases', 'tags', *NAV_KEYS})
COMMON_FIELDS = {'preset', 'aliases', 'tags', 'cssclasses', 'publish', 'icon'}
FIELD_ORDER = ('title', 'up', 'prev', 'next', 'lectures', 'sources', 'created', 'summary', 'tags', 'aliases')
SUMMARY_MAX_WORDS = 12
PARAGRAPH_MAX_WORDS = 60
CAPTION_MAX_WORDS = 40
FLAT_H2_LIMIT = 6
MAX_WARNINGS = 12
MAX_REJECTION_REASONS = 3

PROFILE_FIELDS = {
    'lecture': ('title created summary', 'order up prev next lectures sources media_link published'),
    'lecture-moc': ('title created summary', 'up prev next lectures sources'),
    'paper': ('title authors year created summary', 'doi arxiv url venue sources'),
    'zettel': ('created', 'title summary up source sources media_link'),
    'term': ('created', ''),
    'diary': ('created', ('mark', 'sleep hours', 'weight', 'neighbours', 'mood music', 'date')),
    'diary-periodic': ('created', ('mark', 'sleep hours', 'weight', 'neighbours', 'mood music', 'date')),
    'hub-person': ('created aliases', 'birthday tg phone home title summary'),
    'hub-project': ('created aliases', 'title summary up'),
    'hub-moc': ('created aliases', 'title summary up'),
    'hub-event': ('created aliases', 'date title summary'),
    'project-note': ('created summary up', 'title prev next sources status superseded_by'),
}
PROFILE_PATHS = (
    ('00. Термины/*', 'term'),
    ('Статьи/*', 'paper'),
    ('02. Zettelkasten/*', 'zettel'),
    ('03. Записки/01. Дневник/01. Daily/*', 'diary'),
    ('03. Записки/01. Дневник/*', 'diary-periodic'),
    ('03. Записки/02. Ядра/01. Люди/*', 'hub-person'),
    ('03. Записки/02. Ядра/02. Проекты/*', 'hub-project'),
    ('03. Записки/02. Ядра/03. События/*', 'hub-event'),
)


def wiki_rule(state, silent):
    match = WIKI.match(state.src, state.pos, state.posMax)
    if match is None:
        return False
    if not silent:
        token = state.push('wiki_embed' if match[1] else 'wiki_link', '', 0)
        token.content = match[0]
        target, _, label = match[2].replace('\\|', '|').partition('|')
        token.meta = {'target': target.strip(), 'label': label.strip()}
    state.pos = match.end()
    return True


MARKDOWN = (MarkdownIt('commonmark').enable('table')
            .use(front_matter_plugin)
            .use(footnote_plugin, inline=False, move_to_end=False, always_match_refs=True)
            .use(dollarmath_plugin, allow_labels=False, double_inline=True))
MARKDOWN.inline.ruler.before('link', 'wiki', wiki_rule)


def scalar(node):
    return node.value if isinstance(node, ScalarNode) else ''


def yaml_properties(token):
    if token is None:
        return {}
    try:
        node = yaml.compose(token.content, Loader=yaml.BaseLoader)
    except (yaml.YAMLError, RecursionError):
        return None
    if node is None:
        return {}
    if not isinstance(node, MappingNode):
        return None
    result = {}
    for key, value in node.value:
        if not isinstance(key, ScalarNode) or key.value in result:
            return None
        result[key.value] = value
    return result


def profile_for(path, properties, files):
    declared = scalar(properties.get('preset'))
    if declared:
        return declared
    if '00. Вложения' in PurePosixPath(path).parts:
        return ''
    for pattern, profile in PROFILE_PATHS:
        if fnmatchcase(path, pattern):
            if profile == 'hub-project':
                parts = PurePosixPath(path).parts
                if len(parts) >= 5:
                    hub = '/'.join((*parts[:4], parts[3] + '.md'))
                    if hub in files:
                        return 'hub-moc' if hub == path else 'project-note'
            return profile
    return ''


def plain_inline(children):
    return ''.join(c.content if c.type == 'text' else
                   c.meta['label'] or c.meta['target'] if c.type == 'wiki_link' else ' '
                   for c in children if c.nesting == 0)


def heading_rules(outline, add):
    heads = [(title, line) for level, title, line in outline if level == 1]
    if not heads:
        add('single-h1', 'missing', 1, 'У заметки должен быть заголовок H1')
    for _, line in heads[1:]:
        add('single-h1', 'extra', line, 'Оставь в заметке только один заголовок H1')
    previous = 1
    for level, title, line in outline:
        dash = re.search(r'\s[—–]\s+(.+)', title)
        if dash and not re.match(r'это\b', dash[1], re.I):
            add('heading-dash', title, line, 'Проверь, нужен ли заголовку хвост после тире')
        if level > previous + 1:
            add('heading-level-jump', (previous, level, title), line, 'Не пропускай уровень заголовка')
        previous = level
    h2 = [(title, line) for level, title, line in outline if level == 2]
    if len(h2) >= FLAT_H2_LIMIT and not any(level > 2 for level, _, _ in outline):
        add('headings-flat', 'outline', h2[0][1], 'Проверь, можно ли сгруппировать заголовки H2')


def callout_rules(raw, at, stack, add):
    match = CALLOUT.match(raw[at])
    if match is None or match[1].count('>') != len(stack) + 1:
        return False
    title = match[2].strip()
    if not title:
        add('callout-title-empty', raw[at].strip(), at + 1, 'Добавь заголовок callout-а')
    elif META_LABEL.match(title) and not re.search(r'[—–]\s+это\b', title, re.I):
        add('callout-title-label', title, at + 1, 'Вынеси в заголовок саму мысль, а не мета-ярлык')
    if any(stack) and not (at and QUOTE_ONLY.fullmatch(raw[at - 1])
                           and raw[at - 1].count('>') == len(stack)):
        add('callout-separator', title, at + 1, 'Отдели вложенный callout строкой с >')
    return True


def note_rules(text, tokens, links, add):
    raw = text.splitlines()
    outline, quotes = [], []
    definitions, references, last_content = {}, {}, {}
    section = -1
    in_definition = 0
    previous_embed_end = -1
    for index, block in enumerate(tokens):
        if block.type == 'blockquote_close':
            quotes.pop()
        if block.type == 'footnote_reference_close':
            in_definition -= 1
        if not block.map:
            continue
        start, end = block.map
        line = start + 1
        if block.type == 'blockquote_open':
            quotes.append(callout_rules(raw, start, quotes, add))
        if block.type == 'heading_open' and block.level == 0:
            title = tokens[index + 1]
            outline.append((int(block.tag[1]), plain_inline(title.children or []).strip(), line))
            section = start
        if block.type == 'footnote_reference_open':
            definitions[block.meta['label']] = (start, section)
            in_definition += 1
        if block.level == 0 and not in_definition and block.type != 'front_matter':
            last_content[section] = start
        if block.type != 'inline':
            continue
        children = block.children or []
        for token in children:
            if token.type == 'math_inline' and token.content != token.content.strip():
                add('math-inline-space', token.content.strip(), line, 'Убери пробелы сразу после и перед $')
            elif token.type == 'footnote_ref' and not in_definition:
                references.setdefault(token.meta['label'], (line, section))
            elif token.type == 'wiki_link' and not token.meta['label']:
                target, _, anchor = token.meta['target'].partition('#')
                if anchor and not anchor.startswith('^') and (
                    not target or token.content in links
                ):
                    add('self-heading-link', token.content, line, 'Добавь подпись к ссылке на свой раздел')
        if index == 0 or tokens[index - 1].type != 'paragraph_open' or in_definition:
            continue
        significant = [c for c in children if c.type != 'text' or c.content.strip()]
        is_embed = len(significant) == 1 and significant[0].type in {'wiki_embed', 'image'}
        caption = (previous_embed_end >= 0 and previous_embed_end <= start
                   and all(not row.strip() for row in raw[previous_embed_end:start]))
        previous_embed_end = end if is_embed else -1
        plain = plain_inline(children)
        count = len(WORDS.findall(plain))
        limit = CAPTION_MAX_WORDS if caption else PARAGRAPH_MAX_WORDS
        if count > limit:
            rule = 'caption-length' if caption else 'paragraph-length'
            add(rule, block.content, line, f'Сократи текст: {count} слов, предел {limit}')
    heading_rules(outline, add)
    for key, (line, _) in references.items():
        if key not in definitions:
            add('footnote-missing', key, line, 'У ссылки на сноску нет определения')
    for key, (start, section) in definitions.items():
        if key not in references:
            add('footnote-unused', key, start + 1, 'На сноску нет ссылки')
        elif section != references[key][1] or last_content.get(section, -1) > start:
            add('footnote-position', key, start + 1, 'Поставь определение в конце секции первого упоминания')
    for rule, payload, line in EXAMPLE_SCAN(text):
        message = ('Поставь оба $$ на отдельных строках' if rule == 'math-block-layout'
                   else 'Используй * и ** для выделения вместо подчёркиваний')
        add(rule, payload, line, message)


def valid_created(node):
    value = scalar(node)
    if not isinstance(node, ScalarNode) or node.style is not None or not re.fullmatch(r'[0-9]{4}-[0-9]{2}-[0-9]{2}', value):
        return False
    try:
        date.fromisoformat(value)
    except ValueError:
        return False
    return True


def metadata_rules(properties, profile, add):
    if profile in PROFILE_FIELDS:
        required, extra = PROFILE_FIELDS[profile]
        required = required.split()
        allowed = COMMON_FIELDS | set(required) | set(extra.split() if isinstance(extra, str) else extra)
        for key in required:
            if key not in properties:
                add('field-missing', (profile, key), 1, f'Добавь обязательное поле {key}')
        for key in properties.keys() - allowed - ({'host'} if profile in {'lecture', 'lecture-moc'} else set()):
            add('field-extra', (profile, key), 1, 'Поле не предусмотрено профилем заметки')
        keys = tuple(key for key in properties if key in FIELD_ORDER)
        if keys != tuple(key for key in FIELD_ORDER if key in keys):
            add('field-order', keys, 1, 'Проверь порядок полей шапки')
    if profile in {'lecture', 'lecture-moc'} and 'host' in properties:
        add('host-instead-of-up', 'host', 1, 'В профиле курса для родительской заметки используется up')
    if 'created' in properties and not valid_created(properties['created']):
        add('created-format', scalar(properties['created']), 1, 'Укажи реальную дату YYYY-MM-DD без кавычек')
    if 'summary' in properties:
        node = properties['summary']
        if not isinstance(node, ScalarNode) or not node.value.strip():
            add('summary-markup', 'shape', 1, 'Summary должен быть непустым простым текстом')
        else:
            summary = node.value.strip()
            parsed = MARKDOWN.parseInline(summary)[0].children or []
            plain = plain_inline(parsed)
            if any(token.type != 'text' for token in parsed):
                add('summary-markup', summary, 1, 'Убери разметку из summary')
            first = next((char for char in plain if char.isalpha()), '')
            if first.islower():
                add('summary-capital', summary, 1, 'Начни summary с заглавной буквы')
            if summary.endswith('.'):
                add('summary-period', summary, 1, 'Убери последнюю точку из summary')
            if len(WORDS.findall(plain)) > SUMMARY_MAX_WORDS:
                add('summary-length', summary, 1, f'Сократи summary до {SUMMARY_MAX_WORDS} слов')
    aliases = properties.get('aliases')
    if isinstance(aliases, SequenceNode) and not aliases.value:
        add('aliases-empty', 'aliases', 1, 'Не оставляй пустой список aliases')
    for node in aliases.value if isinstance(aliases, SequenceNode) else [aliases]:
        if NUMERIC_ALIAS.fullmatch(scalar(node).strip()):
            add('alias-number', scalar(node), 1, 'Алиас не должен состоять только из числа')


def scalar_list(value):
    return value if isinstance(value, list) else [value] if isinstance(value, str) else []


def property_values(properties, key):
    node = properties.get(key)
    if isinstance(node, SequenceNode):
        return [scalar(value) for value in node.value]
    return [node.value] if isinstance(node, ScalarNode) else []


def tag_key(value):
    value = re.sub(r'^\d+\.\s*', '', value.strip())
    return re.sub(r'[\s_-]+', '_', value.casefold())


def tag_rules(path, properties, profile, current, add):
    parent_labels = set(PurePosixPath(path).parts[:-1]) | {profile}
    created = scalar(properties.get('created'))
    if re.match(r'^[0-9]{4}-', created):
        parent_labels.add(created[:4])
    for link in current.get('property_links', {}).get('up', []):
        parent_labels.add(PurePosixPath(link['target']).stem)
        parent_labels.update(PurePosixPath(p).stem for p in link['resolved'])
    equivalent = {tag_key(label) for label in parent_labels if label}
    for tag in property_values(properties, 'tags'):
        if tag in IGNORED_TAGS:
            continue
        if tag != tag.casefold() or not TAG.fullmatch(tag) or not any(c.isalpha() for c in tag):
            add('tag-format', tag, 1, 'Тег нужен в нижнем регистре, без #, пробелов и дефисов')
        if tag_key(tag) in equivalent:
            add('tag-redundant', tag, 1, 'Тег дублирует папку, тип, год или поле up')


def tag_owners(notes):
    result = defaultdict(set)
    for path, note in notes.items():
        for value in scalar_list(note['properties'].get('tags')):
            tag = value.strip().removeprefix('#').casefold()
            if tag and tag not in IGNORED_TAGS:
                result[tag].add(path)
    return result


def note_targets(links):
    return {target for link in links for target in link['resolved'] if target.lower().endswith('.md')}


def vault_rules(path, context, current, body_links, add):
    if current is None:
        return
    notes = context['notes'] | {path: current}
    aliases = {v.strip().casefold() for v in scalar_list(current['properties'].get('aliases')) if v.strip()}
    for other, note in context['notes'].items():
        other_aliases = {v.strip().casefold() for v in scalar_list(note['properties'].get('aliases'))}
        for shared in sorted((aliases & other_aliases) - SHARED_ALIASES):
            add('alias-duplicate', (shared, other), 1, 'Алиас уже есть у другой заметки')
    old = (context.get('before') or {}).get('properties', {})
    watched_tags = tag_owners({path: current}) | tag_owners({path: {'properties': old}})
    tags = tag_owners(notes)
    groups = defaultdict(set)
    up_links = {}
    for source, note in notes.items():
        up_links[source] = note_targets(note['property_links'].get('up', ())) - {source}
        for parent in up_links[source]:
            groups[parent].add(source)
    for tag in sorted(watched_tags):
        owners = tags[tag]
        if len(owners) == 1:
            add('tag-singleton', (tag, next(iter(owners))), 1, 'Тег встречается только у одной заметки')
        if len(owners) >= 2:
            for parent, children in groups.items():
                if up_links.get(parent) and owners in (children, children | {parent}):
                    add('tag-mirrors-moc', (tag, parent), 1, 'Тег повторяет группу sub-MOC')
    nav_rules(path, notes, add)
    attachment_dir = PurePosixPath(path).parent / '00. Вложения'
    for link in body_links:
        if link['embed'] and len(link['resolved']) == 1:
            destination = PurePosixPath(link['resolved'][0])
            if destination.suffix.lower() != '.md' and not destination.is_relative_to(attachment_dir):
                add('local-attachment', link['raw'], 1, 'Вложение должно быть в локальной папке 00. Вложения')


def nav_rules(path, notes, add):
    for source, note in notes.items():
        for direction in NAV_KEYS:
            links = note['property_links'].get(direction, ())
            if source == path and direction in note['properties'] and not links:
                add('nav-target', (source, direction, 'shape'), 1, f'Укажи в {direction} вики-ссылку на заметку')
            for link in links:
                destinations = note_targets((link,))
                if source != path and path not in destinations:
                    continue
                identity = (source, direction, link['raw'])
                if not destinations:
                    add('nav-target', identity, 1, f'Поле {direction} не ведёт к доступной заметке')
                    continue
                if direction == 'up':
                    continue
                reverse = 'prev' if direction == 'next' else 'next'
                candidates = [notes.get(dest) for dest in destinations]
                if any(n is None or n['frontmatter'] in {'unreadable', 'invalid'} for n in candidates):
                    continue
                if not any(source in note_targets(n['property_links'].get(reverse, ())) for n in candidates):
                    add('nav-reciprocal', identity, 1, f'Нет ответной ссылки {reverse} для {direction}')


def scan(path, text, links, context, current):
    findings = []

    def add(rule, key, line, message):
        findings.append((rule, key, line, message))

    tokens = MARKDOWN.parse(text.removeprefix('\ufeff'))
    files = set(context['files'])
    self_links = {link['raw'] for link in links if link['self']}
    note_rules(text.removeprefix('\ufeff'), tokens, self_links, add)
    header = next((token for token in tokens if token.type == 'front_matter'), None)
    properties = yaml_properties(header)
    if properties is not None:
        profile = profile_for(path, properties, files)
        metadata_rules(properties, profile, add)
        tag_rules(path, properties, profile, current or {}, add)
    vault_rules(path, context, current, links, add)
    return findings


def check(change):
    if change['version'] != 1:
        raise ValueError('Unsupported check protocol')
    path = change['path']
    if PurePosixPath(path).suffix.lower() != '.md':
        return {'decision': 'allow'}
    context = change.get('vault_context')
    requested = context.get('property_names', ()) if context is not None else ()
    missing = CONTEXT_PROPERTIES.difference(requested)
    if context is None or missing:
        names = ', '.join(sorted(missing))
        return {'decision': 'reject',
                'message': f'Нет нужного контекста волта. Добавь в checker.vault_context_properties: {names}'}
    links = change['links']
    before = change['before']
    old = (scan(path, before, context['links_before'], context, context['before'])
           if before is not None else [])
    remaining = Counter((rule, key) for rule, key, _, _ in old)
    new_warnings, existing_warnings, errors = [], [], []
    for rule, key, line, message in scan(path, change['after'], links, context, context['after']):
        label = f'[{rule}, line {line}] {message}'
        if remaining[rule, key]:
            remaining[rule, key] -= 1
            existing_warnings.append('Existing: ' + label)
        elif rule == 'single-h1':
            errors.append(label)
        else:
            new_warnings.append(label)
    if errors:
        return {'decision': 'reject', 'message': '; '.join(errors[:MAX_REJECTION_REASONS])}
    warnings = new_warnings + existing_warnings
    if len(warnings) > MAX_WARNINGS:
        warnings = warnings[:MAX_WARNINGS] + [f'Ещё предупреждений: {len(warnings) - MAX_WARNINGS}']
    return {'decision': 'allow', **({'warnings': warnings} if warnings else {})}


if __name__ == '__main__':
    json.dump(check(json.load(sys.stdin)), sys.stdout)
