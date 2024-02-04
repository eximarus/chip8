#!/bin/bash

cd "$(dirname "$0")"/..
cmake -B build/linux -S .
cmake --build build/linux