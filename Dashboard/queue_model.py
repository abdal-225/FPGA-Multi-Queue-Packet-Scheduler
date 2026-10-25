# queue_model.py
# Reconstructs and synchronizes the queue states[cite: 120]

class QueueModel:
    def __init__(self):
        # Four queues representing Q0, Q1, Q2, Q3
        self.queues = {0: [], 1: [], 2: [], 3: []}

    def process_event(self, event_dict):
        """Updates the software queue model based on hardware events."""
        q_id = event_dict["queue_id"]
        packet = event_dict["packet_hex"]
        event_type = event_dict["type"]

        if q_id not in self.queues:
            return

        if event_type == "ENQUEUED":
            # Add the packet to the corresponding software queue[cite: 120]
            self.queues[q_id].append(packet)
            
        elif event_type == "TRANSMITTED":
            # Remove the matching packet from the software queue[cite: 120]
            # Uses FIFO order to distinguish successive occurrences[cite: 119]
            if packet in self.queues[q_id]:
                self.queues[q_id].remove(packet)
            elif self.queues[q_id]:
                # Fallback: remove oldest if exact packet data mismatch
                self.queues[q_id].pop(0)

    def get_queue_contents(self, q_id):
        """Returns the list of packets currently in the queue."""
        return self.queues.get(q_id, [])
        
    def clear_all(self):
        self.queues = {0: [], 1: [], 2: [], 3: []}