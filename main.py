import os
import threading
from kivy.app import App
from kivy.uix.boxlayout import BoxLayout
from kivy.uix.button import Button
from kivy.uix.label import Label
from kivy.uix.textinput import TextInput
from kivy.uix.progressbar import ProgressBar
from kivy.clock import Clock

class PKGStudioNative(BoxLayout):
    def __init__(self, **kwargs):
        super(PKGStudioNative, self).__init__(**kwargs)
        self.orientation = 'vertical'
        self.padding = 20
        self.spacing = 15

        self.title_label = Label(
            text='[b]PS4 PKG Studio Native[/b]',
            markup=True,
            font_size='22sp',
            size_hint_y=None,
            height=40
        )
        self.add_widget(self.title_label)

        self.path_input = TextInput(
            hint_text='أدخل المسار الكامل لملف PKG أو مجلد الأجزاء',
            multiline=False,
            size_hint_y=None,
            height=50
        )
        self.add_widget(self.path_input)

        self.parts_input = TextInput(
            text='4',
            hint_text='عدد الأجزاء',
            multiline=False,
            input_filter='int',
            size_hint_y=None,
            height=50
        )
        self.add_widget(self.parts_input)

        self.progress_bar = ProgressBar(max=100, size_hint_y=None, height=20)
        self.add_widget(self.progress_bar)

        self.status_label = Label(
            text='الحالة: في إنتظار البدء...',
            font_size='14sp',
            size_hint_y=None,
            height=30
        )
        self.add_widget(self.status_label)

        self.split_btn = Button(
            text='بدء التقسيم المباشر (Native Split)',
            background_color=(0.2, 0.6, 1, 1),
            size_hint_y=None,
            height=50
        )
        self.split_btn.bind(on_press=self.start_split_thread)
        self.add_widget(self.split_btn)

    def update_status(self, text, progress):
        self.status_label.text = text
        self.progress_bar.value = progress

    def start_split_thread(self, instance):
        file_path = self.path_input.text.strip()
        if not os.path.exists(file_path):
            self.status_label.text = 'خطأ: الملف غير موجود في المسار المكتوب!'
            return
        
        self.split_btn.disabled = True
        threading.Thread(target=self.native_split_engine, args=(file_path,)).start()

    def native_split_engine(self, file_path):
        try:
            num_parts = int(self.parts_input.text) or 4
            total_size = os.path.getsize(file_path)
            part_size = total_size // num_parts
            buffer_size = 8 * 1024 * 1024  # 8MB chunk stream

            output_dir = '/sdcard/Download/PS4_PKG_Tools'
            os.makedirs(output_dir, exist_ok=True)

            base_name = os.path.basename(file_path).replace('.pkg', '')

            with open(file_path, 'rb') as f_in:
                for i in range(num_parts):
                    part_name = f"{base_name}_part{i+1}.pkg.part"
                    part_path = os.path.join(output_dir, part_name)
                    bytes_written = 0
                    target_for_part = part_size if i < num_parts - 1 else (total_size - (part_size * i))

                    with open(part_path, 'wb') as f_out:
                        while bytes_written < target_for_part:
                            chunk_size = min(buffer_size, target_for_part - bytes_written)
                            data = f_in.read(chunk_size)
                            if not data:
                                break
                            f_out.write(data)
                            bytes_written += len(data)

                            current_progress = int(((f_in.tell()) / total_size) * 100)
                            Clock.schedule_once(lambda dt, p=current_progress, part=i+1: self.update_status(f'جاري كتابة الجزء {part}...', p))

            Clock.schedule_once(lambda dt: self.update_status('تم التقسيم بنجاح في مجلد Download/PS4_PKG_Tools!', 100))
        except Exception as e:
            Clock.schedule_once(lambda dt, err=str(e): self.update_status(f'خطأ: {err}', 0))
        finally:
            Clock.schedule_once(lambda dt: setattr(self.split_btn, 'disabled', False))

class PS4StudioApp(App):
    def build(self):
        return PKGStudioNative()

if __name__ == '__main__':
    PS4StudioApp().run()
