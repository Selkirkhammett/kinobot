import os
import sys

from dotenv import find_dotenv, load_dotenv

# Reference: /scripts/envs.sh.template

# The .env file is optional. Environment variables can be sourced from
# the bash script shown above.
dot_env = find_dotenv()
if dot_env:
    load_dotenv(dot_env)

try:
    FACEBOOK = os.environ["FACEBOOK"]
    FACEBOOK_TV = os.environ["FACEBOOK_TV"]
    FILM_COLLECTION = os.environ["FILM_COLLECTION"]
    EPISODE_COLLECTION = os.environ["EPISODE_COLLECTION"]
    FRAMES_DIR = os.environ["FRAMES_DIR"]
    NSFW_MODEL = os.environ["NSFW_MODEL"]
    MAGICK_SCRIPT = os.environ["MAGICK_SCRIPT"]
    FONTS = os.environ["FONTS"]
    TMDB = os.environ["TMDB"]
    RANDOMORG = os.environ["RANDOMORG"]
    RADARR = os.environ["RADARR"]
    RADARR_URL = os.environ["RADARR_URL"]
    REQUESTS_JSON = os.environ["REQUESTS_JSON"]
    OFFENSIVE_JSON = os.environ["OFFENSIVE_JSON"]
    KINOBASE = os.environ["KINOBASE"]
    REQUESTS_DB = os.environ["REQUESTS_DB"]
    DISCORD_WEBHOOK = os.environ["DISCORD_WEBHOOK"]
    DISCORD_WEBHOOK_TEST = os.environ["DISCORD_WEBHOOK_TEST"]
    DISCORD_TOKEN = os.environ["DISCORD_TOKEN"]
    DISCORD_DB = os.environ["DISCORD_DB"]
    PLEX_URL = os.environ["PLEX_URL"]
    PLEX_TOKEN = os.environ["PLEX_TOKEN"]
    KINOLOG = os.environ["KINOLOG"]
    KINOLOG_COMMENTS = os.environ["KINOLOG_COMMENTS"]
except KeyError as error:
    sys.exit(f"Environment variable not set: {error}")
