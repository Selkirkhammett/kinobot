#! /bin/bash

## crontab: */20 10-23,0-3 * * * ~/kinobot.sh

facebook_token=$(cat ~/.tokens | jq -r .facebook)
tmdb_token=$(cat ~/.tokens | jq -r .tmdb)
google_token=$(cat ~/.tokens | jq -r .google)

date1=$(date +"%H:%M:%S GMT %:z")

rm -rf /var/www/html/bbad/*

function sorteo_pelicula {
	lista=$(ls ~/plex/Personal/films/Criterion/ | grep -E "mkv|mp4|m4v|avi")
	numero=$(ls ~/plex/Personal/films/Criterion/ | grep -E "mkv|mp4|m4v|avi" | wc -l)
	numero1=$(shuf -i 1-${numero} -n 1)
	lista1=$(sed $numero1!d <(echo "$lista"))
	pelicula=$(echo "/home/victor/plex/Personal/films/Criterion/${lista1}") ## I forgot to change the name. It's not a folder full of Criterion movies
	guessit=$(python3 /usr/local/bin/guessit "$pelicula" -j)
	terminar="None"
	titulo=$(echo "$guessit" | jq -r .title)

	if [ -z "$titulo" ]; then
		exit 1
	fi

	anho=$(echo "$guessit" | jq -r .year)
	name=$(echo "${pelicula%.*}")
	}

function elegir_frame {
	duration=$(($(mediainfo --Inform="General;%Duration%" "${pelicula}" ) / 1000 ))
	framerate=$(mediainfo --Inform="General;%FrameRate%" "${pelicula}")
	let duration=duration-140
	shuffled=$(shuf -i 90-${duration} -n 1)
	frame=$(echo ${shuffled}*${framerate} | bc)
	frameint=${frame%.*}
	random_time=$(date -u -d @$(echo $shuffled) +"%T")
	}


function normal_frame {
	elegir_frame

	ffmpeg -ss ${random_time} -copyts -i "$pelicula" -vf subtitles="${name}.en.srt" -vframes 1 "/var/www/html/bbad/${random_time}.png" 2> /dev/null

	if [ ! -e "/var/www/html/bbad/${random_time}.png" ]; then
		ffmpeg -ss ${random_time} -copyts -i "$pelicula" -vframes 1 "/var/www/html/bbad/${random_time}.png" 2> /dev/null
	fi
	}

function third_rule_frame {
	elegir_frame

	ffmpeg -ss ${random_time} -copyts -i "$pelicula" -vf subtitles="${name}.en.srt" -vframes 1 "/var/www/html/bbad/${random_time}.png" 2> /dev/null
	nice -n 19 convert "/var/www/html/bbad/${random_time}.png" \( +clone -colorspace gray   -fx "(i==0||i==int(w/3)||i==2*int(w/3)||i==w-1||j==0||j==int(h/3)||j==2*int(h/3)||j==h-1)?0:1" \) -compose darken -composite "/var/www/html/bbad/${random_time}.png" 2> /dev/null

	if [ ! -e "/var/www/html/bbad/${random_time}.png" ]; then
		ffmpeg -ss ${random_time} -copyts -i "$pelicula" -vframes 1 "/var/www/html/bbad/${random_time}.png" 2> /dev/null
		nice -n 19 convert "/var/www/html/bbad/${random_time}.png" \( +clone -colorspace gray   -fx "(i==0||i==int(w/3)||i==2*int(w/3)||i==w-1||j==0||j==int(h/3)||j==2*int(h/3)||j==h-1)?0:1" \) -compose darken -composite "/var/www/html/bbad/${random_time}.png" 2> /dev/null
	fi
	}

function tmdb_api {
	dawget=$(wget -qO- "https://api.themoviedb.org/3/search/movie?api_key=${tmdb_token}&query=${titulo}&year=${anho}")
	id_peli=$(echo "$dawget" | jq .results[].id | head -n1)
	dawget2=$(wget -qO- "https://api.themoviedb.org/3/movie/${id_peli}?api_key=${tmdb_token}")
	director_inf=$(wget -qO- "https://api.themoviedb.org/3/movie/${id_peli}/credits?api_key=${tmdb_token}" | jq '.crew[] | select(.job == "Director")' | jq -r .name | head -n1)
	recos=$(wget -qO- "https://api.themoviedb.org/3/movie/${id_peli}/recommendations?api_key=${tmdb_token}" | jq -r .results[].release_date | date +"%Y" -f - | head -n5 | tr '\n' ' ')
	recos_titles=$(wget -qO- "https://api.themoviedb.org/3/movie/${id_peli}/recommendations?api_key=${tmdb_token}" | jq -r .results[].title | head -n5 | tr '\n' ',')

	IFS=' ' read -r -a rec_year <<< "$recos"
	IFS=',' read -r -a rec_title <<< "$recos_titles"

	year=$(echo "$dawget2" | jq -r .release_date | date +"%Y" -f -)
	genres=$(echo "$dawget2" | jq -r '[.genres[].name]|join(", ")')
	title5=$(echo "$dawget2" | jq -r .title)
	og_title=$(echo "$dawget2" | jq -r .original_title)
	sinopsis=$(echo "$dawget2" | jq -r .overview)
	country=$(echo "$dawget2" | jq -r '[.production_countries[].name]|join(", ")')
	tagline=$(echo "$dawget2" | jq -r .tagline)
	rating=$(echo "$dawget2" | jq -r .vote_average)

	if [ -z "$title5" ]; then
		exit 1
	fi

	link7=$(wget -qO- "https://www.googleapis.com/customsearch/v1/?cx=${google_token}&q=${title5}&num=1" | jq -r .items[].link)
	sinopsis_mubi=$(wget -qO- "${link7}" | pup 'p[class=light-on-dark] json{}' --charset UTF-8 | jq -r .[].text | sed '2!d')
	}

function random_cast {
	randomcast=$(shuf -n 1 ~/cast_list)
	link7=$(wget -qO- "https://www.googleapis.com/customsearch/v1/?cx=${google_token}&q=${randomcast}&num=1" | jq -r .items[].link)
	imagen=$(wget -qO- "https://www.googleapis.com/customsearch/v1/?cx=${google_token}&searchType=image&q=${randomcast}&num=3" | jq -r .items[].link)
	quote=$(wget -qO- "${link7}" | pup -p 'div[class="entity-description cast-member-quote"] json{}' --charset UTF-8 | jq -r .[].text)

	if [ -z "$quote" ]; then
		biogra=$(echo -e "Bot has randomly chosen: ${randomcast} \n \nThis bot was automatically executed at $(echo "$date1"); last commit: Jul 14")
	else
		biogra=$(echo -e "${quote} \n \nBot has randomly chosen: ${randomcast} \n \nThis bot was automatically executed at $(echo "$date1"); last commit: Jul 14")
	fi

	while IFS= read -r line; do
		random3=$(shuf -i50000-10000000 -n 1)

		if [[ $line =~ \.png$ ]]; then
			wget -qO /var/www/html/bbad/${random3}.png "${line}"
		elif [[ $line =~ \.jpg$ ]]; then
			wget -qO /var/www/html/bbad/${random3}.jpg "${line}"
		elif [[ $line =~ \.jpeg$ ]]; then
			wget -qO /var/www/html/bbad/${random3}.jpg "${line}"
		fi
	done < <(echo "$imagen")

	imagenes=$(ls /var/www/html/bbad/)
	imagen1=$(shuf -n 1 <(echo "$imagenes"))

	curl -s -X POST \
		-d "url=http://109.169.10.182/bbad/${imagen1}" \
		-d "caption=${biogra}" \
		-d "access_token=${facebook_token}" \
		"https://graph.facebook.com/111665010589899/photos"
	}

function descripciones_and_post {
	if [ -z "$sinopsis_mubi" ]; then
		if [ -z "$frameint" ]; then
			descripcion=$(echo -e "${director_inf} - ${title5} (${year}) \nSecond: ${random_time} \nCountry: ${country} \nGenres: ${genres} \n \nAutomatically executed at $(echo "$date1"); last commit: Jul 14; database size: $(du -h ~/plex/Personal/films/Criterion | cut -f1 -d"T")TBs; collected films: $(ls ~/plex/Personal/films/Criterion/ | grep .mkv | wc -l) \nThis bot is open source: https://github.com/vitiko123/Certified-Kino-Bot/")
		else
			descripcion=$(echo -e "${director_inf} - ${title5} (${year}) \nFrame: ${frameint} \nCountry: ${country} \nGenres: ${genres} \n \nAutomatically executed at $(echo "$date1"); last commit: Jul 14; database size: $(du -h ~/plex/Personal/films/Criterion | cut -f1 -d"T")TBs; collected films: $(ls ~/plex/Personal/films/Criterion/ | grep .mkv | wc -l) \nThis bot is open source: https://github.com/vitiko123/Certified-Kino-Bot/")
		fi		
	else
		if [ -z "$frameint" ]; then
			descripcion=$(echo -e "${director_inf} - ${title5} (${year}) \nSecond: ${random_time} \nCountry: ${country} \n \n${sinopsis_mubi} \n \nAutomatically executed at $(echo "$date1"); last commit: Jul 14; database size: $(du -h ~/plex/Personal/films/Criterion | cut -f1 -d"T")TBs; collected films: $(ls ~/plex/Personal/films/Criterion/ | grep .mkv | wc -l) \nThis bot is open source: https://github.com/vitiko123/Certified-Kino-Bot/")			
		else
			descripcion=$(echo -e "${director_inf} - ${title5} (${year}) \nFrame: ${frameint} \nCountry: ${country} \n \n${sinopsis_mubi} \n \nAutomatically executed at $(echo "$date1"); last commit: Jul 14; database size: $(du -h ~/plex/Personal/films/Criterion | cut -f1 -d"T")TBs; collected films: $(ls ~/plex/Personal/films/Criterion/ | grep .mkv | wc -l) \nThis bot is open source: https://github.com/vitiko123/Certified-Kino-Bot/")
		fi

	fi
	
	curl -s -X POST \
	-d "url=http://109.169.10.182/bbad/${random_time}.png" \
	-d "caption=${descripcion}" \
	-d "access_token=${facebook_token}" \
	"https://graph.facebook.com/111665010589899/photos"
	}

numero2=$(shuf -i 1-20 -n 1)

if [ $numero2 -eq 1 ]; then
	random_cast
elif [ $numero2 -gt 1 -a $numero2 -lt 16 ]; then
	sorteo_pelicula
	elegir_frame
	normal_frame
	tmdb_api
	descripciones_and_post
else
	sorteo_pelicula
	elegir_frame
	third_rule_frame
	tmdb_api
	descripciones_and_post
fi
