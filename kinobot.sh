#! /bin/bash

## crontab: */30 10-23,0-3 * * * ~/kinobot.sh

facebook_token=$(jq -r .facebook ~/.tokens)
tmdb_token=$(jq -r .tmdb ~/.tokens)
google_token=$(jq -r .google ~/.tokens)
randomorg=$(jq -r .random ~/.tokens)

date1=$(date +"%H:%M:%S GMT %:z")
terminar="None"
collected_films=$(ls ~/plex/Personal/films/Collection/ | grep -E "mkv|mp4|m4v|avi" | wc -l)
collected_tv=$(find ~/plex/Personal/tv/Bot/ -name "*mkv" | wc -l)
films_size=$(du -h ~/plex/Personal/films/Collection | cut -f1)
episodes_size=$(du -h --max-depth=0 ~/plex/Personal/tv/Bot | cut -f1)
commit=$(git --git-dir /home/victor/Certified-Kino-Bot/.git log --graph --pretty=format:'%cr' \
	| cut -d "*" -f 2 | sed 1!d)

footnote="Automatically executed at $date1; last commit:${commit}; collected films: $collected_films (${films_size}B); collected episodes: $collected_tv (${episodes_size}B) \n \nThis bot is open source: https://github.com/vitiko123/Certified-Kino-Bot/"

rm -rf /var/www/html/bbad/*

function sorteo_pelicula {
	lista=$(ls ~/plex/Personal/films/Collection/ | grep -E "mkv|mp4|m4v|avi")
	numero1=$(curl -s --header "Content-Type: application/json; charset=utf-8" \
	  --request POST \
	  --data '{"jsonrpc":"2.0","method":"generateIntegers","params":{"apiKey":"'$randomorg'","n":1,"min":1,"max":'$collected_films',"replacement":true,"base":10},"id":6206}' \
	  "https://api.random.org/json-rpc/2/invoke" | jq .result.random.data[])
	lista1=$(sed $numero1!d <(echo "$lista"))
	pelicula=$(echo "/home/victor/plex/Personal/films/Collection/${lista1}") 
	guessit=$(python3 /usr/local/bin/guessit "$pelicula" -j)
	titulo=$(echo "$guessit" | jq -r .title)

	if [ -z "$titulo" ]; then
		exit 1
	fi

	anho=$(echo "$guessit" | jq -r .year)
	}

function sorteo_episodio {
	lista=$(find ~/plex/Personal/tv/Bot/ -name "*mkv")
	numero1=$(curl -s --header "Content-Type: application/json; charset=utf-8" \
	  --request POST \
	  --data '{"jsonrpc":"2.0","method":"generateIntegers","params":{"apiKey":"'$randomorg'","n":1,"min":1,"max":'$collected_tv',"replacement":true,"base":10},"id":6206}' \
	  "https://api.random.org/json-rpc/2/invoke" | jq .result.random.data[])
	pelicula=$(sed $numero1!d <(echo "$lista"))
	guessit=$(python3 /usr/local/bin/guessit "$pelicula" -j)
	titulo=$(echo "$guessit" | jq -r .title)

	if [ -z "$titulo" ]; then
		exit 1
	fi

	season=$(echo "$guessit" | jq -r .season)
	episode=$(echo "$guessit" | jq -r .episode)
	}

function descripcion_episodio {
	if [ -z "$frameint" ]; then
		descripcion=$(echo -e "${titulo} - Season ${season}, Episode ${episode} \nSecond: ${random_time} \n \n$footnote")
        else
        	descripcion=$(echo -e "${titulo} - Season ${season}, Episode ${episode} \nFrame: ${frameint} \n \n$footnote")
        fi
	}


function elegir_frame {
	duration=$(($(mediainfo --Inform="General;%Duration%" "${pelicula}" ) / 1000 ))
	framerate=$(mediainfo --Inform="General;%FrameRate%" "${pelicula}")
	let duration=duration-180
	shuffled=$(curl -s --header "Content-Type: application/json; charset=utf-8" \
	  --request POST \
	  --data '{"jsonrpc":"2.0","method":"generateIntegers","params":{"apiKey":"'$randomorg'","n":1,"min":100,"max":'$duration',"replacement":true,"base":10},"id":6206}' \
	  "https://api.random.org/json-rpc/2/invoke" | jq .result.random.data[])
	frame=$(echo ${shuffled}*${framerate} | bc)
	frameint=${frame%.*}
	random_time=$(date -u -d @$(echo $shuffled) +"%T")
	}


function normal_frame {
	elegir_frame
	ffmpeg -ss ${random_time} -copyts -i "$pelicula" -vframes 1\
		"/var/www/html/bbad/${random_time}.png" 2> /dev/null
	}

function third_rule_frame {
	elegir_frame

	ffmpeg -ss ${random_time} -copyts -i "$pelicula"\
		-vframes 1 "/var/www/html/bbad/${random_time}.png" 2> /dev/null
	nice -n 19 convert "/var/www/html/bbad/${random_time}.png" \( +clone -colorspace gray \
		-fx "(i==0||i==int(w/3)||i==2*int(w/3)||i==w-1||j==0||j==int(h/3)||j==2*int(h/3)||j==h-1)?0:1" \) \
	       	-compose darken -composite "/var/www/html/bbad/${random_time}.png" 2> /dev/null
	}

function tmdb_api {
	dawget=$(wget -qO- "https://api.themoviedb.org/3/search/movie?api_key=${tmdb_token}&query=${titulo}&year=${anho}")
	id_peli=$(echo "$dawget" | jq .results[].id | head -n1)
	dawget2=$(wget -qO- "https://api.themoviedb.org/3/movie/${id_peli}?api_key=${tmdb_token}")
	director_inf=$(wget -qO- "https://api.themoviedb.org/3/movie/${id_peli}/credits?api_key=${tmdb_token}" \
	       	| jq '.crew[] | select(.job == "Director")' | jq -r .name | head -n1)
	recos=$(wget -qO- "https://api.themoviedb.org/3/movie/${id_peli}/recommendations?api_key=${tmdb_token}" \
		| jq -r .results[].release_date | date +"%Y" -f - | head -n5 | tr '\n' ' ')
	recos_titles=$(wget -qO- "https://api.themoviedb.org/3/movie/${id_peli}/recommendations?api_key=${tmdb_token}" \
		| jq -r .results[].title | head -n5 | tr '\n' ',')

	IFS=' ' read -r -a rec_year <<< "$recos"
	IFS=',' read -r -a rec_title <<< "$recos_titles"

	year=$(echo "$dawget2" | jq -r .release_date | date +"%Y" -f -)
	genres=$(echo "$dawget2" | jq -r '[.genres[].name]|join(", ")')
	title5=$(echo "$dawget2" | jq -r .title)
	og_title=$(echo "$dawget2" | jq -r .original_title)
	sinopsis=$(echo "$dawget2" | jq -r .overview)
	country=$(echo "$dawget2" | jq -r '[.production_countries[].name]|join(", ")')

	if [ -z "$title5" ]; then
		exit 1
	fi

	link7=$(wget -qO- "https://www.googleapis.com/customsearch/v1/?cx=${google_token}&q=${title5}&num=1" \
	       	| jq -r .items[].link)
	sinopsis_mubi=$(wget -qO- "${link7}" | pup 'p[class=light-on-dark] json{}' --charset UTF-8 \
		| jq -r .[].text | sed '2!d')
	}

function random_cast {
	randomcast=$(wc -l < ~/cast_list)
	randomcast1=$(curl -s --header "Content-Type: application/json; charset=utf-8" \
          --request POST \
          --data '{"jsonrpc":"2.0","method":"generateIntegers","params":{"apiKey":"'$randomorg'","n":1,"min":1,"max":'$randomcast',"replacement":true,"base":10},"id":6206}' \
          "https://api.random.org/json-rpc/2/invoke" | jq .result.random.data[])
	take_cast=$(sed "${randomcast1}q;d" ~/cast_list)

	link7=$(wget -qO- "https://www.googleapis.com/customsearch/v1/?cx=${google_token}&q=${take_cast}&num=1" \
		| jq -r .items[].link)
	imagen=$(wget -qO- "https://www.googleapis.com/customsearch/v1/?cx=${google_token}&searchType=image&q=${randomcast}&num=3" \
		| jq -r .items[].link)
	quote=$(wget -qO- "${link7}" | pup -p 'div[class="entity-description cast-member-quote"] json{}' --charset UTF-8 \
		| jq -r .[].text)

	if [ -z "$quote" ]; then
		biogra=$(echo -e "Bot has randomly chosen: ${take_cast} \n \n$footnote")
	else
		biogra=$(echo -e "${quote} \n \nBot has randomly chosen: ${take_cast} \n \n$footnote")
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

function descripcion_pelicula {
	if [ -z "$sinopsis_mubi" ]; then
		if [ -z "$frameint" ]; then
			descripcion=$(echo -e "${director_inf} - ${title5} (${year}) \nSecond: ${random_time} \nCountry: ${country} \nGenres: ${genres} \n \n$footnote")
		else
			descripcion=$(echo -e "${director_inf} - ${title5} (${year}) \nFrame: ${frameint} \nCountry: ${country} \nGenres: ${genres} \n \n$footnote")
		fi		
	else
		if [ -z "$frameint" ]; then
			descripcion=$(echo -e "${director_inf} - ${title5} (${year}) \nSecond: ${random_time} \nCountry: ${country} \n \n${sinopsis_mubi} \n \n$footnote")			
		else
			descripcion=$(echo -e "${director_inf} - ${title5} (${year}) \nFrame: ${frameint} \nCountry: ${country} \n \n${sinopsis_mubi} \n \n$footnote")
		fi

	fi
}

function post {
	curl -s -X POST \
	-d "url=http://109.169.10.182/bbad/${random_time}.png" \
	-d "caption=${descripcion}" \
	-d "access_token=${facebook_token}" \
	-d "published=false" \
	"https://graph.facebook.com/111665010589899/photos"
}

numero2=$(curl -s --header "Content-Type: application/json; charset=utf-8" \
	  --request POST \
	  --data '{"jsonrpc":"2.0","method":"generateIntegers","params":{"apiKey":"'$randomorg'","n":1,"min":1,"max":20,"replacement":true,"base":10},"id":6206}' \
	  "https://api.random.org/json-rpc/2/invoke" | jq .result.random.data[])


if [ $numero2 -eq 21 ]; then ## deprecating cast and rule of thirds for now
	random_cast
elif [ $numero2 -gt 1 -a $numero2 -lt 15 ]; then
	sorteo_pelicula
	normal_frame
	tmdb_api
	descripcion_pelicula
	post
else
	sorteo_episodio
	normal_frame
	descripcion_episodio
	post
fi
