import os
import math
import threading

from kivy.app import App
from kivy.uix.boxlayout import BoxLayout
from kivy.uix.label import Label
from kivy.uix.button import Button
from kivy.uix.textinput import TextInput
from kivy.uix.progressbar import ProgressBar
from kivy.core.text import LabelBase
from kivy.clock import Clock
from kivy.utils import platform

try:
    import arabic_reshaper
    from bidi.algorithm import get_display
    HAS_ARABIC_LIBS = True
except ImportError:
    HAS_ARABIC_LIBS = False

def fix_text(text):
    if not text:
        return ""
    if HAS_ARABIC_LIBS:
        try:
            reshaped = arabic_reshaper.reshape(text)
            return get_display(reshaped)
        except Exception:
            return text
    return text

FONT_NAME = 'Roboto'
font_path = 'Cairo-Regular.ttf'
if os.path.exists(font_path):
    try:
        LabelBase.register(name='ArabicFont', fn_regular=font_path)
        FONT_NAME = 'ArabicFont'
    except Exception as e:
        print(f"Font Error: {e}")

class PS4ToolUI(BoxLayout):
    def __init__(self, **kwargs):
        super().__init__(orientation='vertical', padding=20, spacing=15, **kwargs)

        self.title_label = Label(
            text=fix_text("أداة تقسيم ودمج ملفات PS4 PKG"),
            font_name=FONT_NAME,
            font_size='20sp',
            bold=True,
            size_hint_y=None,
            height=40
        )
        self.add_widget(self.title_label)

        self.file_input = TextInput(
            hint_text=fix_text("اكتب مسار ملف الـ PKG هنا..."),
            font_name=FONT_NAME,
            font_size='14sp',
            multiline=False,
            size_hint_y=None,
            height=50
        )
        self.add_widget(self.file_input)

        self.status_label = Label(
            text=fix_text("الحالة: جاهز للعمل"),
            font_name=FONT_NAME,
            font_size='14sp',
            size_hint_y=None,
            height=30
        )
        self.add_widget(self.status_label)

        self.progress_bar = ProgressBar(max=100, value=0, size_hint_y=None, height=20)
        self.add_widget(self.progress_bar)

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
            buffer_size = 4 * 1024 * 1024

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

                            current_pos = src.tell()
                            progress_pct = int((current_pos / total_size) * 100)
                            self.update_status(f"جاري التقسيم: {progress_pct}% (الجزء {i+1}/4)", progress_pct)

            self.update_status("تمت عملية التقسيم بنجاح!", 100)
        except Exception as e:
            self.update_status(f"حدث خطأ: {str(e)}")
        finally:
            def _reenable(dt):
                self.split_btn.disabled = False
            Clock.schedule_once(_reenable)

class PS4PKGToolApp(App):
    def build(self):
        return PS4ToolUI()

    def on_start(self):
        if platform == 'android':
            Clock.schedule_once(self.request_android_permissions, 1.0)

    def request_android_permissions(self, dt):
        try:
            from android.permissions import request_permissions, Permission
            request_permissions([
                Permission.READ_EXTERNAL_STORAGE,
                Permission.WRITE_EXTERNAL_STORAGE
            ])
        except Exception as e:
            print(f"Android Permission Request Handled: {e}")

if __name__ == '__main__':
    PS4PKGToolApp().run()
