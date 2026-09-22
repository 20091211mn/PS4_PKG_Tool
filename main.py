import arabic_reshaper
from bidi.algorithm import get_display

from kivy.app import App
from kivy.uix.boxlayout import BoxLayout
from kivy.uix.label import Label
from kivy.uix.button import Button
from kivy.uix.textinput import TextInput
from kivy.core.text import LabelBase

# تسجيل الخط العربي في Kivy
LabelBase.register(name='ArabicFont', fn_regular='Cairo-Regular.ttf')

# دالة تصحيح النص العربي
def fix_text(text):
    if not text:
        return ""
    reshaped = arabic_reshaper.reshape(text)
    return get_display(reshaped)

class PS4ToolUI(BoxLayout):
    def __init__(self, **kwargs):
        super().__init__(orientation='vertical', padding=20, spacing=15, **kwargs)

        # العنوان الرئيسي
        self.title_label = Label(
            text=fix_text("[ PS4 PKG Splitter & Merger ]"),
            font_size='22sp',
            bold=True,
            size_hint_y=None,
            height=50
        )
        self.add_widget(self.title_label)

        # مربع معلومات الملف
        self.info_input = TextInput(
            text=fix_text("اضغط على زر الفحص لاختيار ملف PKG"),
            font_name='ArabicFont',
            font_size='16sp',
            readonly=True,
            multiline=True
        )
        self.add_widget(self.info_input)

        # تسمية حالة الأجزاء
        self.status_label = Label(
            text=fix_text("حالة الملف: بانتظار تحديد الملف"),
            font_name='ArabicFont',
            font_size='14sp',
            size_hint_y=None,
            height=40
        )
        self.add_widget(self.status_label)

        # زر التقسيم
        self.split_btn = Button(
            text=fix_text("تقسيم الملف (4 أجزاء)"),
            font_name='ArabicFont',
            font_size='18sp',
            background_color=(0, 0.4, 0.8, 1),
            size_hint_y=None,
            height=60
        )
        self.add_widget(self.split_btn)

        # زر الدمج
        self.merge_btn = Button(
            text=fix_text("دمج الأجزاء"),
            font_name='ArabicFont',
            font_size='18sp',
            background_color=(0, 0.6, 0.2, 1),
            size_hint_y=None,
            height=60
        )
        self.add_widget(self.merge_btn)

class PS4PKGToolApp(App):
    def build(self):
        return PS4ToolUI()

if __name__ == '__main__':
    PS4PKGToolApp().run()
