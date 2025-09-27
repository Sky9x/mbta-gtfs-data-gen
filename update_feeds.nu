# fetch feed list
wget --no-show-progress -O archived_feeds.txt 'https://cdn.mbta.com/archive/archived_feeds.txt'

let archived_feeds = open archived_feeds.txt --raw | from csv --no-infer

# -- first time run check --

if not ("archived_feeds" | path exists) {
    mkdir archived_feeds
    "filename,mtime\n" | save file_times.csv
}

# -- Update All Feeds --

cd archived_feeds

let file_times = open ../file_times.csv --raw | from csv --no-infer

# restore file mtimes for use with wget -N (git doesn't save them)
for $it in $file_times {
    # nushell's touch doesn't support -d ?????
    # the entire purpose of touch is to change file times????????
    run-external "touch" "-cm" $it.filename "-d" ("@" + $it.mtime)
}

# wget all urls
$archived_feeds | get archive_url | str join "\n" | wget --no-show-progress --timestamping --no-if-modified-since -i -

let new_file_times = stat *.zip --format "%n,%Y" | from csv --no-infer --noheaders | rename filename mtime

if $file_times == $new_file_times {
    print "no new archives"
} else {
    print "some archives were updated"
    $new_file_times | save ../file_times.csv --force
}
