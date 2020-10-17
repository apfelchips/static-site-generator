#!/bin/sh
#
# https://www.romanzolotarev.com/bin/rssg
# Copyright 2018 Roman Zolotarev <hi@romanzolotarev.com>
#
# Permission to use, copy, modify, and/or distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

set -e

export PATH="$(realpath $(dirname $0)):$PATH"
test -f "$(dirname $0)/.env" && . "$(dirname $0)/.env"

main () {
	test -n "$1" || usage
	test -f "$1" || no_file "$1"


	index_file=$(realpath "$1")
	base_dir="$(dirname $index_file)"
	html=$(cat "$index_file")
	base_url="${2:-localhost:8080}"

	#description=$( echo "$html" | get_description | remove_tags | remove_nbsp )

	#echo $html

	items=$(echo "$html" | get_items)

	echo $items

	rss=$(echo "$items" |
	 	render_items "$base" "$base_url" |
	 	render_feed "$url" "$title" "$description")

	>&2 echo "[rssg] ${index_file##$(pwd)/} $(echo "$rss" | grep -c '<item>') items"
	echo "$rss"
}


usage() {
	echo "usage: ${0##*/} index.{html,md} title > rss.xml" >&2
	exit 1
}


no_file() {
	echo "${0##*/}: $1: No such file" >&2
	exit 2
}


md_to_html() {
	test -x "$(which lowdown)" || exit 3
	lowdown \
	-D html-skiphtml \
	-D smarty \
	-d metadata \
	-d autolink "$1"
}


get_title() {
	awk 'tolower($0)~/^<h1/{gsub(/<[^>]*>/,"",$0);print;exit}'
}


get_url() {
	grep -i '<a .*rss.xml"' | head -1 |
	sed 's#.*href="\(.*\)".*#\1#'
}


get_items() {
	grep "article-nav-item" # | sed 's#.*href="\(.*\)">\(.*\)</a>#\1 \2#'
}


get_description() {
	start='sub("^.*<"s"*"t"("s"[^>]*)?>","")'
	stop='sub("</"s"*"t""s"*>.*","")&&x=1'
	awk -v 's=[[:space:]]' -v 't=[Pp]' "$start,$stop;x{exit}"
}

remove_tags() {
	sed 's#<[^>]*>##g;s#</[^>]*>##g'
}


remove_nbsp() {
	sed 's#\&nbsp;# #g'
}


rel_to_abs_urls() {
	site_url="$1"
	base_url="$2"

	abs='s#(src|href)="/([^"]*)"#\1="'"$site_url"/'\2"#g'
	rel='s#(src|href)="([^:/"]*)"#\1="'"$base_url"/'\2"#g'
	sed -E "$abs;$rel"
}


date_rfc_822() {
	date -j '+%a, %d %b %Y %H:%M:%S %z' \
	"$(echo "$1"| tr -cd '[:digit:]')0000"
}


render_items() {
	while read -r i
	do render_item "$1" "$2" "$i"
	done
}


render_item() {
	base="$1"
	base_url="$2"
	item="$3"

	site_url="$(echo "$base_url"| sed 's#\(.*//.*\)/.*#\1#')"

	date=$(echo "$item"|awk '{print$2}')
	url=$(echo "$item"|awk '{print$1}')

	f="$base/$url"
	test -f "$f" && html=$(cat "$f")
	test -f "${f%\.html}.md" && html=$(md_to_html "${f%\.html}.md")

	description=$(
		echo "$html" |
		rel_to_abs_urls "$site_url" "$base_url" |
		remove_nbsp
	)
	title=$(echo "$description" | get_title)
	guid="$base_url/$(echo "$url" | sed 's#^/##')"

	echo '
<item>
<guid>'"$guid"'</guid>
<link>'"$guid"'</link>
<pubDate>'"$(date_rfc_822 "$date")"'</pubDate>
<title>'"$title"'</title>
<description><![CDATA[

'"$description"'

]]></description>
</item>'
}


render_feed() {
	url="$1"
	title=$(echo "$2" | remove_nbsp)
	description="$3"

	base_url="$(echo "$url" | cut -d '/' -f1-3)"

	echo '<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom">
<channel>
<atom:link href="'"$url"'" rel="self" type="application/rss+xml" />
<title>'"$title"'</title>
<description>'"$description"'</description>
<link>'"$base_url"'/</link>
<lastBuildDate>'"$(date_rfc_822 date)"'</lastBuildDate>
'"$(cat)"'
</channel></rss>'
}


main "$@"
