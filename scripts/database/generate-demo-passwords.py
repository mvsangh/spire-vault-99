#!/usr/bin/env python3
"""
Generate bcrypt password hashes for demo users.
Run this script to get the actual hashes to use in init-db.sql
"""

import bcrypt

# Demo users (Brooklyn Nine-Nine theme)
# Password format: <username>-precinct99 (meets 8-char minimum)
users = [
    ("jake", "jake-precinct99"),
    ("amy", "amy-precinct99"),
    ("rosa", "rosa-precinct99"),
    ("terry", "terry-precinct99"),
    ("charles", "charles-precinct99"),
    ("gina", "gina-precinct99"),
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
