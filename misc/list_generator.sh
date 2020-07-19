#! /bin/bash

movies=$(find ~/plex/Personal/films/Collection/ -type f \
	\( -iname \*.mkv -o -iname \*.avi -o -iname \*.m4v -o -iname \*.mp4 \))

episodes=$(find ~/plex/Personal/tv/Bot -type f -iname "*.mkv")

limit=$(echo "$movies" | wc -l)
limit1=$(echo "$episodes" | wc -l)

## we will use some wild piping and a tricky loop because
## for some reason mapfile can't handle filenames with spaces :(

movieList=$(for d in $( seq 1 ${limit} ); do
	movie=$(echo "$movies" | sed $d!d)
	echo "$movie" | python3 /usr/local/bin/guessit "$movie" -j \
		| jq -r '("* " + .title + " - " + (.year|tostring) + "; " + .source)'
	done)

episodeList=$(for i in $( seq 1 ${limit1} ); do
	episode=$(echo "$episodes" | sed $d!d)
	echo "$episode" | python3 /usr/local/bin/guessit "$episode" -j \
		| jq -r '("* " + .title + " - Season " + (.season|tostring) + ", Episode  " + (.episode|tostring) + "; " + .source)'
	done)

echo -e "---
title: Certified Kino Bot
output:
  html_document:
    toc: yes
pagetitle: Certified Kino Bot
---
### This list was automatically generated at $(date). This list is updated every day.
### Table of Contents
1. [Movies](#Movies)
2. [Episodes](#Episodes)

## Movies
$movieList

## Episodes
$episodeList" > ~/.kinobot.md

pandoc ~/.kinobot.md -s -o /var/www/collage/kinobot.html
