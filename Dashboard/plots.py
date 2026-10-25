# plots.py
# Matplotlib integration for performance graphs[cite: 116, 120]

import matplotlib.pyplot as plt
from matplotlib.backends.backend_tkagg import FigureCanvasTkAgg

class PerformancePlots:
    def __init__(self, parent_frame):
        # Create a matplotlib figure with 2 subplots
        self.fig, (self.ax_tx, self.ax_lat) = plt.subplots(2, 1, figsize=(6, 4))
        self.fig.tight_layout(pad=3.0)
        
        # Embed the plot in the Tkinter GUI
        self.canvas = FigureCanvasTkAgg(self.fig, master=parent_frame)
        self.canvas.get_tk_widget().pack(fill='both', expand=True)
        
        self.time_data = []
        self.tx_data = []
        self.latency_data = []
        self.start_time = None

    def update_plots(self, tx_count, latency):
        import time
        if self.start_time is None:
            self.start_time = time.time()
            
        current_time = time.time() - self.start_time
        
        self.time_data.append(current_time)
        self.tx_data.append(tx_count)
        self.latency_data.append(latency)
        
        # Keep only the last 50 data points to avoid lag
        if len(self.time_data) > 50:
            self.time_data.pop(0)
            self.tx_data.pop(0)
            self.latency_data.pop(0)

        # Update TX Plot
        self.ax_tx.clear()
        self.ax_tx.set_title("Cumulative Transmitted Packets")
        self.ax_tx.plot(self.time_data, self.tx_data, color='green')
        
        # Update Latency Plot
        self.ax_lat.clear()
        self.ax_lat.set_title("Average Latency (Cycles)")
        self.ax_lat.plot(self.time_data, self.latency_data, color='orange')
        
        self.canvas.draw()