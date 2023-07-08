#!/usr/bin/awk -f

# markdown-subset-translator.awk
# Markdown形式で記述されたテキストファイルをHTMLに変換する
#
# 後ろの行で読んだ結果を前の方に反映する処理があるため、
# 途中の変換はすべて最終出力変数に入れ、処理後にEND
# ブロックで出力する
#
# 外部オプション
#   del_p_newline: 1のとき、<p>段落中の改行を除去する

BEGIN {
    # ある深さのリストを処理中であるかのフラグ
    is_list_processing[1] = 0
    # 順序なし箇条書きリストの最上位階層
    # re_ul_top = /^[\*+\-] /
    re_ul_top = "^[*+-] "
    # 順序なし箇条書きリスト (最上位階層を含むすべて)
    re_ul_lv2 = "^ *[*+-] "
    # 順序あり箇条書きリストの最上位階層
    re_ol_top = "^[0-9]{1,}. "
    # 順序あり箇条書きリストのLv2 (最上位階層を含むすべて)
    re_ol_lv2 = "^ *[0-9]{1,}. "
    # 終端処理用のリスト種類記憶
    list_type_for_finalization = ""
    # ブロックモード
    #    0  inside of unknown block
    #    1  inside of paragraph block
    #    2  inside of HTML block
    #    3  inside of list (<ul>) block
    #    4  inside of list (<ol>) block
    #    5  inside of code block
    #    6  inside of blockquote
    #    7  inside of table block
    block = 0

    # 定義参照形式のリンクとそのtitle属性を保存する連想配列
    reference_link_url["\005"] = ""
    reference_link_title["\005"] = ""
    # 定義参照
    reflink_sep = "\037"

    # 最終出力を保存する変数
    final_output = ""

}

# ===============================================================
# コードブロックの処理
# <pre><code>...</code></pre>
#
# 特定のコードブロックにいない時に行頭スペース4つ以上の行が現れた
# 場合
# ===============================================================
/(^ {4,}|^\t{1,})/ && block == 0 {
    final_output = final_output "<pre><code>" "\n"
    block = 5
}

# ===============================================================
# 引用ブロックの処理
# <blockquote>
#
# 引用ブロック内のMarkdownは通常の通り解釈される
#
# 引用ブロック中の引用 (blockquote-in-blockquote) もMarkdownの
# 文法に存在し、HTMLの定義上も存在し得るため、引用ブロックの全
# 行を読み込んでこのプログラムに再帰的に通す
# ===============================================================
/^>/ {
    # 引用ブロック処理モードとする
    block = 6

    # 空行に当たるまでを引用ブロックとして全部読み込む
    # その際、行頭に引用記号があれば除去する
    sub(/^> ?/, "", $0)
    line = $0
    while ((getline != 0) && ($0 != "")) {
        sub(/^> ?/, "", $0)
        line = line "\n" $0
    }

    # 引用ブロック中の文章をMarkdownとして再解釈するため、この
    # markdown-subset-translator.awk を再帰的に呼び出す
    bq_translate_command = "echo \"" line "\" | awk -f markdown-subset-translator.awk"

    # パイブ機能とgetlineの効果により、再解釈の結果がbq_output_strに得られる
    while ((bq_translate_command | getline bq_out_buf) > 0){
        bq_output_str = bq_output_str bq_out_buf "\n"
    }
    close(bq_translate_command)

    # 再解釈結果を出力し、引用ブロック処理を終了する
    final_output = final_output "<blockquote>\n" bq_output_str "</blockquote>\n"
    bq_output_str = ""
    block = 0
    next
}

# ===============================================================
# テーブル記法の処理
# <table>、<tr>、<th>、<td>
#
# 左右揃え、中央揃えはCSSと連携
# ===============================================================
/^\|/ {
    block = 7
    final_output = final_output process_table()
    block = 0
    next
}

# ===============================================================
# HTMLブロック要素の処理
#
# HTMLブロック要素はそのまま出力し、ブロック要素内部のMarkdownは
# 解釈しない
# ===============================================================
# ブロック要素の始点
/<(address|article|aside|blockquote|details|dialog|dd|div|dl|dt|fieldset|figcaption|figure|footer|form|h.|header|hgroup|hr|li|main|nav|ol|p|pre|section|table|ul)>/ {
    block = 2
    final_output = final_output $0 "\n"
    next
}

# ブロック要素の終点
/<\/(address|article|aside|blockquote|details|dialog|dd|div|dl|dt|fieldset|figcaption|figure|footer|form|h.|header|hgroup|hr|li|main|nav|ol|p|pre|section|table|ul)>/ {
    block = 0
    final_output = final_output $0 "\n"
    next
}

# ===============================================================
# 見出しの処理
# <h1> ～ <h6>
#
# # の数で表記
# ===============================================================
/^#{1,6}/ {
    final_output = final_output make_header_str($0) "\n"
    next
}

# ===============================================================
# 区切り線 <hr>
# ===============================================================
/^([\*_\-] ?){3,}$/ {
    final_output = final_output "<hr>" "\n"
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
    final_output = final_output process_list(1, "ul")
    block = 0
    next
}

# 1桁以上の数字 + ピリオド + 空白を順序つき箇条書きの冒頭とする
$0 ~ re_ol_top {
    block = 4
    list_type_for_finalization = "ol"
    final_output = final_output process_list(1, "ol")
    block = 0
    next
}

# ===============================================================
# 定義参照形式のリンク処理
#
# リンクの定義がリンクの参照部分以降に来る
# 定義参照部分の変換をここで行う
# ===============================================================

/^\[.+\]: +.+/ {
    link_string = gensub(/^\[([^\]]+)\]: +.+/, "\\1", 1, $0)
    link_url    = gensub(/^\[[^\]]+\]: +([^ ]+) ?.*/, "\\1", 1, $0)
    link_title  = gensub(/^\[[^\]]+\]: +[^ ]+ ?(["'\(](.+)["'\)])*/, "\\2", 1, $0)

    reference_link_url[link_string] = link_url
    reference_link_title[link_string] = link_title
    next
}

# ===============================================================
# 空行処理
#
# 段落区切り、コードブロックの終わりの場合は終了タグを打ってから
# デフォルトモードに復帰する
# HTMLブロック要素処理中は単に無視する
# ===============================================================
/^$/ {
    # 段落の区切りであれば </p> を入れる
    if (block == 1) {
        # del_p_newline の指定有無による分岐は単なる出力結果の
        # 見栄え調整のものであって、本質的ではないので除去しても
        # 動作には問題がない
        if (del_p_newline == 1) {
            final_output = final_output "\n</p>\n"
        } else {
            final_output = final_output "</p>\n"
        }
        block = 0
    }
    # コードブロックの終わりであれば </code></pre> を入れる
    else if (block == 5) {
        final_output = final_output "</code></pre>\n"
        block = 0
    }
    # HTMLブロック要素処理中は空行のままとする
    else if (block == 2) {
        final_output = final_output "\n"
    }
    next
}

# ===============================================================
# 一般の行の処理
# ===============================================================
{
    # 各要素の外の場合
    if (block == 0) {
        final_output = final_output "<p>\n"
        block = 1
    }

    # 段落ブロック処理中
    if (block == 1) {
        # 段落ブロック中の改行を消去するよう外部からフラグが設定されている場合
        if (del_p_newline == 1) {
            final_output = final_output parse_span_elements($0)
            next
        }
    }
    # コードブロック内の場合、コードブロックを表現する先頭の字下げ
    # を削除
    else if (block == 5) {
        sub(/(^ {4}|^\t)/, "", $0)
        final_output = final_output $0 "\n"
        next
    }
    # HTMLブロック要素処理中は単に無視する
    else if (block == 2) {
        final_output = final_output $0 "\n"
    }
    # インライン要素を処理
    final_output = final_output parse_span_elements($0) "\n"
}

# ===============================================================
# 最終行処理
# ===============================================================
END {
    # ファイル末尾が箇条書きリストであった場合は、ul, olに応じた
    # 閉じタグを出力
    if (is_list_processing[1] == 1) {
        final_output = final_output "</" list_type_for_finalization ">\n"
    }
    # 段落処理中に最終行に達した場合は段落を閉じる
    if (block == 1) {
        final_output = final_output "</p>\n"
    }
    # コードブロック処理中に最終行に達した場合はコードブロックを閉じる
    if (block == 5) {
        final_output = final_output "</code></pre>\n"
    }

    # 定義参照リンクを変換
    for (ref in reference_link_url) {
        gsub(reflink_sep ref reflink_sep, "<a href=\"" reference_link_url[ref] "\" title=\"" reference_link_title[ref] "\">" ref "</a>", final_output)
        # title属性の指定がない場合は、title属性の定義を消去する
        gsub(/ title=""/, "", final_output)
    }

    printf "%s", final_output
}

# ===============================================================
# 各ブロック処理関数群
# ===============================================================

# 箇条書きリストの変換
function process_list(list_depth, list_type,        output_str, pos, next_depth, row_head, lv2_head, line) {
    # この関数で変換する文書ブロックの最終出力
    output_str = ""

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
        output_str = output_str "<" list_type ">\n"
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
            output_str = output_str "<li>" parse_span_elements(line) "</li>\n"
            output_str = output_str "</" list_type ">\n"

            # 全ての深さについてリスト処理の終了を設定
            for (i = 1; i <= list_depth; i++) {
                is_list_processing[i] = 0
            }
            return output_str
        }

        # 次のリストの始まりを検出した場合
        if ($0 ~ lv2_head) {
            # ネスト段階を計算する
            pos = match($0, /^ {1,}/)
            next_depth = int((RLENGTH / 4)) + 1

            # ネスト段階の変化による分岐
            if (next_depth - list_depth == 0) {
                # 同一レベル
                output_str = output_str "<li>" parse_span_elements(line) "</li>\n"
                line = gensub(lv2_head, "", 1, $0)
            } else if (next_depth - list_depth == 1) {
                # 1つ深い
                output_str = output_str "<li>" parse_span_elements(line) "\n"
                output_str = output_str process_list(list_depth + 1, list_type) "</li>\n"

                # 最終行 or 空行検出によりリスト処理が終了している場合は、閉じタグを打つ
                if (is_list_processing[list_depth] == 0) {
                    output_str = output_str "</" list_type ">\n"
                    return output_str
                }
                # 再帰から帰ってきたこの時点で$0に次の行が読み込まれている
                line = gensub(lv2_head, "", 1, $0)
            } else if (next_depth - list_depth == -1) {
                # 1つ浅い
                output_str = output_str "<li>" line "</li>\n"
                output_str = output_str "</" list_type ">\n</li>\n"

                # 現在行を処理対象に加える
                line = gensub(lv2_head, "", 1, $0)
                # 次の行以降に1つの箇条書きの続きの文がないかチェック
                while (1) {
                    eof_status_2 = getline
                    if (eof_status_2 != 0 && $0 !~ lv2_head) {
                        line = line gensub(/^ */, "", 1, $0)
                    }
                    else {
                        break
                    }
                }

                # この時点で$0に次の行が読み込まれているので、次工程では注意
                output_str = output_str "<li>" parse_span_elements(line) "\n"
                is_list_processing[list_depth] = 0
                return output_str
            }
        } else {
            # 途中で改行された1項目の続きなので、先頭のインデントを取り除いて連結する
            line = line gensub(/^ */, "", 1, $0)
        }
    }

    return output_str
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
function parse_span_elements(str,      tmp_str, output_str, link_href_and_title, link_str, link_url, link_title) {
    # 強調処理 (通常・行頭・行末)
    # アスタリスクは前後空白なしを許容
    # アンダースコアは文章の一部となり得やすいので空白必須
    tmp_str = gensub(/ ?\*\*([^\*]+)\*\* ?/, "<strong>\\1</strong>", "g", str)
    tmp_str = gensub(/ __([^_]+)__ /, "<strong>\\1</strong>", "g", tmp_str)
    tmp_str = gensub(/^__([^_]+)__ /, "<strong>\\1</strong>", "g", tmp_str)
    tmp_str = gensub(/ __([^_]+)__$/, "<strong>\\1</strong>", "g", tmp_str)

    # 弱い強調処理 (通常・行頭・行末)
    # アスタリスクは前後空白なしを許容
    # アンダースコアは文章の一部となり得やすいので空白必須
    tmp_str = gensub(/ ?\*([^\*]+)\* ?/, "<em>\\1</em>", "g", tmp_str)
    tmp_str = gensub(/ _([^_]+)_ /, "<em>\\1</em>", "g", tmp_str)
    tmp_str = gensub(/^_([^_]+)_ /, "<em>\\1</em>", "g", tmp_str)
    tmp_str = gensub(/ _([^_]+)_$/, "<em>\\1</em>", "g", tmp_str)

    # 打ち消しの処理 (通常・行頭・行末)
    tmp_str = gensub(/ ~~([^~]+)~~ /, "<s>\\1</s>", "g", tmp_str)
    tmp_str = gensub(/^~~([^~]+)~~ /, "<s>\\1</s>", "g", tmp_str)
    tmp_str = gensub(/ ~~([^~]+)~~$/, "<s>\\1</s>", "g", tmp_str)

    # 単一フレーズのコードの処理
    tmp_str = gensub(/`([^`]+)`/, "<code>\\1</code>", "g", tmp_str)

    # 文中リンク文字列の処理
    tmp_str = gensub(/\[([^\]]+)\]\(([^ ]+)( ?['"]([^\)]+)['"])*\)/, "<a href=\"\\2\" title=\"\\4\">\\1</a>", "g", tmp_str)
    # title属性の指定がない場合は、title属性の定義を消去する
    tmp_str = gensub(/ title=""/, "", "g", tmp_str)

    # 定義参照リンク生成のための準備
    tmp_str = gensub(/\[([^\]]+)\]/, reflink_sep "\\1" reflink_sep, "g", tmp_str)
    output_str = tmp_str

    return output_str
}

# テーブル記法の処理
function process_table(       eof_status, tmp_line, output_table, mode) {
    # 処理モード (th, td)
    mode = "th"
    output_table = "<table>\n"

    while(1) {
        # ヘッダとデータを区切る線まで来たらヘッダモードからデータモードへ移行
        if ($0 ~ /^[-\|:]+$/) {
            mode = "td"
            getline
            continue
        }
        tmp_line = gensub(/^\| */, "<tr><" mode ">", 1, $0)
        tmp_line = gensub(/ *\|$/, "</" mode "></tr>", 1, tmp_line)
        tmp_line = gensub(/ *\| */, "</" mode "><" mode ">", "g", tmp_line)

        output_table = output_table tmp_line "\n"

        eof_status = getline
        if (eof_status == 0 || $0 == "") {
            output_table = output_table "</table>\n"
            return output_table
        }
    }
    return output_table
}
