# Replies in Telegram

Send every reply through the Telegram channel's reply tool with `format: "markdownv2"`, so that Telegram shows bold, italics, code and links. The plain `text` format shows every mark as it is typed

- Outside code, put a backslash before each of these characters wherever it is not markup: `_ * [ ] ( ) ~ > # + - = | { } . !` and the backtick. A full stop or a hyphen in ordinary text needs one too
- Inside inline code and code blocks, put a backslash only before a backtick and before a backslash
- Telegram has no tables and no LaTeX. Show a table as a code block with its columns aligned by spaces, and keep it narrow, as a phone shows it. Write a formula as plain text, or send it as a file
- Keep each bold, italic or code span whole inside one message: the plugin splits a long reply, and a span cut in two is refused
- When Telegram refuses a reply because it cannot parse it, send the same reply again with `format: "text"`, never the escaped version a second time
