"""PS4 PKG Tool (PC) - Windows GUI over pkgtool_core.

Run:            python pkgtool_gui.py
CI smoke test:  python pkgtool_gui.py --selftest
"""
import json
import os
import queue
import sys
import tempfile
import threading
import time
import tkinter as tk
from tkinter import filedialog, ttk

import pkgtool_core as core
from pkgtool_core import ar

FONT = ('Tahoma', 11)
FONT_B = ('Tahoma', 12, 'bold')
PURPLE = '#7c4dff'


def payload_candidates():
    here = os.path.dirname(os.path.abspath(__file__))
    return [os.path.join(getattr(sys, '_MEIPASS', here), 'payload.bin'),
            os.path.join(here, 'payload.bin'), os.path.join(os.getcwd(), 'payload.bin')]


def load_payload():
    for p in payload_candidates():
        if os.path.isfile(p):
            with open(p, 'rb') as f:
                return f.read()
    raise core.PkgError('payload.bin was not found next to the program (the build copies it in automatically)')


def settings_path():
    base = os.environ.get('APPDATA') or os.path.expanduser('~')
    return os.path.join(base, 'PS4PkgTool.json')


class App:
    def __init__(self, root, settings_file=None):
        self.root = root
        self.settings_file = settings_file or settings_path()
        self.settings = self._load()
        self.q = queue.Queue()
        self.busy = False
        self.server = None
        self._last_put = 0.0
        self._sample = (time.monotonic(), 0)
        self._speed = 0.0
        self.group = None
        self.watch = None
        self.warn_after = (30, 60)

        root.title(ar('أداة حزم PS4') + '  -  PS4 PKG Tool  (direct ' + core.DIRECT_VERSION + ')')
        root.geometry('800x620')
        root.minsize(720, 540)
        style = ttk.Style()
        try:
            style.theme_use('vista' if 'vista' in style.theme_names() else 'clam')
        except tk.TclError:
            pass
        style.configure('TLabel', font=FONT)
        style.configure('TButton', font=FONT)
        style.configure('TNotebook.Tab', font=FONT_B, padding=(14, 6))
        style.configure('Big.TButton', font=FONT_B, padding=8)

        nb = ttk.Notebook(root)
        nb.pack(fill='both', expand=True, padx=10, pady=(10, 4))
        self.tab_split, self.tab_merge, self.tab_send = ttk.Frame(nb), ttk.Frame(nb), ttk.Frame(nb)
        nb.add(self.tab_split, text=ar('تقسيم') + '  Split')
        nb.add(self.tab_merge, text=ar('دمج') + '  Merge')
        nb.add(self.tab_send, text=ar('إرسال للـ PS4') + '  Send')
        self._build_split()
        self._build_merge()
        self._build_send()

        bottom = ttk.Frame(root)
        bottom.pack(fill='x', padx=10, pady=(0, 10))
        self.bar = ttk.Progressbar(bottom, mode='determinate', maximum=100)
        self.bar.pack(fill='x')
        self.status = tk.StringVar(value=ar('جاهز'))
        ttk.Label(bottom, textvariable=self.status).pack(anchor='w', pady=(4, 0))
        self.log = tk.Text(root, height=7, font=('Consolas', 10), state='disabled', bg='#14141c', fg='#dfe3f5')
        self.log.pack(fill='x', padx=10, pady=(0, 10))
        root.protocol('WM_DELETE_WINDOW', self.close)
        self.root.after(100, self.poll)

    # ------------------------------------------------------------- helpers
    def _load(self):
        try:
            with open(self.settings_file, 'r', encoding='utf-8') as f:
                return json.load(f)
        except (OSError, ValueError):
            return {}

    def _save(self):
        try:
            with open(self.settings_file, 'w', encoding='utf-8') as f:
                json.dump(self.settings, f)
        except OSError:
            pass

    def say(self, text):
        self.log.configure(state='normal')
        self.log.insert('end', time.strftime('%H:%M:%S  ') + text + '\n')
        self.log.see('end')
        self.log.configure(state='disabled')

    def _pick(self, var, title, types):
        p = filedialog.askopenfilename(title=title, filetypes=types)
        if p:
            var.set(p)
        return p

    # --------------------------------------------------------------- tabs
    def _build_split(self):
        f = self.tab_split
        f.columnconfigure(1, weight=1)
        self.split_path = tk.StringVar()
        ttk.Label(f, text=ar('الملف') + ' / File').grid(row=0, column=0, sticky='w', padx=10, pady=(16, 4))
        ttk.Entry(f, textvariable=self.split_path, font=FONT).grid(row=0, column=1, sticky='ew', pady=(16, 4))
        ttk.Button(f, text=ar('اختيار') + ' ...', command=self.pick_split).grid(row=0, column=2, padx=10, pady=(16, 4))
        self.split_info = tk.StringVar()
        ttk.Label(f, textvariable=self.split_info, wraplength=700, justify='left').grid(
            row=1, column=0, columnspan=3, sticky='w', padx=10, pady=4)
        ttk.Label(f, text=ar('عدد الأجزاء') + ' / Parts').grid(row=2, column=0, sticky='w', padx=10, pady=8)
        self.parts = tk.IntVar(value=2)
        self.spin = ttk.Spinbox(f, from_=2, to=99, textvariable=self.parts, width=6, font=FONT, command=self.update_hint)
        self.spin.grid(row=2, column=1, sticky='w', pady=8)
        self.split_hint = tk.StringVar()
        ttk.Label(f, textvariable=self.split_hint).grid(row=3, column=0, columnspan=3, sticky='w', padx=10)
        self.btn_split = ttk.Button(f, text=ar('ابدأ التقسيم') + '  Split', style='Big.TButton', command=self.start_split)
        self.btn_split.grid(row=4, column=0, columnspan=3, pady=18)

    def _build_merge(self):
        f = self.tab_merge
        f.columnconfigure(1, weight=1)
        self.merge_path = tk.StringVar()
        ttk.Label(f, text=ar('أي جزء') + ' / Any part').grid(row=0, column=0, sticky='w', padx=10, pady=(16, 4))
        ttk.Entry(f, textvariable=self.merge_path, font=FONT).grid(row=0, column=1, sticky='ew', pady=(16, 4))
        ttk.Button(f, text=ar('اختيار') + ' ...', command=self.pick_merge).grid(row=0, column=2, padx=10, pady=(16, 4))
        self.merge_info = tk.StringVar(value=ar('اختر أي جزء (part1 أو part3 أو 001 ...) وسيجد الباقي تلقائياً'))
        ttk.Label(f, textvariable=self.merge_info, wraplength=700, justify='left').grid(
            row=1, column=0, columnspan=3, sticky='w', padx=10, pady=10)
        self.btn_merge = ttk.Button(f, text=ar('دمج كل الأجزاء') + '  Merge', style='Big.TButton',
                                    command=self.start_merge, state='disabled')
        self.btn_merge.grid(row=2, column=0, columnspan=3, pady=18)

    def _build_send(self):
        f = self.tab_send
        f.columnconfigure(1, weight=1)
        self.ip = tk.StringVar(value=self.settings.get('ps4_ip', ''))
        self.send_path = tk.StringVar()
        ttk.Label(f, text='PS4 IP').grid(row=0, column=0, sticky='w', padx=10, pady=(16, 4))
        ttk.Entry(f, textvariable=self.ip, font=FONT, width=22).grid(row=0, column=1, sticky='w', pady=(16, 4))
        ttk.Label(f, text=ar('ملف PKG') + ' / PKG').grid(row=1, column=0, sticky='w', padx=10, pady=4)
        ttk.Entry(f, textvariable=self.send_path, font=FONT).grid(row=1, column=1, sticky='ew', pady=4)
        ttk.Button(f, text=ar('اختيار') + ' ...', command=self.pick_send).grid(row=1, column=2, padx=10, pady=4)
        self.method = tk.StringVar(value=self.settings.get('method', 'direct'))
        self.ctype = tk.StringVar(value='Auto')
        box = ttk.Frame(f)
        box.grid(row=2, column=0, columnspan=3, sticky='w', padx=10, pady=(8, 0))
        ttk.Radiobutton(box, text=ar('مباشر بدون RPI') + '  Direct (GoldHEN)', variable=self.method,
                        value='direct').pack(anchor='w')
        ttk.Radiobutton(box, text=ar('عبر RPI') + '  RPI', variable=self.method, value='rpi').pack(anchor='w')
        tbox = ttk.Frame(f)
        tbox.grid(row=3, column=0, columnspan=3, sticky='w', padx=10, pady=(6, 0))
        ttk.Label(tbox, text=ar('نوع الحزمة') + ' / Type').pack(side='left')
        ttk.Combobox(tbox, textvariable=self.ctype, values=['Auto', 'PS4GD', 'PS4AC', 'PS4GP'],
                     state='readonly', width=10).pack(side='left', padx=8)
        self.send_help = tk.StringVar(value=ar('مباشر: شغّل GoldHEN على الـ PS4 (لا تحتاج أي تطبيق). RPI: افتح تطبيق RPI أولاً'))
        ttk.Label(f, textvariable=self.send_help, wraplength=700).grid(row=4, column=0, columnspan=3, sticky='w', padx=10, pady=10)
        self.btn_send = ttk.Button(f, text=ar('إرسال') + '  Send', style='Big.TButton', command=self.start_send)
        self.btn_send.grid(row=5, column=0, columnspan=3, pady=(8, 4))
        self.btn_stop = ttk.Button(f, text=ar('إيقاف السيرفر') + '  Stop', command=self.stop_send, state='disabled')
        self.btn_stop.grid(row=6, column=0, columnspan=3)

    # ------------------------------------------------------- file choosers
    def pick_split(self):
        if self._pick(self.split_path, 'PKG', [('PKG', '*.pkg'), ('All', '*.*')]):
            self.refresh_split()

    def refresh_split(self):
        p = self.split_path.get()
        if not os.path.isfile(p):
            self.split_info.set('')
            return
        size = os.path.getsize(p)
        info = core.read_pkg_info(p)
        text = '%s   %s' % (os.path.basename(p), core.fmt_size(size))
        if info:
            text += '\n' + ar('حزمة PS4 صالحة') + '   %s   %s   0x%X' % (info['title_id'], info['region'], info['content_type'])
        self.split_info.set(text)
        need = core.min_parts(size)
        self.spin.configure(from_=need)
        if self.parts.get() < need:
            self.parts.set(need)
        self.update_hint()

    def update_hint(self):
        p = self.split_path.get()
        try:
            n = int(self.parts.get())
        except (tk.TclError, ValueError):
            return
        if os.path.isfile(p) and n > 0:
            self.split_hint.set(ar('حجم كل جزء تقريباً') + ': ' + core.fmt_size(-(-os.path.getsize(p) // n)))

    def pick_merge(self):
        if self._pick(self.merge_path, 'Part', [('All', '*.*')]):
            self.refresh_merge()

    def refresh_merge(self):
        self.group = core.group_for_file(self.merge_path.get())
        self.btn_merge.configure(state='disabled')
        if not self.group:
            self.merge_info.set(ar('هذا الملف ليس جزءاً من ملف مقسوم'))
            return
        g = self.group
        first = os.path.join(g['folder'], core.part_name(g['base'], g['style'], g['width'], g['first']))
        info = core.read_pkg_info(first)
        text = '%s\n%s %d / %d    %s' % (g['base'], ar('هذا الجزء'), g['index'], g['last'], core.fmt_size(g['total']))
        if info:
            text += '\n' + ar('حزمة PS4 صالحة') + '   ' + info['title_id']
        if g['missing']:
            text += '\n' + ar('جزء ناقص: رقم') + ' %d' % g['missing']
        else:
            text += '\n' + ar('كل الأجزاء موجودة')
            self.btn_merge.configure(state='normal')
        self.merge_info.set(text)

    def pick_send(self):
        self._pick(self.send_path, 'PKG', [('PKG', '*.pkg'), ('All', '*.*')])

    # ------------------------------------------------------------- tasks
    def run(self, label, fn):
        if self.busy:
            return False
        self.busy = True
        self.bar['value'] = 0
        self._sample, self._speed = (time.monotonic(), 0), 0.0
        self.status.set(label)
        self.say(label)

        def work():
            try:
                self.q.put(('done', fn(self.progress_cb)))
            except core.PkgError as e:
                self.q.put(('error', str(e)))
            except Exception as e:  # never let a worker die silently
                self.q.put(('error', '%s: %s' % (type(e).__name__, e)))

        threading.Thread(target=work, daemon=True).start()
        return True

    def progress_cb(self, done, total):
        now = time.monotonic()
        if done >= total or now - self._last_put >= 0.1:
            self._last_put = now
            self.q.put(('p', done, total))

    def start_split(self):
        try:
            p, n = self.split_path.get(), int(self.parts.get())
        except (tk.TclError, ValueError):
            self.say(ar('عدد الأجزاء غير صالح'))
            return
        self.run(ar('جاري التقسيم') + ' ...', lambda cb: ('split', core.split_file(p, n, cb)))

    def start_merge(self):
        g = self.group
        if g:
            self.run(ar('جاري الدمج') + ' ...', lambda cb: ('merge', core.merge_group(g, cb)))

    def start_send(self):
        ip, p = self.ip.get().strip(), self.send_path.get()
        if not ip or not os.path.isfile(p):
            self.say(ar('اكتب IP الـ PS4 واختر ملف PKG'))
            return
        method = self.method.get()
        ctype = None if self.ctype.get() == 'Auto' else self.ctype.get()
        self.settings['ps4_ip'] = ip
        self.settings['method'] = method
        self._save()

        def job(cb):
            if method == 'direct':
                payload = load_payload()
                self.server = core.direct_install(ip, p, payload, ctype=ctype,
                                                  log=lambda m: self.q.put(('log', m)))
                return ('send', 'direct')
            self.server = core.FileServer(p).start()
            url = self.server.url(core.local_ip_for(ip))
            self.q.put(('log', 'URL: ' + url))
            reply = core.rpi_install(ip, url)
            self.q.put(('log', 'RPI: ' + json.dumps(reply)[:300]))
            return ('send', url)

        if self.busy:
            return
        self.stop_send(quiet=True)
        if self.run(ar('جاري الإرسال') + ' ...', job):
            self.btn_stop.configure(state='normal')

    def stop_send(self, quiet=False):
        if self.server:
            try:
                self.server.stop()
            except OSError:
                pass
            self.server = None
            if not quiet:
                self.say(ar('تم إيقاف السيرفر'))
        self.btn_stop.configure(state='disabled')

    # -------------------------------------------------------------- queue
    def poll(self):
        try:
            while True:
                m = self.q.get_nowait()
                if m[0] == 'p':
                    done, total = m[1], m[2]
                    self.bar['value'] = 100.0 * done / max(1, total)
                    now = time.monotonic()
                    t0, d0 = self._sample
                    if now - t0 >= 0.5:
                        inst = (done - d0) / 1048576.0 / (now - t0)
                        self._speed = inst if self._speed == 0 else 0.6 * self._speed + 0.4 * inst
                        self._sample = (now, done)
                    left = int((total - done) / 1048576.0 / self._speed) if self._speed > 0 else 0
                    self.status.set('%d%%   %.1f MB/s   %s' % (self.bar['value'], self._speed,
                                                              ar('باقي') + ' %dm %ds' % (left // 60, left % 60)))
                elif m[0] == 'log':
                    self.say(m[1])
                elif m[0] == 'done':
                    self.busy = False
                    kind, res = m[1]
                    if kind == 'split':
                        self.bar['value'] = 100
                        self.say(ar('تم التقسيم') + ': %d parts' % len(res))
                        self.status.set(ar('تم التقسيم'))
                    elif kind == 'merge':
                        self.bar['value'] = 100
                        self.say(ar('تم الدمج') + ': ' + res)
                        self.status.set(ar('تم الدمج'))
                    else:
                        self.watch = {'t0': time.monotonic(), 'direct': res == 'direct', 'w1': False, 'w2': False,
                                      'started': False}
                        self.status.set(ar('تم الإرسال - السيرفر شغال حتى تضغط إيقاف'))
                        self.say(ar('رسالة النجاح لا تعني أن التحميل بدأ. انتظر رسالة: الـ PS4 بدأ التحميل'))
                elif m[0] == 'error':
                    self.busy = False
                    self.stop_send(quiet=True)
                    self.status.set(ar('فشل'))
                    self.say('ERROR: ' + m[1])
        except queue.Empty:
            pass
        if self.server and self.watch and not self.busy:
            self.check_ps4()
        if self.server and not self.busy:
            sent = self.server.sent
            self.status.set('%s  %s / %s' % (ar('أُرسل للـ PS4'), core.fmt_size(sent), core.fmt_size(self.server.size)))
            self.bar['value'] = 100.0 * min(sent, self.server.size) / max(1, self.server.size)
        self.root.after(100, self.poll)

    def check_ps4(self):
        """Tell the user whether the PS4 really came to fetch the package, and what to do when it did not."""
        w, sv = self.watch, self.server
        el = time.monotonic() - w['t0']
        first, second = self.warn_after
        if sv.pkg_hits:
            if not w['started']:
                w['started'] = True
                self.say(ar('الـ PS4 بدأ التحميل فعلاً') + '  OK')
        elif w['direct'] and not sv.manifest_hits and el > first and not w['w1']:
            w['w1'] = True
            self.say(ar('تحذير: الـ PS4 ما طلب الملف. غالباً الـ payload خرج (إشعار DirectPackageInstaller Exited).'))
            self.say(ar('الحل: في GoldHEN أطفئ BinLoader ثم شغّله من جديد (أو أعد تشغيل الـ PS4) ثم اضغط إرسال.'))
        elif w['direct'] and sv.manifest_hits and el > second and not w['w2']:
            w['w2'] = True
            self.say(ar('تحذير: الـ PS4 قرأ الوصف لكنه لم يبدأ التحميل. تأكد من الشبكة وجدار الحماية، وجرّب نوع حزمة آخر.'))
        elif not w['direct'] and el > first and not w['w1']:
            w['w1'] = True
            self.say(ar('تحذير: الـ PS4 لم يطلب الملف بعد. تأكد أن تطبيق RPI مفتوح وأن الجهازين على نفس الشبكة.'))

    def close(self):
        self.stop_send(quiet=True)
        self.root.destroy()


def selftest():
    """Builds the window, then runs a real split + merge through the worker thread and queue."""
    root = tk.Tk()
    root.withdraw()
    d = tempfile.mkdtemp()
    app = App(root, settings_file=os.path.join(d, 's.json'))
    src = os.path.join(d, 'sample.pkg')
    data = os.urandom(3 * 1024 * 1024)
    with open(src, 'wb') as f:
        f.write(data)

    def pump(seconds=20):
        end = time.time() + seconds
        while time.time() < end:
            root.update()
            if not app.busy and app.q.empty():
                return True
            time.sleep(0.02)
        return False

    app.split_path.set(src)
    app.refresh_split()
    app.parts.set(3)
    app.start_split()
    assert pump(), 'split did not finish'
    assert os.path.exists(src + '.part3'), 'part3 missing'
    os.remove(src)
    app.merge_path.set(src + '.part2')           # merge starting from the MIDDLE part
    app.refresh_merge()
    assert app.group and not app.group['missing'], 'group not detected'
    app.start_merge()
    assert pump(), 'merge did not finish'
    with open(src, 'rb') as f:
        assert f.read() == data, 'merged file differs'
    app.close()
    print('SELFTEST OK')


def main():
    if '--selftest' in sys.argv:
        try:
            selftest()
        except Exception as e:
            print('SELFTEST FAILED:', type(e).__name__, e)
            sys.exit(1)
        return
    root = tk.Tk()
    App(root)
    root.mainloop()


if __name__ == '__main__':
    main()
