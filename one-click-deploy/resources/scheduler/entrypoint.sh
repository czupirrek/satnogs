#!/bin/bash
SLEEP_TIMER=3000
SATNOGS_GS_ID=4063


while true
do
        schedule_single_station.py -s "$SATNOGS_GS_ID" -d 1.5 -T -P /data/priorities_4063.txt
        echo "scheduled something, now sleeping for $SLEEP_TIMER seconds"
        sleep "$SLEEP_TIMER"
done