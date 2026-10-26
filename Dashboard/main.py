# main.py
# The primary entry point for the FPGA Scheduler Dashboard[cite: 117, 118]

import tkinter as tk
from tkinter import ttk, scrolledtext
import time

from serial_receiver import SerialReceiver
from queue_model import QueueModel
from plots import PerformancePlots

class MainApp:
    def __init__(self, root):
        self.root = root
        self.root.title("FPGA Multi-Queue Packet Scheduler")
        self.root.geometry("1000x800")
        
        self.q_model = QueueModel()
        self.receiver = None
        
        self.setup_ui()

    def setup_ui(self):
        # --- Top Connection Bar ---
        top_frame = ttk.Frame(self.root, padding=10)
        top_frame.pack(fill=tk.X)
        
        ttk.Label(top_frame, text="COM Port:").pack(side=tk.LEFT)
        self.port_entry = ttk.Entry(top_frame, width=10)
        self.port_entry.insert(0, "COM3")
        self.port_entry.pack(side=tk.LEFT, padx=5)
        
        self.btn_connect = ttk.Button(top_frame, text="Connect", command=self.toggle_connection)
        self.btn_connect.pack(side=tk.LEFT, padx=5)
        
        self.lbl_status = ttk.Label(top_frame, text="DISCONNECTED", foreground="red")
        self.lbl_status.pack(side=tk.LEFT, padx=20)
        
        self.lbl_mode = ttk.Label(top_frame, text="Mode: UNKNOWN", font=("Arial", 12, "bold"))
        self.lbl_mode.pack(side=tk.RIGHT, padx=10)

        # --- Queue Visualizations (Reconstructed Packets) ---
        queue_frame = ttk.LabelFrame(self.root, text="Live Queue Contents", padding=10)
        queue_frame.pack(fill=tk.X, padx=10, pady=5)
        
        self.q_listboxes = []
        for i in range(4):
            f = ttk.Frame(queue_frame)
            f.pack(side=tk.LEFT, expand=True, fill=tk.BOTH, padx=5)
            ttk.Label(f, text=f"Queue {i}", font=("Arial", 10, "bold")).pack()
            
            listbox = tk.Listbox(f, height=8, width=15, font=("Courier", 10))
            listbox.pack(pady=5)
            self.q_listboxes.append(listbox)

        # --- Middle Layout: Logs & Performance Counters ---
        mid_frame = ttk.Frame(self.root, padding=10)
        mid_frame.pack(fill=tk.X)
        
        log_frame = ttk.LabelFrame(mid_frame, text="Packet Event Log")
        log_frame.pack(side=tk.LEFT, fill=tk.BOTH, expand=True, padx=(0, 5))
        self.log_text = scrolledtext.ScrolledText(log_frame, width=40, height=10, state='disabled')
        self.log_text.pack(fill=tk.BOTH, expand=True)
        
        stats_frame = ttk.LabelFrame(mid_frame, text="Performance Counters")
        stats_frame.pack(side=tk.RIGHT, fill=tk.BOTH, expand=True, padx=(5, 0))
        
        self.lbl_gen = ttk.Label(stats_frame, text="Generated: 0", font=("Arial", 11))
        self.lbl_gen.pack(anchor=tk.W, pady=2, padx=10)
        self.lbl_tx = ttk.Label(stats_frame, text="Transmitted: 0", font=("Arial", 11))
        self.lbl_tx.pack(anchor=tk.W, pady=2, padx=10)
        self.lbl_latency = ttk.Label(stats_frame, text="Avg Latency: 0 cycles", font=("Arial", 11))
        self.lbl_latency.pack(anchor=tk.W, pady=2, padx=10)
        self.lbl_throughput = ttk.Label(stats_frame, text="Throughput: 0", font=("Arial", 11))
        self.lbl_throughput.pack(anchor=tk.W, pady=2, padx=10)

        # --- Bottom Layout: Matplotlib Graphs ---
        plot_frame = ttk.LabelFrame(self.root, text="Performance Graphs", padding=5)
        plot_frame.pack(fill=tk.BOTH, expand=True, padx=10, pady=5)
        self.plots = PerformancePlots(plot_frame)

    def log_message(self, msg):
        self.log_text.config(state='normal')
        self.log_text.insert(tk.END, msg + "\n")
        self.log_text.see(tk.END)
        self.log_text.config(state='disabled')

    def toggle_connection(self):
        if self.receiver and self.receiver.is_running:
            self.receiver.disconnect()
            self.btn_connect.config(text="Connect")
            self.lbl_status.config(text="DISCONNECTED", foreground="red")
            self.log_message("Disconnected.")
            self.q_model.clear_all()
        else:
            port = self.port_entry.get()
            self.receiver = SerialReceiver(
                port=port,
                baud_rate=115200,
                event_callback=self.handle_event,
                status_callback=self.handle_status,
                error_callback=self.handle_error
            )
            if self.receiver.connect():
                self.btn_connect.config(text="Disconnect")
                self.lbl_status.config(text="CONNECTED", foreground="green")
                self.log_message(f"Listening on {port}...")

    # --- Callbacks triggered by the SerialReceiver thread ---
    def handle_event(self, event_data):
        # Route to main GUI thread safely
        self.root.after(0, self._update_event_ui, event_data)

    def handle_status(self, status_data):
        self.root.after(0, self._update_status_ui, status_data)

    def handle_error(self, err_msg):
        self.root.after(0, self.log_message, f"ERROR: {err_msg}")

    # --- UI Update Logic (Runs in main thread) ---
    def _update_event_ui(self, event_data):
        # 1. Update Log
        log_str = f"{time.strftime('%H:%M:%S')} | {event_data['type']:11} Q{event_data['queue_id']} [{event_data['packet_hex']}]"
        self.log_message(log_str)
        
        # 2. Update Queue Visualizations[cite: 119]
        self.q_model.process_event(event_data)
        for i in range(4):
            self.q_listboxes[i].delete(0, tk.END)
            for pkt in self.q_model.get_queue_contents(i):
                self.q_listboxes[i].insert(tk.END, f"[{pkt}]")

    def _update_status_ui(self, data):
        self.lbl_mode.config(text=f"Mode: {data['mode_str']}")
        self.lbl_gen.config(text=f"Generated: {data['gen_count']}")
        self.lbl_tx.config(text=f"Transmitted: {data['tx_count']}")
        self.lbl_latency.config(text=f"Avg Latency: {data['latency']} cycles")
        self.lbl_throughput.config(text=f"Throughput: {data['throughput']}")
        
        # 3. Update the Matplotlib Graphs[cite: 120]
        self.plots.update_plots(data['tx_count'], data['latency'])

if __name__ == "__main__":
    root = tk.Tk()
    app = MainApp(root)
    root.mainloop()