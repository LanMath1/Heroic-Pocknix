# Problemas conhecidos

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
