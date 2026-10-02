import threading
import os
from kivy.app import App
from kivy.uix.boxlayout import BoxLayout
from kivy.uix.label import Label
from kivy.uix.button import Button
from kivy.clock import Clock

try:
    from android.permissions import request_permissions, Permission
    request_permissions([Permission.READ_EXTERNAL_STORAGE, Permission.WRITE_EXTERNAL_STORAGE])
except ImportError:
    pass

try:
    from plyer import filechooser, notification
    def send_notification(title, message):
        try:
            notification.notify(title=title, message=message)
        except:
            pass
except ImportError:
    def send_notification(title, message):
        pass
    filechooser = None

from pkg_backend import verify_and_get_filename, split_pkg_bash, merge_pkg_bash

class PKGToolUI(BoxLayout):
    def __init__(self, **kwargs):
        super(PKGToolUI, self).__init__(**kwargs)
        self.orientation = 'vertical'
        self.padding = 30
        self.spacing = 15

        # عنوان التطبيق
        self.add_widget(Label(
            text="PS4 PKG Tool", 
            font_size=28, 
            size_hint_y=None, 
            height=50
        ))

        # زر رفع / اختيار الملف
        self.pick_btn = Button(
            text='رفع / اختيار ملف PKG',
            size_hint_y=None,
            height=55
        )
        self.pick_btn.bind(on_press=self.open_file_chooser)
        self.add_widget(self.pick_btn)

        # خانة اسم الملف المستخرج والمفحوص
        self.file_label = Label(
            text='اسم الملف: لم يتم اختيار ملف بعد',
            font_size=16,
            size_hint_y=None,
            height=40
        )
        self.add_widget(self.file_label)

        # زر التقسيم
        self.split_btn = Button(
            text='Split PKG (تقسيم)', 
            size_hint_y=None, 
            height=55
        )
        self.split_btn.bind(on_press=self.start_split)
        self.add_widget(self.split_btn)

        # زر الدمج
        self.merge_btn = Button(
            text='Merge PKG Parts (دمج)', 
            size_hint_y=None, 
            height=55
        )
        self.merge_btn.bind(on_press=self.start_merge)
        self.add_widget(self.merge_btn)

        # حالة العملية
        self.status_label = Label(
            text='الحالة: جاهز', 
            font_size=15
        )
        self.selected_file_path = ""
        self.add_widget(self.status_label)

    def open_file_chooser(self, instance):
        if filechooser:
            try:
                filechooser.open_file(on_selection=self.on_file_selected)
            except Exception as e:
                self.status_label.text = f"خطأ في فتح المستعرض: {e}"
        else:
            self.status_label.text = "مستعرض الملفات غير مدعوم على الجهاز."

    def on_file_selected(self, selection):
        if selection and len(selection) > 0:
            self.selected_file_path = selection[0]
            
            # التحقق من اسم وصحة الملف فور الرفع
            filename, check_status = verify_and_get_filename(self.selected_file_path)
            if filename:
                self.file_label.text = f"اسم الملف: {filename}"
                self.status_label.text = f"نتيجة الفحص: {check_status}"
            else:
                self.file_label.text = "اسم الملف: غير صالح"
                self.status_label.text = check_status

    def start_split(self, instance):
        threading.Thread(target=self._split_worker, daemon=True).start()

    def _split_worker(self):
        if not self.selected_file_path or not os.path.exists(self.selected_file_path):
            Clock.schedule_once(lambda dt: setattr(self.status_label, 'text', 'خطأ: يرجى رفع ملف صحيح أولاً!'))
            return

        Clock.schedule_once(lambda dt: setattr(self.status_label, 'text', 'جاري تقسيم الملف في الخلفية...'))
        send_notification("PS4 PKG Tool", "جاري تقسيم ملف PKG...")

        success = split_pkg_bash(self.selected_file_path)

        if success:
            Clock.schedule_once(lambda dt: setattr(self.status_label, 'text', 'تم التقسيم بنجاح!'))
            send_notification("PS4 PKG Tool", "تم التقسيم بنجاح!")
        else:
            Clock.schedule_once(lambda dt: setattr(self.status_label, 'text', 'فشل التقسيم! تحقق من الأذونات المساحة.'))

    def start_merge(self, instance):
        threading.Thread(target=self._merge_worker, daemon=True).start()

    def _merge_worker(self):
        if not self.selected_file_path:
            Clock.schedule_once(lambda dt: setattr(self.status_label, 'text', 'خطأ: يرجى رفع جزء من الملف أولاً!'))
            return

        Clock.schedule_once(lambda dt: setattr(self.status_label, 'text', 'جاري دمج الملفات...'))
        send_notification("PS4 PKG Tool", "جاري دمج ملفات PKG...")

        file_path = self.selected_file_path
        if ".part_" in file_path:
            base_prefix = file_path.rsplit('.part_', 1)[0]
        else:
            base_prefix = file_path.rsplit('.', 1)[0]

        pattern = f"'{base_prefix}.part_*'"
        output_pkg = f"{base_prefix}_merged.pkg"

        success = merge_pkg_bash(pattern, output_pkg)

        if success:
            Clock.schedule_once(lambda dt: setattr(self.status_label, 'text', 'تم دمج الملفات بنجاح!'))
            send_notification("PS4 PKG Tool", "تم الدمج بنجاح!")
        else:
            Clock.schedule_once(lambda dt: setattr(self.status_label, 'text', 'فشل الدمج! تحقق من وجود باقي الأجزاء.'))

class PKGApp(App):
    def build(self):
        return PKGToolUI()

if __name__ == '__main__':
    PKGApp().run()
