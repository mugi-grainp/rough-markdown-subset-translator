#!/usr/bin/awk -f

BEGIN {
    prev_line = ""
    inside_paragraph = 0
    inside_pre = 0
}

{
    # print "START: prev_line =", prev_line
    # print "now_line =", $0
}

# 見出し処理
$0 ~ /^={1,}$/ {
    if (inside_paragraph) { inside_paragraph = 0; print "</p>" }
    print "<h1>"prev_line"</h1>"
    prev_line = $0
    next
}

$0 ~ /^-{1,}$/ {
    if (inside_paragraph) { inside_paragraph = 0; print "</p>" }
    print "<h2>"prev_line"</h2>"
    prev_line = $0
    next
}

$0 ~ /^#{1,6}/ {
    if (inside_paragraph) { inside_paragraph = 0; print "</p>" }
    level = length($1)
    hstr = $2
    for (i = 3; i <= NF; i++) { hstr = hstr" "$i }
    print "<h"level">"hstr"</h"level">"
    prev_line = $0
    next
}

# 箇条書き処理
$0 ~ /^[\*+\-]/ {
    if (inside_paragraph) {
        inside_paragraph = 0
        print "</p>"
        print "<ul>"

        li_str = make_li_str(prev_line)
        print "<li>"li_str"</li>"
    }

    if (prev_line !~ /^[*+\-]/) { print "<ul>" }

    li_str = make_li_str($0)
    print "<li>"li_str"</li>"
    prev_line = $0
    next
}

# 順序リスト処理
$0 ~ /^[0-9]{1,}\./ {
    if (inside_paragraph) { inside_paragraph = 0; print "</p>" }
    if (prev_line !~ /^[0-9]{1,}\./) { print "<ol>" }
    print "<li>"$2"</li>"
    prev_line = $0
    next
}

# テーブル処理（実装予定）
$0 ~ /^\|/ {
    print
    prev_line = $0
    next
}

# <pre>タグ処理
$0 ~ /^```$/ {
    if (inside_pre) {
        print "</pre>"
        inside_pre = 0
    } else {
        print "<pre>"
        inside_pre = 1
    }
    prev_line = $0
    next
}

$0 == "" {
    if (inside_paragraph) {
        print "</p>"
        inside_paragraph = 0
        prev_line = $0
        next
    }
}

# 段落処理・末尾処理
{
    if (inside_pre) { 
        print
        prev_line = $0
        next
    }
    if ((prev_line ~ /^[\*+\-] /) && ($0 !~ /^[\*+\-]/)) { 
        print "</ul>"
        prev_line = $0
        next
    }

    if ((prev_line ~ /^[0-9]{1,}\. /) && ($0 !~ /^[0-9]{1,}\. /)) {
        print "</ol>"
        prev_line = $0
        next
    }

    if ((prev_line ~ /^={1,}$/) || (prev_line ~ /^-{1,}$/) || (prev_line ~ /^#{1,6}/)) {
        if ($0 != "") {
            print "<p>"
            inside_paragraph = 1
            print
        }
        prev_line = $0
        next
    }

    if (prev_line == "") {
        now_line = $0
        getline
        if ($0 ~ /^={1,}$/) { print "<h1>"now_line"</h1>" }
        else if ($0 ~ /^-{1,}$/) { print "<h2>"now_line"</h2>" }
        else {
            if (inside_paragraph) {
                print "</p>"
            }
            print "<p>"
            inside_paragraph = 1
            print now_line
            if ($0 != "" && $0 !~ /^[*+\-]/ && $0 !~ /^[0-9]{1,}\. /) { print }
        }
    }

    if (prev_line != "" && prev_line !~ /```/) {
        print prev_line
    }

    prev_line = $0
}

END {
    if (inside_paragraph == 1) { print "</p>" }
}

function make_li_str(line) {
    temp_array_length = split(line, temp_array, / /)

    if (temp_array_length >= 2) {
        li_str = temp_array[2]
        for (i = 3; i <= temp_array_length; i++) { li_str = li_str" "temp_array[i] }
    } else {
        li_str = ""
    }

    return li_str
}
