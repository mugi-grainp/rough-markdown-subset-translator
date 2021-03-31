#!/usr/bin/awk -f

# block
#   -1  outside of the block
#    0  inside of unknown block
#    1  inside of paragraph block
#    2  inside of HTML block
#    3  inside of list (<ul>) block (not used)
#    4  inside of list (<ol>) block (not used)
#    5  inside of code block
#    6  inside of ref block

BEGIN {
    prev_line = ""
    now_line  = ""
    next_line = ""
    block  = 0
    is_eof_after_list = 0

    final_output = ""
    reference_link["foo"] = ""
    reflink_sep = "\037"
}

NR == 1 {
    now_line = $0
    getline next_line
    $0 = next_line      # getlineは$0を設定しない。後処理の統一のためここで設定
}

# それ以外
{
    if (is_eof_after_list == 0) {
        ret = parse_main(prev_line, now_line, next_line)
        if (ret != "") {
            final_output = final_output ret "\n"
        }
    }

    prev_line = now_line
    now_line  = next_line
    next_line = $0
}

# 箇条書き処理
now_line ~ /^[\*+\-] [^\*+\-]+$/ {
    line = now_line "\n" next_line
    li_str = ""

    if (block == 1) {
        block = 3
        final_output = final_output "</p>"
    }

    if (prev_line !~ /^[\*+\-]/) { final_output = final_output "<ul>\n" }

    while (getline && ($0 ~ /^ *[\*+\-]/)) {
        line = line"\n"$0
    }
    li_str = make_li_str(0, line)
    final_output = final_output li_str"\n</ul>"
    block = -1

    prev_line = ""
    now_line  = $0
    ret = getline next_line
    if (ret == 0) { is_eof_after_list = 1 }
    $0 = next_line
}

# 順序リスト処理
now_line ~ /^[0-9]{1,}\. / {
    line = now_line "\n" next_line
    li_str = ""

    if (block == 1) {
        block = 4
        final_output = final_output "</p>"
    }

    if (prev_line !~ /^[0-9]{1,}\./) { final_output = final_output "<ol>\n" }

    while (getline && ($0 ~ /^ *[0-9]{1,}\. /)) {
        line = line"\n"$0
    }
    li_str = make_li_str_ol(0, line)
    final_output = final_output li_str "\n</ol>"
    block = -1

    prev_line = ""
    now_line  = $0
    ret = getline next_line
    if (ret == 0) { is_eof_after_list = 1 }
    $0 = next_line
}

END {
    # 文書がリストで終了した場合、1行前-現在行-1行後のポインタと別に
    # 文書処理が終了しているので、現在行として記録されている文字列の
    # 解釈を行わない
    if (is_eof_after_list == 0) {
        ret = parse_main(prev_line, now_line, next_line)
        if (ret != "") { final_output = final_output ret "\n" }

        ret = parse_main(now_line, next_line, "")
        if (ret != "") { final_output = final_output ret "\n" }
    }

    if (block == 1) {
        final_output = final_output "</p>"
    }

    # 定義参照リンクをここで変換
    for (ref in reference_link) {
        gsub(reflink_sep ref reflink_sep, "<a href=\"" reference_link[ref] "\">" ref "</a>", final_output)
    }
    print final_output
}

function parse_main(prev_l, now_l, next_l) {
    if ((block == 0) || (block == -1)) {
        # 見出し #の数で表記
        if (now_l ~ /^#{1,6}/) {
            return make_header_str(now_l)
        }

        # 見出し H1
        else if (next_l ~ /^={1,}$/) {
            return "<h1>"now_l"</h1>"
        }

        # 見出し H1 を示す = は無視
        else if (now_l ~ /^={1,}$/) {
            return
        }

        # 見出し H2
        else if ((now_l != "") && (next_l ~ /^-{1,}$/)) {
            return "<h2>"now_l"</h2>"
        }

        # 見出し H2 を示す - は無視し、それ以外の - は3つ連続していれば区切り線
        # また、後に文字が続けば箇条書きとみなす
        else if (now_l ~ /^-{1,}$/) {
            if ((prev_l != "") && (prev_l ~ /^[^\-]/)) {
                return
            }
        }

        # 区切り線
        else if (now_l ~ /^([\*_\-] ?){3,}$/) {
            return "<hr>"
        }

        # コードブロック
        else if (now_l ~ /(^ {4,}|^\t{1,})/) {
            block = 5
            out_tmp = "<pre><code>"
            sub(/(^ {4}|^\t{1})/, "", now_l)
            return out_tmp "\n" now_l
        }

        # HTML ブロック要素はじまり
        else if (now_l ~ /<(address|article|aside|blockquote|details|dialog|dd|div|dl|dt|fieldset|figcaption|figure|footer|form|h.|header|hgroup|hr|li|main|nav|ol|p|pre|section|table|ul)>/) {
            block = 2
            return now_l
        }

# 定義参照リンクの定義部分
        else if(now_l ~ /^\[.+\]: .+/) {
            link_title = gensub(/^\[([^\]]+)\]: .+/, "\\1", 1, now_l)
            link_url   = gensub(/^\[[^\]]+\]: (.+)/, "\\1", 1, now_l)
            reference_link[link_title] = link_url
            return
        }

        else if (now_l != "") {
            block = 1
            out_tmp = "<p>"
            return out_tmp "\n" parse_span_elements(now_l)
        }
    }

    else if (block == 1) {
        if (now_l == "") {
            block = -1
            return "</p>"
        }
        else {
            return parse_span_elements(now_l)
        }
    }

    else if (block == 2) {
        # HTML ブロック要素終わり
        if (now_l ~ /<\/(address|article|aside|blockquote|details|dialog|dd|div|dl|dt|fieldset|figcaption|figure|footer|form|h.|header|hgroup|hr|li|main|nav|ol|p|pre|section|table|ul)>/) {
            block = -1
        }
        return now_l
    }

    else if (block == 5) {
        if (now_l == "") {
            block = -1
            return "</code></pre>"
        }
        else {
            sub(/(^ {4}|^\t{1})/, "", now_l)
            return now_l
        }
    }
}

function make_header_str(input_hstr,       level, output_hstr) {
    count = split(input_hstr, buf, " ")

    level = length(buf[1])
    output_hstr = buf[2]

    for (i = 3; i <= count; i++) { output_hstr = output_hstr" "buf[i] }
    return "<h"level">"output_hstr"</h"level">"
}

# 箇条書きの再帰処理
function make_li_str(level, lines,         li_str,subline,i,count,temp_array) {
    count = split(lines, temp_array, /\n/)

    content_start = match(temp_array[1], /[^\*+\- ]/)
    li_str = "<li>"substr(temp_array[1] , content_start, length(temp_array[1]))
    for (i = 2; i <= count; i++) {
        num = (match(temp_array[i], /[\*+\-]/) - 1) / 4
        if (num == level) {
            content_start = match(temp_array[i], /[^\*+\- ]/)
            li_str = li_str"</li>\n<li>"substr(temp_array[i] , content_start, length(temp_array[i]))
        }

        else if (num > level) {
            subline = ""
            num2 = (match(temp_array[i], /[\*+\-]/) - 1) / 4
            while (num2 > level) {
                subline = subline temp_array[i++]"\n"
                num2 = (match(temp_array[i], /[\*+\-]/) - 1) / 4
            }
            li_str = li_str"\n<ul>\n"make_li_str(level + 1, subline)"\n</ul>\n"
            i--
        }
    }
    li_str = li_str"</li>"

    return li_str
}

# 順序付きリストの再帰処理
function make_li_str_ol(level, lines,         li_str,subline,i,count,temp_array) {
    count = split(lines, temp_array, /\n/)

    content_start = match(temp_array[1], /[^0-9 \.]/)
    li_str = "<li>"substr(temp_array[1] , content_start, length(temp_array[1]))
    for (i = 2; i <= count; i++) {
        num = (match(temp_array[i], /[0-9]/) - 1) / 4
        if (num == level) {
            content_start = match(temp_array[i], /[^0-9 \.]/)
            li_str = li_str"</li>\n<li>"substr(temp_array[i] , content_start, length(temp_array[i]))
        }

        else if (num > level) {
            subline = ""
            num2 = (match(temp_array[i], /[0-9]/) - 1) / 4
            while (num2 > level) {
                subline = subline temp_array[i++]"\n"
                num2 = (match(temp_array[i], /[0-9]/) - 1) / 4
            }
            li_str = li_str"\n<ol>\n"make_li_str_ol(level + 1, subline)"\n</ol>\n"
            i--
        }
    }
    li_str = li_str"</li>"

    return li_str
}

function parse_span_elements(str,      tmp_str, output_str) {
    # 文中マークアップ要素の処理
    # 強調処理
    tmp_str = gensub(/\*\*([^\*]+)\*\*/, "<strong>\\1</strong>", "g", str)
    tmp_str = gensub(/__([^\*]+)__/, "<strong>\\1</strong>", "g", tmp_str)

    # 弱い強調処理
    tmp_str = gensub(/\*([^\*]+)\*/, "<em>\\1</em>", "g", tmp_str)
    tmp_str = gensub(/_([^\*]+)_/, "<em>\\1</em>", "g", tmp_str)

    # 文中リンク文字列の処理
    tmp_str = gensub(/\[([^\]]+)\]\(([^\)]+)\)/, "<a href=\"\\2\">\\1</a>", "g", tmp_str)

    # 定義参照リンク生成のための準備
    tmp_str = gensub(/\[([^\]]+)\]/, reflink_sep "\\1" reflink_sep, "g", tmp_str)
    output_str = tmp_str
    return output_str
}
