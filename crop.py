from PIL import Image, ImageChops
import sys
import cv2
import numpy as np

def trim(im):
    bg = Image.new(im.mode, im.size, im.getpixel((0,0)))
    diff = ImageChops.difference(im, bg)
    diff = ImageChops.add(diff, diff)#, 2.0, -100)
    bbox = diff.getbbox()
    if bbox:
        return im.crop(bbox)

pil = Image.open(sys.argv[1])
cv = cv2.imread(sys.argv[1])

def toPil(c2vImage):
    cv2I = cv2.cvtColor(c2vImage,cv2.COLOR_BGR2RGB)
    return Image.fromarray(cv2I)

print(pil2)
trim(pil).save('crop.png')
