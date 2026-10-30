import re, sys
orig = open(sys.argv[1]).read()
ui = open(sys.argv[2]).read()
orig = re.sub(r'\bint\s+main\s*\(', 'int original_font_main(', orig)
incs, body = [], []
for l in ui.split('\n'):
    if l.startswith('#include'):
        if 'graphics.h' not in l:
            incs.append(l)
    else:
        body.append(l)
b = '\n'.join(body)
b = re.sub(r'\bint\s+main\s*\(', 'int ui_main(', b)
out = orig + '\n' + '\n'.join(incs) + '\nnamespace splitui {\n' + b + '\n}\nint main() { return splitui::ui_main(); }\n'
open(sys.argv[1], 'w').write(out)
print('UI main installed:', len(out.split('\n')), 'lines')
