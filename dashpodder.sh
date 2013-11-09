#!/bin/sh
#
# simple commandline podcatcher.
#
# inspired by
# - http://lincgeek.org/bashpodder/
# - https://code.google.com/p/mashpodder/
#
USER_AGENT=$(basename $0)

# read dp.conf and strip comment lines starting with #
sed -e 's/^#.*//' dp.conf | while read line
do
  if [ "$line" = "" ] ; then
    continue
  fi
  echo "$line"
  dst=$(echo "$line" | cut -f1 -d ' ')
  feed=$(echo "$line" | cut -f2 -d ' ')
  xslt=$(echo "$line" | cut -f3 -d ' ')
  amount=$(echo "$line" | cut -f4 -d ' ')
  user=$(echo "$line" | cut -f5 -d ' ')
  pass=$(echo "$line" | cut -f6 -d ' ')

  # fetch feed xml (rss) and get episode url and titles
  mkdir -p "podcasts/$dst"
  curl --silent --user-agent "$USER_AGENT" --user "$user:$pass" --anyauth --compressed --location --url "$feed" \
  | xsltproc "$xslt" - 2>/dev/null \
  | head -n $amount \
  | while read episode
  do
    enclosure=$(echo "$episode" | cut -f1 -d ' ')
    title=$(echo "$episode" | cut -f2- -d ' ')
    extension=$(echo "$enclosure" | sed -e 's/^.*\.//')
    sha=$(echo "$enclosure" | shasum | cut -d ' ' -f1)
    file_base=$(echo "podcasts/$dst/$sha-$title" | sed -e 's/#/_/') # curl doesn't like # in filenames
    file="$file_base.$extension"
    file_rss="$file_base.rss.item"
    tmp="$file.part~"
    echo "\t$enclosure"
    # remove after first run
    # xsltproc -stringparam enclosure "$enclosure" -stringparam now "$file" rss-item.xslt "$feed" 2>/dev/null > "$file_rss"  
    curl --silent --user-agent "$USER_AGENT" --user "$user:$pass" --anyauth --compressed --location --remote-time --time-cond "$file" --output "$tmp" --url "$enclosure"
    # better check http status == 200
    if [ $? = 0 ] && [ -f "$tmp" ] && [ $(du -k "$tmp" | cut -f 1) -gt 4 ] ; then
      mv "$tmp" "$file"
      # keep rss item feed xml snippet
      curl --silent --user-agent "$USER_AGENT" --user "$user:$pass" --anyauth --compressed --location --url "$feed" \
      | xsltproc -stringparam enclosure "$enclosure" -stringparam now "$file" rss-item.xslt - 2>/dev/null \
      > "$file_rss"
    fi
    rm "$tmp" 2>/dev/null
  done
  # purge outdated (but keep all .rss.item)
  ls -t "podcasts/$dst" \
  | egrep -ve "\.rss\.item$" \
  | tail -n +$((amount+1)) \
  | while read f
  do
    echo "\tpurge podcasts/$dst/$f"
    rm "$f"
  done
done
