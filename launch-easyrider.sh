#!/bin/bash

datadir=$PWD"/../easyrider/data/"
outpath=$datadir$(date +%Y%m%d-%H-%M-%S)-$1.json

./launch-simple.sh > $outpath
