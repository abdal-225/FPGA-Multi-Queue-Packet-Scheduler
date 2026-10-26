# serial_receiver.py
# Handles background serial reading and passes decoded data to the GUI[cite: 117]

import serial
import threading
import time
import protocol

class SerialReceiver:
    def __init__(self, port, baud_rate, event_callback, status_callback, error_callback):
        self.port = port
        self.baud_rate = baud_rate
        self.event_callback = event_callback
        self.status_callback = status_callback
        self.error_callback = error_callback
        
        self.serial_conn = None
        self.is_running = False
        self.thread = None

    def connect(self):
        try:
            self.serial_conn = serial.Serial(self.port, self.baud_rate, timeout=1)
            self.is_running = True
            # Run the serial listener in a background daemon thread[cite: 117]
            self.thread = threading.Thread(target=self._read_loop, daemon=True)
            self.thread.start()
            return True
        except Exception as e:
            self.error_callback(f"Connection failed: {e}")
            return False

    def disconnect(self):
        self.is_running = False
        if self.serial_conn and self.serial_conn.is_open:
            self.serial_conn.close()

    def _read_loop(self):
        """Continuously reads bytes and identifies valid frames.[cite: 117]"""
        while self.is_running and self.serial_conn.is_open:
            try:
                # 1. Sync Sequence Detection
                if self.serial_conn.read(1) == b'\xAA':
                    if self.serial_conn.read(1) == b'\x55':
                        
                        frame_id_byte = self.serial_conn.read(1)
                        if not frame_id_byte: continue
                        frame_id = frame_id_byte[0]
                        
                        # 2. Parse ENQUEUED (0x02) and TRANSMITTED (0x03)
                        if frame_id in [0x02, 0x03]:
                            payload = frame_id_byte + self.serial_conn.read(3)
                            checksum = self.serial_conn.read(1)[0]
                            if protocol.validate_checksum(payload, checksum):
                                event_data = protocol.parse_event_frame(payload)
                                self.event_callback(event_data)
                                
                        # 3. Handle Ambiguous 0x01 (GENERATED vs STATUS)
                        elif frame_id == 0x01:
                            payload = frame_id_byte + self.serial_conn.read(3)
                            checksum_or_data = self.serial_conn.read(1)[0]
                            
                            if protocol.validate_checksum(payload, checksum_or_data):
                                event_data = protocol.parse_event_frame(payload)
                                self.event_callback(event_data)
                            else:
                                rest = self.serial_conn.read(26)
                                full_payload = payload + bytes([checksum_or_data]) + rest[:-1]
                                if protocol.validate_checksum(full_payload, rest[-1]):
                                    status_data = protocol.parse_status_frame(full_payload)
                                    self.status_callback(status_data)
            except Exception as e:
                if self.is_running:
                    self.error_callback(f"Serial error: {e}")
                time.sleep(1)