import os
import threading
from kivy.app import App
from kivy.uix.boxlayout import BoxLayout
from kivy.uix.button import Button
from kivy.uix.label import Label
from kivy.uix.textinput import TextInput

# استدعاء الوظائف الخلفية السريعة
from pkg_backend import split_pkg_bash, merge_pkg_bash, get_pkg_info, calculate_md5

# استدعاء الإشعارات بأمان
try:
    from plyer import notification
    def send_notification(title, message):
        notification.notify(
            title=title,
            message=message,
            app_name="PS4 PKG Tool",
            timeout=5
        )
except ImportError:
    def send_notification(title, message):
        print(f"[{title}] {message}")

class PKGToolUI(BoxLayout):
    def __init__(self, **kwargs):
        super().__init__(orientation='vertical', spacing=12, padding=20, **kwargs)

        # 1. عنوان/تسمية الحالة
        self.status_label = Label(
            text="PS4 PKG Tool Ready",
            size_hint_y=None,
            height=40
        )
        self.add_widget(self.status_label)

        # 2. مربع أدخال مسار الملف
        self.path_input = TextInput(
            hint_text="Enter PKG or Part File Path",
            multiline=False,
            size_hint_y=None,
            height=50
        )
        self.add_widget(self.path_input)

        # 3. زر جلب تفاصيل الـ PKG
        self.info_btn = Button(
            text="Get PKG Details",
            size_hint_y=None,
            height=50
        )
        self.info_btn.bind(on_press=self.get_details)
        self.add_widget(self.info_btn)

        # 4. زر التقسيم السريع (split)
        self.split_btn = Button(
            text="Split PKG",
            size_hint_y=None,
            height=50
        )
        self.split_btn.bind(on_press=self.start_split)
        self.add_widget(self.split_btn)

        # 5. زر الدمج السريع (cat)
        self.merge_btn = Button(
            text="Merge PKG",
            size_hint_y=None,
            height=50
        )
        self.merge_btn.bind(on_press=self.start_merge)
        self.add_widget(self.merge_btn)

    def get_details(self, instance):
        file_path = self.path_input.text.strip()
        if not file_path or not os.path.exists(file_path):
            self.status_label.text = "Error: File path invalid!"
            return

        info = get_pkg_info(file_path)
        if "error" in info:
            self.status_label.text = f"Error: {info['error']}"
        else:
            self.status_label.text = f"Title ID: {info['title_id']} | Size: {info['file_size_gb']} GB"

    def start_split(self, instance):
        threading.Thread(target=self._split_worker, daemon=True).start()

    def _split_worker(self):
        file_path = self.path_input.text.strip()
        if not file_path or not os.path.exists(file_path):
            self.status_label.text = "Error: Invalid PKG path!"
            return

        self.status_label.text = "Splitting PKG in background..."
        send_notification("PS4 PKG Tool", "بدأت عملية تقسيم الملف...")

        output_prefix = file_path.rsplit('.', 1)[0]
        # تقسيم بأجزاء بحجم 4000 ميجابايت (4GB)
        success = split_pkg_bash(file_path, 4000, output_prefix)

        if success:
            self.status_label.text = "Split Completed Successfully!"
            send_notification("PS4 PKG Tool", "تمت عملية تقسيم الملف بنجاح!")
        else:
            self.status_label.text = "Split Failed!"
            send_notification("PS4 PKG Tool", "فشلت عملية التقسيم!")

    def start_merge(self, instance):
        threading.Thread(target=self._merge_worker, daemon=True).start()

    def _merge_worker(self):
        file_path = self.path_input.text.strip()
        if not file_path:
            self.status_label.text = "Error: Enter part file path!"
            return

        self.status_label.text = "Merging PKG in background..."
        send_notification("PS4 PKG Tool", "بدأت عملية دمج الملفات...")

        if ".part_" in file_path:
            base_prefix = file_path.rsplit('.part_', 1)[0]
        else:
            base_prefix = file_path.rsplit('.', 1)[0]

        pattern = f"'{base_prefix}.part_*'"
        output_pkg = f"{base_prefix}_merged.pkg"

        success = merge_pkg_bash(pattern, output_pkg)

        if success:
            self.status_label.text = "Merge Completed Successfully!"
            send_notification("PS4 PKG Tool", "تمت عملية الدمج بنجاح!")
        else:
            self.status_label.text = "Merge Failed!"
            send_notification("PS4 PKG Tool", "فشلت عملية الدمج!")

class PKGApp(App):
    def build(self):
        return PKGToolUI()

if __name__ == "__main__":
    PKGApp().run()
