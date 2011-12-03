#!/bin/bash

sudo rm -rf /var/cache/debpool/

sudo mkdir /var/cache/debpool/
sudo PERL5LIB=./lib/ bin/debpool 

sudo cp $T/sample_1* /var/cache/debpool/incoming/
sudo PERL5LIB=./lib/ bin/debpool 
sudo tree /var/cache/debpool/

