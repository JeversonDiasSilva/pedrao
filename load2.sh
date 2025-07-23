#!/usr/bin/env bash
# Curitiba, 09 de Junho de 2025
# Editor: Jeverson D. Silva /// @JCGAMESCLASSICOS

# ==== VARIÁVEIS ====
DEV_PATH="/userdata/system/.dev"
COUNT_FILE="$DEV_PATH/count.txt"
TIME_TMP="$DEV_PATH/time.tmp"
TEMPO_JOGO="$DEV_PATH/tempo_jogo.txt"
CONFIG_FILE="/userdata/system/batocera.conf"
NO_CREDIT_SOUND="/usr/share/retroluxxo/sound/no.mp3"

ROM=$(readlink -f "$1")
SISTEMA_DIR=$(dirname "$ROM")

# === ROM PATHS ===
declare -A CORES=(
    ["/userdata/roms/fba_libretro"]="/usr/lib/libretro/fbalpha2012_libretro.so"
    ["/userdata/roms/fbneo"]="/usr/lib/libretro/fbneo_libretro.so"
    ["/userdata/roms/megadrive"]="/usr/lib/libretro/genesisplusgx_libretro.so"
    ["/userdata/roms/mame/mame_libretro"]="/usr/lib/libretro/mame_libretro.so"
    ["/userdata/roms/mame/mame0139"]="/usr/lib/libretro/mame0139_libretro.so"
    ["/userdata/roms/mame/mame078plus"]="/usr/lib/libretro/mame078plus_libretro.so"
    ["/userdata/roms/n64"]="/usr/lib/libretro/mupen64plus-next_libretro.so"
    ["/userdata/roms/psx"]="/usr/lib/libretro/pcsx_rearmed_libretro.so"
    ["/userdata/roms/snes"]="/usr/lib/libretro/snes9x_libretro.so"
    ["/userdata/roms/nes"]="/usr/lib/libretro/nestopia_libretro.so"
)

# ==== FUNÇÕES ====

iniciar_contagem() {
    mkdir -p "$DEV_PATH"
    : > "$TIME_TMP"  # Garante criação e limpeza

    # Lê e valida o valor de créditos
    if [ -f "$COUNT_FILE" ]; then
        read -r count < "$COUNT_FILE"
        if ! [[ "$count" =~ ^[0-9]+$ ]]; then
            count=300
        fi
        count=$((count - 1))
        echo "$count" > "$COUNT_FILE"
    else
        echo "Arquivo $COUNT_FILE não encontrado!"
        return 1
    fi

    # Lê tempo de jogo em minutos, converte e valida
    tempo_game=$(grep -oP "(?<=^tempo_game=)[0-9]+" "$CONFIG_FILE" 2>/dev/null)
    [[ -z "$tempo_game" || ! "$tempo_game" =~ ^[0-9]+$ ]] && tempo_game=1
    tempo_segundos=$((tempo_game * 60))
    echo "$tempo_segundos" > "$TEMPO_JOGO"

    last_modified=$(stat --format=%Y "$COUNT_FILE")

    # Contagem regressiva
    while [ "$tempo_segundos" -gt 0 ]; do
        [[ ! -f "$TIME_TMP" ]] && echo "Contagem cancelada: time.tmp removido." && break
        current_modified=$(stat --format=%Y "$COUNT_FILE")
        [[ "$last_modified" != "$current_modified" ]] && echo "Contagem interrompida: count.txt alterado." && break

        tempo_segundos=$((tempo_segundos - 1))
        echo "$tempo_segundos" > "$TEMPO_JOGO"
        sleep 1
    done

    if [ "$tempo_segundos" -le 0 ]; then
        pkill retroarch
        rm -f "$TEMPO_JOGO" "$TIME_TMP"
        echo "Tempo esgotado. RetroArch finalizado!"
    fi
}

launch_retroarch() {
    local core="$1"
    retroarch -L "$core" "$ROM"
}

launch_with_countdown() {
    iniciar_contagem &
    Launcher_on
    launch_retroarch "$1"
    Launcher_off
}

play_no_credit_sound() {
    command -v mpv >/dev/null && mpv "$NO_CREDIT_SOUND" >/dev/null 2>&1
}

# ==== VERIFICA CRÉDITOS ====

mkdir -p "$DEV_PATH"

if [ -f "$COUNT_FILE" ]; then
    read -r CREDITOS < "$COUNT_FILE"
    if ! [[ "$CREDITOS" =~ ^[0-9]+$ ]]; then
        CREDITOS=0
    fi
else
    CREDITOS=0
fi

if [ "$CREDITOS" -le 0 ]; then
    echo "Sem créditos. Adicione créditos para jogar."
    play_no_credit_sound
    exit 1
fi

# ==== GARANTIR LIMPEZA ====
trap 'kill $(jobs -p) 2>/dev/null' EXIT

# ==== EXECUÇÃO ====
case "$SISTEMA_DIR" in
    "/userdata/roms/windows")
        Launcher_on
        SDL_RENDER_VSYNC=1 \
        SDL_GAMECONTROLLERCONFIG="030000005e0400008e02000014010000,Microsoft X-Box 360 pad,platform:Linux,b:b1,a:b0,dpdown:h0.4,dpleft:h0.8,rightshoulder:b5,leftshoulder:b4,dpright:h0.2,back:b6,start:b7,dpup:h0.1,y:b2,x:b3," \
        SDL_JOYSTICK_HIDAPI=0 \
        batocera-wine windows play "$ROM"
        Launcher_off
        ;;
    "/userdata/roms/atomiswave"|"/userdata/roms/naomi")
        Launcher_on
        retroarch -L /usr/lib/libretro/flycast_libretro.so \
            --config /userdata/system/configs/retroarch/retroarch.cfg \
            --set-shader /usr/share/batocera/shaders/interpolation/sharp-bilinear-simple.slangp \
            --verbose --log-file /userdata/retroarch.log -f "$ROM"
        Launcher_off
        ;;
    *)
        if [[ -n "${CORES[$SISTEMA_DIR]}" ]]; then
            case "$SISTEMA_DIR" in
                "/userdata/roms/megadrive"|"/userdata/roms/n64"|"/userdata/roms/psx"|"/userdata/roms/snes"|"/userdata/roms/nes")
                    launch_with_countdown "${CORES[$SISTEMA_DIR]}"
                    ;;
                *)
                    Launcher_on
                    launch_retroarch "${CORES[$SISTEMA_DIR]}"
                    Launcher_off
                    ;;
            esac
        else
            echo "Sistema desconhecido: $SISTEMA_DIR"
            exit 1
        fi
        ;;
esac
