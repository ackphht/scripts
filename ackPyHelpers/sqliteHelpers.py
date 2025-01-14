#!python3
# -*- coding: utf-8 -*-

import sys, pathlib, sqlite3
from typing import Any

class SqliteConnHelper:
	"""
	helper class for dealing with sqlite3 connections, and running queries

	it uses the XXXXXX pattern, so you need to use it with "with":

		with SqliteConnHelper(<path to sqlite db>) as dbConn:
			<do some stuff with it>

	can run queries with getScalar(), getAllRows(), getFirstRow(), etc.
	"""

	def __init__(self, sqliteFilename : pathlib.Path) -> None:
		self._filename = sqliteFilename
		self._conn: sqlite3.Connection|None = None

	def __enter__(self) -> "SqliteConnHelper":
		if sys.version_info >= (3, 12):
			self._conn = sqlite3.connect(self._filename, autocommit=False)
		else:
			self._conn = sqlite3.connect(self._filename)
		self._conn.row_factory = sqlite3.Row
		return self

	def __exit__(self, exc_type, exc_value, traceback) -> None:
		if self._conn:
			self._conn.close()
			self._conn = None

	def getScalar(self, query: str, params: dict[str, Any]|list[Any] = []) -> Any:
		if self._conn is None: raise Exception("invalid usage: must use this class in a with statement")
		cursor: sqlite3.Cursor|None = None
		try:
			cursor = self._conn.execute(query, params)
			row = cursor.fetchone()
			return row[0] if row and len(row) > 0 else None
		finally:
			if cursor is not None: cursor.close()

	def getAllRows(self, query: str, params: dict[str, Any]|list[Any] = []) -> list[sqlite3.Row]:
		if self._conn is None: raise Exception("invalid usage: must use this class in a with statement")
		cursor: sqlite3.Cursor|None = None
		try:
			cursor = self._conn.execute(query, params)
#			for row in cursor.fetchone():
#				yield row
			return cursor.fetchall()
		finally:
			if cursor is not None: cursor.close()

	def getFirstRow(self, query: str, params: dict[str, Any]|list[Any] = []) -> sqlite3.Row|None:
		if self._conn is None: raise Exception("invalid usage: must use this class in a with statement")
		cursor: sqlite3.Cursor|None = None
		try:
			cursor = self._conn.execute(query, params)
			return cursor.fetchone()
		finally:
			if cursor is not None: cursor.close()

	def executeDml(self, sql: str, params: dict[str, Any]|list[Any] = []) -> None:
		if self._conn is None: raise Exception("invalid usage: must use this class in a with statement")
		cursor: sqlite3.Cursor|None = None
		try:
			cursor = self._conn.execute(sql, params)
			self._conn.commit()
		except:
			self._conn.rollback()
			raise
		finally:
			if cursor is not None: cursor.close()

	def executeManyDml(self, sql: str, params: list[dict[str, Any]]) -> None:
		if self._conn is None: raise Exception("invalid usage: must use this class in a with statement")
		cursor: sqlite3.Cursor|None = None
		try:
			cursor = self._conn.executemany(sql, params)
			self._conn.commit()
		except:
			self._conn.rollback()
			raise
		finally:
			if cursor is not None: cursor.close()

	def executeScript(self, script: str) -> None:
		if self._conn is None: raise Exception("invalid usage: must use this class in a with statement")
		cursor: sqlite3.Cursor|None = None
		try:
			cursor = self._conn.executescript(script)
			self._conn.commit()
		except:
			self._conn.rollback()
			raise
		finally:
			if cursor is not None: cursor.close()
