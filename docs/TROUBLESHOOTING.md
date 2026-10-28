# Problemas conhecidos

## Velocidade de download baixa

**Sintoma:** os jogos demoram mais do que o link pareceria permitir.

### Medidas deste aparelho (2026-10-28)

Link Wi-Fi a 866 Mbit efetivos: **17 MB/s por fluxo**, **52 MB/s em paralelo**, e o Steam chega a
~**75 MB/s**. O disco não limita (GOG grava a ~55 MiB/s enquanto baixa). Portanto o link não é o
problema.

| Loja | Ferramenta | Resultado medido |
|---|---|---|
| Epic | `legendary` 0.21.1 | **34,8 MiB/s** com 4 workers → **66,4 MiB/s** com 16 |
| GOG | `gogdl` 1.3.0 | ~**21 MiB/s** por instância (16/32/64 workers → 22/21/22) |
| Amazon | `nile` | **80–95 MiB/s** observados no install do usuário |

### Por que a GOG é limitada

Não é o CDN, não é o aparelho e não é falta de conexões:

- **Quatro instâncias de `gogdl` em paralelo no mesmo link: 47 MiB/s** (43 MiB/s na rede). O CDN
  entrega, desde que se peça em vários processos.
- **CPU durante um download: ~130% de 800% disponíveis.** O aparelho fica ocioso.
- Medindo a rede **segundo a segundo**, o `gogdl` alterna **rajadas de 40–69 MiB/s** com janelas de
  **0–9 MiB/s**.

Ou seja: o gerenciador V2 do `gogdl` (que sobe ~15–22 subprocessos Python) trabalha em lotes e
passa um tempo parado entre eles. Uma instância entrega ~20 MiB/s; aumentar `--max-workers` além de
16 não muda nada (medido até 64), porque a limitação é a cadência do processo, não o número de
conexões. O Steam é outro nível: downloader em C++ próprio, dezenas de conexões contra a rede de
cache dele (`cache*-gru1.steamcontent.com`).

**Como contornar na prática:** manter **duas instalações da GOG em andamento ao mesmo tempo** —
cada uma abre um `gogdl` próprio e as rajadas se sobrepõem (foi assim que o teste chegou a 47 MiB/s).

### O que ajuda de verdade

1. **Aumentar os workers.** O Heroic passa `maxWorkers` como `--max-workers` para os três runners.
   Com `0` (padrão) cada um usa o próprio default: `legendary` usa 4, `gogdl` usa o número de
   threads da CPU e `nile` usa o default dele. Em **Configurações → Avançado → Max Workers**, `16`
   é o valor que mediu melhor aqui (Epic dobrou). Voltar para `0` se o link for lento.

2. **Desligar a economia de energia do Wi-Fi.** O Pocknix usa **iwd** como backend
   (`/etc/NetworkManager/conf.d/99-valve-wifi-backend.conf`), então a opção do NetworkManager é
   ignorada e o `power_save` volta para `on` a cada reconexão. O ajuste correto é no iwd:

   ```bash
   iw dev wlan0 get power_save          # se disser "on":
   echo pocknix | sudo -S iw dev wlan0 set power_save off
   ```

   Para persistir, editar `/etc/iwd/main.conf`:

   ```ini
   [General]
   PowerSave=false
   ```

3. **Lembrar que a velocidade mostrada oscila.** A GOG mostra `Download` (bytes que chegam) e
   `Disk` (bytes gravados depois de descomprimir) ao mesmo tempo; ver 10 MiB/s de download com
   37 MiB/s de disco é normal e não indica problema.

### O que não resolve

- `APPIMAGE_EXTRACT_AND_RUN=1` não afeta a rede (só o carregamento inicial do AppImage).
- A compressão `zstd:1` do btrfs não é gargalo: ela roda a centenas de MiB/s.
- IPv6 não está em uso: os CDNs de jogo resolvem só em IPv4 nesta rede.

## Login da GOG: "verifique que você não é um robô" falha sempre

**Sintoma:** o login da Epic e da Amazon funciona, mas a janela da GOG fica presa no desafio do
Cloudflare (`auth.gog.com`) e termina em erro.

**Causa:** o Heroic até a v2.22.3 define um *user agent* falso na webview do login
(`Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/200.0`). Versão `200.0` não existe, e o
Cloudflare trata como bot. Corrigido no upstream em **v2.22.4** (PR
[#5979](https://github.com/Heroic-Games-Launcher/HeroicGamesLauncher/pull/5979)): o UA customizado
agora só é aplicado no login da Epic.

A base deste fork é `v2.22.4`, então o login da GOG abre normalmente. Se voltar a acontecer (o
Cloudflare muda as regras sem avisar), use o caminho alternativo abaixo.

### Caminho alternativo: entrar com código

O Heroic autentica na GOG chamando `gogdl auth --code <código>`. O código vem do OAuth da GOG e pode
ser obtido em um navegador de verdade — o `gogdl` não se importa com quem gerou o código.

1. Abra num navegador (PC, celular ou Desktop Mode):

   ```
   https://auth.gog.com/auth?client_id=46899977096215655&redirect_uri=https%3A%2F%2Fembed.gog.com%2Fon_login_success%3Forigin%3Dclient&response_type=code&layout=galaxy
   ```

2. Entre na conta. No fim o navegador vai para
   `https://embed.gog.com/on_login_success?origin=client&code=XXXX` (a página pode dar erro — o que
   importa é o `code=` na barra de endereço).

3. Com o Heroic instalado em `/home/deck/Applications/Heroic/Heroic-Pocknix.AppImage`, rode:

   ```bash
   # caminho do gogdl dentro do AppImage (extrai uma vez)
   mkdir -p /tmp/gogx && cd /tmp/gogx
   /home/deck/Applications/Heroic/Heroic-Pocknix.AppImage --appimage-extract >/dev/null
   GOGDL=/tmp/gogx/squashfs-root/resources/app.asar.unpacked/build/bin/arm64/linux/gogdl

   GOGDL_CONFIG_PATH="$HOME/.config/heroic/gogdlConfig" \
     "$GOGDL" --auth-config-path "$HOME/.config/heroic/gog_store/auth.json" \
     auth --code 'COLE_O_CODIGO_AQUI'
   ```

   Saída esperada: um JSON com `access_token`, `refresh_token` e `user_id`.

4. O Heroic só carrega o usuário se o próprio store disser que está logado. Com o Heroic fechado:

   ```bash
   python3 - <<'PY'
   import json, os
   path = os.path.expanduser('~/.config/heroic/gog_store/config.json')
   os.makedirs(os.path.dirname(path), exist_ok=True)
   data = {}
   if os.path.exists(path):
       data = json.load(open(path))
   data['isLoggedIn'] = True
   json.dump(data, open(path, 'w'), indent=2)
   PY
   ```

5. Abra o Heroic. A conta GOG deve aparecer na barra lateral.

O código expira em poucos minutos e só vale uma vez: gere outro se o passo 3 falhar.
