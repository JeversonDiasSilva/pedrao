#!/usr/bin/env python3
import pygame
import time
import subprocess
import xml.etree.ElementTree as ET
import os
import threading

ES_INPUT_CFG = '/userdata/system/configs/emulationstation/es_input.cfg'
CAMINHO_COUNT = '/userdata/system/.dev/count.txt'
CAMINHO_RELOGIO = '/userdata/system/.dev/relógio.txt'
CAMINHO_TEMPO_JOGO = '/userdata/system/.dev/tempo_jogo.txt'
CAMINHO_TIME_TMP = '/userdata/system/.dev/time.tmp'
TEMPO_JOGO_MINUTOS = 10  # tempo_jogo=10 → em minutos

contador_thread_ativo = False

def garantir_pasta():
    pasta = os.path.dirname(CAMINHO_COUNT)
    if not os.path.exists(pasta):
        os.makedirs(pasta, exist_ok=True)

def tocar_som_coin():
    try:
        subprocess.Popen(
            ['mpv', '--no-video', '--really-quiet', '/usr/share/retroluxxo/sound/coin.mp3'],
            # ['mpv', '--no-video', '--really-quiet', '--volume=150', '/usr/share/retroluxxo/sound/coin.mp3'],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL
        )
    except Exception as e:
        print(f"[ERRO] Falha ao tocar som com mpv: {e}")

def carregar_ids():
    select_ids = {}
    l3_ids = {}
    try:
        tree = ET.parse(ES_INPUT_CFG)
        root = tree.getroot()
        for inputConfig in root.findall('inputConfig'):
            nome = inputConfig.attrib.get('deviceName', '').strip().lower()
            for input_ in inputConfig.findall('input'):
                if input_.attrib.get('name') == 'select':
                    select_ids[nome] = int(input_.attrib.get('id'))
                elif input_.attrib.get('name') == 'l3':
                    l3_ids[nome] = int(input_.attrib.get('id'))
    except Exception as e:
        print(f"Erro lendo XML: {e}")
    return select_ids, l3_ids

def ler_arquivo_caminho(caminho, valor_padrao=0):
    try:
        with open(caminho, 'r') as f:
            return int(f.read().strip())
    except:
        return valor_padrao

def escrever_arquivo_caminho(caminho, valor):
    try:
        with open(caminho, 'w') as f:
            f.write(str(valor))
    except Exception as e:
        print(f"Erro ao escrever em {caminho}: {e}")

def retroarch_ativo():
    try:
        resultado = subprocess.run(["pgrep", "-f", "retroarch"], stdout=subprocess.DEVNULL)
        return resultado.returncode == 0
    except:
        return False

def iniciar_contagem_regressiva():
    global contador_thread_ativo
    if contador_thread_ativo:
        return

    def decrementar():
        global contador_thread_ativo
        contador_thread_ativo = True
        while True:
            tempo = ler_arquivo_caminho(CAMINHO_TEMPO_JOGO)
            if tempo <= 0 or not retroarch_ativo():
                escrever_arquivo_caminho(CAMINHO_TEMPO_JOGO, 0)
                print("[TEMPO] Tempo esgotado ou RetroArch fechado. Encerrando RetroArch e limpando arquivos.")
                subprocess.run(["pkill", "-f", "retroarch"])
                try:
                    if os.path.exists(CAMINHO_TEMPO_JOGO):
                        os.remove(CAMINHO_TEMPO_JOGO)
                    if os.path.exists(CAMINHO_TIME_TMP):
                        os.remove(CAMINHO_TIME_TMP)
                    print("[LIMPEZA] Arquivos de tempo removidos.")
                except Exception as e:
                    print(f"[ERRO] Falha ao remover arquivos: {e}")
                break
            tempo -= 1
            escrever_arquivo_caminho(CAMINHO_TEMPO_JOGO, tempo)
            time.sleep(1)
        contador_thread_ativo = False

    threading.Thread(target=decrementar, daemon=True).start()

def main():
    global contador, relogio

    garantir_pasta()

    pygame.init()
    pygame.joystick.init()

    select_ids, l3_ids = carregar_ids()

    joysticks = []
    for i in range(pygame.joystick.get_count()):
        j = pygame.joystick.Joystick(i)
        j.init()
        joysticks.append(j)

    contador = ler_arquivo_caminho(CAMINHO_COUNT)
    relogio = ler_arquivo_caminho(CAMINHO_RELOGIO)

    print(f"Créditos iniciais: {contador} | Relógio inicial: {relogio}")
    print("Monitorando botões...")

    estados = {}
    for j in joysticks:
        estados[j.get_id()] = {
            'l3_pressed': False,
            'l3_press_time': None,
            'select_pressed': False,
            'select_press_time': None,
        }

    tempo_inicializado = False
    credito_descontado_na_inicializacao = False

    while True:
        pygame.event.pump()
        retroativo = retroarch_ativo()

        if retroativo and os.path.exists(CAMINHO_TEMPO_JOGO) and os.path.exists(CAMINHO_TIME_TMP):
            if not tempo_inicializado:
                tempo_inicializado = True
                print("[INÍCIO] RetroArch iniciado com arquivos de tempo.")
                if not credito_descontado_na_inicializacao:
                    if contador > 0:
                        contador -= 1
                        escrever_arquivo_caminho(CAMINHO_COUNT, contador)
                        print(f"[INÍCIO] 1 crédito descontado na inicialização. Créditos restantes: {contador}")
                    else:
                        print("[INÍCIO] Sem créditos para descontar na inicialização.")
                    credito_descontado_na_inicializacao = True
                iniciar_contagem_regressiva()
        else:
            tempo_inicializado = False
            credito_descontado_na_inicializacao = False

        for j in joysticks:
            nome = j.get_name().strip().lower()
            select_id = select_ids.get(nome, 6)
            l3_id = l3_ids.get(nome, 9)
            estado = estados[j.get_id()]

            # L3 (adicionar tempo)
            if retroativo and l3_id < j.get_numbuttons():
                pressionado = j.get_button(l3_id)

                if pressionado and not estado['l3_pressed']:
                    estado['l3_pressed'] = True
                    estado['l3_press_time'] = time.time()

                if pressionado and estado['l3_pressed']:
                    duracao = time.time() - estado['l3_press_time']
                    if duracao >= 1:
                        print(f"[L3] Pressão longa >1s no '{nome}', fechando RetroArch...")
                        subprocess.run(["pkill", "-f", "retroarch"])
                        estado['l3_pressed'] = False
                        estado['l3_press_time'] = None

                if not pressionado and estado['l3_pressed']:
                    duracao = time.time() - estado['l3_press_time']
                    estado['l3_pressed'] = False
                    estado['l3_press_time'] = None

                    if duracao < 1.5:
                        contador = ler_arquivo_caminho(CAMINHO_COUNT)
                        if os.path.exists(CAMINHO_TEMPO_JOGO) and os.path.exists(CAMINHO_TIME_TMP):
                            if contador > 0:
                                tempo = ler_arquivo_caminho(CAMINHO_TEMPO_JOGO)
                                tempo += TEMPO_JOGO_MINUTOS * 60
                                escrever_arquivo_caminho(CAMINHO_TEMPO_JOGO, tempo)
                                contador -= 1
                                escrever_arquivo_caminho(CAMINHO_COUNT, contador)
                                print(f"[L3] Adicionado 5 min. Novo tempo: {tempo}s | Créditos: {contador}")
                                tocar_som_coin()
                                iniciar_contagem_regressiva()
                            else:
                                print("[L3] Sem créditos para adicionar tempo.")
                        else:
                            if contador > 0:
                                print(f"[L3] Pressão curta no '{nome}', executando xdotool...")
                                subprocess.run(['xdotool', 'keydown', '62'])
                                time.sleep(0.1)
                                subprocess.run(['xdotool', 'keyup', '62'])
                                contador -= 1
                                escrever_arquivo_caminho(CAMINHO_COUNT, contador)
                                print(f"[L3] Crédito decrementado. Créditos restantes: {contador}")

                                # Só tocar som se o tempo_jogo.txt existir
                                if os.path.exists(CAMINHO_TEMPO_JOGO):
                                    tocar_som_coin()
                            else:
                                print("[L3] Sem créditos para xdotool.")

            # SELECT (adicionar crédito)
            if not retroativo and select_id < j.get_numbuttons():
                pressionado = j.get_button(select_id)

                if pressionado and not estado['select_pressed']:
                    estado['select_pressed'] = True
                    estado['select_press_time'] = time.time()

                if not pressionado and estado['select_pressed']:
                    duracao = time.time() - estado['select_press_time']
                    estado['select_pressed'] = False
                    estado['select_press_time'] = None

                    if duracao < 1.0:
                        contador += 1
                        relogio += 1
                        escrever_arquivo_caminho(CAMINHO_COUNT, contador)
                        escrever_arquivo_caminho(CAMINHO_RELOGIO, relogio)
                        print(f"[SELECT] Pressão curta no '{nome}', Créditos: {contador}")
                        tocar_som_coin()

        time.sleep(0.05)

if __name__ == "__main__":
    main()