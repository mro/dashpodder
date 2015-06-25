#!/bin/sh
#
# simple commandline podcatcher.
#
# Downloads rss and enclosures, creates a local index.rss with rewritten enclosure urls.
#
# inspired by
# - http://lincgeek.org/bashpodder/
# - https://code.google.com/p/mashpodder/
#
USER_AGENT=$(basename $0)
USER_AGENT="http://purl.mro.name/dashpodder"

curl --version >/dev/null || { echo "install curl" && exit 1; }
xsltproc --version >/dev/null || { echo "install xsltproc" && exit 1; }
xmllint --version 2>/dev/null || { echo "install xmllint" && exit 1; }
if [ '68ac906495480a3404beee4874ed853a037a7a8f  -' != "$(echo -n 'Franz jagt im komplett verwahrlosten Taxi quer durch Bayern' | shasum)" ] ; then
  echo "shasum produces strange results." && exit 1
fi
if [ 'd4774986530809767bfafb171f01b060dbc137a3  -' != "$(echo 'Franz jagt im komplett verwahrlosten Taxi quer durch Bayern' | shasum)" ] ; then
  echo "shasum produces strange results." && exit 1
fi

echo "$(date +%FT%T%z) start..."

# read feeds from dp.conf, strip comment lines starting with #, collapse whitespace
sed -re 's/\s+/ / ; s/^#.*//' dp.conf | while read dst feed xslt amount user pass
do
  if [ "$amount" = "" ] ; then
    continue
  fi
  echo "$dst $feed $xslt $amount $user $pass"

  # fetch feed xml (rss) and get episode url and titles
  mkdir -p "podcasts/$dst"
  feed_original="podcasts/$dst/original.rss"
  feed_original_http_head="podcasts/$dst/original.http.rss"

  curl --silent --limit-rate 800K --user-agent "$USER_AGENT" --user "$user:$pass" --anyauth --compressed --location --remote-time --time-cond "$feed_original" --dump-header "$feed_original_http_head" --output "$feed_original" --url "$feed"
  egrep -e "^HTTP/[^ ]+ 200 " "$feed_original_http_head" > /dev/null
  if [ $? = 0 ] ; then
    # download enclosure and extract <item> from feed rss
    xsltproc "$xslt" "$feed_original" 2>/dev/null \
    | sed -re 's/\s+/ /' \
    | head -n $amount \
    | while read enclosure title
    do
      extension=$(echo "$enclosure" | sed -e 's/^.*\.//')
      sha=$(echo "$enclosure" | shasum | cut -d ' ' -f1)
      file_base=$(echo "podcasts/$dst/$sha-$title" | sed -e 's/#/_/') # curl doesn't like # in filenames
      file="$file_base.$extension"
      file_rss="$file_base.item.rss"
      tmp="$file.part~"
      http="$file.head~"
      echo "\t$enclosure"

      curl --silent --limit-rate 800K --user-agent "$USER_AGENT" --user "$user:$pass" --anyauth --compressed --location --remote-time --time-cond "$file" --dump-header "$http" --output "$tmp" --url "$enclosure"
      egrep -e "^HTTP/[^ ]+ 200 " "$http" > /dev/null
      if [ $? = 0 ] ; then
        mv "$tmp" "$file"
        # get rss item, rewrite enclosure url, TODO: make absolute url.
        xsltproc -stringparam enclosure "$enclosure" -stringparam now "$file" --output "$file_rss" item.rss.xslt "$feed_original" 2>/dev/null
        touch -r "$file" "$file_rss"
      fi
      rm "$tmp" "$http" 2>/dev/null
    done
    rm "$feed_original_http_head" 2>/dev/null

    # clean up duplicates?

    # purge outdated enclosures (but keep all *.rss)
    ls -t "podcasts/$dst"/* \
    | egrep -ve "\.rss$" \
    | tail -n +$((amount+1)) \
    | while read f
    do
      echo "\tpurge $f"
      rm "$f"
    done

    # build local podcast index.rss
    index_rss="podcasts/$dst/index.rss"
    cat "podcasts/$dst/index.head.rss" > "$index_rss"~
    # todo: <pubDate> and <lastBuildDate>
    ls -t "podcasts/$dst/"*.item.rss \
    | while read item_rss
    do
      # append in order
      cat "$item_rss" >> "$index_rss"~
    done
    cat "podcasts/$dst/index.tail.rss" >> "$index_rss"~
    xmllint --format --encode UTF-8 --output "$index_rss" "$index_rss"~ && touch -r "$feed_original" "$index_rss"
    rm "$index_rss"~
  fi
  echo "$(date +%FT%T%z) done $dst"
done

echo "$(date +%FT%T%z) finish."
