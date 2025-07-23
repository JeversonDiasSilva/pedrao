#!/bin/bash
# Curitiba 09 de Junho de 2025.
# Editor: Jeverson D. Silva /// @JCGAMESCLASSICOS...





# Função para inicializar a contagem e subtrair 1 de count.txt
iniciar_contagem() {
    # Inicializa o time.tmp com um valor vazio
    rm /userdata/system/.dev/time.tmp >> /dev/lull 2>&1 
    echo "" >> /userdata/system/.dev/time.tmp &&

    # Subtrair 1 de count.txt logo ao iniciar o script
    if [ -f "/userdata/system/.dev/count.txt" ]; then
        # Ler o valor de count.txt
        count=$(cat /userdata/system/.dev/count.txt)

        # Se count.txt estiver vazio ou não for um número, definir um valor padrão de 300 (5 minutos)
        if [ -z "$count" ]; then
            count=300
        fi

        # Subtrair 1 do valor de count.txt
        count=$((count - 1))

        # Atualizar o arquivo count.txt com o novo valor
        echo $count > /userdata/system/.dev/count.txt
        echo "Novo valor de count.txt após subtrair 1: $count"
    else
        echo "Arquivo /userdata/system/.dev/count.txt não encontrado!"
    fi

    # Verificar se o arquivo /userdata/system/.dev/time.tmp existe
    if [ -f "/userdata/system/.dev/time.tmp" ]; then
        # Obter o valor de tempo_game do arquivo batocera.conf
        tempo_game=$(grep -oP "(?<=^tempo_game=)[0-9]+" /userdata/system/batocera.conf)
        
        # Se o valor não for encontrado, definir um valor padrão (1 minuto)
        if [ -z "$tempo_game" ]; then
            tempo_game=1
        fi

        # Converter tempo_game para segundos (tempo_game em minutos * 60)
        tempo_segundos=$((tempo_game * 60))

        # Criar o arquivo tempo_jogo.txt com o valor inicial de tempo em segundos
        echo $tempo_segundos > /userdata/system/.dev/tempo_jogo.txt
        echo "Iniciando a contagem regressiva com ${tempo_segundos} segundos."

        # Obter o timestamp inicial de modificação de count.txt
        last_modified=$(stat --format=%Y /userdata/system/.dev/count.txt)

        # Decrementando o valor no arquivo até chegar a 0
        while [ $tempo_segundos -gt 0 ]; do
            # Verificar se o arquivo time.tmp ainda existe
            if [ ! -f "/userdata/system/.dev/time.tmp" ]; then
                echo "Arquivo time.tmp não encontrado, mantendo RetroArch ativo!"
                break
            fi

            # Verificar se count.txt foi modificado
            current_modified=$(stat --format=%Y /userdata/system/.dev/count.txt)
            if [ "$last_modified" != "$current_modified" ]; then
                echo "O arquivo count.txt foi modificado durante a contagem, encerrando a contagem."
                break
            fi

            # Decrementar 1 segundo
            tempo_segundos=$((tempo_segundos - 1))

            # Atualizar o arquivo tempo_jogo.txt com o novo valor
            echo $tempo_segundos > /userdata/system/.dev/tempo_jogo.txt

            # Pausar por 1 segundo
            sleep 1
        done

        # Se o tempo acabou, finalizar RetroArch e apagar os arquivos temporários
        if [ $tempo_segundos -le 0 ]; then
            pkill retroarch
            rm /userdata/system/.dev/tempo_jogo.txt
            rm /userdata/system/.dev/time.tmp
            echo "Tempo de jogo acabou, RetroArch foi finalizado!"
        else
            # Se a contagem foi interrompida pela modificação de count.txt, apenas limpa o arquivo tempo_jogo.txt
            echo "Contagem interrompida, count.txt foi modificado. RetroArch continua ativo!"
            # NÃO apagar tempo_jogo.txt, apenas o mantém intacto.
            # O arquivo time.tmp fica intacto
        fi
    else
        echo "Arquivo /userdata/system/.dev/time.tmp não encontrado!"
    fi
}




# Chamada da função iniciar_contagem
# iniciar_contagem

####### Fim da função










# Launcher de execução dos games do fliperama com controle de créditos

# Diretórios das ROMs por sistema
ARCADE="/userdata/roms/windows"
ATOMISWAVE="/userdata/roms/atomiswave"
FBA="/userdata/roms/fba_libretro"
FBNEO="/userdata/roms/fbneo"
GENESIS="/userdata/roms/megadrive"
MAMELIBRETRO="/userdata/roms/mame/mame_libretro"
MAMEZEROTRINTEENOVE="/userdata/roms/mame/mame0139"
MAMEZEROSETENTAENOVEPLUS="/userdata/roms/mame/mame078plus"
N64="/userdata/roms/n64"
NAOMI="/userdata/roms/naomi"
NES="/userdata/roms/nes"
PSX="/userdata/roms/psx"
SNES="/userdata/roms/snes"

# Caminho da ROM recebida como argumento
ROM=$(readlink -f "$1")
SISTEMA_DIR=$(dirname "$ROM")

# Caminho do arquivo de créditos
CREDITOS_FILE="/userdata/system/.dev/count.txt"

# Lê o valor de créditos (ou assume 0 se não existir ou estiver inválido)
if [ -f "$CREDITOS_FILE" ]; then
    CREDITOS=$(grep -o '^[0-9]\+' "$CREDITOS_FILE")
    if [ -z "$CREDITOS" ]; then
        CREDITOS=0
    fi
else
    CREDITOS=0
fi

# Só continua se houver créditos
if [ "$CREDITOS" -le 0 ]; then
    echo "Sem créditos. Adicione créditos para jogar."
    mpv /usr/share/retroluxxo/sound/no.mp3 >/dev/null 2>&1
    exit 1
fi

# Diminui 1 crédito
#NOVO_CREDITO=$((CREDITOS - 1))
#echo "$NOVO_CREDITO" > "$CREDITOS_FILE"
#echo "Créditos restantes: $NOVO_CREDITO"

# Função para executar RetroArch com um core
launch_retroarch() {
    local core=$1
    retroarch -L "$core" "$ROM"
}

# Executa o sistema apropriado com base na pasta
case "$SISTEMA_DIR" in
    "$ARCADE")
        Launcher_on ; SDL_RENDER_VSYNC=1 \
        SDL_GAMECONTROLLERCONFIG="030000005e0400008e02000014010000,Microsoft X-Box 360 pad,platform:Linux,b:b1,a:b0,dpdown:h0.4,dpleft:h0.8,rightshoulder:b5,leftshoulder:b4,dpright:h0.2,back:b6,start:b7,dpup:h0.1,y:b2,x:b3," \
        SDL_JOYSTICK_HIDAPI=0 \
        batocera-wine windows play "$ROM" && Launcher_off
        ;;
    "$ATOMISWAVE")
        Launcher_on ; retroarch -L /usr/lib/libretro/flycast_libretro.so \
            --config /userdata/system/configs/retroarch/retroarch.cfg \
            --set-shader /usr/share/batocera/shaders/interpolation/sharp-bilinear-simple.slangp \
            --verbose --log-file /userdata/retroarch.log -f "$ROM" && Launcher_off
        ;;
    "$FBA")
        Launcher_on ; launch_retroarch "/usr/lib/libretro/fbalpha2012_libretro.so" && Launcher_off
        ;;
    "$FBNEO")
        Launcher_on ; launch_retroarch "/usr/lib/libretro/fbneo_libretro.so" && Launcher_off
        ;;
    "$GENESIS")
        iniciar_contagem &
        sleep 1
        Launcher_on ; launch_retroarch "/usr/lib/libretro/genesisplusgx_libretro.so" && Launcher_off

        ;;
    "$MAMELIBRETRO")
        Launcher_on ; launch_retroarch "/usr/lib/libretro/mame_libretro.so" && Launcher_off
        ;;

    "$MAMEZEROTRINTEENOVE")
        Launcher_on ; launch_retroarch "/usr/lib/libretro/mame0139_libretro.so" && Launcher_off
        ;;

    "$MAMEZEROSETENTAENOVEPLUS")
        Launcher_on ; launch_retroarch "/usr/lib/libretro/mame078plus_libretro.so" --config "/userdata/system/configs/retroarch/retroarch.cfg" && Launcher_off
        ;;
    "$N64")
        iniciar_contagem &
        sleep 1
        Launcher_on ; launch_retroarch "/usr/lib/libretro/mupen64plus-next_libretro.so" && Launcher_off

        ;;
    "$NAOMI")
        Launcher_on ; retroarch -L /usr/lib/libretro/flycast_libretro.so \
            --config /userdata/system/configs/retroarch/retroarch.cfg \
            --set-shader /usr/share/batocera/shaders/interpolation/sharp-bilinear-simple.slangp \
            --verbose --log-file /userdata/retroarch.log -f "$ROM" && Launcher_off
        ;;
    "$PSX")
        iniciar_contagem &
        sleep 1
        Launcher_on ; launch_retroarch "/usr/lib/libretro/pcsx_rearmed_libretro.so" && Launcher_off

        ;;
    "$SNES")
        iniciar_contagem &
        sleep 1
        Launcher_on ; launch_retroarch "/usr/lib/libretro/snes9x_libretro.so" && Launcher_off
        ;;

    "$NES")
        iniciar_contagem &
        sleep 1
        Launcher_on ; launch_retroarch "/usr/lib/libretro/nestopia_libretro.so" && Launcher_off 
        ;;
    *)
        echo "Sistema desconhecido: $SISTEMA_DIR"
        ;;
esac
