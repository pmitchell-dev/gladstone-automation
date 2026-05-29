import socket
import select
import sys

def main():
    # Setup UDP Socket
    u = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    u.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    u.bind(('0.0.0.0', 514))

    # Setup TCP Socket
    t = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    t.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    t.bind(('0.0.0.0', 514))
    t.listen(5)

    print('📡 [NVR Syslog] Listening directly on Host UDP and TCP 514...', flush=True)

    while True:
        try:
            r, _, _ = select.select([u, t], [], [])
            for s in r:
                if s is u:
                    d, a = u.recvfrom(65535)
                    msg = d.decode("utf-8", "replace").strip()
                    print(f'[UDP {a[0]}] {msg}', flush=True)
                elif s is t:
                    c, a = t.accept()
                    try:
                        d = c.recv(65535)
                        if d:
                            msg = d.decode("utf-8", "replace").strip()
                            print(f'[TCP {a[0]}] {msg}', flush=True)
                        else:
                            print(f'[TCP {a[0]}] Connection tested (No Data)', flush=True)
                    except Exception as e:
                        print(f'[TCP] Error reading data: {e}', flush=True)
                    finally:
                        c.close()
        except Exception as e:
            print(f'[Error] {e}', flush=True)

if __name__ == '__main__':
    main()
