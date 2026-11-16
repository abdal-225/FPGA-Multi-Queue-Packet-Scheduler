"""Background UART reader. Tkinter is never touched from this thread."""
import threading
import time
import queue

try:
    import serial
    from serial.tools import list_ports
except ImportError:
    serial = None
    list_ports = None

from protocol import FrameParser


class SerialReceiver:
    def __init__(self, output_queue):
        self.output_queue = output_queue
        self.serial_port = None
        self.thread = None
        self.stop_event = threading.Event()
        self.parser = FrameParser()

    @staticmethod
    def available_ports():
        if list_ports is None:
            return []
        return [p.device for p in list_ports.comports()]

    def connect(self, port, baudrate=115200):
        if serial is None:
            raise RuntimeError("pyserial is not installed. Run: python -m pip install pyserial")
        self.disconnect()
        self.parser = FrameParser()
        self.serial_port = serial.Serial(
            port=port,
            baudrate=baudrate,
            bytesize=serial.EIGHTBITS,
            parity=serial.PARITY_NONE,
            stopbits=serial.STOPBITS_ONE,
            timeout=0.1,
        )
        self.stop_event.clear()
        self.thread = threading.Thread(target=self._reader, daemon=True)
        self.thread.start()

    def _reader(self):
        while not self.stop_event.is_set():
            try:
                if self.serial_port and self.serial_port.is_open:
                    data = self.serial_port.read(256)
                    if data:
                        for item in self.parser.feed(data):
                            self.output_queue.put(item)
                else:
                    time.sleep(0.1)
            except Exception as exc:
                self.output_queue.put({"kind": "error", "message": str(exc)})
                break

    def disconnect(self):
        self.stop_event.set()
        if self.serial_port:
            try:
                self.serial_port.close()
            except Exception:
                pass
            self.serial_port = None
        if self.thread and self.thread.is_alive():
            self.thread.join(timeout=0.5)
        self.thread = None

    @property
    def connected(self):
        return bool(self.serial_port and self.serial_port.is_open)
