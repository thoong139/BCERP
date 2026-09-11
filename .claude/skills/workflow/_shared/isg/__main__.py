"""Entry point for python -m isg."""

import sys

from .isg_recommender import main

if __name__ == "__main__":
    sys.exit(main())
