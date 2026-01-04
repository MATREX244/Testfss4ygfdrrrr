# 🚀 muuf PRO - Bug Bounty Automation Framework

O **muuf PRO** é um framework de automação de reconhecimento e descoberta de vulnerabilidades, focado em metodologias utilizadas por profissionais de elite (6-figure hunters). Ele automatiza todo o fluxo de trabalho, desde a descoberta de subdomínios até a notificação de bugs críticos no seu Discord.

---

## 🛠️ O que o muuf PRO faz?

| Fase | Descrição | Ferramentas |
| :--- | :--- | :--- |
| **Recon** | Encontra subdomínios ocultos e esquecidos. | `subfinder`, `amass`, `assetfinder`, `crt.sh` |
| **Probing** | Verifica quais sites estão realmente ativos e quais tecnologias usam. | `httpx` |
| **Discovery** | Mapeia todas as páginas, arquivos JS e parâmetros. | `katana`, `gau` |
| **Vuln Scan** | Procura por falhas críticas (XSS, SQLi, SSRF, etc). | `nuclei` |
| **Fuzzing** | Tenta burlar acessos negados (403) e encontrar diretórios. | `ffuf` |
| **Alertas** | Envia notificações em tempo real para o seu Discord. | `notify` |

---

## 📦 Como Instalar

Siga estes passos no seu Kali Linux:

1. **Clone o repositório:**
   ```bash
   git clone https://github.com/MATREX244/Testfss4ygfdrrrr.git
   cd Testfss4ygfdrrrr
   ```

2. **Rode o instalador de dependências:**
   ```bash
   chmod +x install.sh
   ./install.sh
   ```

3. **Atualize seu terminal:**
   ```bash
   source ~/.bashrc
   ```

---

## 🔔 Configurando o Discord (Opcional, mas recomendado)

Para receber alertas no seu celular:

1. Crie um Webhook no seu servidor do Discord.
2. Rode o comando abaixo substituindo `SEU_LINK` pelo link do seu Webhook:
   ```bash
   mkdir -p ~/.config/notify/ && echo -e "discord:\n  - id: \"bug-bounty\"\n    discord_webhook_url: \"SEU_LINK\"" > ~/.config/notify/provider.yaml
   ```

---

## 🚀 Como Usar

Para iniciar um scan completo em um alvo:

```bash
./muuf_pro.sh -d alvo.com
```

### Opções Avançadas:
* `-d`: Domínio alvo (obrigatório).
* `-t`: Número de threads (padrão: 50).
* `-o`: Diretório de saída customizado.

---

## 💡 Dica de Profissional
Os grandes hunters rodam este script em uma **VPS** de forma contínua. Use o `notify` para receber alertas assim que o `nuclei` encontrar algo, permitindo que você seja o primeiro a reportar o bug!

---
*Desenvolvido para elevar seu nível no Bug Bounty.*
