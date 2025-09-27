wget --no-verbose -O archived_feeds.txt 'https://cdn.mbta.com/archive/archived_feeds.txt'

print -e ""

let archived_feeds = open archived_feeds.txt --raw | from csv --no-infer
mut file_times = open file_times.csv --raw | from csv --no-infer | transpose -ird | update cells { into datetime -f "%s" }

mkdir archived_feeds
cd archived_feeds

for $url in $archived_feeds.archive_url {
    let filename = $url | url parse | get path | path basename
    let mtime = $file_times | get -o $filename

    let headers = http head $url | transpose -ird
    let newtime = $headers.last-modified! | into datetime | date to-timezone UTC

    if $mtime == null or $mtime < $newtime {
        if $mtime == null {
            print -e $"New Feed: ($filename)"
        } else {
            print -e $"Feed Updated: ($filename)"
        }

        # remove old feed (if present)
        rm -pfv $filename

        # fetch new feed
        wget --no-verbose --timestamping $url
        print -e ""

        # update timestamp
        $file_times = $file_times | upsert $filename $newtime
    } else {
        print -e $"Fresh: ($filename)"
    }
}

$file_times | update cells { format date "%s" } | transpose filename mtime | save -f ../file_times.csv
