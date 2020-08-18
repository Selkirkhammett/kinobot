import kino_utils.comments as check_comments
import kino_utils.subs as subs

from facepy import GraphAPI
import normal_kino
import argparse
import sys
import json


def args():
    parser = argparse.ArgumentParser(prog='main.py')
    parser.add_argument("--comments", metavar="json", required=True)
    parser.add_argument("--collection", metavar="path", type=str, required=True)
    parser.add_argument("--tokens", metavar="json", required=True)
    parser.add_argument("--films", metavar="json", required=True)
    return parser.parse_args()


def get_normal(collection, tokens, arbitray_movie):
    normal_kino.main(collection, tokens)


def get_comment_json(tokens, arguments):
    return check_comments.main(arguments.comments, tokens)



def post_request(file, fbtoken, movie_info, request, discriminator):
    print('Posting')
    fb = GraphAPI(fbtoken)
    mes = ("{} by {}\n{}\n\nRequested by {} (!req {})\n\n"
           "This bot is open source: https://github.com/"
           "vitiko98/Certified-Kino-Bot".format(movie_info['title'],
                                                movie_info['director(s)'],
                                                discriminator,
                                                request['user'],
                                                request['comment']))
    id2 = fb.post(
        path = 'me/photos',
        source = open(file, 'rb'),
        published = False,
        message = mes
    )
    return id2['id']

def comment_post(fbtoken, postid):
    fb = GraphAPI(fbtoken)
    com = ('Comments your requests! Examples:\n'
    '"!req Taxi Driver 1976 [you talking to me?]"\n"!req Stalker [20:34]"')
    com_id = fb.post(
        path = postid + '/comments',
        message = com
    )
    print(com_id['id'])

def main():
    arguments = args()
    tokens = json.load(open(arguments.tokens))
    print('Checking comments...')
    slctd = get_comment_json(tokens, arguments)
    if slctd:
        inc = 0
        while True:
            m = slctd[inc]
            output = '/tmp/' + m['id'] + '.png'
            if not m['used']:
                init_sub = subs.Subs(m['movie'], m['content'], output, arguments.films)
                if init_sub.exists:
                    print('Ok {}'.format(init_sub.movie['title']))
                    m['used'] = True
                    post_id = post_request(output, tokens['facebook'],
                                           init_sub.movie, m, init_sub.discriminator)
                    comment_post(tokens['facebook'], post_id)
                    with open(arguments.comments, 'w') as c:
                        json.dump(slctd, c)
                    break
            inc += 1
            if inc == len(slctd):
                get_normal(arguments.collection, tokens, arbitray_movie=None)
                break
    else:
        get_normal(arguments.collection, tokens, arbitray_movie=None)

main()
