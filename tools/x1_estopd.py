"""Emergency stop over the network for the 3DWOX 1X bring-up.

Runs next to Klipper (same user, inside the Debian root). Any TCP
connection to its port makes it send Klipper an emergency stop: motors
stop, heaters go off, Klipper shuts down. It can do nothing else.

    python3 x1_estopd.py /home/klipper/printer_data/comms/klippy.sock [PORT]

From the PC:  curl -m 3 http://PRINTER:7126/
Why: on 2026-11-21 the owner said "stop" during a jam and the only way
in, the serial console, was busy with a command of ours.
"""
import json, socket, sys, time

SOCK = sys.argv[1]
PORT = int(sys.argv[2]) if len(sys.argv) > 2 else 7126


def estop():
    k = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    k.settimeout(2)
    k.connect(SOCK)
    k.sendall(json.dumps({'id': 1, 'method': 'emergency_stop'}).encode() + b'\x03')
    try:
        k.recv(4096)
    except socket.timeout:
        pass
    k.close()


srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
srv.bind(('0.0.0.0', PORT))
srv.listen(4)
while True:
    c, addr = srv.accept()
    t = time.strftime('%H:%M:%S')
    try:
        estop()
        msg = 'emergency stop sent %s\n' % t
    except Exception as e:
        msg = 'FAILED to reach Klipper: %s\n' % (e,)
    print(addr[0], msg.strip(), flush=True)
    try:
        c.settimeout(1)
        c.sendall(('HTTP/1.0 200 OK\r\nContent-Type: text/plain\r\nContent-Length: %d\r\n\r\n%s'
                   % (len(msg), msg)).encode())
    except Exception:
        pass
    c.close()
