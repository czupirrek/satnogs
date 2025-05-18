#!/bin/bash
set -eu
ROOT_DIR=$(pwd)
copy_or_fail() {
    local dest="${@: -1}"          # ostatni argument = dest
    local sources=("${@:1:$#-1}")  # wszystkie poza ostatnim = źródła

    cp "${sources[@]}" "$dest"
    if [ $? -ne 0 ]; then
        echo "❌ Błąd kopiowania: ${sources[*]} → $dest"
        exit 1
    else
        echo "✅ Skopiowano: ${sources[*]} → $dest"
    fi
}


echo "📦 Automated satnogs client + autoscheduler + addons deploy started..."

if [ "$EUID" -ne 0 ]; then
    echo "❌ Error: Musisz uruchomić ten skrypt jako root (sudo)."
    echo "ℹ️ Jest to związane z tworzeniem folderów z różnymi właścicielami."
    exit 1
fi

# czy jest docker i docker compose
if ! command -v docker &> /dev/null || ! command -v docker compose &> /dev/null
then
    echo "❌ Error: Docker lub Docker Compose nie są zainstalowane."
    exit 1
    else
    echo "✅ Docker i Docker Compose są zainstalowane."
fi

# czy jest git
if ! command -v git &> /dev/null 
then
    echo "❌ Error: Docker lub Docker Compose nie są zainstalowane."
    exit 1
    else
    echo "✅ Git jest zainstalowany."
fi



echo "📦 Pobieranie repo 1/2..." 
if [ -d "satnogs-client-docker" ]; then
    echo "ℹ️  Folder satnogs-client-docker już istnieje, pomijam klonowanie."
else
    git clone https://github.com/kng/satnogs-client-docker.git
    if [ -d "satnogs-client-docker" ]; then
        echo "✅ Repozytorium satnogs-client-docker zostało sklonowane pomyślnie."
    else
        echo "❌ Error: Nie można sklonować repozytorium satnogs-client-docker."
        exit 1
    fi
fi


echo "📦 Pobieranie repo 2/2..." 
if [ -d "satnogs-auto-scheduler" ]; then
    echo "ℹ️  Folder satnogs-client-docker już istnieje, pomijam klonowanie."
else
    git clone https://gitlab.com/librespacefoundation/satnogs/satnogs-auto-scheduler.git
    if [ -d "satnogs-auto-scheduler" ]; then
        echo "✅ Repozytorium satnogs-auto-scheduler zostało sklonowane pomyślnie."
    else
        echo "❌ Error: Nie można sklonować repozytorium satnogs-client-docker."
        exit 1
    fi
fi

copy_or_fail resources/client/Dockerfile satnogs-client-docker/addons
copy_or_fail resources/client/flowgraphs.py satnogs-client-docker/addons
copy_or_fail resources/client/packages.client satnogs-client-docker/addons
copy_or_fail resources/scripts/* satnogs-client-docker/addons/scripts/

copy_or_fail resources/scheduler/Dockerfile satnogs-auto-scheduler/Dockerfile

echo "🗿 First we build..."
echo "🗿 Building satnogs-client..."
cd satnogs-client-docker/addons
if docker build --build-arg BUILD_SATDUMP=1 -t satnogs-diy .; then
    echo "✅ Build satnogs-client udany!"
else
    echo "❌ Błąd podczas budowania satnogs-client!" >&2
    exit 1
fi

echo "🗿 Building satnogs-auto-scheduler..."
cd "$ROOT_DIR"
cd satnogs-auto-scheduler
if docker compose build; then
    echo "✅ Build satnogs-auto-scheduler udany!"
else
    echo "❌ Błąd podczas budowania satnogs-auto-scheduler!" >&2
    exit 1
fi

cd "$ROOT_DIR"
SATNOGS_CLIENT_DIR="$ROOT_DIR/deploy/satnogs-client"
SATNOGS_SCHEDULER_DIR="$ROOT_DIR/deploy/satnogs-scheduler"
echo "📦 Tworzenie folderów z uprawnieniami..."

# sudo install -d -m 0755 -o 999 -g 999 "$SATNOGS_SCHEDULER_DIR"
if [ ! -d deploy ]; then
    mkdir -p deploy
    mkdir "$SATNOGS_CLIENT_DIR"
    sudo install -d -m 0755 -o 500 -g 500 "$SATNOGS_CLIENT_DIR"/data
    sudo install -d -m 0755 -o 500 -g 500 "$SATNOGS_CLIENT_DIR"/data/app
    sudo install -d -m 0755 -o 500 -g 500 "$SATNOGS_CLIENT_DIR"/data/app/data
    sudo install -d -m 0755 -o 500 -g 500 "$SATNOGS_CLIENT_DIR"/data/app/data/complete
    sudo install -d -m 0755 -o 500 -g 500 "$SATNOGS_CLIENT_DIR"/data/app/data/incomplete
    sudo install -o 500 -g 500 /dev/null "$SATNOGS_CLIENT_DIR"/data/iq
    echo "Stworzono folder "$SATNOGS_CLIENT_DIR" i podfoldery z uprawnieniami 500:500."

    mkdir "$SATNOGS_SCHEDULER_DIR"
    sudo install -d -m 0755 -o 999 -g 999 "$SATNOGS_SCHEDULER_DIR"/data
    echo "Stworzono folder "$SATNOGS_SCHEDULER_DIR" i podfoldery z uprawnieniami 999:999."

fi

copy_or_fail resources/client/client-compose.yml "$SATNOGS_CLIENT_DIR"/compose.yml
copy_or_fail resources/client/station.env "$SATNOGS_CLIENT_DIR"/station.env
echo "✅ Skopiowano pliki docker compose dla satnogs-client."
echo "📦 W tym momencie, satnogs-client powinien być już funkcjonalny."




copy_or_fail resources/scheduler/compose.yml "$SATNOGS_SCHEDULER_DIR"/compose.yml
copy_or_fail resources/scheduler/station.env "$SATNOGS_SCHEDULER_DIR"/station.env
copy_or_fail resources/scheduler/entrypoint.sh "$SATNOGS_SCHEDULER_DIR"/data/entrypoint.sh
copy_or_fail resources/scheduler/priorities.txt "$SATNOGS_SCHEDULER_DIR"/data/priorities_4063.txt
sudo chmod +x "$SATNOGS_SCHEDULER_DIR"/data/entrypoint.sh
echo "✅ Skopiowano pliki docker compose dla satnogs-scheduler."
echo "🥰 W tym momencie, satnogs-scheduler powinien być już funkcjonalny."

echo "ℹ️ Zacznij od satnogs-client. Przejdź do katalogu $SATNOGS_CLIENT_DIR."
echo "❗ Uzupełnij plik station.env swoimi danymi i koniecznie zweryfikuj flagę ENABLE_BIAST!"
echo "❗ Najważniejsze zmienne:"
echo "➡️ SATNOGS_API_TOKEN"
echo "➡️ SATNOGS_STATION_ID"
echo "➡️ SATNOGS_STATION_LAT"
echo "➡️ SATNOGS_STATION_LON"
echo "➡️ ENABLE_BIAST   ❗TRUE tylko jeśli posiadasz wzmacniacz❗"

echo "ℹ️ Następnie uruchom satnogs-client:"
echo "➡️ docker compose up -d"
echo "ℹ️ Sprawdź, czy satnogs-client działa prawidłowo - sprawdź logi:"
echo "➡️ docker compose logs"


echo "ℹ️ Uruchom satnogs-scheduler. Przejdź do katalogu $SATNOGS_SCHEDULER_DIR i wywołaj te same komendy co poprzednio."
echo "❗Tu też uzupełnij plik station.env swoimi danymi!"
echo "➡️ numer stacji"
echo "➡️ token API satnogs"
echo "➡️ token API satnogs-db"
echo "‼️ Scheduler może nie zadziałać od razu, bo musi zweryfikować, czy stacja jest online. W takim przypadku zrestartuj go:"
echo "➡️ docker compose restart"
echo "ℹ️ Ewentualnie testy odbioru stacji można przeprowadzić przez ręczne planowanie obserwacji na stronie:"
echo "➡️ network.satnogs.org → Dashbord → twoja stacja → Future Passes"


echo "✅ Gotowe!"
