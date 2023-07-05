#!/usr/bin/awk -f

# new-markdown-subset-translator.awk
# Markdown形式で記述されたテキストファイルをHTMLに変換する

BEGIN {
    # ある深さのリストを処理中であるかのフラグ
    is_list_processing[1] = 0
    # 順序なし箇条書きリストの最上位階層
    # re_ul_top = /^[\*+\-] /
    re_ul_top = "^[*+-] "
    # 順序なし箇条書きリストのLv2以降
    re_ul_lv2 = "^ *[*+-] "
    # 順序あり箇条書きリストの最上位階層
    re_ol_top = "^[0-9]{1,}. "
    # 順序あり箇条書きリストのLv2以降
    re_ol_lv2 = "^ *[0-9]{1,}. "
    # 終端処理用のリスト種類記憶
    list_type_for_finalization = ""
    # ブロックモード
    #    0  inside of unknown block
    #    1  inside of paragraph block
    #    2  inside of HTML block
    #    3  inside of list (<ul>) block (not used)
    #    4  inside of list (<ol>) block (not used)
    #    5  inside of code block
    block = 0
}

# 見出し #の数で表記
/^#{1,6}/ {
    print make_header_str($0)
    next
}

# 区切り線 <hr>
/^([\*_\-] ?){3,}$/ {
    print "<hr>"
    next
}

# ===============================================================
# 箇条書きの処理
# <ul>, <ol> タグに変換
# ===============================================================

# 行頭の箇条書き
# アスタリスク・ハイフン・プラス記号を順序なし箇条書きの冒頭とする
$0 ~ re_ul_top {
    block = 3
    list_type_for_finalization = "ul"
    process_list(1, "ul")
    block = 0
    next
}

# 1桁以上の数字 + ピリオド + 空白を順序つき箇条書きの冒頭とする
$0 ~ re_ol_top {
    block = 4
    list_type_for_finalization = "ol"
    process_list(1, "ol")
    block = 0
    next
}

# ===============================================================
# 空行処理（段落区切りなど）
# ===============================================================
/^$/ {
    # 段落の区切りであれば </p> を入れる
    if (block == 1) {
        print "</p>"
        block = 0
    }
    next
}


# ===============================================================
# 一般の行の処理
# ===============================================================
{
    if (block == 0) {
        print "<p>"
        block = 1
    }
    print parse_span_elements($0)
}

# ===============================================================
# 最終行処理
# ===============================================================
END {
    if (is_list_processing[1] == 1) {
        print "</" list_type_for_finalization ">"
    }
}

# ===============================================================
# 各ブロック処理関数群
# ===============================================================

# 箇条書きリストの変換
function process_list(list_depth, list_type) {
    # list_type: ul もしくは ol（タグの名前そのまま）
    # list_typeにより、行頭の正規表現を定める
    if (list_type == "ul") {
        row_head = re_ul_top
        lv2_head = re_ul_lv2
    } else if (list_type == "ol") {
        row_head = re_ol_top
        lv2_head = re_ol_lv2
    }

    # 当該階層のリスト処理をここから始める場合は開始タグを打つ
    if (is_list_processing[list_depth] != 1) {
        print "<" list_type ">"
        is_list_processing[list_depth] = 1
    }

    line = $0

    # (リストの深さ - 1) * 4文字分の行頭スペースを削る
    for (i = 0; i < list_depth; i++) {
        line = gensub(/^ {4}/, "", 1, line)
    }
    # リストを表す行頭文字を削る
    line = gensub(row_head, "", 1, line)

    while (1) {
        # 次の行を読み込み、同時にファイル終端に達していないかどうかのフラグを得る
        eof_status = getline

        # ファイル終端、または空行に行き当たったらリスト1個の終わりとする
        if (eof_status == 0 || $0 == "") {
            print "<li>" line "</li>"
            print "</" list_type ">"

            # 全ての深さについてリスト処理の終了を設定
            for (i = 1; i <= list_depth; i++) {
                is_list_processing[i] = 0
            }
            return
        }

        # 次のリストの始まりを検出した場合
        if ($0 ~ lv2_head) {
            # ネスト段階を計算する
            pos = match($0, /^ {1,}/)
            next_depth = int((RLENGTH / 4)) + 1

            # ネスト段階の変化による分岐
            if (next_depth - list_depth == 0) {
                # 同一レベル
                print "<li>" line "</li>"
                line = gensub(lv2_head, "", 1, $0)
            } else if (next_depth - list_depth == 1) {
                # 1つ深い
                print "<li>" line
                process_list(list_depth + 1, list_type)
                print "</li>"

                # 最終行 or 空行検出によりリスト処理が終了している場合は、閉じタグを打つ
                if (is_list_processing[list_depth] == 0) {
                    print "</" list_type ">"
                }
                return
            } else if (next_depth - list_depth == -1) {
                # 1つ浅い
                print "<li>" line "</li>"
                line = gensub(lv2_head, "", 1, $0)
                print "</" list_type ">"
                print "</li>"
                print "<li>" line
                is_list_processing[list_depth] = 0
                return
            }
        } else {
            # 途中で改行された1項目の続きなので、先頭のインデントを取り除いて連結する
            line = line gensub(/^ */, "", 1, $0)
        }
    }
}

# #の数に応じた見出しタグの生成
# 入力
#   input_hstr: 見出し記法を含む行の文字列
function make_header_str(input_hstr,       level, output_hstr) {
    count = split(input_hstr, buf, " ")

    level = length(buf[1])
    output_hstr = buf[2]

    for (i = 3; i <= count; i++) { output_hstr = output_hstr " " buf[i] }
    return "<h" level ">" output_hstr "</h" level ">"
}

# 文中マークアップ要素の処理
function parse_span_elements(str,      tmp_str, output_str) {
    # 強調処理
    tmp_str = gensub(/\*\*([^\*]+)\*\*/, "<strong>\\1</strong>", "g", str)
    tmp_str = gensub(/__([^\*]+)__/, "<strong>\\1</strong>", "g", tmp_str)

    # 弱い強調処理
    tmp_str = gensub(/\*([^\*]+)\*/, "<em>\\1</em>", "g", tmp_str)
    tmp_str = gensub(/_([^\*]+)_/, "<em>\\1</em>", "g", tmp_str)

    # 文中リンク文字列の処理
    tmp_str = gensub(/\[([^\]]+)\]\(([^\)]+)\)/, "<a href=\"\\2\">\\1</a>", "g", tmp_str)

    output_str = tmp_str

    return output_str
}
