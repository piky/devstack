#!/bin/bash
# canary.sh - Keep an eye on the coal mine


# Basic sanity checks
function bad_declaration() {
    echo "Who? Me?"
}

if [[ -z $HOME ]]
then
  echo "why do that?"
fi  

A=`ls`
B=$(ls)

