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
- 文章強調・意味付け
    - 強調 (&lt;em&gt;)
    - さらに強い強調 (&lt;strong&gt;)
    - 打ち消し線 (&lt;s&gt;)
- テーブル
    - テーブル内テキストの位置揃え指定（左・中央・右）を除く
- 画像挿入 (&lt;img&gt;)

上記以外の文やHTMLはそのまま出力します。

## 現在実装していない代表的な文法

### もとのMarkdownに存在する文法

- 見出し
    - Atx-styleのうち、# を行末にも置く形のもの
    - Underlined-styleのH1、H2見出し (処理再実装の都合上、このバージョンではまだ実装していません)
- Automatic Link

### もとのMarkdownには存在しないが、各種サービスで広く実装されている文法

- テーブル内テキストの位置揃え指定（左・中央・右）
- バッククォート3つの行によって囲むコードブロック

## 使い方

単にawkプログラムとして呼び出してください。

    awk -f markdown-subset-translator.awk [FILE]

### 指定できるオプション

`del_p_newline` オプションを1に設定すると、段落ブロックを&lt;p&gt;タグで囲う際
に、段落中にある改行をすべて除去します。awkのvオプションを使って変数の値をプロ
グラム外から設定します。

    awk -f markdown-subset-translator.awk -v del_p_newline=1 [FILE]

## 利用場面

pandocなどのMarkdown変換プログラムが何らかの理由で利用できないときに、
ごく基本的な文法のみを用いて書かれたMarkdownをHTMLに変換するのに役立ちます。

## Future Work

- Underlined-styleのH1、H2見出しへの対応
- テーブル記法への完全対応
