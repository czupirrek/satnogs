#!/bin/bash
if [[ ! "${METEOR_EXPERIMENTAL^^}" =~ (TRUE|YES|1) ]]; then exit; fi

set -eu
#skrypt post-obs jest wywoływany z następujacymi argumentami:
# CMD NIE ISTNIEJE!!! przesuwam o jeden
#CMD="$1"     # $1 [start|stop]
ID="$1"      # $2 observation ID
FREQ="$2"    # $3 frequency
TLE="$3"     # $4 used tle's
DATE="$4"    # $5 timestamp Y-m-dTH-M-S
BAUD="$5"    # $6 baudrate
SCRIPT="$6"  # $7 script name, satnogs_bpsk.py

# etap 1 - po zakończeniu obserwacji konwertujemy .raw na .wav, ale tylko jeśli to METEOR
# METEOR M2-3 -> 57166
# METEOR M2-4 -> 59051

NORAD=$(echo "$3" | jq .tle2 | awk '{print $2}')
if [ "$NORAD" == "57166" ] || [ "$NORAD" == "59051" ]; then
    echo "[meteor pipeline] Converting raw to wav"
else
    echo "[meteor pipeline] Not a METEOR satellite, skipping conversion ($NORAD)"
    exit 0
fi


INPUT_RAW="$IQ_DUMP_FILENAME"
OUTPUT_WAV="$SATNOGS_APP_PATH"/"tmp_wavfile.wav"

SAMP=$(find_samp_rate.py "$BAUD" "$SCRIPT")
sox -t raw -b 16 -e signed-integer -r "$SAMP" -c 2 "$INPUT_RAW" "$OUTPUT_WAV"

echo "[meteor pipeline] sox done"
# etap 2 - przetwarzamy plik .wav w satdumpie

case "$NORAD" in
    59051)
        SAT_NUMBER=4
        echo "[meteor pipeline] found sat METEOR M2-4"
        ;;
    57166)
        SAT_NUMBER=3
        echo "[meteor pipeline] found sat METEOR M2-3"
        ;;
    *)
        echo "[meteor pipeline] Nieznany NORAD: $NORAD"
        exit 3
        ;;
esac

OUT="$SATNOGS_APP_PATH"/satdump_"$ID"


echo "[meteor pipeline] attempting to run satdump now"
# wywolanie satdumpa
satdump meteor_m2-x_lrpt baseband "$OUTPUT_WAV" "$OUT" --satellite-number "$SAT_NUMBER"

echo "[meteor pipeline] satdump finished processing"

echo "[meteor pipeline] removing old files..."
# etap 3 - usuniecie nieptorzebnych plikow
rm -f "$OUTPUT_WAV"
rm "$OUT"/MSU-MR/*map*
rm "$OUT"/MSU-MR/*projected*

echo "[meteor pipeline] old files removed"

# etap 4 - wyslanie najwiekszego pliku do satnogs
#FILE=$(ls "$OUT"/MSU-MR -S | head -n 1)
FILE=$(find "$OUT"/MSU-MR -maxdepth 1 -type f -name '*.png' -printf "%s %p\n" | sort -nr | head -n1 | cut -d' ' -f2-)
mv "$OUT"/MSU-MR/"$FILE" "$SATNOGS_OUTPUT_PATH"/data_"$ID"_"$DATE".png

echo "[meteor pipeline] mam nadzieje ze wszystko dziala bo powinien byc SUKCES"
