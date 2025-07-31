#!/usr/bin/python3.14
import subprocess
import customtkinter as ctk
import tkinter.messagebox as msgbox
import re
import os

CAMINHO_SCRIPT = "/usr/share/retroluxxo/scripts/coin.py"

ctk.set_appearance_mode("System")
ctk.set_default_color_theme("blue")

class ConfiguradorApp(ctk.CTk):
    def __init__(self):
        super().__init__()
        self.title("🕹️ Configurar Créditos e Tempo")
        self.geometry("500x340")
        self.resizable(False, False)

        self.main_frame = ctk.CTkFrame(self, corner_radius=10)
        self.main_frame.pack(padx=20, pady=20, fill="both", expand=True)

        self.title_label = ctk.CTkLabel(
            self.main_frame, 
            text="⚙️ Configuração do Sistema",
            font=ctk.CTkFont(size=20, weight="bold")
        )
        self.title_label.pack(pady=(10, 15))

        self.label_saida = ctk.CTkLabel(self.main_frame, text="Tempo botão pressionado para sair do jogo (segundos):")
        self.label_saida.pack(anchor="w", padx=10)
        self.input_saida = ctk.CTkEntry(self.main_frame, placeholder_text="Ex: 3")
        self.input_saida.pack(padx=10, pady=(0, 15), fill="x")

        self.label_creditos = ctk.CTkLabel(self.main_frame, text="Duração dos créditos para jogod de Plataforma em (minutos):")
        self.label_creditos.pack(anchor="w", padx=10)
        self.input_creditos = ctk.CTkEntry(self.main_frame, placeholder_text="Ex: 5")
        self.input_creditos.pack(padx=10, pady=(0, 20), fill="x")

        self.button_frame = ctk.CTkFrame(self.main_frame, fg_color="transparent")
        self.button_frame.pack(pady=(0, 10))

        # Botão gravar (visível inicialmente)
        self.save_btn = ctk.CTkButton(self.button_frame, text="💾 Gravar Mudanças", command=self.salvar_config)
        self.save_btn.grid(row=0, column=0, padx=10)

        # Botão sair verde (invisível inicialmente)
        self.exit_btn = ctk.CTkButton(
            self.button_frame, text="✅ Sair", fg_color="#28a745", hover_color="#218838", command=self.destroy
        )
        self.exit_btn.grid(row=0, column=1, padx=10)
        self.exit_btn.grid_remove()  # Esconde no início

    def salvar_config(self):
        tempo_saida = self.input_saida.get().strip()
        tempo_creditos = self.input_creditos.get().strip()

        if not tempo_saida.isdigit() or not tempo_creditos.isdigit():
            msgbox.showerror("Erro", "Insira apenas números inteiros.")
            return

        tempo_saida = int(tempo_saida)
        tempo_creditos = int(tempo_creditos)

        if not os.path.exists(CAMINHO_SCRIPT):
            msgbox.showerror("Erro", f"Arquivo não encontrado:\n{CAMINHO_SCRIPT}")
            return

        try:
            with open(CAMINHO_SCRIPT, 'r') as f:
                conteudo = f.read()

            conteudo = re.sub(
                r'TEMPO_JOGO_MINUTOS\s*=\s*\d+\s*#.*',
                f'TEMPO_JOGO_MINUTOS = {tempo_creditos}  # tempo_jogo={tempo_creditos} → em minutos',
                conteudo
            )

            conteudo = re.sub(
                r'if\s+duracao\s*>=\s*\d+(\.\d+)?',
                f'if duracao >= {tempo_saida}',
                conteudo
            )

            conteudo = re.sub(
                r'print\(f?\s*"?\[L3\]\s*Press[aã]o longa\s*>[0-9]+s',
                f'print(f"[L3] Pressão longa >{tempo_saida}s',
                conteudo
            )

            conteudo = re.sub(
                r'print\(f?\s*"?\[L3\]\s*Adicionado\s*\{?TEMPO_JOGO_MINUTOS\}?\s*min',
                f'print(f"[L3] Adicionado {tempo_creditos} min',
                conteudo
            )

            with open(CAMINHO_SCRIPT, 'w') as f:
                f.write(conteudo)

            # Roda os comandos externos
            subprocess.run(["batocera-save-overlay"], check=True)
            subprocess.run(["/usr/share/retroluxxo/scripts/restart-coin.sh"], check=True)

            # Limpa campos
            self.input_saida.delete(0, 'end')
            self.input_creditos.delete(0, 'end')

            # Esconde botão gravar e mostra o botão verde sair
            self.save_btn.grid_remove()
            self.exit_btn.grid()

            msgbox.showinfo("Sucesso", "Configurações atualizadas e scripts executados!")

        except subprocess.CalledProcessError as e:
            msgbox.showerror("Erro", f"Erro ao executar comando externo:\n{e}")
        except Exception as e:
            msgbox.showerror("Erro", f"Erro ao modificar o script:\n{e}")

if __name__ == "__main__":
    app = ConfiguradorApp()
    app.mainloop()