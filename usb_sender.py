#!/usr/bin/env python3
"""
USB CDC Configuration File Sender for ESP32-S3 Battery Tester

This script sends configuration files to the ESP32-S3 battery tester
via USB CDC (Virtual COM Port). It implements the reverse protocol from
usb_receiver.py - handshake initiated by PC, file selection, and transfer.

Usage:
    python usb_sender.py [--port PORT] [--config-dir DIR]

Example:
    python usb_sender.py --port /dev/ttyACM0 --config-dir ./send_settings
"""

import serial
import struct
import sys
import argparse
import time
import os
from pathlib import Path
from datetime import datetime

# Protocol Constants (matching ESP32 firmware)
USB_PROTO_MAGIC = 0xAA55
USB_PROTO_CMD_HANDSHAKE = 0x01
USB_PROTO_CMD_FILE_LIST = 0x02
USB_PROTO_CMD_FILE_DATA = 0x03
USB_PROTO_CMD_FILE_END = 0x04
USB_PROTO_CMD_ACK = 0x05
USB_PROTO_CMD_NACK = 0x06
USB_PROTO_CMD_CONFIG_REQ = 0x07  # PC requests to send config

USB_CHUNK_SIZE = 512
USB_TIMEOUT = 30.0  # seconds

class USBSender:
    def __init__(self, port, config_dir, baudrate=115200):
        """Initialize USB sender.
        
        Args:
            port: Serial port name (e.g., /dev/ttyACM0 or COM3)
            config_dir: Directory containing config files to send
            baudrate: Serial baudrate (default 115200)
        """
        self.port = port
        self.config_dir = Path(config_dir)
        self.baudrate = baudrate
        self.ser = None
        
        print(f"USB Sender initialized")
        print(f"  Port: {port}")
        print(f"  Config directory: {self.config_dir.absolute()}")
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
            time.sleep(0.5)  # Give device time to stabilize
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
        packet = struct.pack('<HBH', USB_PROTO_MAGIC, USB_PROTO_CMD_ACK, 0)
        checksum = self.calculate_checksum(packet[6:])  # Checksum of empty data
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
                return None
            
            magic, command, length, checksum = struct.unpack('<HBHB', header)
            
            if magic != USB_PROTO_MAGIC:
                print(f"✗ Invalid magic: 0x{magic:04X}")
                return None
            
            return (magic, command, length, checksum)
        except Exception as e:
            print(f"✗ Error reading header: {e}")
            return None
    
    def wait_for_handshake(self, timeout=30.0):
        """Wait for handshake from device after it enters receive mode.
        
        Returns:
            bool: True if handshake received
        """
        start_time = time.time()
        
        while time.time() - start_time < timeout:
            if self.ser.in_waiting > 0:
                header = self.read_packet_header()
                if header is None:
                    continue
                
                magic, command, length, header_checksum = header
                
                if command == USB_PROTO_CMD_HANDSHAKE:
                    # Read handshake data
                    data = self.ser.read(length)
                    if len(data) != length:
                        continue
                    
                    # Verify checksum
                    calc_checksum = self.calculate_checksum(data)
                    if calc_checksum != header_checksum:
                        self.send_nack()
                        continue
                    
                    version, timestamp = struct.unpack('<BI', data)
                    print(f"✓ Device ready (version: {version}, timestamp: {timestamp})")
                    
                    # Send ACK
                    self.send_ack()
                    return True
            
            time.sleep(0.1)
        
        print(f"\n✗ Timeout after {timeout}s - Device did not respond")
        print("   Make sure you pressed 'Receive Config' button on device!")
        return False
    
    def get_config_files(self):
        """Get list of available config files.
        
        Returns:
            list: List of (filename, filepath) tuples
        """
        config_files = []
        
        # Look for setting_X.csv files
        for i in range(1, 5):
            filename = f"setting_{i}.csv"
            filepath = self.config_dir / filename
            if filepath.exists():
                config_files.append((filename, filepath))
        
        return config_files
    
    def select_config_file(self, config_files):
        """Let user select which config file to send.
        
        Args:
            config_files: List of (filename, filepath) tuples
            
        Returns:
            tuple: (filename, filepath) or None if cancelled
        """
        print("\n" + "="*60)
        print("AVAILABLE CONFIGURATION FILES")
        print("="*60)
        
        for i, (filename, filepath) in enumerate(config_files, 1):
            size = filepath.stat().st_size
            print(f"  [{i}] {filename} ({size} bytes)")
        
        print(f"  [0] Cancel")
        print("="*60)
        
        while True:
            try:
                choice = input("\nSelect file to send (0-4): ").strip()
                choice_num = int(choice)
                
                if choice_num == 0:
                    print("✗ Transfer cancelled by user")
                    return None
                
                if 1 <= choice_num <= len(config_files):
                    selected = config_files[choice_num - 1]
                    print(f"✓ Selected: {selected[0]}")
                    return selected
                else:
                    print(f"Invalid choice. Please enter 0-{len(config_files)}")
            except ValueError:
                print("Invalid input. Please enter a number.")
            except KeyboardInterrupt:
                print("\n✗ Cancelled by user")
                return None
    
    def send_file_info(self, filename, filesize, file_index):
        """Send file info packet to device.
        
        Args:
            filename: Name of file
            filesize: Size of file in bytes
            file_index: Index (1-4 for setting_1 to setting_4)
            
        Returns:
            bool: True if ACK received
        """
        print(f"\n📤 Sending file info...")
        print(f"   Filename: {filename}")
        print(f"   Size: {filesize} bytes")
        print(f"   Index: {file_index}")
        
        # Build packet: magic(2) + command(1) + length(2) + checksum(1) + file_index(1) + file_size(4) + filename(64)
        filename_bytes = filename.encode('utf-8')[:64].ljust(64, b'\x00')
        data = struct.pack('<BI', file_index, filesize) + filename_bytes
        
        packet = struct.pack('<HBH', USB_PROTO_MAGIC, USB_PROTO_CMD_FILE_DATA, len(data))
        checksum = self.calculate_checksum(data)
        packet += struct.pack('B', checksum) + data
        
        self.ser.write(packet)
        self.ser.flush()
        
        # Wait for ACK
        return self.wait_for_ack(5.0)
    
    def send_file_chunks(self, filepath, filesize):
        """Send file data in chunks.
        
        Args:
            filepath: Path to file
            filesize: Size of file
            
        Returns:
            bool: True if all chunks sent successfully
        """
        print(f"\n📦 Sending file chunks...")
        
        chunk_number = 0
        total_sent = 0
        
        with open(filepath, 'rb') as f:
            while total_sent < filesize:
                # Read chunk
                chunk_data = f.read(USB_CHUNK_SIZE)
                if not chunk_data:
                    break
                
                chunk_size = len(chunk_data)
                
                # Build packet: magic(2) + command(1) + length(2) + checksum(1) + chunk_number(2) + chunk_size(2) + data[512]
                chunk_header = struct.pack('<HH', chunk_number, chunk_size)
                data = chunk_header + chunk_data
                
                packet = struct.pack('<HBH', USB_PROTO_MAGIC, USB_PROTO_CMD_FILE_DATA, len(data))
                checksum = self.calculate_checksum(data)
                packet += struct.pack('B', checksum) + data
                
                self.ser.write(packet)
                self.ser.flush()
                
                # Wait for ACK
                if not self.wait_for_ack(5.0):
                    print(f"✗ Failed to get ACK for chunk {chunk_number}")
                    return False
                
                total_sent += chunk_size
                chunk_number += 1
                
                # Progress
                progress = (total_sent / filesize) * 100
                print(f"   Progress: {progress:.1f}% ({total_sent}/{filesize} bytes, chunk {chunk_number})", end='\r')
        
        print()  # New line
        return True
    
    def wait_for_ack(self, timeout):
        """Wait for ACK packet.
        
        Returns:
            bool: True if ACK received
        """
        start_time = time.time()
        
        while time.time() - start_time < timeout:
            if self.ser.in_waiting >= 6:
                header = self.read_packet_header()
                if header is None:
                    continue
                
                magic, command, length, checksum = header
                
                if command == USB_PROTO_CMD_ACK:
                    # Read any remaining data
                    if length > 0:
                        self.ser.read(length)
                    return True
                elif command == USB_PROTO_CMD_NACK:
                    return False
            
            time.sleep(0.05)
        
        return False
    
    def send_config_file(self):
        """Main function to send config file.
        
        Returns:
            bool: True if successful
        """
        print("\n" + "="*60)
        print("USB CONFIGURATION FILE SENDER")
        print("="*60)
        
        # Get available config files (BEFORE connecting to device)
        config_files = self.get_config_files()
        
        if not config_files:
            print("\n✗ No configuration files found in:", self.config_dir)
            print("   Expected files: setting_1.csv, setting_2.csv, setting_3.csv, setting_4.csv")
            return False
        
        # User selects file (BEFORE connecting to device)
        selected = self.select_config_file(config_files)
        if selected is None:
            return False
        
        filename, filepath = selected
        
        # Extract file index (1-4) from filename
        file_index = int(filename.split('_')[1].split('.')[0])
        filesize = filepath.stat().st_size
        
        print(f"\n📋 Selected: {filename} ({filesize} bytes)")
        print("="*60)
        print("⏳ Connecting to device...")
        print("   Press 'Receive Config' button on device if not already pressed")
        print("="*60)
        
        # Connect to device (this triggers the connection)
        if not self.connect():
            print("✗ Failed to connect to device")
            return False
        
        # Small delay for USB to stabilize
        time.sleep(0.5)
        
        # Send file info immediately
        if not self.send_file_info(filename, filesize, file_index):
            print("✗ Device did not acknowledge file info")
            return False
        
        # Send file chunks
        if not self.send_file_chunks(filepath, filesize):
            print("✗ Failed to send file chunks")
            return False
        
        print("\n" + "="*60)
        print(f"✓ TRANSFER COMPLETE: {filename} sent successfully!")
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
        description='USB CDC Configuration File Sender for ESP32-S3 Battery Tester',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Send config from default directory
  python usb_sender.py --port /dev/ttyACM0
  
  # Send config from specific directory
  python usb_sender.py --port COM3 --config-dir ./send_settings
  
  # List available serial ports
  python usb_sender.py --list-ports
        """
    )
    
    parser.add_argument('--port', '-p', default='/dev/ttyACM0',
                        help='Serial port (default: /dev/ttyACM0, or COM3 on Windows)')
    parser.add_argument('--config-dir', '-c', default='./send_settings',
                        help='Directory containing config files (default: ./send_settings)')
    parser.add_argument('--baudrate', '-b', type=int, default=115200,
                        help='Serial baudrate (default: 115200)')
    parser.add_argument('--list-ports', '-l', action='store_true',
                        help='List available serial ports and exit')
    
    args = parser.parse_args()
    
    if args.list_ports:
        list_serial_ports()
        return 0
    
    # Create sender (DON'T connect yet - will connect after file selection)
    sender = USBSender(args.port, args.config_dir, args.baudrate)
    
    try:
        # Send config file (this will connect at the right time)
        success = sender.send_config_file()
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
        sender.disconnect()

if __name__ == '__main__':
    sys.exit(main())
