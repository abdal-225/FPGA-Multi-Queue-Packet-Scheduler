# protocol.py
# Parses the 7-byte Event frames and 33-byte Status frames[cite: 114, 118]

def validate_checksum(payload, received_checksum):
    """Calculates modulo 256 checksum for the payload."""
    # Payload includes the 0xAA 0x55 sync bytes
    calc_cs = (0xAA + 0x55 + sum(payload)) % 256
    return calc_cs == received_checksum

def parse_event_frame(payload):
    """Decodes a 7-byte Event Frame into a dictionary."""
    event_type = payload[0]
    queue_id = payload[1]
    # Little-endian packet data reconstruction
    packet_data = (payload[3] << 8) | payload[2] 
    
    event_names = {1: "GENERATED", 2: "ENQUEUED", 3: "TRANSMITTED"}
    
    return {
        "type": event_names.get(event_type, "UNKNOWN"),
        "queue_id": queue_id,
        "packet_hex": f"{packet_data:04X}"
    }

def parse_status_frame(payload):
    """Decodes a 33-byte Status Frame into a dictionary."""
    mode_names = {0: "PRIORITY", 1: "ROUND-ROBIN", 2: "WEIGHTED RR"}
    
    empty_flags = payload[4]
    full_flags = payload[5]
    
    occupancies = [payload[6], payload[7], payload[8], payload[9]]
    
    # 32-bit little-endian decoding
    gen_count = int.from_bytes(payload[10:14], byteorder='little')
    tx_count = int.from_bytes(payload[14:18], byteorder='little')
    latency = int.from_bytes(payload[22:26], byteorder='little')
    throughput = int.from_bytes(payload[26:30], byteorder='little')
    
    return {
        "mode_str": mode_names.get(payload[1], "UNKNOWN"),
        "empty_flags": empty_flags,
        "full_flags": full_flags,
        "occupancies": occupancies,
        "gen_count": gen_count,
        "tx_count": tx_count,
        "latency": latency,
        "throughput": throughput
    }