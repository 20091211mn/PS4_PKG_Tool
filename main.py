import threading
import os
from kivy.app import App
from kivy.uix.boxlayout import BoxLayout
from kivy.uix.label import Label
from kivy.uix.button import Button
from kivy.clock import Clock

try:
    from plyer import filechooser
except ImportError:
    filechooser = None

from pkg_backend import verify_and_get_filename, split_pkg, merge_pkg


class PKGToolUI(BoxLayout):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self.orientation = 'vertical'
        self.padding = 30
        self.spacing = 15
        self.selected_file_path = ""

        self.add_widget(Label(text="PS4 PKG Tool", font_size=28,
                              size_hint_y=None, height=50))

        self.pick_btn = Button(text='Select / Upload PKG File',
                               size_hint_y=None, height=55)
        self.pick_btn.bind(on_press=self.open_file_chooser)
        self.add_widget(self.pick_btn)

        self.file_label = Label(text='File Name: No file selected',
                                font_size=16, size_hint_y=None, height=40)
        self.add_widget(self.file_label)

        self.split_btn = Button(text='Split PKG', size_hint_y=None, height=55)
        self.split_btn.bind(on_press=self.start_split)
        self.add_widget(self.split_btn)

        self.merge_btn = Button(text='Merge PKG Parts',
                                size_hint_y=None, height=55)
        self.merge_btn.bind(on_press=self.start_merge)
        self.add_widget(self.merge_btn)

        self.status_label = Label(text='Status: Ready', font_size=15,
                                  text_size=(self.width, None), halign='center')
        self.add_widget(self.status_label)

    def set_status(self, text):
        Clock.schedule_once(lambda dt: setattr(self.status_label, 'text', text))

    def open_file_chooser(self, instance):
        if filechooser:
            try:
                filechooser.open_file(on_selection=self.on_file_selected)
            except Exception as e:
                self.set_status(f"Chooser Error: {e}")
        else:
            self.set_status("File chooser not supported on this device.")

    def on_file_selected(self, selection):
        if selection:
            self.selected_file_path = selection[0]
            filename, check = verify_and_get_filename(self.selected_file_path)
            if filename:
                self.file_label.text = f"File Name: {filename}"
                self.set_status(f"Verification: {check}")
            else:
                self.file_label.text = "File Name: Invalid"
                self.set_status(f"{check}\nPath: {self.selected_file_path}")

    def start_split(self, instance):
        threading.Thread(target=self._split_worker, daemon=True).start()

    def _split_worker(self):
        path = self.selected_file_path
        if not path or not os.path.exists(path):
            self.set_status('Error: Please select a valid file first!')
            return
        self.set_status('Splitting PKG file in background...')
        ok, msg = split_pkg(path)
        self.set_status(f"Split OK: {msg}" if ok else f"Split Failed: {msg}")

    def start_merge(self, instance):
        threading.Thread(target=self._merge_worker, daemon=True).start()

    def _merge_worker(self):
        path = self.selected_file_path
        if not path:
            self.set_status('Error: Please select a part file first!')
            return
        self.set_status('Merging PKG parts...')

        if ".part_" in path:
            base_prefix = path.rsplit('.part_', 1)[0]
        else:
            base_prefix = path

        stem = base_prefix[:-4] if base_prefix.lower().endswith('.pkg') else base_prefix
        output_pkg = f"{stem}_merged.pkg"

        ok, msg = merge_pkg(base_prefix, output_pkg)
        self.set_status(f"Merge OK: {msg}" if ok else f"Merge Failed: {msg}")


class PKGApp(App):
    def build(self):
        return PKGToolUI()

    def on_start(self):
        try:
            from android.permissions import request_permissions, Permission
            request_permissions([Permission.READ_EXTERNAL_STORAGE,
                                 Permission.WRITE_EXTERNAL_STORAGE])
        except ImportError:
            pass


if __name__ == '__main__':
    PKGApp().run()
