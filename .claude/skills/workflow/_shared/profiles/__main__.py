"""Entry point for python -m profiles."""

import sys

from .profile_resolver import main

if __name__ == "__main__":
    sys.exit(main())
