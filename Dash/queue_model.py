
from collections import deque


class QueueModel:

    def __init__(self, depth=16):
        self.depth = depth

        self.queues = [deque() for _ in range(4)]
        self.occupancy = [0] * 4

        self.incoming = ["—"] * 4
        self.outgoing = ["—"] * 4

        self.empty_flags = 0x0F
        self.full_flags = 0

    @staticmethod
    def packet_text(packet):
        return f"{packet:04X}"

    def apply_event(self, item):

        q = item["queue"]

        if not 0 <= q < 4:
            return

        packet = self.packet_text(item["packet"])
        event = item["event"]

        if event == "generated":
            return

        elif event == "enqueued":

            self.incoming[q] = packet

            # Add packet to the corresponding FIFO model.
            if len(self.queues[q]) >= self.depth:
                self.queues[q].popleft()

            self.queues[q].append(packet)
            self.occupancy[q] = len(self.queues[q])

        elif event == "transmitted":

            self.outgoing[q] = packet

            # Remove the transmitted packet.
            if self.queues[q]:

                if self.queues[q][0] == packet:
                    self.queues[q].popleft()

                elif packet in self.queues[q]:
                    self.queues[q].remove(packet)

                else:
                    self.queues[q].popleft()

            self.occupancy[q] = len(self.queues[q])

    def apply_status(self, item):

        self.occupancy = list(item["occupancy"])

        self.empty_flags = item["empty"]
        self.full_flags = item["full"]

        # Maintain queue identities where possible.
        # Unknown packets are shown as ???? when the dashboard
        # connects after packets have already entered the FPGA.

        for q in range(4):

            while len(self.queues[q]) > self.occupancy[q]:
                self.queues[q].popleft()

            while len(self.queues[q]) < self.occupancy[q]:
                self.queues[q].append("????")

    def get_queue_contents(self, q):

        return list(self.queues[q])
