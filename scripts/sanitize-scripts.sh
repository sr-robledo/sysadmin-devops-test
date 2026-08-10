#!/bin/bash
# Reemplaza paths absolutos por paths relativos portables en los scripts.
# Sin chars especiales problemáticos para sed.
set -e
cd /mnt/h/Prueba\ cibervoluntarios/scripts

# Path absoluto del repo → variable REPO_ROOT
ABS_PATH='/mnt/h/Prueba\ cibervoluntarios'
RELATIVE='"$(cd "$(dirname "$0")/.." && pwd)"'

for f in *.sh; do
  if [ "$f" = "sanitize-scripts.sh" ]; then continue; fi
  # Reemplaza el path absoluto en todas sus formas
  # Forma 1: cd /mnt/h/Prueba\ cibervoluntarios
  # Forma 2: cd /mnt/h/Prueba\ cibervoluntarios/<subdir>
  # Forma 3: /mnt/h/Prueba\ cibervoluntarios/<path>/<file>
  python3 -c "
import sys, re
p = '$f'
with open(p) as fh: content = fh.read()
# Path absoluto
abs_re = re.compile(r'/mnt/h/Prueba\\\\ cibervoluntarios(/[^\"\\s]*)')
def repl(m):
    sub = m.group(1) or ''
    return '\${REPO_ROOT}' + sub
# Pero \$ se rompe al pasar por bash. Usamos doble escapado.
content = re.sub(r'/mnt/h/Prueba\\\\\\\\ cibervoluntarios', '\${REPO_ROOT}', content)
with open(p, 'w') as fh: fh.write(content)
"
done

# El truco de python arriba no es perfecto. Lo hago con un python mejor.
python3 <<'PYEOF'
import os, re
scripts_dir = os.getcwd()
abs_re = re.compile(r'/mnt/h/Prueba\\ cibervoluntarios')
# Patrón real (con espacio escapado)
abs_re2 = re.compile(r'/mnt/h/Prueba[ \t]+cibervoluntarios')

for f in sorted(os.listdir(scripts_dir)):
    if not f.endswith('.sh'): continue
    if f == 'sanitize-scripts.sh': continue
    p = os.path.join(scripts_dir, f)
    with open(p) as fh: content = fh.read()
    new = abs_re2.sub('${REPO_ROOT}', content)
    # Añade la línea de REPO_ROOT al principio si hizo falta
    if new != content:
        if 'REPO_ROOT=' not in new[:500]:
            # Inserto el cálculo de REPO_ROOT tras el shebang
            lines = new.split('\n', 1)
            shebang = lines[0] if lines else '#!/bin/bash'
            rest = lines[1] if len(lines) > 1 else ''
            repo_root_line = '\n# Raíz del repo (calculada desde la ubicación del script)\nREPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"\n'
            new = shebang + repo_root_line + rest
        with open(p, 'w') as fh: fh.write(new)
        print(f"  modificado: {f}")
    else:
        print(f"  sin cambios: {f}")
PYEOF

echo ""
echo "=== Verificación: ya no debe haber /mnt/h/ en scripts ==="
grep -l '/mnt/h/' *.sh 2>/dev/null || echo "  OK, ningún script contiene /mnt/h/"
