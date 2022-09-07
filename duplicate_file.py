import os
from os.path import isfile, join, isdir
from os import listdir
import subprocess
import argparse

dict={}

def finddir(dirpath):
    for f in listdir(dirpath):
        full_name = join(dirpath,f)
        if isfile(full_name):
            ret = subprocess.run(['sha1sum',full_name], capture_output=True, text=True)
            # print(type(ret.stdout))
            # print(ret.stdout)
            # print(ret.stdout.split())
            sha1 = ret.stdout.split()[0] 
            name = ''.join(ret.stdout.split()[1:])
            # print(name)
            if sha1 in dict:
                print (f'duplicate: {dict[sha1]} <-> {full_name}')
            else:
                dict.update({sha1: name}) 
        else:
            if isdir(full_name):
                finddir(full_name)

#finddir("/volume1")
parser = argparse.ArgumentParser()
parser.add_argument('--path', dest='mainpath')
args = parser.parse_args()

finddir(args.mainpath)


