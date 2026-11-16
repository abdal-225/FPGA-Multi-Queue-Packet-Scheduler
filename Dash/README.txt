FPGA MULTI-QUEUE PACKET SCHEDULER - PYTHON DASHBOARD
===================================================

FILES
-----
main.py             Tkinter desktop dashboard
serial_receiver.py  Background USB-UART reader
protocol.py         Parser for the FPGA's 7-byte and 33-byte frames
queue_model.py      Four-queue packet state model
requirements.txt    Python dependency

INSTALL
-------
1. Install Python 3.10 or newer.
2. Open Command Prompt in this folder.
3. Run:
       python -m pip install -r requirements.txt
4. Run:
       python main.py
5. Select the FPGA USB-UART COM port and click Connect.

UART SETTINGS
-------------
115200 baud, 8 data bits, no parity, 1 stop bit (8-N-1).

IMPORTANT RTL CORRECTION: EVENT QUEUE BYTE
------------------------------------------
Your current uart_telemetry.v event frame has:

    3: frame_byte = active_event_data[23:16];

But active_event_data is constructed as:

    {8'h01, 6'b000000, queue[1:0], packet[15:0]}

The queue number is in active_event_data[17:16], not [23:16].
Correct event byte index 3 in STATE_SEND_EVENT to:

    3: frame_byte = {6'b000000, active_event_data[17:16]};

Keep the event packet bytes as:
    4: frame_byte = active_event_data[7:0];
    5: frame_byte = active_event_data[15:8];

This correction is required for Python to identify the correct queue.

IMPORTANT CDC NOTE
------------------
Your top_scheduler currently sends multi-bit status/counter signals directly
from slow_clk logic into the 100 MHz UART domain. That can cause inconsistent
status snapshots. Before relying on hardware results, transfer a coherent
status snapshot using a bundled-data request/acknowledge CDC handshake (or
another properly designed CDC mechanism). The three event toggle paths are
separate from this multi-bit status issue.

THROUGHPUT LABEL
----------------
The current dashboard displays the FPGA's throughput_count as "Throughput
count" in the code label. If your throughput_counter outputs a raw number of
packets in a measurement window rather than packets/second, keep that unit.
Do not call it packets/s unless the RTL actually calculates that rate.

QUEUE CONTENTS LIMITATION
-------------------------
On a fresh connection, the FPGA sends occupancy but not the identities of
packets already inside the queues. The dashboard therefore displays ???? for
unknown packets until it observes enqueue/transmit events. It can accurately
show packet identities for events observed after connection.

STATUS FRAME PARSING
--------------------
The status occupancy is parsed as four 5-bit values from bytes 8..11.
Counters are little-endian. Checksum is the 8-bit sum of bytes 2..31.
Event checksum is the 8-bit sum of bytes 2..5.

DEMO CHECKLIST
--------------
1. Program the FPGA bitstream.
2. Connect the board's USB-UART interface to the laptop.
3. Find the correct COM port in Device Manager if needed.
4. Close other serial-terminal applications using that COM port.
5. Start the Python dashboard and connect at 115200 baud.
6. Press reset, then start traffic.
7. Change SW[1:0] between Priority (00), RR (01), and WRR (10).
8. Check incoming/outgoing packets, occupancy, selected queue and metrics.

This is a fresh implementation and does not depend on your previous dashboard
Python source files.
