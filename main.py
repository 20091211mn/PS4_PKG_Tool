import os
from kivy.app import App
from kivy.uix.boxlayout import BoxLayout
from kivy.uix.button import Button
from kivy.uix.label import Label
from kivy.uix.textinput import TextInput

class PKGTool(BoxLayout):
    def __init__(self, **kwargs):
        super().__init__(orientation='vertical', padding=20, spacing=10, **kwargs)
        
        self.add_widget(Label(text="[ PS4 PKG Splitter & Merger ]", font_size='20sp'))
        
        self.path_input = TextInput(hint_text="أدخل مسار ملف الـ PKG أو الجزء 0 هنا", multiline=False)
        self.add_widget(self.path_input)
        
        self.status_label = Label(text="الحالة: جاهز", font_size='14sp')
        self.add_widget(self.status_label)
        
        btn_split = Button(text="تقسيم الملف (4 أجزاء)", background_color=(0, 0.7, 1, 1))
        btn_split.bind(on_press=self.split_pkg)
        self.add_widget(btn_split)
        
        btn_merge = Button(text="تجميع الأجزاء", background_color=(0, 0.9, 0.2, 1))
        btn_merge.bind(on_press=self.merge_pkg)
        self.add_widget(btn_merge)

    def split_pkg(self, instance):
        file_path = self.path_input.text.strip()
        if not os.path.exists(file_path):
            self.status_label.text = "خطأ: الملف غير موجود!"
            return
        
        self.status_label.text = "جاري التقسيم..."
        file_size = os.path.getsize(file_path)
        parts = 4
        part_size = file_size // parts
        
        with open(file_path, 'rb') as f:
            for i in range(parts):
                part_name = f"{file_path}.part{i}"
                bytes_to_read = part_size if i < parts - 1 else (file_size - (part_size * i))
                with open(part_name, 'wb') as p:
                    p.write(f.read(bytes_to_read))
        
        self.status_label.text = "تم التقسيم إلى 4 أجزاء بنجاح!"

    def merge_pkg(self, instance):
        first_part = self.path_input.text.strip()
        if not first_part.endswith('.part0') or not os.path.exists(first_part):
            self.status_label.text = "خطأ: اختر ملف .part0 الصحيح!"
            return
        
        self.status_label.text = "جاري التجميع..."
        output_pkg = first_part.replace('.part0', '_Merged.pkg')
        base_name = first_part.replace('.part0', '')
        
        with open(output_pkg, 'wb') as outfile:
            i = 0
            while True:
                part_file = f"{base_name}.part{i}"
                if not os.path.exists(part_file):
                    break
                with open(part_file, 'rb') as infile:
                    outfile.write(infile.read())
                i += 1
                
        self.status_label.text = "تم تجميع الملف بنجاح!"

class PKGApp(App):
    def build(self):
        return PKGTool()

if __name__ == '__main__':
    PKGApp().run()
