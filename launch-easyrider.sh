#!/bin/bash

datadir=$PWD"/../easyrider/data/"
outpath=$datadir$(date +%Y%m%d-%H-%M-%S)-drive-$1.json

./launch-simple.sh easyrider2016 > $outpath
