#!/bin/bash
perl Build.PL && ./Build test
prove -bj4
