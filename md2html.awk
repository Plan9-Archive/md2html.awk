#!/bin/awk -f
# md2html.awk
# by: Jesus Galan (yiyus) <yiyu.jgl@gmail>, 2006 - June 2009
# Usage: md2html.awk file.md > file.html

function newblock(nblock){
	if(block == "code")
		text = "<pre>\n" text "</pre>";
	while(text && block != "li" && nl > 0)
		print "</" list[nl--] ">";
	if(text) {
		if(block == "p" && match(text, /^<.*>$/))
			print text;
		else
			print "<" block ">" text "</" block ">";
	}
	text = "";
	block = nblock ? nblock : "p";
}

function subinline(tgl, inl){
	res = $0;
	$0 = "";
	while(match(res, tgl)){
		nres = substr(res, RSTART + RLENGTH);
		il = inline[ni];
		if(inline[ni] == inl){
			tag = "</" inl ">";
			ni--;
		}
		else {
			tag = "<" inl ">";
			inline[++ni] = inl;
		}
		inltext = substr(res, 0, RSTART - 1);
		if(tgl == "`" && il == "code"){
			gsub("&amp;#?[A-Za-z0-9]+;", "\\&&", inltext);
			gsub("&&amp;", "\\&", inltext);
			gsub("&lt;[A-Za-z !/]", "<&", inltext);
			gsub("<&lt;", "<", inltext);
		}
		$0 = $0 inltext tag;
		res = nres;
	}
	if(tgl == "`" && inline[ni] != "code"){
		gsub("&amp;#?[A-Za-z0-9]+;", "\\&&", res);
		gsub("&&amp;", "\\&", res);
		gsub("&lt;[A-Za-z!/]", "<&", res);
		gsub("<&lt;", "<", res);
	}
	$0 = $0 res;
}

function dolink(href, link){
	return "<a href=\"" href "\">" link "</a>";
}

BEGIN {
	ni = 0;	# inlines
	nl = 0;	# nested lists
	nq = 0;	# quote blocks
	text = "";
	block = "p";
}

# html
block == "p" && /^[ 	]*<[A-Za-z\/!].*>[ 	]*$/ {
	newblock();
	print;
	next;
}

{
	# Quote blocks
	nnq = 0;
	while(sub(/^> ?/,""))
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

# Horizontal rules
/^ ? ? ?([-*_][ 	]*)([-*_][ 	]*)([-*_][ 	]*)+$/ && text ~ /^[ 	]*$/ {
	while(block != "li" && nl > 0)
		print "</" list[nl--] ">";
	print "<hr>";
	text = "";
	next;
}

# Tables (not in markdown)
# Syntax:
# | 		Right Align| 	Center Align	|Left Align	|
/^\|.*/ && /([ 	]\|)|(\|[ 	])/ && block != "code" {
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
	next;
}

# Code blocks
/^(    |	)/ && block != "li" {
	if(block != "code")
		newblock("code");
	sub(/^(    |	)/, "");
	text = text $0 "\n";
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
	subinline("`", "code");
	# Images
	while(match($0, /!\[[^\]]+\]\([^\)]+\)/)){
		split(substr($0, RSTART + 2, RLENGTH - 3), a, /\]\(/);
		$0 = substr($0, 0, RSTART - 1) "<img src=\"" a[2] "\" alt=\"" a[1] "\">" substr($0, RSTART + RLENGTH);
	}
	# Links
	while(match($0, /\[[^\]]+\]\([^\)]+\)/)){
		split(substr($0, RSTART + 1, RLENGTH - 2), a, /\]\(/);
		$0 = substr($0, 0, RSTART - 1) dolink(a[2], a[1]) substr($0, RSTART + RLENGTH);
	}
	# Auto links (uri matching is poor)
	while(match($0, /<(((https?|ftp|file|news|irc):\/\/)|(mailto:))[^>]+>/)) {
		link = substr($0, RSTART + 1, RLENGTH -2);
		$0 = substr($0, 0, RSTART - 1) dolink(link, link) substr($0, RSTART + RLENGTH);
	}
	# Inline (TODO: underscores ?)
	subinline("(\\*\\*)|(__)", "strong");
	subinline("\\*", "em");
	text = text (text ? " " : "") $0;
}

END {
	while(ni > 0)
		text = text "</" inline[ni--] ">";
	newblock();
	while(nl > 0)
		print "</" list[nl--] ">";
	while(nq > 0){
		print "</blockquote>";
		nq--;
	}
}
