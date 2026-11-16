import tkinter as tk
from tkinter import ttk, messagebox
import queue
from datetime import datetime

from serial_receiver import SerialReceiver
from queue_model import QueueModel

# THEME

BG = "#071326"
PANEL = "#0B1B33"
PANEL2 = "#102746"
BORDER = "#244A76"

TEXT = "#EAF4FF"
MUTED = "#9BB5D3"

CYAN = "#16B8F4"
BLUE = "#368BFF"
GREEN = "#32E58B"
ORANGE = "#FF9D36"
PURPLE = "#A879FF"
RED = "#FF627D"

QUEUE_COLORS = [CYAN, GREEN, ORANGE, PURPLE]

MODE_NAMES = {
    0: "PRIORITY",
    1: "ROUND ROBIN",
    2: "WEIGHTED ROUND ROBIN",
    3: "RESERVED"
}


class SchedulerDashboard:

    def __init__(self, root):

        self.root = root
        self.root.title("FPGA Multi-Queue Packet Scheduler")
        self.root.geometry("1440x900")
        self.root.minsize(1080, 720)
        self.root.configure(bg=BG)

        self.incoming = queue.Queue()

        self.receiver = SerialReceiver(self.incoming)
        self.model = QueueModel(depth=16)

        self.port_var = tk.StringVar()
        self.connection_var = tk.StringVar(value="DISCONNECTED")
        self.mode_var = tk.StringVar(value="—")
        self.selected_var = tk.StringVar(value="—")

        self.generated_var = tk.StringVar(value="0")
        self.transmitted_var = tk.StringVar(value="0")
        self.latency_var = tk.StringVar(value="0 cycles")
        self.throughput_var = tk.StringVar(value="0 packets")

        self.frames_var = tk.StringVar(value="0")
        self.last_update_var = tk.StringVar(
            value="Waiting for FPGA telemetry"
        )

        self.queue_widgets = []

        self.setup_style()
        self.build_dashboard()
        self.refresh_ports()

        self.root.after(80, self.process_incoming)
        self.root.protocol("WM_DELETE_WINDOW", self.close)

    # STYLING

    def setup_style(self):

        style = ttk.Style()
        style.theme_use("clam")

        style.configure(
            "Dark.TCombobox",
            fieldbackground="#0A1B32",
            background="#102846",
            foreground=TEXT,
            arrowcolor=TEXT,
            bordercolor=BORDER,
            padding=7
        )

        style.map(
            "Dark.TCombobox",
            fieldbackground=[("readonly", "#0A1B32")],
            foreground=[("readonly", TEXT)]
        )

    def make_label(
        self, parent, text="", size=10,
        color=TEXT, bold=False, **kwargs
    ):

        return tk.Label(
            parent,
            text=text,
            bg=kwargs.pop("bg", parent.cget("bg")),
            fg=color,
            font=(
                "Segoe UI",
                size,
                "bold" if bold else "normal"
            ),
            **kwargs
        )

    def make_panel(self, parent, color=PANEL, accent=BORDER):

        return tk.Frame(
            parent,
            bg=color,
            highlightthickness=1,
            highlightbackground=accent
        )

    def make_button(self, parent, text, command, color):

        return tk.Button(
            parent,
            text=text,
            command=command,
            bg=color,
            fg="white",
            activebackground=color,
            activeforeground="white",
            relief="flat",
            bd=0,
            padx=16,
            pady=9,
            cursor="hand2",
            font=("Segoe UI", 9, "bold")
        )

    # MAIN DASHBOARD

    def build_dashboard(self):

        outer = tk.Frame(self.root, bg=BG)
        outer.pack(
            fill="both",
            expand=True,
            padx=22,
            pady=16
        )

        self.build_header(outer)
        self.build_serial_bar(outer)
        self.build_queue_cards(outer)
        self.build_bottom_panels(outer)
        self.build_footer(outer)

    # HEADER

    def build_header(self, parent):

        header = tk.Frame(parent, bg=BG)
        header.pack(fill="x", pady=(0, 15))

        logo = tk.Frame(
            header,
            bg="#0B2B4C",
            width=112,
            height=105,
            highlightthickness=1,
            highlightbackground="#1679B9"
        )

        logo.pack(side="left", padx=(0, 20))
        logo.pack_propagate(False)

        self.make_label(
            logo, "FPGA", 21, CYAN, True
        ).place(relx=0.5, rely=0.48, anchor="center")

        self.make_label(
            logo, "◈  ◈  ◈", 9, MUTED, True
        ).place(relx=0.5, rely=0.83, anchor="center")

        title = tk.Frame(header, bg=BG)
        title.pack(side="left", fill="y", expand=True)

        self.make_label(
            title,
            "FPGA MULTI-QUEUE",
            25,
            TEXT,
            True
        ).pack(anchor="w", pady=(8, 0))

        self.make_label(
            title,
            "PACKET SCHEDULER",
            25,
            CYAN,
            True
        ).pack(anchor="w")

        right = tk.Frame(header, bg=BG)
        right.pack(side="right", anchor="ne", pady=8)

        self.status_badge = tk.Label(
            right,
            textvariable=self.connection_var,
            bg="#4A2435",
            fg="#FFD7E0",
            font=("Segoe UI", 11, "bold"),
            padx=18,
            pady=9
        )

        self.status_badge.pack(anchor="e")

        self.make_label(
            right,
            "▦  UART · 115200 BAUD  |  8-N-1",
            10,
            MUTED
        ).pack(anchor="e", pady=(12, 0))

    # SERIAL CONNECTION BAR

    def build_serial_bar(self, parent):

        serial = self.make_panel(
            parent,
            color="#0A1D35",
            accent="#167EC0"
        )

        serial.pack(fill="x", pady=(0, 18))

        self.make_label(
            serial,
            "SERIAL CONNECTION",
            10,
            MUTED,
            True
        ).pack(side="left", padx=(18, 12), pady=13)

        self.port_combo = ttk.Combobox(
            serial,
            textvariable=self.port_var,
            width=12,
            state="readonly",
            style="Dark.TCombobox"
        )

        self.port_combo.pack(side="left", padx=(0, 8), pady=8)

        self.make_button(
            serial,
            "↻ Refresh",
            self.refresh_ports,
            "#17385D"
        ).pack(side="left", padx=4)

        self.connect_button = self.make_button(
            serial,
            "Connect",
            self.toggle_connection,
            "#087FC4"
        )

        self.connect_button.pack(side="left", padx=(8, 18))

        tk.Frame(
            serial,
            bg="#315477",
            width=1,
            height=34
        ).pack(side="left", padx=(0, 18), pady=8)

        self.make_label(
            serial,
            "MODE",
            10,
            MUTED,
            True
        ).pack(side="left", padx=(0, 10))

        self.mode_pill = tk.Label(
            serial,
            textvariable=self.mode_var,
            bg="#30205A",
            fg="#E5D5FF",
            font=("Segoe UI", 10, "bold"),
            padx=16,
            pady=9
        )

        self.mode_pill.pack(side="left", pady=7)

        self.make_label(
            serial,
            "Mode is read from FPGA telemetry",
            9,
            MUTED
        ).pack(side="right", padx=18)

    # ========================================================
    # FOUR QUEUE CARDS
    # ========================================================

    def build_queue_cards(self, parent):

        grid = tk.Frame(parent, bg=BG)
        grid.pack(fill="x")

        grid.grid_columnconfigure(0, weight=1, uniform="queue")
        grid.grid_columnconfigure(1, weight=1, uniform="queue")

        for q in range(4):

            color = QUEUE_COLORS[q]

            card = self.make_panel(
                grid,
                color="#0B1B33",
                accent=color
            )

            card.grid(
                row=q // 2,
                column=q % 2,
                sticky="nsew",
                padx=(0, 12) if q % 2 == 0 else (0, 0),
                pady=(0, 14)
            )

            # Queue heading

            heading = tk.Frame(card, bg="#0B1B33")
            heading.pack(fill="x", padx=22, pady=(19, 10))

            self.make_label(
                heading,
                f"QUEUE {q}",
                18,
                TEXT,
                True
            ).pack(side="left")

            tk.Label(
                heading,
                text=f"Q{q}",
                bg=color,
                fg="#071326",
                font=("Segoe UI", 9, "bold"),
                padx=9,
                pady=3
            ).pack(side="left", padx=12)

            # Occupancy

            occupancy_row = tk.Frame(card, bg="#0B1B33")
            occupancy_row.pack(fill="x", padx=22)

            self.make_label(
                occupancy_row,
                "Occupancy",
                11,
                MUTED
            ).pack(side="left")

            occupancy = self.make_label(
                occupancy_row,
                "0 / 16",
                21,
                color,
                True
            )

            occupancy.pack(side="right")

            # Progress bar

            bar_background = tk.Frame(
                card,
                bg="#1A3557",
                height=15
            )

            bar_background.pack(
                fill="x",
                padx=22,
                pady=(12, 21)
            )

            bar_background.pack_propagate(False)

            bar = tk.Frame(
                bar_background,
                bg=color,
                width=0
            )

            bar.pack(side="left", fill="y")

            self.queue_widgets.append({
                "occupancy": occupancy,
                "bar": bar,
                "background": bar_background
            })

            bar_background.bind(
                "<Configure>",
                lambda event: self.update_queue_cards()
            )

    # BOTTOM PANELS

    def build_bottom_panels(self, parent):

        lower = tk.Frame(parent, bg=BG)
        lower.pack(fill="both", expand=True, pady=(1, 0))

        self.build_activity_panel(lower)
        self.build_metrics_panel(lower)

    # Scheduler activity

    def build_activity_panel(self, parent):

        activity = self.make_panel(
            parent,
            color="#0B1B33",
            accent=PURPLE
        )

        activity.pack(
            side="left",
            fill="both",
            padx=(0, 8)
        )

        activity.configure(width=370)
        activity.pack_propagate(False)

        heading = tk.Frame(activity, bg="#0B1B33")
        heading.pack(fill="x", padx=20, pady=(18, 14))

        self.make_label(
            heading,
            "⚙",
            20,
            PURPLE,
            True
        ).pack(side="left", padx=(0, 12))

        self.make_label(
            heading,
            "SCHEDULER ACTIVITY",
            14,
            TEXT,
            True
        ).pack(side="left")

        self.make_label(
            activity,
            "SELECTED QUEUE",
            10,
            MUTED,
            True
        ).pack(anchor="w", padx=24, pady=(5, 7))

        selected_box = tk.Frame(
            activity,
            bg="#102746",
            highlightthickness=1,
            highlightbackground=BORDER,
            height=62
        )

        selected_box.pack(fill="x", padx=22)
        selected_box.pack_propagate(False)

        tk.Label(
            selected_box,
            textvariable=self.selected_var,
            bg="#102746",
            fg=ORANGE,
            font=("Segoe UI", 25, "bold")
        ).pack(expand=True)

        self.make_label(
            activity,
            "SCHEDULING ALGORITHM",
            10,
            MUTED,
            True
        ).pack(anchor="w", padx=24, pady=(18, 7))

        tk.Label(
            activity,
            textvariable=self.mode_var,
            bg="#30205A",
            fg="#E5D5FF",
            font=("Segoe UI", 12, "bold"),
            padx=12,
            pady=12
        ).pack(fill="x", padx=22)

        self.make_label(
            activity,
            "TELEMETRY",
            9,
            MUTED
        ).pack(anchor="w", padx=24, pady=(20, 3))

        self.make_label(
            activity,
            textvariable=self.last_update_var,
            size=9,
            color=CYAN
        ).pack(anchor="w", padx=24)

    # --------------------------------------------------------
    # Performance metrics
    # --------------------------------------------------------

    def build_metrics_panel(self, parent):

        metrics = self.make_panel(
            parent,
            color="#0B1B33",
            accent="#168FE1"
        )

        metrics.pack(
            side="left",
            fill="both",
            expand=True,
            padx=(8, 0)
        )

        heading = tk.Frame(metrics, bg="#0B1B33")
        heading.pack(fill="x", padx=22, pady=(18, 14))

        self.make_label(
            heading,
            "▥",
            20,
            BLUE,
            True
        ).pack(side="left", padx=(0, 12))

        self.make_label(
            heading,
            "PERFORMANCE METRICS",
            14,
            TEXT,
            True
        ).pack(side="left")

        grid = tk.Frame(metrics, bg="#0B1B33")
        grid.pack(fill="both", expand=True, padx=14, pady=(0, 16))

        grid.grid_columnconfigure(0, weight=1, uniform="metric")
        grid.grid_columnconfigure(1, weight=1, uniform="metric")

        grid.grid_rowconfigure(0, weight=1, uniform="metric")
        grid.grid_rowconfigure(1, weight=1, uniform="metric")

        self.make_metric(
            grid, "GENERATED",
            self.generated_var, "⬡", GREEN, 0, 0
        )

        self.make_metric(
            grid, "TRANSMITTED",
            self.transmitted_var, "➤", CYAN, 0, 1
        )

        self.make_metric(
            grid, "AVERAGE LATENCY",
            self.latency_var, "◷", PURPLE, 1, 0
        )

        self.make_metric(
            grid, "THROUGHPUT",
            self.throughput_var, "◉", ORANGE, 1, 1
        )

    def make_metric(
        self, parent, title, variable,
        symbol, color, row, column
    ):

        card = tk.Frame(
            parent,
            bg="#102746",
            highlightthickness=1,
            highlightbackground=BORDER
        )

        card.grid(
            row=row,
            column=column,
            sticky="nsew",
            padx=6,
            pady=6
        )

        heading = tk.Frame(card, bg="#102746")
        heading.pack(fill="x", padx=15, pady=(13, 4))

        self.make_label(
            heading,
            symbol,
            20,
            color,
            True
        ).pack(side="left")

        self.make_label(
            heading,
            title,
            9,
            MUTED,
            True
        ).pack(side="left", padx=10)

        tk.Label(
            card,
            textvariable=variable,
            bg="#102746",
            fg=TEXT,
            font=("Segoe UI", 22, "bold")
        ).pack(anchor="w", padx=17, pady=(3, 12))

    # FOOTER

    def build_footer(self, parent):

        footer = tk.Frame(
            parent,
            bg="#0A1A30",
            highlightthickness=1,
            highlightbackground="#1D4A76"
        )

        footer.pack(fill="x", pady=(14, 0))

        self.make_label(
            footer,
            "ⓘ  Live values are received from FPGA UART telemetry.",
            9,
            MUTED
        ).pack(side="left", padx=15, pady=10)

        self.make_label(
            footer,
            "●",
            10,
            GREEN,
            True
        ).pack(side="right", padx=(8, 5), pady=10)

        self.make_label(
            footer,
            "LIVE UPDATES",
            9,
            MUTED,
            True
        ).pack(side="right", pady=10)

        self.make_label(
            footer,
            "FRAMES",
            8,
            MUTED,
            True
        ).pack(side="right", padx=(22, 5))

        self.make_label(
            footer,
            textvariable=self.frames_var,
            size=9,
            color=TEXT,
            bold=True
        ).pack(side="right")

    # SERIAL CONNECTION

    def refresh_ports(self):

        ports = self.receiver.available_ports()

        self.port_combo["values"] = ports

        if ports and self.port_var.get() not in ports:
            self.port_var.set(ports[0])

        elif not ports:
            self.port_var.set("")

    def toggle_connection(self):

        if self.receiver.connected:

            self.receiver.disconnect()

            self.connection_var.set("DISCONNECTED")
            self.status_badge.configure(
                bg="#4A2435",
                fg="#FFD7E0"
            )

            self.connect_button.configure(
                text="Connect",
                bg="#087FC4"
            )

            self.last_update_var.set("Disconnected from FPGA")
            return

        port = self.port_var.get().strip()

        if not port:
            messagebox.showwarning(
                "Select COM port",
                "Choose the FPGA USB-UART COM port first."
            )
            return

        try:

            self.receiver.connect(port, 115200)

            self.connection_var.set(f"CONNECTED · {port}")

            self.status_badge.configure(
                bg="#124A37",
                fg="#BFFFE0"
            )

            self.connect_button.configure(
                text="Disconnect",
                bg="#B65B2A"
            )

            self.last_update_var.set(
                f"Listening on {port} at 115200 baud"
            )

        except Exception as error:

            messagebox.showerror(
                "UART connection failed",
                str(error)
            )

    # RECEIVE AND PROCESS FPGA DATA

    def process_incoming(self):

        changed = False

        while True:

            try:
                item = self.incoming.get_nowait()

            except queue.Empty:
                break

            if item["kind"] == "error":

                self.last_update_var.set("UART read error")

                messagebox.showerror(
                    "UART error",
                    item["message"]
                )

                self.receiver.disconnect()

                self.connection_var.set("DISCONNECTED")

                self.status_badge.configure(
                    bg="#4A2435",
                    fg="#FFD7E0"
                )

                self.connect_button.configure(
                    text="Connect",
                    bg="#087FC4"
                )

                continue

            # Packet event

            if item["kind"] == "event":

                self.model.apply_event(item)
                changed = True

            # Periodic status frame

            elif item["kind"] == "status":

                self.model.apply_status(item)

                mode = MODE_NAMES.get(
                    item["mode"],
                    "UNKNOWN"
                )

                self.mode_var.set(mode)

                selected = item["selected_queue"]

                self.selected_var.set(
                    f"Q{selected}"
                    if selected is not None
                    else "—"
                )

                self.generated_var.set(
                    f'{item["generated_count"]:,}'
                )

                self.transmitted_var.set(
                    f'{item["transmitted_count"]:,}'
                )

                self.latency_var.set(
                    f'{item["average_latency"]:,} cycles'
                )

                self.throughput_var.set(
                    f'{item["throughput_count"]:,} packets'
                )

                self.last_update_var.set(
                    "Last status: "
                    + datetime.now().strftime("%H:%M:%S")
                )

                changed = True

        if changed:

            self.update_queue_cards()

            self.frames_var.set(
                str(self.receiver.parser.frames_received)
            )

        self.root.after(80, self.process_incoming)

    # UPDATE QUEUE OCCUPANCY BARS

    def update_queue_cards(self):

        for q, widget in enumerate(self.queue_widgets):

            occupancy = max(
                0,
                min(16, self.model.occupancy[q])
            )

            widget["occupancy"].configure(
                text=f"{occupancy} / 16"
            )

            available_width = widget["background"].winfo_width()

            bar_width = int(
                available_width * occupancy / 16
            )

            widget["bar"].configure(
                width=bar_width
            )

    
    # CLOSE APPLICATION

    def close(self):

        self.receiver.disconnect()
        self.root.destroy()


# APPLICATION ENTRY POINT

if __name__ == "__main__":

    root = tk.Tk()

    app = SchedulerDashboard(root)

    root.mainloop()
