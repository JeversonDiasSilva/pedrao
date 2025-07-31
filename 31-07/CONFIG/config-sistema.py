#!/usr/bin/python3.14
import subprocess
import customtkinter as ctk
import tkinter.messagebox as msgbox
import re
import os

CAMINHO_SCRIPT = "/usr/share/retroluxxo/scripts/coin.py"

# Configurações globais do tema dark
ctk.set_appearance_mode("dark")  # modo dark
ctk.set_default_color_theme("dark-blue")  # tema azul escuro

class ConfiguradorApp(ctk.CTk):
    def __init__(self):
        super().__init__()
        self.title("🕹️ Configurar Créditos e Tempo")
        self.geometry("650x360")
        self.resizable(False, False)
        self.configure(padx=20, pady=20)

        # Frame principal com padding e borda arredondada
        self.main_frame = ctk.CTkFrame(self, corner_radius=15, border_width=1, border_color="#3a3f5c")
        self.main_frame.pack(fill="both", expand=True)

        # Título principal, fonte maior e peso bold
        self.title_label = ctk.CTkLabel(
            self.main_frame, 
            text="⚙️ Configuração do Sistema",
            font=ctk.CTkFont(size=22, weight="bold"),
            pady=20
        )
        self.title_label.pack()

        # Label + Entry: Tempo para sair
        self.label_saida = ctk.CTkLabel(
            self.main_frame, 
            text="Tempo botão pressionado para sair do jogo (segundos):",
            anchor="w",
            font=ctk.CTkFont(size=14)
        )
        self.label_saida.pack(fill="x", padx=30, pady=(10, 5))

        self.input_saida = ctk.CTkEntry(self.main_frame, placeholder_text="Ex: 3", font=ctk.CTkFont(size=14))
        self.input_saida.pack(fill="x", padx=30, pady=(0, 15))

        # Label + Entry: Duração dos créditos
        self.label_creditos = ctk.CTkLabel(
            self.main_frame,
            text="Duração dos créditos para jogo de Plataforma (minutos):",
            anchor="w",
            font=ctk.CTkFont(size=14)
        )
        self.label_creditos.pack(fill="x", padx=30, pady=(10, 5))

        self.input_creditos = ctk.CTkEntry(self.main_frame, placeholder_text="Ex: 5", font=ctk.CTkFont(size=14))
        self.input_creditos.pack(fill="x", padx=30, pady=(0, 25))

        # Frame para os botões, centralizado com espaçamento uniforme
        self.button_frame = ctk.CTkFrame(self.main_frame, fg_color="transparent")
        self.button_frame.pack(pady=(0, 20))

        self.save_btn = ctk.CTkButton(
            self.button_frame, text="💾 Gravar Mudanças", width=140, height=40,
            fg_color="#2874a6", hover_color="#1b5273", font=ctk.CTkFont(size=14, weight="bold"),
            command=self.salvar_config
        )
        self.save_btn.grid(row=0, column=0, padx=12)

        self.restart_btn = ctk.CTkButton(
            self.button_frame, text="🔄 Restart Joysticks", width=140, height=40,
            fg_color="#d87f33", hover_color="#b26c29", font=ctk.CTkFont(size=14, weight="bold"),
            command=self.restart_joysticks
        )
        self.restart_btn.grid(row=0, column=1, padx=12)

        self.exit_btn = ctk.CTkButton(
            self.button_frame, text="✅ Sair", width=140, height=40,
            fg_color="#28a745", hover_color="#218838", font=ctk.CTkFont(size=14, weight="bold"),
            command=self.destroy
        )
        self.exit_btn.grid(row=0, column=2, padx=12)

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

            subprocess.run(["batocera-save-overlay"], check=True)
            subprocess.run(["/usr/share/retroluxxo/scripts/restart-coin.sh"], check=True)

            self.input_saida.delete(0, 'end')
            self.input_creditos.delete(0, 'end')

            msgbox.showinfo("Sucesso", "Configurações atualizadas e scripts executados!")

        except subprocess.CalledProcessError as e:
            msgbox.showerror("Erro", f"Erro ao executar comando externo:\n{e}")
        except Exception as e:
            msgbox.showerror("Erro", f"Erro ao modificar o script:\n{e}")

    def restart_joysticks(self):
        try:
            subprocess.run(["pkill", "-f", "coin.py"], check=False)
            subprocess.run(["/usr/share/retroluxxo/scripts/restart-coin.sh"], check=True)
            msgbox.showinfo("Sucesso", "Joystick reiniciado com sucesso!")

        except subprocess.CalledProcessError as e:
            msgbox.showerror("Erro", f"Erro ao reiniciar joysticks:\n{e}")
        except Exception as e:
            msgbox.showerror("Erro", f"Erro inesperado:\n{e}")

if __name__ == "__main__":
    app = ConfiguradorApp()
    app.mainloop()
