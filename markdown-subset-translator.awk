#!/usr/bin/awk -f

# block
#   -1  outside of the block
#    0  inside of unknown block
#    1  inside of paragraph block
#    2  inside of HTML block
#    3  inside of list (<ul>) block (not used)
#    4  inside of list (<ol>) block (not used)
#    5  inside of code block

BEGIN {
    prev_line = ""
    now_line  = ""
    next_line = ""
    block  = 0
    is_eof_after_list = 0
}

NR == 1 {
    now_line = $0
    getline next_line
    $0 = next_line      # getlineは$0を設定しない。後処理の統一のためここで設定
}

# それ以外
{
    if (is_eof_after_list == 0) {
        parse_main(prev_line, now_line, next_line)
    }

    prev_line = now_line
    now_line  = next_line
    next_line = $0
}

# 箇条書き処理
$0 ~ /^[\*+\-] / {
    prev_line = now_line
    now_line  = next_line
    next_line = $0

    line = $0
    li_str = ""

    if (block == 1) {
        block = 3
        print "</p>"
    }

    if (prev_line !~ /^[\*+\-]/) { print "<ul>" }

    while (getline && ($0 ~ /^ *[\*+\-]/)) {
        line = line"\n"$0
    }
    li_str = make_li_str(0, line)
    print li_str"\n</ul>"
    block = -1

    prev_line = ""
    now_line  = $0
    ret = getline next_line
    if (ret == 0) { is_eof_after_list = 1 }
    $0 = next_line
}

# 順序リスト処理
$0 ~ /^[0-9]{1,}\./ {
    prev_line = now_line
    now_line  = next_line
    next_line = $0

    line = $0
    li_str = ""

    if (block == 1) {
        block = 4
        print "</p>"
    }

    if (prev_line !~ /^[0-9]{1,}\./) { print "<ol>" }

    while (getline && ($0 ~ /^ *[0-9]{1,}\. /)) {
        line = line"\n"$0
    }
    li_str = make_li_str_ol(0, line)
    print li_str"\n</ol>"
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
        parse_main(prev_line, now_line, next_line)
        parse_main(now_line, next_line, "")
    }

    if (block == 1) {
        print "</p>"
    }
}

function parse_main(prev_l, now_l, next_l) {
    if ((block == 0) || (block == -1)) {
        # 見出し #の数で表記
        if (now_l ~ /^#{1,6}/) {
            print make_header_str(now_l)
        }

        # 見出し H1
        else if (next_l ~ /^={1,}$/) {
            print "<h1>"now_l"</h1>"
        }

        # 見出し H1 を示す = は無視
        else if (now_l ~ /^={1,}$/) {
            return
        }

        # 見出し H2
        else if (next_l ~ /^-{1,}$/) {
            print "<h2>"now_l"</h2>"
        }

        # 見出し H2 を示す - は無視し、それ以外の - は3つ連続していれば区切り線
        # また、後に文字が続けば箇条書きとみなす
        else if (now_l ~ /^-{1,}$/) {
            if (prev_l ~ /^[^\-]/) {
                return
            }
            else if (now_l ~ /^-{3,}$/) {
                print "<hr>"
            }
        }

        # コードブロック
        else if (now_l ~ /(^ {4,}|^\t{1,})/) {
            block = 5
            print "<pre><code>"
            sub(/(^ {4}|^\t{1})/, "", now_l)
            print now_l
        }

        # HTML ブロック要素はじまり
        else if (now_l ~ /<(address|article|aside|blockquote|details|dialog|dd|div|dl|dt|fieldset|figcaption|figure|footer|form|h.|header|hgroup|hr|li|main|nav|ol|p|pre|section|table|ul)>/) {
            block = 2
            print now_l
        }

        else if (now_l != "") {
            block = 1
            print "<p>"
            print parse_span_elements(now_l)
        }
    }

    else if (block == 1) {
        if (now_l == "") {
            print "</p>"
            block = -1
        }
        else {
            print parse_span_elements(now_l)
        }
    }

    else if (block == 2) {
        # HTML ブロック要素終わり
        if (now_l ~ /<\/(address|article|aside|blockquote|details|dialog|dd|div|dl|dt|fieldset|figcaption|figure|footer|form|h.|header|hgroup|hr|li|main|nav|ol|p|pre|section|table|ul)>/) {
            block = -1
        }
        print now_l
    }

    else if (block == 5) {
        if (now_l == "") {
            print "</code></pre>"
            block = -1
        }
        else {
            sub(/(^ {4}|^\t{1})/, "", now_l)
            print now_l
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
    tmp_str = gensub(/\*\*([^\*]+)\*\*/, "<strong>\\1</strong>", "g", str)
    tmp_str = gensub(/__([^\*]+)__/, "<strong>\\1</strong>", "g", tmp_str)
    tmp_str = gensub(/\*([^\*]+)\*/, "<em>\\1</em>", "g", tmp_str)
    tmp_str = gensub(/_([^\*]+)_/, "<em>\\1</em>", "g", tmp_str)
    output_str = tmp_str
    return output_str
}
