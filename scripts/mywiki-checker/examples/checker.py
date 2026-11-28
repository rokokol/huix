"""Example write checker for obsidian-thing.

Start from a script like this one when a vault needs rules that the server does not
provide. The server sends one JSON object on stdin and reads one JSON object from
stdout. A finding of the previous version warns; a new finding follows the rule level.

| Rule               | Level   | Catches                                                        |
| ------------------ | ------- | -------------------------------------------------------------- |
| math-block-layout  | warning | `$$formula$$` on one line, instead of `$$` on separate lines   |
| emphasis-asterisk  | warning | `_text_` and `__text__` instead of `*text*` and `**text**`     |

Both rules read the parsed Markdown, not the raw text. Code spans, fenced code,
YAML frontmatter and inline `$formula$` are never reported.

Run it on its own with `uv run --script examples/checker.py < request.json`. The
server runs it with its own interpreter and passes the package directories of the
server, so the imports below also work as a checker.
"""

# /// script
# requires-python = ">=3.11"
# dependencies = ["markdown-it-py>=4,<5", "mdit-py-plugins>=0.5,<1"]
# ///

import json
import sys
from collections import Counter
from pathlib import PurePosixPath

from markdown_it import MarkdownIt
from mdit_py_plugins.dollarmath import dollarmath_plugin
from mdit_py_plugins.front_matter import front_matter_plugin


MARKDOWN = (MarkdownIt('commonmark').enable('table')
            .use(front_matter_plugin)
            .use(dollarmath_plugin, allow_labels=False, double_inline=True))
MESSAGES = {
    'math-block-layout': 'Put both $$ delimiters on their own lines, with the formula between them',
    'emphasis-asterisk': 'Use * for emphasis and ** for strong text, not underscores',
}


def scan(text):
    """Yield (rule, payload, line) for the rules of this checker."""
    for block in MARKDOWN.parse(text):
        if block.map is None:
            continue
        line = block.map[0] + 1
        if block.type == 'math_block':
            if not (block.content.startswith('\n') and block.content.endswith('\n')):
                yield 'math-block-layout', block.content.strip(), line
        if block.type != 'inline':
            continue
        children = block.children or ()
        for index, child in enumerate(children):
            if child.type == 'math_inline_double':
                yield 'math-block-layout', child.content.strip(), line
            if child.type in ('em_open', 'strong_open') and child.markup.startswith('_'):
                closing = child.type.replace('_open', '_close')
                depth = 1
                for end in range(index + 1, len(children)):
                    token = children[end]
                    depth += (token.type == child.type) - (token.type == closing)
                    if depth == 0:
                        content = ''.join(item.content for item in children[index + 1:end])
                        yield 'emphasis-asterisk', content, line
                        break


def check(change):
    """Compare the proposed text with the current one and answer the server."""
    if change['version'] != 1:
        raise ValueError('Unsupported check protocol')
    if PurePosixPath(change['path']).suffix.lower() != '.md':
        return {'decision': 'allow'}
    remaining = Counter((rule, payload) for rule, payload, _ in scan(change['before'] or ''))
    warnings = []
    for rule, payload, line in scan(change['after']):
        prefix = ''
        if remaining[rule, payload]:
            remaining[rule, payload] -= 1
            prefix = 'Existing: '
        warnings.append(f'{prefix}[{rule}, line {line}] {MESSAGES[rule]}: {payload}')
    return {'decision': 'allow', **({'warnings': warnings} if warnings else {})}


if __name__ == '__main__':
    json.dump(check(json.load(sys.stdin)), sys.stdout)
