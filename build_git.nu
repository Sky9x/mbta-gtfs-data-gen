let feed_versions = open archived_feeds.txt --raw | from csv --no-infer

rm -rfpv build_git
mkdir build_git -v
cd build_git

git init

git config --local --add user.name "MBTA"
git config --local --add user.email "developer@mbta.com"
git config --local --add commit.gpgSign false
git config --local --add gc.auto 0

with-env { GIT_COMMITTER_DATE: "1970-01-01T00:00:00Z", GIT_AUTHOR_DATE: "1970-01-01T00:00:00Z" } {
    git commit -vv -m "Initial Dummy Commit" --allow-empty
}

# -- loop over each feed version --

for $feed in ($feed_versions | reverse) {
    print ""

    # get rid of everything except .git and README.md
    for $file in (ls -a | where name != ".git" and name != "README.md") {
        rm -p $file.name
    }

    let filename = $feed.archive_url | split row '/' | last

    # extract the zip
    unzip $"../archived_feeds/($filename)" -x "stop_times.txt"

    # -- cleanup --

    # remove macos artifacts (fuck you tim apple!)
    rm -rfpv __MACOSX .DS_STORE

    if $filename == "20180216.zip" {
        rm -rfpv "20180216" # it contains a subfolder with exactly the same files WHHYYY
    }

    # the files are way too big (50-300MiB)
    # wreaks havoc on git's delta compression and github doesn't like it either
    #rm -fp stop_times.txt

    # -- commit --

    # this is hell.
    let date = $feed.feed_version | split row ',' | first 2 | str join | split row ' ' | last | into datetime

    # add and commit. its that easy!
    git add .
    with-env { GIT_COMMITTER_DATE: $date, GIT_AUTHOR_DATE: $date } {
        git commit -vv -m (commit-msg $feed)
    }
}

print ""
print ""

cp -v ../built-readme.md README.md

git add -v README.md
git commit -vv -m "Add README.md"

print ""
print ""

git gc --aggressive

print ""

git remote -v add origin git@github.com:Sky9x/mbta-gtfs-data.git

def commit-msg [feed] {
    let start = $feed.feed_start_date | format date "%D"
    let end = $feed.feed_end_date | format date "%D"
    let version = $feed.feed_version
    let url = $feed.archive_url
    let notes = $feed.archive_note | str replace --all --regex "; |;" "\n"

    $"[($start)-($end)] ($version)\n\n($notes)\n\n($url)" | str trim
}
