# rough-markdown-subset-translator

[English Edition is here.](README.en.md)

## できること

MarkdownをHTMLに変換します。

一部の文法にしか対応していませんが、世界の8割のMarkdownは
これで十分に変換できるかもしれません。

## 変換できる文法

### 基礎的な文法

- 見出し
    - ATX style
    - Setext style
- 段落
- 箇条書き（入れ子・複数階層に対応）
    - 順序付きリスト (&lt;ol&gt;)
    - 順序なしリスト (&lt;ul&gt;)
- インライン要素としてのコード (&lt;code&gt;)
- コードブロック
    - 空白4つ or タブ文字によるインデント形式
    - バッククォート3つによって囲む形式（フェンス形式）
        - 各種ハイライトプラグイン向け言語指定キーワード記法対応
- 区切り線
- リンク (title属性付与にも対応)
    - 通常のリンク
    - 定義参照リンク
- 引用 (&lt;blockquote&gt;)
- 文章強調・意味付け
    - 強調 (&lt;em&gt;)
    - さらに強い強調 (&lt;strong&gt;)
    - 打ち消し線 (&lt;s&gt;)
- 画像挿入 (&lt;img&gt;)

### 各種サービスで広くサポートされている拡張文法

- テーブル
- 脚注

### その他の文

上記以外の文やHTMLはそのまま出力します。

## 現在実装していない代表的な文法

- Automatic Link

## 使い方

単にawkプログラムとして呼び出してください。

    awk -f markdown-subset-translator.awk [FILE]

### 指定できるオプション

awkのvオプションを使って、プログラム外から動作を設定できます。オプションは複数
同時に設定可能です。

- `del_p_newline` オプション
    - 1に設定すると、段落ブロックを&lt;p&gt;タグで囲う際に、段落中にある改行を
      すべて除去します。
- `th_always_center` オプション
    - 1に設定すると、テーブル記法を処理する際に列タイトル（&lt;th&gt;タグ）を常
      に中央揃えで出力するようstyle属性を設定します。

    awk -f markdown-subset-translator.awk -v del_p_newline=1 [FILE]
    awk -f markdown-subset-translator.awk -v th_always_center=1 [FILE]

## 利用場面

pandocなどのMarkdown変換プログラムが何らかの理由で利用できないときに、
ごく基本的な文法のみを用いて書かれたMarkdownをHTMLに変換するのに役立ちます。

