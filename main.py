import os
import math
import threading
import arabic_reshaper
from bidi.algorithm import get_display

from kivy.app import App
from kivy.uix.boxlayout import BoxLayout
from kivy.uix.label import Label
from kivy.uix.button import Button
from kivy.uix.textinput import TextInput
from kivy.uix.progressbar import ProgressBar
from kivy.core.text import LabelBase
from kivy.clock import Clock
from kivy.utils import platform

# تسجيل الخط العربي إن وجد
FONT_NAME = 'Roboto'
if os.path.exists('Cairo-Regular.ttf'):
    LabelBase.register(name='ArabicFont', fn_regular='Cairo-Regular.ttf')
    FONT_NAME = 'ArabicFont'

def fix_text(text):
    if not text:
        return ""
    reshaped = arabic_reshaper.reshape(text)
    return get_display(reshaped)

class PS4ToolUI(BoxLayout):
    def __init__(self, **kwargs):
        super().__init__(orientation='vertical', padding=20, spacing=15, **kwargs)

        self.selected_file_path = ""

        # العنوان
        self.title_label = Label(
            text=fix_text("[ أداة تقسيم ودمج ملفات PS4 PKG ]"),
            font_name=FONT_NAME,
            font_size='20sp',
            bold=True,
            size_hint_y=None,
            height=40
        )
        self.add_widget(self.title_label)

        # مسار الملف
        self.file_input = TextInput(
            hint_text=fix_text("اكتب مسار ملف الـ PKG هنا أو اختر ملفاً..."),
            font_name=FONT_NAME,
            font_size='14sp',
            multiline=False,
            size_hint_y=None,
            height=50
        )
        self.add_widget(self.file_input)

        # حالة العمل والتقدم
        self.status_label = Label(
            text=fix_text("الحالة: جاهز للعمل"),
            font_name=FONT_NAME,
            font_size='14sp',
            size_hint_y=None,
            height=30
        )
        self.add_widget(self.status_label)

        # شريط التقدم
        self.progress_bar = ProgressBar(max=100, value=0, size_hint_y=None, height=20)
        self.add_widget(self.progress_bar)

        # زر التقسيم
        self.split_btn = Button(
            text=fix_text("بدء تقسيم الملف إلى 4 أجزاء"),
            font_name=FONT_NAME,
            font_size='16sp',
            background_color=(0, 0.4, 0.8, 1),
            size_hint_y=None,
            height=55
        )
        self.split_btn.bind(on_press=self.start_split_thread)
        self.add_widget(self.split_btn)

    def update_status(self, text, progress=None):
        def _update(dt):
            self.status_label.text = fix_text(text)
            if progress is not None:
                self.progress_bar.value = progress
        Clock.schedule_once(_update)

    def start_split_thread(self, instance):
        file_path = self.file_input.text.strip()
        if not file_path or not os.path.exists(file_path):
            self.update_status("خطأ: تعذر العثور على الملف المحدد!")
            return

        self.split_btn.disabled = True
        threading.Thread(target=self.split_pkg_file, args=(file_path,), daemon=True).start()

    def split_pkg_file(self, file_path):
        try:
            total_size = os.path.getsize(file_path)
            part_size = math.ceil(total_size / 4)
            buffer_size = 64 * 1024 * 1024  # 64MB Buffer

            self.update_status("جاري بدء عملية التقسيم...", 0)

            with open(file_path, 'rb') as src:
                for i in range(4):
                    part_filename = f"{file_path}.part{i}"
                    bytes_remaining = part_size
                    with open(part_filename, 'wb') as dst:
                        while bytes_remaining > 0:
                            read_len = min(bytes_remaining, buffer_size)
                            chunk = src.read(read_len)
                            if not chunk:
                                break
                            dst.write(chunk)
                            bytes_remaining -= len(chunk)

                            # التقدير لشريط التقدم
                            current_pos = src.tell()
                            progress_pct = int((current_pos / total_size) * 100)
                            self.update_status(f"جاري التقسيم: {progress_pct}% (الجزء {i+1}/4)", progress_pct)

            self.update_status("تمت عملية التقسيم بنجاح!", 100)
        except Exception as e:
            self.update_status(f"حدث خطأ أثناء التقسيم: {str(e)}")
        finally:
            def _reenable(dt):
                self.split_btn.disabled = False
            Clock.schedule_once(_reenable)

class PS4PKGToolApp(App):
    def build(self):
        return PS4ToolUI()

    def on_start(self):
        if platform == 'android':
            from android.permissions import request_permissions, Permission
            request_permissions([
                Permission.READ_EXTERNAL_STORAGE,
                Permission.WRITE_EXTERNAL_STORAGE
            ])

if __name__ == '__main__':
    PS4PKGToolApp().run()
