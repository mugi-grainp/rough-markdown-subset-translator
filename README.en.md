# rough-markdown-subset-translator

[日本語版READMEはこちら](README.md)

## What this script can do

Translate Markdown to HTML.

This script supports most major Markdown syntax. However, there are some that
cannot be converted correctly depending on how they are written.

## Syntax supported by this script

- Headings (&lt;h1&gt;, &lt;h2&gt;,...,&lt;h6&gt;)
    - Supports ATX style. (put # at the beginning of a line.)
    - Also supports Setext style (for &lt;h1&gt; and &lt;h2&gt;).
- Paragraph (&lt;p&gt;)
- Lists (&lt;ul&gt;, &lt;ol&gt;)
    - Supports nested lists.
- Code markup (&lt;code&gt;)
    - Supports inline code span.
    - Also supports code block.
        - both indented style and fenced style by 3 backquotes.
        - Output syntax highlighting class.
- Link (&lt;a&gt;)
    - Inline link
    - Link reference definitions
- Block quotes (&lt;blockquote&gt;)
- Inline markup
    - Emphasis (&lt;em&gt;): single asterisk or underscore.
    - Strong Emphasis (&lt;strong&gt;): double asterisks or underscores.
    - Strikethrough (&lt;s&gt;)
- Table
    - Supports pipe table syntax.
        - Not supports column alignment yet.
- Image file insertion (&lt;img&gt;)
    - Supports inline syntax.
    - Also supports reference definitions syntax.

This program outputs other than the above syntax and HTML tags as is. 

## Usage

Run `markdown-subset-translator.awk`.

```bash
awk -f markdown-subset-translator.awk [FILE]
```

If no file is specified, read from STDIN.

Outputs conversion results to STDOUT.

### Options

The following items can be configured, using the AWK v option.

- `del_p_newline`
    - Remove line breaks in paragraph tag (&lt;p&gt;).
    - This option is useful for languages that do not use word divider
      (whitespace between words) such as Japanese language and Chinese
      language.

```bash
awk -f markdown-subset-translator.awk -v del_p_newline=1 [FILE]
```

## Usecases

This script helps convert Markdown written using only basic syntax to HTML in
environments where Markdown conversion programs such as pandoc are not
available.

## Future work

- Table alignment syntax
- footnotes syntax
