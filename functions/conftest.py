import os
import sys

# Get the absolute path of the 'functions' directory
functions_dir = os.path.dirname(os.path.abspath(__file__))

# Add the functions directory to the Python path
sys.path.insert(0, functions_dir) 