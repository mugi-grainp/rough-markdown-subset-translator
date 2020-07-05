# rough-markdown-subset-translator

## できること

Markdownのきわめて限定されたサブセットの変換。

世界の半分のMarkdownはこれで十分に変換できる可能性。

## 変換できる文法

- 見出し
- 段落
- 1階層に限った箇条書き
- 1階層に限った順序付きリスト

上記以外の文はそのまま出力します。たぶん。

## 使い方

```
$ awk -f markdown-subset-translator.awk (変換したいMarkdownファイル)
```

## 利用場面

pandocなどのMarkdown変換プログラムが何らかの理由で利用できないときに、
ごく基本的な文法のみを用いて書かれたMarkdownをHTMLに変換するのに役立ちます。

## Future Work

- 強調、取り消し線などの要素の反映
- 複数階層の箇条書き・順序付きリストの処理、引用表記の処理など

