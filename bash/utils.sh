#! /usr/bin/env bash

# Function to display a simple loading animation
show_loader() {
    local message=$1
    local pid=$!
    local delay=0.3
    local spinstr='|/-\\'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf "\r%s [%c]  " "$message" "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
    done
    printf "\r%s [Done]   \n" "$message"
}