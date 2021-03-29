# rough-markdown-subset-translator

## できること

MarkdownをHTMLに変換します。

一部の文法にしか対応していませんが、世界の半分のMarkdownは
これで十分に変換できるかもしれません。

## 変換できる文法

- 見出し
- 段落
- 箇条書き
    - 複数階層にも対応
- 順序付きリスト
    - 複数階層にも対応
- コードブロック
- 区切り線

上記以外の文やHTMLはそのまま出力します。

## 使い方

    $ awk -f markdown-subset-translator.awk [FILE]

## 利用場面

pandocなどのMarkdown変換プログラムが何らかの理由で利用できないときに、
ごく基本的な文法のみを用いて書かれたMarkdownをHTMLに変換するのに役立ちます。

## Future Work

- リンク記法への対応
- 引用表記の処理
- GitHub等が用いている拡張Markdown文法に対応するかどうかを検討
