#!/bin/awk -f
# md2html.awk
# by: Jesus Galan (yiyus) <yiyu.jgl@gmail>, 2006 - June 2009
# Usage: md2html.awk file.md > file.html

function newblock(nblock){
	if(block == "code")
		text = "<pre>" text "</pre>";
	if(text)
		print "<" block ">" text "</" block ">";
	text = "";
	block = nblock ? nblock : "p";
}

function subinline(tgl, inl){
	res = $0;
	$0 = "";
	while(match(res, tgl)){
		nres = substr(res, RSTART + RLENGTH);
		if(inline[ni] == inl){
			tag = "</" inl ">";
			ni--;
		}
		else {
			tag = "<" inl ">";
			inline[++ni] = inl;
		}
		$0 = $0 substr(res, 0, RSTART - 1) tag;
		res = nres;
	}
	$0 = $0 res;
}

function dolink(href, lnk){
	return "<a href=\"" href "\">" lnk "</a>";
}

BEGIN {
	ni = 0;	# inlines
	nl = 0;	# nested lists
	nq = 0;	# quote blocks
	text = "";
	block = "p";
}

{
	# Quote blocks
	nnq = 0;
	while(sub(/^>/,""))
		nnq++;
	if(nnq != nq)
		newblock();
	while(nnq < nq){
		print "</blockquote>";
		nq--;
	}
	while(nnq > nq){
		print "<blockquote>";
		nq++;
	}

	# Escape html
	gsub("&", "\\&amp;");
	gsub("<", "\\&lt;");
}

# Horizontal rules (_ is not in markdown)
/^ *([-*_][ 	]*([-*_][ 	]*))([-*_][ 	]*)+$/ && ! text {
	print "<hr>";
	next;
}

# Tables (not in markdown)
# Syntax:
# 		Right Align| 	Center Align	|Left Align
/([ 	]\|)|(\|[ 	])/ && block != "code" {
	if(block != "table")
		newblock("table");
	nc = split($0, cells, "|");
	$0 = "<tr>\n";
	for(i = 1; i <= nc; i++){
		align = "left";
		if(sub(/^[ 	]+/, "", cells[i])){
			if(sub(/[ 	]+$/, "", cells[i]))
				align = "center";
			else
				align = "right";
		}
		sub(/[ 	]+$/,"", cells[i]);
		$0 = $0 "<td align=\"" align "\">" cells[i] "</td>\n";
	}
	$0 = $0 "</tr>";
}

# Paragraph
/^$/{
	newblock();
	while(nl > 0)
		print "</" list[nl--] ">";
	next;
}

# Ordered and unordered (possibly nested) lists
/^(  ? ?|	)*([*+-]|(([0-9]+\.)+))[ 	]/ && block != "code" {
	newblock("li");
	nnl = 0;
	while(match($0, /^(  ? ?|	)/))
		nnl += sub(/^(  ? ?|	)/, "");
	if(nnl == 0)
		nnl = 1;
	while(nl > nnl)
		print "</" list[nl--] ">";
	while(nl < nnl){
		list[++nl] = "ol";
		if(match($0, /^[*+-]/))
			list[nl] = "ul";
		print "<" list[nl] ">";
	}
	sub(/^([*+-]|(([0-9]+[\.-]?)+))[ 	]/,"");
	lp = 0;	# beginning of the last list paragraph
}
block == "li" {
	for(i = 0; i <= nl; i++)
		sub(/^(  ? ?|	)/,"");
}
/^$/ {
	text = substr(text, 0, lp) "<p>" substr(text, lp) "</p>";
	lp = length(text) + 2;
}

# Code blocks
/^(    |	)/ && block != "li" {
	if(block != "code")
		newblock("code");
	sub(/^(    |	)/, "");
	text = text $0 "\n";
	next;
}

# Setex-style Headers
# (Plus h3 with underscores.)
/^=+$/ {block = "h" 1;}
/^-+$/ {block = "h" 2;} 
/^_+$/ {block = "h" 3;}
/^=+$|^-+$|^_+$/ {next;}

# Atx-style headers
/^#/ {
	newblock();
	match($0, /#+/);
	n = RLENGTH;
	if(n > 6)
		n = 6;
	text = substr($0, RLENGTH + 1);
	block = "h" n;
	next;
}

{
	# undo \&
	gsub("\\\\&amp;", "\\&");
	# Images
	while(match($0, /!\[[^\]]+\]\([^\)]+\)/)){
		split(substr($0, RSTART + 2, RLENGTH - 3), a, /\]\(/);
		sub(/!\[[^\]]+\]\([^\)]+\)/, "<img src=\"" a[2] "\" alt=\"" a[1] "\">");
	}
	# Links
	while(match($0, /\[[^\]]+\]\([^\)]+\)/)){
		split(substr($0, RSTART + 1, RLENGTH - 2), a, /\]\(/);
		sub(/\[[^\]]+\]\([^\)]+\)/, dolink(a[2], a[1]));
	}
	# Undo html word by word
	for(i = 1; i <= NF; i++){
		gsub("&amp;.+;", "\\&&", $i);
		gsub("&&amp;", "\\&", $i);
		gsub("&lt;[A-Za-z !/]", "<&", $i);
		gsub("<&lt;", "<", $i);
	}
	# Auto links (uri matching is poor)
	while(match($0, /<(((https?|ftp|file|news|irc):\/\/)|(mailto:))[^>]+>/)) {
		link = substr($0, RSTART + 1, RLENGTH -2);
		sub(substr($0,RSTART,RLENGTH), dolink(link, link));
	}
	# Inline (TODO: underscores ?)
	subinline("(\\*\\*)|(__)", "strong");
	subinline("\\*", "em");
	subinline("`", "code");	# TODO: html escaping
	text = text (text ? " " : "") $0;
}

END {
	while(ni > 0)
		text = text "</" inline[ni--] ">";
	newblock();
	while(nl > 0)
		print "</" list[nl--] ">";
}
