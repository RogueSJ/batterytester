#!/usr/bin/env python3
"""
USB CDC File Receiver for ESP32-S3 Battery Tester

This script receives test result files from the ESP32-S3 battery tester
via USB CDC (Virtual COM Port). It implements the custom protocol with
handshake, file list, chunked transfer, and acknowledgments.

Usage:
    python usb_receiver.py [--port PORT] [--output-dir DIR]

Example:
    python usb_receiver.py --port /dev/ttyACM0 --output-dir ./test_results
"""

import serial
import struct
import sys
import argparse
import time
import os
from pathlib import Path
from datetime import datetime

# Protocol Constants
USB_PROTO_MAGIC = 0xAA55
USB_PROTO_CMD_HANDSHAKE = 0x01
USB_PROTO_CMD_FILE_LIST = 0x02
USB_PROTO_CMD_FILE_DATA = 0x03
USB_PROTO_CMD_FILE_END = 0x04
USB_PROTO_CMD_ACK = 0x05
USB_PROTO_CMD_NACK = 0x06

USB_CHUNK_SIZE = 512
USB_TIMEOUT = 30.0  # seconds - give user time to prepare

class USBReceiver:
    def __init__(self, port, output_dir, baudrate=115200):
        """Initialize USB receiver.
        
        Args:
            port: Serial port name (e.g., /dev/ttyACM0 or COM3)
            output_dir: Directory to save received files
            baudrate: Serial baudrate (default 115200)
        """
        self.port = port
        self.output_dir = Path(output_dir)
        self.baudrate = baudrate
        self.ser = None
        self.files_received = 0
        
        # Create output directory if it doesn't exist
        self.output_dir.mkdir(parents=True, exist_ok=True)
        
        print(f"USB Receiver initialized")
        print(f"  Port: {port}")
        print(f"  Output directory: {self.output_dir.absolute()}")
        print(f"  Baudrate: {baudrate}")
    
    def connect(self):
        """Open serial port connection."""
        try:
            self.ser = serial.Serial(
                port=self.port,
                baudrate=self.baudrate,
                timeout=USB_TIMEOUT,
                write_timeout=USB_TIMEOUT
            )
            print(f"✓ Connected to {self.port}")
            # Flush any existing data
            self.ser.reset_input_buffer()
            self.ser.reset_output_buffer()
            return True
        except serial.SerialException as e:
            print(f"✗ Failed to open port {self.port}: {e}")
            return False
    
    def disconnect(self):
        """Close serial port connection."""
        if self.ser and self.ser.is_open:
            self.ser.close()
            print("✓ Disconnected")
    
    def calculate_checksum(self, data):
        """Calculate XOR checksum of data.
        
        Args:
            data: bytes to checksum
            
        Returns:
            uint8 checksum value
        """
        checksum = 0
        for byte in data:
            checksum ^= byte
        return checksum & 0xFF
    
    def send_ack(self):
        """Send ACK packet to ESP32."""
        # Packet: magic(2) + command(1) + length(2) + checksum(1)
        packet = struct.pack('<HBH', USB_PROTO_MAGIC, USB_PROTO_CMD_ACK, 0)
        checksum = self.calculate_checksum(packet[6:])  # Checksum of data (empty)
        packet += struct.pack('B', checksum)
        
        self.ser.write(packet)
        self.ser.flush()
    
    def send_nack(self):
        """Send NACK packet to ESP32."""
        packet = struct.pack('<HBH', USB_PROTO_MAGIC, USB_PROTO_CMD_NACK, 0)
        checksum = self.calculate_checksum(packet[6:])
        packet += struct.pack('B', checksum)
        
        self.ser.write(packet)
        self.ser.flush()
    
    def read_packet_header(self):
        """Read packet header from serial port.
        
        Returns:
            tuple: (magic, command, length, checksum) or None if invalid
        """
        try:
            # Read header: magic(2) + command(1) + length(2) + checksum(1)
            header = self.ser.read(6)
            if len(header) != 6:
                print(f"✗ Incomplete header received (got {len(header)} bytes)")
                return None
            
            magic, command, length, checksum = struct.unpack('<HBHB', header)
            
            if magic != USB_PROTO_MAGIC:
                print(f"✗ Invalid magic number: 0x{magic:04X} (expected 0x{USB_PROTO_MAGIC:04X})")
                return None
            
            return (magic, command, length, checksum)
        except Exception as e:
            print(f"✗ Error reading header: {e}")
            return None
    
    def wait_for_handshake(self, timeout=30.0):
        """Wait for handshake packet from ESP32.
        
        Args:
            timeout: Timeout in seconds
            
        Returns:
            bool: True if handshake received successfully
        """
        print("\nWaiting for handshake from device...")
        start_time = time.time()
        
        while time.time() - start_time < timeout:
            # Check if data available
            if self.ser.in_waiting > 0:
                header = self.read_packet_header()
                if header is None:
                    continue
                
                magic, command, length, header_checksum = header
                
                if command == USB_PROTO_CMD_HANDSHAKE:
                    # Read handshake data: version(1) + timestamp(4)
                    data = self.ser.read(length)
                    if len(data) != length:
                        print(f"✗ Incomplete handshake data")
                        self.send_nack()
                        continue
                    
                    # Verify checksum
                    calc_checksum = self.calculate_checksum(data)
                    if calc_checksum != header_checksum:
                        print(f"✗ Checksum mismatch (got 0x{header_checksum:02X}, expected 0x{calc_checksum:02X})")
                        self.send_nack()
                        continue
                    
                    # Parse handshake data
                    version, timestamp = struct.unpack('<BI', data)
                    print(f"✓ Handshake received (version: {version}, timestamp: {timestamp})")
                    
                    # Send ACK
                    self.send_ack()
                    print("✓ Handshake ACK sent")
                    return True
            
            time.sleep(0.1)
        
        print(f"✗ Handshake timeout after {timeout}s")
        return False
    
    def receive_file_list(self):
        """Receive file list from ESP32.
        
        Returns:
            list: List of filenames to receive, or None on error
        """
        print("\nWaiting for file list...")
        
        header = self.read_packet_header()
        if header is None:
            return None
        
        magic, command, length, header_checksum = header
        
        if command != USB_PROTO_CMD_FILE_LIST:
            print(f"✗ Expected FILE_LIST command, got 0x{command:02X}")
            self.send_nack()
            return None
        
        # Read file list data: file_count(1) + filenames[8*64]
        data = self.ser.read(length)
        if len(data) != length:
            print(f"✗ Incomplete file list data")
            self.send_nack()
            return None
        
        # Verify checksum
        calc_checksum = self.calculate_checksum(data)
        if calc_checksum != header_checksum:
            print(f"✗ File list checksum mismatch")
            self.send_nack()
            return None
        
        # Parse file list
        file_count = data[0]
        print(f"✓ File list received: {file_count} files")
        
        filenames = []
        for i in range(file_count):
            offset = 1 + (i * 64)
            filename_bytes = data[offset:offset + 64]
            # Find null terminator
            null_pos = filename_bytes.find(b'\x00')
            if null_pos >= 0:
                filename = filename_bytes[:null_pos].decode('utf-8', errors='replace')
            else:
                filename = filename_bytes.decode('utf-8', errors='replace')
            
            # Extract just the basename (remove /data/ prefix)
            filename = os.path.basename(filename)
            filenames.append(filename)
            print(f"  [{i+1}] {filename}")
        
        # Send ACK
        self.send_ack()
        print("✓ File list ACK sent")
        return filenames
    
    def receive_file(self, expected_filename=None):
        """Receive a single file from ESP32.
        
        Args:
            expected_filename: Expected filename (optional, for verification)
            
        Returns:
            str: Saved filename or None on error
        """
        print(f"\nReceiving file...")
        
        # Read file info header
        header = self.read_packet_header()
        if header is None:
            return None
        
        magic, command, length, header_checksum = header
        
        if command != USB_PROTO_CMD_FILE_DATA:
            print(f"✗ Expected FILE_DATA command, got 0x{command:02X}")
            self.send_nack()
            return None
        
        # Read file info: file_index(1) + file_size(4) + filename(64)
        data = self.ser.read(length)
        if len(data) != length:
            print(f"✗ Incomplete file info data")
            self.send_nack()
            return None
        
        # Verify checksum
        calc_checksum = self.calculate_checksum(data)
        if calc_checksum != header_checksum:
            print(f"✗ File info checksum mismatch")
            self.send_nack()
            return None
        
        # Parse file info
        file_index, file_size = struct.unpack('<BI', data[:5])
        filename_bytes = data[5:69]
        null_pos = filename_bytes.find(b'\x00')
        if null_pos >= 0:
            filename = filename_bytes[:null_pos].decode('utf-8', errors='replace')
        else:
            filename = filename_bytes.decode('utf-8', errors='replace')
        
        filename = os.path.basename(filename)  # Remove path prefix
        
        print(f"  File index: {file_index}")
        print(f"  File size: {file_size} bytes")
        print(f"  Filename: {filename}")
        
        # Send ACK for file info
        self.send_ack()
        
        # Receive file chunks
        file_data = bytearray()
        chunk_number = 0
        expected_chunks = (file_size + USB_CHUNK_SIZE - 1) // USB_CHUNK_SIZE
        
        while len(file_data) < file_size:
            # Read chunk header
            header = self.read_packet_header()
            if header is None:
                print(f"✗ Failed to read chunk {chunk_number} header")
                self.send_nack()
                return None
            
            magic, command, length, header_checksum = header
            
            # File transfer complete when we've received all bytes
            if len(file_data) >= file_size:
                break
            
            if command != USB_PROTO_CMD_FILE_DATA:
                print(f"✗ Expected FILE_DATA, got 0x{command:02X}")
                self.send_nack()
                return None
            
            # Read chunk data: chunk_number(2) + chunk_size(2) + data[512]
            data = self.ser.read(length)
            if len(data) != length:
                print(f"✗ Incomplete chunk data")
                self.send_nack()
                return None
            
            # Verify checksum
            calc_checksum = self.calculate_checksum(data)
            if calc_checksum != header_checksum:
                print(f"✗ Chunk {chunk_number} checksum mismatch")
                self.send_nack()
                return None
            
            # Parse chunk
            recv_chunk_num, chunk_size = struct.unpack('<HH', data[:4])
            chunk_data = data[4:4 + chunk_size]
            
            if recv_chunk_num != chunk_number:
                print(f"✗ Chunk number mismatch (expected {chunk_number}, got {recv_chunk_num})")
                self.send_nack()
                return None
            
            # Append chunk data
            file_data.extend(chunk_data)
            chunk_number += 1
            
            # Send ACK for chunk
            self.send_ack()
            
            # Progress indicator
            progress = (len(file_data) / file_size) * 100
            print(f"  Progress: {progress:.1f}% ({len(file_data)}/{file_size} bytes, chunk {chunk_number}/{expected_chunks})", end='\r')
        
        print()  # New line after progress
        
        # Save file
        output_path = self.output_dir / filename
        try:
            with open(output_path, 'wb') as f:
                f.write(file_data)
            print(f"✓ File saved: {output_path}")
            self.files_received += 1
            return filename
        except Exception as e:
            print(f"✗ Failed to save file: {e}")
            return None
    
    def receive_all_files(self):
        """Receive all files from ESP32.
        
        Returns:
            bool: True if all files received successfully
        """
        print("\n" + "="*60)
        print("USB FILE TRANSFER SESSION")
        print("="*60)
        
        # Wait for handshake
        if not self.wait_for_handshake():
            return False
        
        # Receive file list
        filenames = self.receive_file_list()
        if filenames is None or len(filenames) == 0:
            print("✗ No files to receive")
            return False
        
        # Receive each file
        print(f"\nReceiving {len(filenames)} files...")
        for i, expected_filename in enumerate(filenames):
            print(f"\n--- File {i+1}/{len(filenames)} ---")
            received_filename = self.receive_file(expected_filename)
            if received_filename is None:
                print(f"✗ Failed to receive file {i+1}")
                return False
        
        print("\n" + "="*60)
        print(f"✓ TRANSFER COMPLETE: {self.files_received} files received")
        print("="*60)
        return True

def list_serial_ports():
    """List available serial ports."""
    try:
        from serial.tools import list_ports
        ports = list_ports.comports()
        if ports:
            print("\nAvailable serial ports:")
            for port in ports:
                print(f"  {port.device}: {port.description}")
        else:
            print("\nNo serial ports found")
    except ImportError:
        print("Install pyserial to list ports: pip install pyserial")

def main():
    parser = argparse.ArgumentParser(
        description='USB CDC File Receiver for ESP32-S3 Battery Tester',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Receive files to current directory
  python usb_receiver.py --port /dev/ttyACM0
  
  # Receive files to specific directory
  python usb_receiver.py --port COM3 --output-dir ./test_results
  
  # List available serial ports
  python usb_receiver.py --list-ports
        """
    )
    
    parser.add_argument('--port', '-p', default='/dev/ttyACM0',
                        help='Serial port (default: /dev/ttyACM0, or COM3 on Windows)')
    parser.add_argument('--output-dir', '-o', default='./received_files',
                        help='Output directory for received files (default: ./received_files)')
    parser.add_argument('--baudrate', '-b', type=int, default=115200,
                        help='Serial baudrate (default: 115200)')
    parser.add_argument('--list-ports', '-l', action='store_true',
                        help='List available serial ports and exit')
    
    args = parser.parse_args()
    
    if args.list_ports:
        list_serial_ports()
        return 0
    
    # Create receiver (port now has default value)
    receiver = USBReceiver(args.port, args.output_dir, args.baudrate)
    
    # Connect to device
    if not receiver.connect():
        return 1
    
    try:
        # Receive files
        success = receiver.receive_all_files()
        return 0 if success else 1
    except KeyboardInterrupt:
        print("\n\n✗ Transfer interrupted by user")
        return 1
    except Exception as e:
        print(f"\n✗ Error during transfer: {e}")
        import traceback
        traceback.print_exc()
        return 1
    finally:
        receiver.disconnect()

if __name__ == '__main__':
    sys.exit(main())
