#!/bin/bash

check() {
    return 0
}

depends() {
    echo network
    return 0
}

install() {
    . "$moddir/install"
}
