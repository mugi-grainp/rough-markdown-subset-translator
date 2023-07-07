# rough-markdown-subset-translator

## できること

MarkdownをHTMLに変換します。

一部の文法にしか対応していませんが、世界の半分のMarkdownは
これで十分に変換できるかもしれません。

## 変換できる文法

- 見出し
    - 現在、Atx-styleの一部 ( # : NUMBER SIGN U+0023 を行頭にだけ置く形のもの) に対応
- 段落
- 箇条書き
    - 複数階層にも対応
- 順序付きリスト
    - 複数階層にも対応
- 単一のコード
- コードブロック
    - 空白4つ or タブ文字によるインデントによるブロック表現に対応
- 区切り線
- リンク (title属性付与にも対応)
    - 通常のリンク
    - 定義参照リンク
- 引用

上記以外の文やHTMLはそのまま出力します。

## 現在実装していない代表的な文法

### もとのMarkdownに存在する文法

- 見出し
    - Atx-styleのうち、# を行末にも置く形のもの
    - Underlined-styleのH1、H2見出し (処理再実装の都合上、このバージョンではまだ実装していません)
- 画像挿入 (&lt;img&gt;タグに変換)
- Automatic Link

### もとのMarkdownには存在しないが、各種サービスで広く実装されている文法

- テーブル
- バッククォート3つの行によって囲むコードブロック
- 打ち消し線

## 使い方

    $ awk -f markdown-subset-translator.awk [FILE]

## 利用場面

pandocなどのMarkdown変換プログラムが何らかの理由で利用できないときに、
ごく基本的な文法のみを用いて書かれたMarkdownをHTMLに変換するのに役立ちます。

## Future Work

- Underlined-styleのH1、H2見出しへの対応
- テーブル記法への対応
