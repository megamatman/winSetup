# Scratch file -- not committed to git
#
# Use this for quick experiments, API tests, and throwaway code.
# Divide into cells with # %% for interactive execution in VS Code.

import os

# Load .env file if present (optional, not needed in container environments)
# pip install python-dotenv
# from dotenv import load_dotenv
# load_dotenv()

# Use os.environ.get with defaults for portable environment variable access.
# This works in containers (where env vars are injected directly) and in
# local development (where you can uncomment load_dotenv above).
DATABASE_URL = os.environ.get("DATABASE_URL", "sqlite:///local.db")
DEBUG = os.environ.get("DEBUG", "true").lower() == "true"

# %%
print(f"DATABASE_URL: {DATABASE_URL}")
print(f"DEBUG: {DEBUG}")
