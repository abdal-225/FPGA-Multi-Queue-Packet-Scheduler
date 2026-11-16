"""UART frame parser for the FPGA Multi-Queue Packet Scheduler.

Event frame (7 bytes):
AA 55 TYPE QUEUE PACKET_LO PACKET_HI CHECKSUM
TYPE: 01 generated, 02 enqueued, 03 transmitted
Checksum: 8-bit sum of bytes 2..5.

Status frame (33 bytes):
AA 55 01 MODE SELECTED_QUEUE SELECT_VALID EMPTY FULL
OCC_Q0 OCC_Q1 OCC_Q2 OCC_Q3
GENERATED_COUNT[4] TRANSMITTED_COUNT[4] CYCLE_COUNT[4]
AVERAGE_LATENCY[4] THROUGHPUT_COUNT[4] CHECKSUM
Multi-byte counters are little-endian. Status checksum is the 8-bit
sum of bytes 2..31.
"""

HEADER = b"\xAA\x55"
EVENT_LENGTH = 7
STATUS_LENGTH = 33


def _checksum(data):
    return sum(data) & 0xFF


class FrameParser:
    def __init__(self):
        self.buffer = bytearray()
        self.bad_frames = 0
        self.frames_received = 0

    @staticmethod
    def _u32_le(data):
        return int.from_bytes(data, byteorder="little", signed=False)

    def feed(self, data):
        """Feed arbitrary serial bytes; return a list of decoded dictionaries."""
        self.buffer.extend(data)
        decoded = []

        while True:
            start = self.buffer.find(HEADER)
            if start < 0:
                # Preserve a possible first header byte split across reads.
                self.buffer[:] = self.buffer[-1:] if self.buffer.endswith(b"\xAA") else b""
                break

            if start:
                del self.buffer[:start]

            if len(self.buffer) < 3:
                break

            frame_type = self.buffer[2]

            # Event types use 0x81/0x82/0x83, while status uses 0x01.
            # This avoids ambiguity between a 7-byte generated event and
            # the 33-byte status frame.
            if frame_type in (0x81, 0x82, 0x83):
                frame_len = EVENT_LENGTH
                if len(self.buffer) < frame_len:
                    break
                frame = bytes(self.buffer[:frame_len])
                if _checksum(frame[2:6]) != frame[6]:
                    self.bad_frames += 1
                    del self.buffer[0]
                    continue
                decoded.append(self._decode_event(frame))
                del self.buffer[:frame_len]
                self.frames_received += 1
                continue

            if frame_type == 0x01:
                if len(self.buffer) < STATUS_LENGTH:
                    break
                frame = bytes(self.buffer[:STATUS_LENGTH])
                if _checksum(frame[2:32]) != frame[32]:
                    self.bad_frames += 1
                    del self.buffer[0]
                    continue
                decoded.append(self._decode_status(frame))
                del self.buffer[:STATUS_LENGTH]
                self.frames_received += 1
                continue

            # Unknown frame type or damaged header: advance one byte and resync.
            self.bad_frames += 1
            del self.buffer[0]

        return decoded

    def _decode_event(self, frame):
        # Current RTL places queue in bits [17:16] of the 32-bit event word,
        # but its frame byte 3 currently selects [23:16]. That byte therefore
        # contains queue in bits [1:0] only if the RTL is corrected as noted
        # in the accompanying README.
        event_type = frame[2]
        queue = frame[3] & 0x03
        packet = (frame[5] << 8) | frame[4]
        names = {0x81: "generated", 0x82: "enqueued", 0x83: "transmitted"}
        return {
            "kind": "event",
            "event": names.get(event_type, "unknown"),
            "event_type": event_type,
            "queue": queue,
            "packet": packet,
        }

    def _decode_status(self, frame):
        mode = frame[3] & 0x03
        selected_valid = bool(frame[5] & 0x01)
        selected_queue = frame[4] & 0x03 if selected_valid else None

        occupancy = [
            frame[8] & 0x1F,
            frame[9] & 0x1F,
            frame[10] & 0x1F,
            frame[11] & 0x1F,
        ]
        return {
            "kind": "status",
            "mode": mode,
            "selected_queue": selected_queue,
            "select_valid": selected_valid,
            "empty": frame[6] & 0x0F,
            "full": frame[7] & 0x0F,
            "occupancy": occupancy,
            "generated_count": self._u32_le(frame[12:16]),
            "transmitted_count": self._u32_le(frame[16:20]),
            "cycle_count": self._u32_le(frame[20:24]),
            "average_latency": self._u32_le(frame[24:28]),
            "throughput_count": self._u32_le(frame[28:32]),
        }
