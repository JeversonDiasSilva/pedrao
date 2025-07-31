#!/usr/bin/env python3


import pygame
import time

# Inicialização
pygame.init()
pygame.joystick.init()

# Inicializa joysticks
joysticks = []
for i in range(pygame.joystick.get_count()):
    joystick = pygame.joystick.Joystick(i)
    joystick.init()
    print(f'Joystick {i} conectado: {joystick.get_name()}')
    joysticks.append(joystick)

# Dicionário para armazenar os tempos de pressão dos botões
botoes_pressionados = {}

print("\n▶ Monitorando botões... Pressione Ctrl+C para sair.\n")

# Loop principal
try:
    while True:
        for event in pygame.event.get():
            if event.type == pygame.JOYBUTTONDOWN:
                chave = (event.joy, event.button)
                botoes_pressionados[chave] = time.time()
                print(f'[Joystick {event.joy}] Botão {event.button} PRESSIONADO')

            elif event.type == pygame.JOYBUTTONUP:
                chave = (event.joy, event.button)
                if chave in botoes_pressionados:
                    tempo_pressionado = time.time() - botoes_pressionados.pop(chave)
                    print(f'[Joystick {event.joy}] Botão {event.button} SOLTO após {tempo_pressionado:.3f} segundos')

        # Pequena pausa para evitar uso excessivo de CPU
        pygame.time.wait(10)

except KeyboardInterrupt:
    print("\nEncerrando monitoramento...")
    pygame.quit()
