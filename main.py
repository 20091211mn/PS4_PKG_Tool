import threading
import os
from kivy.app import App
from kivy.uix.boxlayout import BoxLayout
from kivy.uix.label import Label
from kivy.uix.textinput import TextInput
from kivy.uix.button import Button
from kivy.clock import Clock

try:
    from plyer import notification
    def send_notification(title, message):
        try:
            notification.notify(title=title, message=message)
        except:
            pass
except ImportError:
    def send_notification(title, message):
        pass

from pkg_backend import get_pkg_info, split_pkg_bash, merge_pkg_bash

class PKGToolUI(BoxLayout):
    def __init__(self, **kwargs):
        super(PKGToolUI, self).__init__(**kwargs)
        self.orientation = 'vertical'
        self.padding = 30
        self.spacing = 20

        self.add_widget(Label(
            text="PS4 PKG Tool", 
            font_size=28, 
            size_hint_y=None, 
            height=50
        ))

        self.path_input = TextInput(
            text='', 
            hint_text='Enter PKG or Part file path...', 
            size_hint_y=None, 
            height=50,
            multiline=False
        )
        self.add_widget(self.path_input)

        self.split_btn = Button(
            text='Split PKG', 
            size_hint_y=None, 
            height=60
        )
        self.split_btn.bind(on_press=self.start_split)
        self.add_widget(self.split_btn)

        self.merge_btn = Button(
            text='Merge PKG Parts', 
            size_hint_y=None, 
            height=60
        )
        self.merge_btn.bind(on_press=self.start_merge)
        self.add_widget(self.merge_btn)

        self.status_label = Label(
            text='Status: Ready', 
            font_size=18
        )
        self.add_widget(self.status_label)

    def start_split(self, instance):
        threading.Thread(target=self._split_worker, daemon=True).start()

    def _split_worker(self):
        file_path = self.path_input.text.strip()
        if not file_path or not os.path.exists(file_path):
            Clock.schedule_once(lambda dt: setattr(self.status_label, 'text', 'Error: Invalid file path!'))
            return

        Clock.schedule_once(lambda dt: setattr(self.status_label, 'text', 'Splitting PKG in background...'))
        send_notification("PS4 PKG Tool", "جاري تقسيم ملف PKG في الخلفية...")

        success = split_pkg_bash(file_path)

        if success:
            Clock.schedule_once(lambda dt: setattr(self.status_label, 'text', 'Split Completed Successfully!'))
            send_notification("PS4 PKG Tool", "تم بنجاح تقسيم ملف الـ PKG!")
        else:
            Clock.schedule_once(lambda dt: setattr(self.status_label, 'text', 'Split Failed!'))
            send_notification("PS4 PKG Tool", "حدث خطأ أثناء تقسيم الملف!")

    def start_merge(self, instance):
        threading.Thread(target=self._merge_worker, daemon=True).start()

    def _merge_worker(self):
        file_path = self.path_input.text.strip()
        if not file_path:
            Clock.schedule_once(lambda dt: setattr(self.status_label, 'text', 'Error: Enter part file path!'))
            return

        Clock.schedule_once(lambda dt: setattr(self.status_label, 'text', 'Merging PKG in background...'))
        send_notification("PS4 PKG Tool", "جاري دمج ملفات PKG في الخلفية...")

        if ".part_" in file_path:
            base_prefix = file_path.rsplit('.part_', 1)[0]
        else:
            base_prefix = file_path.rsplit('.', 1)[0]

        pattern = f"'{base_prefix}.part_*'"
        output_pkg = f"{base_prefix}_merged.pkg"

        success = merge_pkg_bash(pattern, output_pkg)

        if success:
            Clock.schedule_once(lambda dt: setattr(self.status_label, 'text', 'Merge Completed Successfully!'))
            send_notification("PS4 PKG Tool", "تم بنجاح دمج أجزاء الـ PKG!")
        else:
            Clock.schedule_once(lambda dt: setattr(self.status_label, 'text', 'Merge Failed!'))
            send_notification("PS4 PKG Tool", "فشلت عملية دمج الملفات!")

class PKGApp(App):
    def build(self):
        return PKGToolUI()

if __name__ == '__main__':
    PKGApp().run()
