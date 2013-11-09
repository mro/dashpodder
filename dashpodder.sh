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

# read feeds from dp.conf, strip comment lines starting with #, collapse whitespace
sed -e 's/\s+/ / ; s/^#.*//' dp.conf | while read line
do
  if [ "$line" = "" ] ; then
    continue
  fi
  echo "$line"
  dst=$(echo "$line" | cut -f1 -d ' ')
  feed=$(echo "$line" | cut -d " " -f2)
  xslt=$(echo "$line" | cut -f3 -d ' ')
  amount=$(echo "$line" | cut -f4 -d ' ')
  user=$(echo "$line" | cut -f5 -d ' ')
  pass=$(echo "$line" | cut -f6 -d ' ')

  # fetch feed xml (rss) and get episode url and titles
  mkdir -p "podcasts/$dst"
  feed_original="podcasts/$dst/original.rss"
  feed_original_http_head="podcasts/$dst/original.http.rss"

  curl --silent --user-agent "$USER_AGENT" --user "$user:$pass" --anyauth --compressed --location --remote-time --time-cond "$feed_original" --dump-header "$feed_original_http_head" --output "$feed_original" --url "$feed"
  egrep -e "^HTTP/[^ ]+ 200 " "$feed_original_http_head" > /dev/null
  if [ $? = 0 ] ; then
    # download enclosure and extract <item> from feed rss
    xsltproc "$xslt" "$feed_original" 2>/dev/null \
    | sed -e 's/\s+/ /' \
    | head -n $amount \
    | while read episode
    do
      enclosure=$(echo "$episode" | cut -f1 -d ' ')
      title=$(echo "$episode" | cut -f2- -d ' ')
      extension=$(echo "$enclosure" | sed -e 's/^.*\.//')
      sha=$(echo "$enclosure" | shasum | cut -d ' ' -f1)
      file_base=$(echo "podcasts/$dst/$sha-$title" | sed -e 's/#/_/') # curl doesn't like # in filenames
      file="$file_base.$extension"
      file_rss="$file_base.item.rss"
      tmp="$file.part~"
      http="$file.head~"
      echo "\t$enclosure"

      curl --silent --user-agent "$USER_AGENT" --user "$user:$pass" --anyauth --compressed --location --remote-time --time-cond "$file" --dump-header "$http" --output "$tmp" --url "$enclosure"
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
    cat "podcasts/$dst/index.head.rss" > "$index_rss"
    # todo: <pubDate> and <lastBuildDate>
    ls -t "podcasts/$dst/"*.item.rss \
    | while read item_rss
    do
      # append in order
      cat "$item_rss" >> "$index_rss"
    done
    cat "podcasts/$dst/index.tail.rss" >> "$index_rss"
    touch -r "$feed_original" "$index_rss"
  fi
done
