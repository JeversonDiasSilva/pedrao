#!/bin/bash

# @JCGAMESCLASSICOS SOLUÇÕES

# CORES
VERDE='\033[1;32m'
NEUTRO='\033[0m'

# MENSAGENS
log_inicio() {
    echo -e "${VERDE}>>> INICIANDO INSTALAÇÃO DO EMULADOR PS2...${NEUTRO}"
}

log_aviso() {
    echo -e "${VERDE}EMULADOR PRECISA SER CONFIGURADO APÓS A INSTALAÇÃO ...${NEUTRO}"
}

log_fim() {
    echo -e "${VERDE}✔ INSTALAÇÃO CONCLUÍDA COM SUCESSO!${NEUTRO}"
}

sleep_sec=5

log_inicio
sleep $sleep_sec

# Remover BIOS antiga
rm -rf /userdata/bios/ps2

# Verifica root
if [[ $EUID -ne 0 ]]; then
   echo "Este script precisa ser executado como root."
   exit 1
fi

# Diretório do app
dir_app="/userdata/system/.dev/apps/ps2_light"
mkdir -p "$dir_app"
rm -rf "$dir_app"/*
cd "$dir_app" || exit 1

# AppImage
app="pcsx2-1.7.0.AppImage"
url="https://github.com/JeversonDiasSilva/pedrao/releases/download/v1.0/PS2-LIGHT"
squash=$(basename "$url")

# Download silencioso
wget "$url" -O "$squash" > /dev/null 2>&1 || exit 1

# Extrair AppImage
unsquashfs -d "$dir_app" "$squash" > /dev/null 2>&1 || exit 1

# Apagar AppImage
rm -f "$squash"

# Mover BIOS
if [[ -d "$dir_app/ps2" ]]; then
    mv "$dir_app/ps2" /userdata/bios/
fi

# Permissão e link
chmod +x "$dir_app/light.sh"
ln -sf "$dir_app/light.sh" /usr/bin/light

# Configs
ORIGINAL_CFGS=(
    "/userdata/system/configs/emulationstation/es_systems.cfg"
    "/usr/share/emulationstation/es_systems.cfg"
)
DEST_CFG="/userdata/system/configs/emulationstation/es_systems_ps2.cfg"

# XML do sistema PS2
read -r -d '' NOVO_CONTEUDO << 'EOF'
<?xml version="1.0"?>
<systemList>
  <system>
        <fullname>PlayStation 2</fullname>
        <name>ps2</name>
        <manufacturer>Sony</manufacturer>
        <release>2000</release>
        <hardware>console</hardware>
        <path>/userdata/roms/ps2</path>
        <extension>.iso .mdf .nrg .bin .img .dump .gz .cso .chd .m3u</extension>
        <command>light %ROM%  | emulatorlauncher %CONTROLLERSCONFIG% -system %SYSTEM% -rom %ROM% -gameinfoxml %GAMEINFOXML% -systemname %SYSTEMNAME%</command>
        <platform>ps2</platform>
        <theme>ps2</theme>
        <emulators>
            <emulator name="libretro">
                <cores>
                    <core>pcsx2</core>
                    <core incompatible_extensions=".m3u">play</core>
                </cores>
            </emulator>
            <emulator name="pcsx2">
                <cores>
                    <core default="true" incompatible_extensions=".m3u">pcsx2</core>
                </cores>
            </emulator>
            <emulator name="play">
                <cores>
                    <core incompatible_extensions=".m3u">play</core>
                </cores>
            </emulator>
            <emulator name="pcsx2-light">
                <cores>
                    <core incompatible_extensions=".m3u">pcsx2-light</core>
                </cores>
            </emulator>
        </emulators>
  </system>
</systemList>
EOF

# Cria pasta destino do XML
mkdir -p "$(dirname "$DEST_CFG")"

# Função: comenta bloco PS2 anterior
comentar_bloco_ps2() {
    local file="$1"
    local temp_file="${file}.bak"
    local found=0
    awk '
    BEGIN { inside=0 }
    /<system>/ {
        block=""
        block = block $0 "\n"
        inside=1
        next
    }
    inside {
        block = block $0 "\n"
        if ($0 ~ /<name>ps2<\/name>/) { found=1 }
        if ($0 ~ /<\/system>/) {
            inside=0
            if (found) {
                print "<!--" block "-->"
                found=0
            } else {
                print block
            }
            next
        }
        next
    }
    { print }
    ' "$file" > "$temp_file" && mv "$temp_file" "$file"
}

# Processa os arquivos existentes
for cfg in "${ORIGINAL_CFGS[@]}"; do
    if [[ -f "$cfg" ]] && grep -q '<name>ps2</name>' "$cfg"; then
        comentar_bloco_ps2 "$cfg"
    fi
done

# Salva novo XML
echo "$NOVO_CONTEUDO" > "$DEST_CFG"

# Salva overlay do Batocera
batocera-save-overlay 150

sleep $sleep_sec
log_aviso
log_fim
/userdata/system/.dev/apps/ps2_light/pcsx2-1.7.0.AppImage