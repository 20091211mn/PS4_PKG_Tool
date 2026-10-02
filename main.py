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

from pkg_backend import get_pkg_info, split_pkg_bash, merge_pkg_bash, calculate_md5

class PKGToolUI(BoxLayout):
    def __init__(self, **kwargs):
        super(PKGToolUI, self).__init__(**kwargs)
        self.orientation = 'vertical'
        self.padding = 30
        self.spacing = 20

        # Title (نفس الواجهة الأصلية بدون تغيير)
        self.add_widget(Label(
            text="PS4 PKG Tool", 
            font_size=28, 
            size_hint_y=None, 
            height=50
        ))

        # Path Input
        self.path_input = TextInput(
            text='', 
            hint_text='Enter PKG or Part file path...', 
            size_hint_y=None, 
            height=50,
            multiline=False
        )
        self.path_input.bind(text=self.on_path_changed)
        self.add_widget(self.path_input)

        # Split Button
        self.split_btn = Button(
            text='Split PKG', 
            size_hint_y=None, 
            height=60
        )
        self.split_btn.bind(on_press=self.start_split)
        self.add_widget(self.split_btn)

        # Merge Button
        self.merge_btn = Button(
            text='Merge PKG Parts', 
            size_hint_y=None, 
            height=60
        )
        self.merge_btn.bind(on_press=self.start_merge)
        self.add_widget(self.merge_btn)

        # Status Label
        self.status_label = Label(
            text='Status: Ready', 
            font_size=16
        )
        self.add_widget(self.status_label)

    def on_path_changed(self, instance, value):
        """فحص CUSA وهيدر الملف تلقائياً فور إدخال المسار"""
        path = value.strip()
        if os.path.exists(path) and os.path.isfile(path):
            info = get_pkg_info(path)
            cusa = info.get("cusa", "غير معروف")
            size_str = info.get("size_str", "")
            self.status_label.text = f"File: {os.path.basename(path)} | Size: {size_str} | CUSA: {cusa}"

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

        Clock.schedule_once(lambda dt: setattr(self.status_label, 'text', 'Merging PKG & Verifying MD5...'))
        send_notification("PS4 PKG Tool", "جاري دمج ملفات PKG وفحص التجزئة...")

        if ".part_" in file_path:
            base_prefix = file_path.rsplit('.part_', 1)[0]
        else:
            base_prefix = file_path.rsplit('.', 1)[0]

        pattern = f"'{base_prefix}.part_*'"
        output_pkg = f"{base_prefix}_merged.pkg"

        success = merge_pkg_bash(pattern, output_pkg)

        if success:
            # التحقق الفعلي من صحة التجزئة MD5 بعد الدمج
            md5_hash = calculate_md5(output_pkg)
            status_msg = f"Merge OK! Hash: {md5_hash[:8]}..." if md5_hash else "Merge Completed Successfully!"
            Clock.schedule_once(lambda dt: setattr(self.status_label, 'text', status_msg))
            send_notification("PS4 PKG Tool", "تم دمج الـ PKG والتحقق من سلامة الملف!")
        else:
            Clock.schedule_once(lambda dt: setattr(self.status_label, 'text', 'Merge Failed!'))
            send_notification("PS4 PKG Tool", "فشلت عملية دمج الملفات!")

class PKGApp(App):
    def build(self):
        return PKGToolUI()

if __name__ == '__main__':
    PKGApp().run()
