#!/usr/bin/env python3
"""
Generate bcrypt password hashes for demo users.
Run this script to get the actual hashes to use in init-db.sql
"""

import bcrypt

# Demo users (Brooklyn Nine-Nine theme)
users = [
    ("jake", "jake99"),
    ("amy", "amy99"),
    ("rosa", "rosa99"),
    ("terry", "terry99"),
    ("charles", "charles99"),
    ("gina", "gina99"),
]

print("-- Demo User Password Hashes (bcrypt, cost factor 12)")
print("-- Copy these into init-db.sql")
print()

for username, password in users:
    # Generate bcrypt hash with cost factor 12
    salt = bcrypt.gensalt(rounds=12)
    password_hash = bcrypt.hashpw(password.encode('utf-8'), salt)
    hash_str = password_hash.decode('utf-8')

    print(f"-- {username} / {password}")
    print(f"('{username}', '{username}@precinct99.nypd', '{hash_str}'),")
    print()
