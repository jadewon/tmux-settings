#!/bin/bash
d=$(date +%u)
chars=(X 月 火 水 木 金 土 日)
colors=(X colour226 colour196 colour39 colour76 colour220 colour130 colour208)
echo "#[fg=${colors[$d]}]${chars[$d]}#[fg=colour250]"
