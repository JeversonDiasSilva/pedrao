#!/bin/bash
# Curitiba 09 de Junho de 2025.
# Editor: Jeverson D. Silva /// @JCGAMESCLASSICOS...
# Script revisado e corrigido por Gemini Code Assist.

# --- Configurações e Constantes ---
# Para facilitar a manutenção, definimos os caminhos importantes aqui.
DEV_DIR="/userdata/system/.dev"
CREDITOS_FILE="$DEV_DIR/count.txt"
TIME_FLAG_FILE="$DEV_DIR/time.tmp"
TIME_VALUE_FILE="$DEV_DIR/tempo_jogo.txt"
BATOCERA_CONF="/userdata/system/batocera.conf"
LOG_SAIDA="/dev/null" # Mude para /dev/stderr para ver os logs do script

# --- Funções de Controle de Tempo ---

# Função que executa o contador em segundo plano.
# Ela apenas controla o tempo e encerra o retroarch se o tempo acabar.
run_countdown() {
    # Obtém o valor de tempo_game do arquivo batocera.conf, com padrão de 1 minuto.
    local tempo_game
    tempo_game=$(grep -oP '(?<=^tempo_game=)[0-9]+' "$BATOCERA_CONF")
    [[ -z "$tempo_game" ]] && tempo_game=1
    local tempo_segundos=$((tempo_game * 60))

    echo "Contador iniciado: ${tempo_segundos} segundos." >"$LOG_SAIDA"

    # Escreve o tempo inicial no arquivo para exibição no tema
    echo "$tempo_segundos" > "$TIME_VALUE_FILE"

    while [[ $tempo_segundos -gt 0 ]]; do
        # A flag time.tmp é o sinal para continuar. Se for removida, o loop para.
        if [[ ! -f "$TIME_FLAG_FILE" ]]; then
            echo "Flag time.tmp removida. Interrompendo contador." >"$LOG_SAIDA"
            break
        fi

        sleep 1
        tempo_segundos=$((tempo_segundos - 1))
        echo "$tempo_segundos" > "$TIME_VALUE_FILE"
    done

    # Se o tempo acabou (loop terminou sem ser interrompido), encerra o jogo.
    if [[ -f "$TIME_FLAG_FILE" ]]; then
        echo "Tempo esgotado! Encerrando retroarch." >"$LOG_SAIDA"
        pkill retroarch
    fi
}

# --- Funções de Lançamento de Jogos ---

# Função para lançar jogos COM controle de tempo.
launch_timed_game() {
    local core_path="$1"
    local rom_path="$2"

    echo "Iniciando jogo com tempo: $rom_path" >"$LOG_SAIDA"

    # 1. Cria o arquivo de flag para o contador.
    # Esta é a condição que você pediu: criar o time.tmp ao iniciar o jogo.
    touch "$TIME_FLAG_FILE"

    # 2. Inicia o contador em segundo plano.
    run_countdown &
    local countdown_pid=$!

    # 3. Executa o jogo. O script vai esperar aqui até o jogo fechar.
    Launcher_on
    retroarch -L "$core_path" "$rom_path"
    Launcher_off

    # 4. Limpeza: Garante que o contador seja encerrado e os arquivos temporários removidos.
    # Isso acontece quando o jogador sai do jogo ou o tempo acaba.
    echo "Jogo finalizado. Realizando limpeza..." >"$LOG_SAIDA"
    kill "$countdown_pid" &>/dev/null # Encerra o processo do contador
    rm -f "$TIME_FLAG_FILE" "$TIME_VALUE_FILE" # Remove os arquivos temporários
}

# Função para lançar jogos SEM controle de tempo.
launch_normal_game() {
    local core_path="$1"
    local rom_path="$2"
    echo "Iniciando jogo normal: $rom_path" >"$LOG_SAIDA"
    Launcher_on
    retroarch -L "$core_path" "$rom_path"
    Launcher_off
}

# --- Lógica Principal do Script ---

# Caminho da ROM recebida como argumento
ROM=$(readlink -f "$1")
SISTEMA_DIR=$(dirname "$ROM")

# Verifica se há créditos
if [[ -f "$CREDITOS_FILE" ]]; then
    CREDITOS=$(grep -o '^[0-9]\+' "$CREDITOS_FILE")
    [[ -z "$CREDITOS" ]] && CREDITOS=0
else
    CREDITOS=0
fi

if [[ "$CREDITOS" -le 0 ]]; then
    echo "Sem créditos. Adicione créditos para jogar." >&2
    mpv /usr/share/retroluxxo/sound/no.mp3 >/dev/null 2>&1
    exit 1
fi

# Deduz UM crédito ANTES de iniciar o jogo.
NOVO_CREDITO=$((CREDITOS - 1))
echo "$NOVO_CREDITO" > "$CREDITOS_FILE"
echo "Crédito deduzido. Restantes: $NOVO_CREDITO" >"$LOG_SAIDA"

# Executa o sistema apropriado com base na pasta
case "$SISTEMA_DIR" in
    "/userdata/roms/windows")
        # Este é um caso especial, não usa retroarch.
        Launcher_on ; SDL_RENDER_VSYNC=1 \
        SDL_GAMECONTROLLERCONFIG="030000005e0400008e02000014010000,Microsoft X-Box 360 pad,platform:Linux,b:b1,a:b0,dpdown:h0.4,dpleft:h0.8,rightshoulder:b5,leftshoulder:b4,dpright:h0.2,back:b6,start:b7,dpup:h0.1,y:b2,x:b3," \
        SDL_JOYSTICK_HIDAPI=0 \
        batocera-wine windows play "$ROM" && Launcher_off
        ;;
    "/userdata/roms/atomiswave" | "/userdata/roms/naomi")
        Launcher_on ; retroarch -L /usr/lib/libretro/flycast_libretro.so \
            --config /userdata/system/configs/retroarch/retroarch.cfg \
            --set-shader /usr/share/batocera/shaders/interpolation/sharp-bilinear-simple.slangp \
            --verbose --log-file /userdata/retroarch.log -f "$ROM" && Launcher_off
        ;;
    "/userdata/roms/fba_libretro")
        launch_normal_game "/usr/lib/libretro/fbalpha2012_libretro.so" "$ROM" ;;
    "/userdata/roms/fbneo")
        launch_normal_game "/usr/lib/libretro/fbneo_libretro.so" "$ROM" ;;
    "/userdata/roms/mame/mame_libretro")
        launch_normal_game "/usr/lib/libretro/mame_libretro.so" "$ROM" ;;
    "/userdata/roms/mame/mame0139")
        launch_normal_game "/usr/lib/libretro/mame0139_libretro.so" "$ROM" ;;
    "/userdata/roms/mame/mame078plus")
        Launcher_on ; retroarch -L /usr/lib/libretro/mame078plus_libretro.so --config "/userdata/system/configs/retroarch/retroarch.cfg" "$ROM" && Launcher_off ;;
    
    # --- Sistemas com controle de tempo ---
    "/userdata/roms/megadrive")
        launch_timed_game "/usr/lib/libretro/genesisplusgx_libretro.so" "$ROM" ;;
    "/userdata/roms/n64")
        launch_timed_game "/usr/lib/libretro/mupen64plus-next_libretro.so" "$ROM" ;;
    "/userdata/roms/psx")
        launch_timed_game "/usr/lib/libretro/pcsx_rearmed_libretro.so" "$ROM" ;;
    "/userdata/roms/snes")
        launch_timed_game "/usr/lib/libretro/snes9x_libretro.so" "$ROM" ;;
    "/userdata/roms/nes")
        launch_timed_game "/usr/lib/libretro/nestopia_libretro.so" "$ROM" ;;
    *)
        echo "Sistema desconhecido: $SISTEMA_DIR. Devolvendo crédito." >&2
        # Devolve o crédito se o sistema não for encontrado
        CREDITO_DEVOLVIDO=$((NOVO_CREDITO + 1))
        echo "$CREDITO_DEVOLVIDO" > "$CREDITOS_FILE"
        exit 1
        ;;
esac

exit 0