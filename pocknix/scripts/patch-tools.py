#!/usr/bin/env python3
"""Aplica os patches de Python nas zipapps auxiliares do Heroic.

`legendary` e `gogdl` são zipapps com `#!/usr/bin/env python3`, ou seja: rodam
no Python do sistema. No Pocknix esse Python é o 3.14, e a partir do 3.14 o
método de start padrão do `multiprocessing` no Linux deixou de ser `fork` e
passou a ser `forkserver`. O forkserver precisa serializar o processo filho
para outro processo; legendary e gogdl passam `SharedMemory`/`Queue` e objetos
não-picklables, então o download travava. Os `SharedMemory` também ficavam
registrados no `resource_tracker`, que reclamava de vazamento no fim.

O patch (em `pocknix/tools/patches/`) força `set_start_method("fork")` e usa
`SharedMemory(..., track=False)`.

O script reescreve a zipapp no lugar:

  1. extrai em diretório temporário;
  2. aplica os patches que tocam arquivos presentes na zipapp, com
     `patch -p1 --fuzz=0` (contexto exato: se o upstream mudar as linhas, o
     build quebra em vez de aplicar torto);
  3. reempacota preservando ordem, timestamps, modo e tipo de compressão de
     cada entrada, com o shebang na frente;
  4. confere byte a byte que o conteúdo novo é exatamente o esperado.

É idempotente: rodar duas vezes não estraga nada (patch já aplicado é
detectado e ignorado).

Uso:
    python3 pocknix/scripts/patch-tools.py \\
        public/bin/arm64/linux/legendary public/bin/arm64/linux/gogdl

Qualquer patch de `pocknix/tools/patches/` que não seja aplicado em nenhuma
zipapp é erro: significa que o upstream mudou e a correção passou a ser
ignorada em silêncio.
"""

from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import sys
import tempfile
import zipfile
from pathlib import Path

PATCH_DIR = Path(__file__).resolve().parent.parent / "tools" / "patches"
SHEBANG = b"#!/usr/bin/env python3\n"


class PatchError(RuntimeError):
    pass


def _entries(zipapp: Path) -> list[zipfile.ZipInfo]:
    try:
        with zipfile.ZipFile(zipapp) as zf:
            bad = zf.testzip()
            if bad is not None:
                raise PatchError(f"{zipapp}: entrada corrompida ({bad})")
            return zf.infolist()
    except zipfile.BadZipFile as exc:
        raise PatchError(f"{zipapp}: não é uma zipapp ({exc})") from exc


def _targets(patch_file: Path) -> list[str]:
    """Arquivos que o patch toca, a partir das linhas `+++ b/<caminho>`."""
    out = []
    for line in patch_file.read_text(encoding="utf-8").splitlines():
        if line.startswith("+++ b/"):
            out.append(line[len("+++ b/") :])
    return out


def _applies(patch_file: Path, present: set[str]) -> bool:
    """Um patch entra se todos os arquivos que ele toca existem na zipapp.

    É o critério que separa legendary de gogdl: os caminhos internos não se
    cruzam. Se o upstream renomear algo, o patch não é selecionado — e nesse
    caso o build segue sem a correção, então o CI confere o resultado no fim.
    """
    targets = _targets(patch_file)
    if not targets:
        raise PatchError(f"{patch_file.name}: nenhum alvo `+++ b/...` encontrado")
    return all(t in present for t in targets)


def _apply(dest: Path, patch_file: Path) -> str:
    cmd = [
        "patch",
        "-p1",
        "--batch",
        "--forward",
        "--fuzz=0",
        "--no-backup-if-mismatch",
        "-d",
        str(dest),
        "-i",
        str(patch_file),
    ]
    dry = subprocess.run(cmd + ["--dry-run"], capture_output=True, text=True)
    output = dry.stdout + dry.stderr
    if dry.returncode == 0:
        real = subprocess.run(cmd, capture_output=True, text=True)
        if real.returncode != 0:
            raise PatchError(
                f"{patch_file.name}: aplicação falhou\n{real.stdout}{real.stderr}"
            )
        return "aplicado"
    if "previously applied" in output or "Reversed" in output:
        return "já aplicado"
    raise PatchError(
        f"{patch_file.name}: não casa com esta versão da zipapp "
        f"(contexto exato, sem fuzz)\n{output}"
    )


def _repack(zipapp: Path, tree: Path, dest: Path) -> None:
    infos = _entries(zipapp)
    tmp = dest.with_name(dest.name + ".tmp")
    with open(tmp, "wb") as fh:
        fh.write(SHEBANG)
    with zipfile.ZipFile(
        tmp, "a", compression=zipfile.ZIP_DEFLATED, compresslevel=9
    ) as zout:
        for info in infos:
            # metadata preservada: o runtime do Heroic compara CRCs e o
            # gogdl confere o hash do xdelta extraído
            zi = zipfile.ZipInfo(info.filename, info.date_time)
            zi.external_attr = info.external_attr
            zi.create_system = info.create_system
            zi.compress_type = info.compress_type
            if info.is_dir():
                zout.writestr(zi, b"")
                continue
            zout.writestr(zi, (tree / info.filename).read_bytes())
    os.chmod(tmp, 0o755)
    os.replace(tmp, dest)


def _verify(dest: Path, tree: Path, names: list[str]) -> None:
    with zipfile.ZipFile(dest) as zf:
        bad = zf.testzip()
        if bad is not None:
            raise PatchError(f"{dest}: zipapp gerada está corrompida ({bad})")
        if zf.namelist() != names:
            raise PatchError(f"{dest}: conjunto/ordem de entradas mudou")
        for name in names:
            if name.endswith("/"):
                continue
            if zf.read(name) != (tree / name).read_bytes():
                raise PatchError(f"{dest}: conteúdo divergente em {name}")


def patch_zipapp(zipapp: Path) -> list[str]:
    infos = _entries(zipapp)
    names = [i.filename for i in infos]
    present = set(names)
    patches = [p for p in sorted(PATCH_DIR.glob("*.patch")) if _applies(p, present)]
    if not patches:
        print(f"  {zipapp.name}: nenhum patch corresponde, ignorado")
        return []

    with tempfile.TemporaryDirectory(prefix="pocknix-tools-") as tmp:
        tree = Path(tmp)
        with zipfile.ZipFile(zipapp) as zf:
            zf.extractall(tree)
        results = []
        for p in patches:
            results.append((p.name, _apply(tree, p)))
        dest = zipapp.with_name(zipapp.name + ".patched")
        _repack(zipapp, tree, dest)
        _verify(dest, tree, names)
        shutil.copystat(zipapp, dest)
        os.replace(dest, zipapp)

    for name, how in results:
        print(f"  {zipapp.name}: {name} ({how})")
    return [name for name, _ in results]


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument("zipapps", nargs="+", type=Path, help="zipapps a corrigir")
    args = parser.parse_args(argv)

    if shutil.which("patch") is None:
        print("erro: `patch` não encontrado no PATH", file=sys.stderr)
        return 2
    if not PATCH_DIR.is_dir():
        print(f"erro: {PATCH_DIR} não existe", file=sys.stderr)
        return 2

    failed = False
    applied: set[str] = set()
    for zipapp in args.zipapps:
        if not zipapp.is_file():
            print(f"erro: {zipapp} não existe", file=sys.stderr)
            failed = True
            continue
        try:
            applied.update(patch_zipapp(zipapp))
        except PatchError as exc:
            print(f"erro: {exc}", file=sys.stderr)
            failed = True

    stale = sorted({p.name for p in PATCH_DIR.glob("*.patch")} - applied)
    for name in stale:
        print(
            f"erro: {name} não foi aplicado em nenhuma zipapp "
            f"(upstream mudou? patch órfão?)",
            file=sys.stderr,
        )
        failed = True

    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
