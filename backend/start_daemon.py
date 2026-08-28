import os
from pathlib import Path
import sys


def main() -> None:
    service_script = Path(sys.argv[1]).resolve()
    log_path = Path(sys.argv[2]).resolve()
    pid_path = Path(sys.argv[3]).resolve()

    first_child = os.fork()
    if first_child:
        os.waitpid(first_child, 0)
        return

    os.setsid()
    second_child = os.fork()
    if second_child:
        os._exit(0)

    log_descriptor = os.open(
        log_path,
        os.O_WRONLY | os.O_CREAT | os.O_TRUNC,
        0o600,
    )
    null_descriptor = os.open(os.devnull, os.O_RDONLY)
    os.dup2(null_descriptor, sys.stdin.fileno())
    os.dup2(log_descriptor, sys.stdout.fileno())
    os.dup2(log_descriptor, sys.stderr.fileno())
    os.close(null_descriptor)
    os.close(log_descriptor)

    pid_path.write_text(str(os.getpid()), encoding="utf-8")
    os.execv("/bin/zsh", ["/bin/zsh", str(service_script)])


if __name__ == "__main__":
    main()
