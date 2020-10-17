#!/bin/sh
#
# https://rgz.ee/bin/ssg5
# Copyright 2018-2019 Roman Zolotarev <hi@romanzolotarev.com>
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

main() {
	test -n "$1" || usage
	test -n "$2" || usage
	test -n "$3" || usage
	test -n "$4" || usage
 	test -d "$1" || no_dir "$1"
 	test -d "$2" || no_dir "$2"


	src=$(readlink_f "$1")
	dst=$(readlink_f "$2")

	IGNORE=$(
		if ! test -f "$src/.ssgignore"
		then
			printf ' ! -path "*/.*"'
			return
		fi
		while read -r x
		do
			test -n "$x" || continue
			printf ' ! -path "*/%s*"' "$x"
		done < "$src/.ssgignore"
	)

	# files

	title="$3"

	h_file="$src/_header.html"
	f_file="$src/_footer.html"
	test -f "$h_file" && HEADER=$(cat "$h_file") && export HEADER
	test -f "$f_file" && FOOTER=$(cat "$f_file") && export FOOTER

	list_dirs "$src" | (cd "$src" && cpio -pdu "$dst")

	fs=$(
 	if test -f "$dst/.files"; then
 		list_affected_files "$src" "$dst/.files"
	else
		list_files "$1"
	fi
	)

	if test -n "$fs"; then
		echo "$fs" | tee "$dst/.files"

		if echo "$fs" | grep -q '\.md$'; then
			if test -x "$(which lowdown 2> /dev/null)"; then
				echo "$fs" | grep '\.md$' |
				render_md_files_lowdown "$src" "$dst" "$title"
			else
				if test -x "$(which Markdown.pl 2> /dev/null)"; then
					echo "$fs" | grep '\.md$' |
					render_md_files_Markdown_pl "$src" "$dst" "$title"
				else
					echo "couldn't find lowdown nor Markdown.pl"
					exit 3
				fi
			fi
		fi

		echo "$fs" | grep '\.html$' |
		render_html_files "$src" "$dst" "$title"


		echo "$fs" | grep -Ev '\.md$|\.html$' |
		(cd "$src" && cpio -pu "$dst")
	fi

	printf '[ssg] ' >&2
	print_status 'file, ' 'files, ' "$fs" >&2


	# sitemap

	base_url="$4"
	date=$(date +%Y-%m-%d)
 	urls=$(list_pages "$src")

	test -n "$urls" &&
	render_sitemap "$urls" "$base_url" "$date" > "$dst/sitemap.xml"
	render_article_list "$urls" "$base_url" "$dst" "$src"

	print_status 'url' 'urls' "$urls" >&2
	echo >&2
}


readlink_f() {
	file="$1"
	cd "$(dirname "$file")"
	file=$(basename "$file")
	while test -L "$file"
	do
		file=$(readlink "$file")
		cd "$(dirname "$file")"
		file=$(basename "$file")
	done
	dir=$(pwd -P)
	echo "$dir/$file"
}


print_status() {
	test -z "$3" && printf 'no %s' "$2" && return

	echo "$3" | awk -v singular="$1" -v plural="$2" '
	END {
		if (NR==1) printf NR " " singular
		if (NR>1) printf NR " " plural
	}'
}


usage() {
	echo "usage: ${0##*/} src dst title base_url" >&2
	exit 1
}


no_dir() {
	echo "${0##*/}: $1: No such directory" >&2
	exit 2
}

list_dirs() {
	cd "$1" && eval "find . -type d ! -name '.' ! -path '*/_*' $IGNORE"
}


list_files() {
	cd "$1" && eval "find . -type f ! -name '.' ! -path '*/_*' $IGNORE"
}


list_dependant_files () {
 	e="\\( -name '*.html' -o -name '*.md' -o -name '*.css' -o -name '*.js' \\)"
	cd "$1" && eval "find . -type f ! -name '.' ! -path '*/_*' $IGNORE $e"
}

list_newer_files() {
	cd "$1" && eval "find . -type f ! -name '.' $IGNORE -newer $2"
}


has_partials() {
	grep -qE '^./_.*\.html$|^./_.*\.js$|^./_.*\.css$'
}


list_affected_files() {
	fs=$(list_newer_files "$1" "$2")

	if echo "$fs" | has_partials; then
		list_dependant_files "$1"
	else
		echo "$fs"
	fi
}


render_html_files() {
	while read -r f
	do render_html_file "$3" < "$1/$f" > "$2/$f"
	done
}


render_md_files_lowdown() {
	# Check if the previous file has a date in it
	while read -r f
	do
		lowdown \
		--html-no-skiphtml \
		--html-no-escapehtml \
		-d metadata \
		-d autolink < "$1/$f" |
		render_html_file "$3" > "$2/${f%\.md}.html"
	done
}


render_md_files_Markdown_pl() {
	while read -r f
	do
		Markdown.pl < "$1/$f" |
		render_html_file "$3" \
		> "$2/${f%\.md}.html"
	done
}


render_html_file() {
	# h/t Devin Teske
	awk -v title="$1" '
	{ body = body "\n" $0 }
	END {
		body = substr(body, 2)
		if (body ~ /<[Hh][Tt][Mm][Ll]/) {
			print body
			exit
		}
		if (match(body, /<[[:space:]]*[Hh]1(>|[[:space:]][^>]*>)/)) {
			t = substr(body, RSTART + RLENGTH)
			sub("<[[:space:]]*/[[:space:]]*[Hh]1.*", "", t)
			gsub(/^[[:space:]]*|[[:space:]]$/, "", t)
			if (t) title = t " &mdash; " title
		}
		n = split(ENVIRON["HEADER"], header, /\n/)
		for (i = 1; i <= n; i++) {
			if (match(tolower(header[i]), "<title></title>")) {
				head = substr(header[i], 1, RSTART - 1)
				tail = substr(header[i], RSTART + RLENGTH)
				print head "<title>" title "</title>" tail
			} else print header[i]
		}
		print body
		print ENVIRON["FOOTER"]
	}'
}


list_pages() {
	e="\\( -name '*.html' -o -name '*.md' \\)"
	cd "$1" && eval "find . -type f ! -path '*/.*' ! -path '*/_*' $IGNORE $e" |
	sed 's#^./##;s#.md$#.html#;s#/index.html$#/#'
}

render_article_list() {
	urls="$1"
	# base_url="$2"
	items=""
	for i in $1; do
		if ! echo $i | grep -Eq "index|contact"; then
			url="$i"
			page_title=$(head -n 1 "$4/${i%\.html}.md" | cut -c 3-)
			item="<li><a class=\"article-nav-item\" href=\"./${url}\">${page_title}</a></li>"
			items="$item$items"
		fi
	done
	# sed -i non standard | can't cat directly?? aha: https://unix.stackexchange.com/a/586461
	test -f "$3/index.html" && cat "$3/index.html" | sed -e "s|<!--article-nav-placeholder-->|<nav class=\"article-nav\"><h2>Articles</h2><ul>${items}</ul></nav>|g" >| "$3/index_articles.html" && \
	mv -f "$3/index_articles.html" "$3/index.html"
}

render_sitemap() {
	urls="$1"
	base_url="$2"
	date="$3"

	echo '<?xml version="1.0" encoding="UTF-8"?>'
	echo '<urlset'
	echo 'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"'
	echo 'xsi:schemaLocation="http://www.sitemaps.org/schemas/sitemap/0.9'
	echo 'http://www.sitemaps.org/schemas/sitemap/0.9/sitemap.xsd"'
	echo 'xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">'
	echo "$urls" |
	sed -E 's#^(.*)$#<url><loc>'"$base_url"'/\1</loc><lastmod>'"$date"'</lastmod><priority>1.0</priority></url>#'
	echo '</urlset>'
}

main "$@"
