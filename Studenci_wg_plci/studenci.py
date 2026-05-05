import csv
import re
from collections import defaultdict
import matplotlib.pyplot as plt
import numpy as np

def _extract_category(header_cell: str) -> str:
	"""Split a header cell by ';' and return a cleaned category name.

	Rules:
	- remove common tokens like 'studenci', 'uczelnie publiczne', 'ogółem', '[osoba]'
	- ignore 4-digit years
	- join remaining tokens (preserving order) to form category name
	- if nothing remains, return 'ogolem'
	"""
	# Return list of tokens (preserve order). The caller will use tuple(tokens)
	if not header_cell:
		return ["ogolem"]
	parts = [p.strip() for p in header_cell.split(";")]
	# keep all tokens (including years and labels) but strip empties
	tokens = [p for p in parts if p]
	if not tokens:
		return ["ogolem"]
	return tokens


def load_csv_to_area_category_table(path: str):
	"""Load the CSV at `path` and return a 2D table (areas x categories) in memory.

	Returns either a pandas.DataFrame (if pandas is installed) or a tuple
	(area_category_dict, categories_list) where area_category_dict is
	{area: {category: sum}}.
	"""
	# map column index -> category name
	col_category = {}
	area_cat_sums = defaultdict(lambda: defaultdict(float))

	with open(path, newline='', encoding='utf-8') as f:
		reader = csv.reader(f, delimiter=';', quotechar='"')
		try:
			header = next(reader)
		except StopIteration:
			raise ValueError("CSV is empty")

		# identify categories for columns starting from index 2
		for idx in range(2, len(header)):
			tokens = _extract_category(header[idx])
			# store as tuple so it can be used as dict key
			col_category[idx] = tuple(tokens)

		# process data rows
		for row in reader:
			if len(row) < 2:
				continue
			area = row[1].strip().strip('"')
			for idx in range(2, len(row)):
				raw = row[idx].strip().strip('"') if idx < len(row) else ""
				if raw == "":
					val = 0
				else:
					# try int then float
					try:
						val = int(raw)
					except Exception:
						try:
							val = float(raw.replace(',', '.'))
						except Exception:
							val = 0
				cat = col_category.get(idx, ("ogolem",))
				area_cat_sums[area][cat] += val

	# produce a structured table; prefer pandas if available
	try:
		import pandas as pd

		# DataFrame columns will be tuples; create DataFrame directly
		df = pd.DataFrame.from_dict(area_cat_sums, orient='index').fillna(0)
		# ensure columns are MultiIndex (tuples -> MultiIndex)
		if not isinstance(df.columns, pd.MultiIndex):
			try:
				df.columns = pd.MultiIndex.from_tuples(df.columns)
			except Exception:
				# if columns are strings, leave as-is
				pass
		# try to convert numeric columns to integers when possible
		try:
			df = df.astype(int)
		except Exception:
			pass
		return df
	except Exception:
		# return raw dict and categories list
		categories = list(dict.fromkeys(col_category.values()))
		return area_cat_sums, categories


def columns_with_token(table, token: str):
	"""Return list of column tuples that contain `token` (case-insensitive).

	`table` can be a pandas.DataFrame or a tuple (area_cat_sums, categories_list).
	"""
	token_low = token.lower()
	cols = []
	try:
		import pandas as pd
		if isinstance(table, pd.DataFrame):
			for c in table.columns:
				if isinstance(c, tuple):
					if any(str(x).lower() == token_low for x in c):
						cols.append(c)
				else:
					if str(c).lower() == token_low:
						cols.append((c,))
			return cols
	except Exception:
		pass

	# fallback: table is (area_cat_sums, categories)
	if isinstance(table, tuple) and len(table) == 2:
		_, categories = table
		for c in categories:
			if any(str(x).lower() == token_low for x in c):
				cols.append(c)
	return cols


if __name__ == "__main__":
	# example usage
	path = "SZKO_3566_CTAB_20260329232651.csv"
	table = load_csv_to_area_category_table(path)
	# keep in memory; show a short summary
	try:
		import pandas as pd

		df = table
		print("Loaded table: rows (areas)", df.shape[0], "columns (categories)", df.shape[1])
		# show first 10 column tuples
		cols = df.columns.tolist()[:10]
		print(cols)
	except Exception:
		area_cat_sums, categories = table
		print("Loaded table: areas:", len(area_cat_sums), "categories:", len(categories))
	


	
	print("\n")
	print(table["studenci"]["uczelnie publiczne"]["ogółem"]["ogółem"]["ogółem"]["2014"]["[osoba]"]["POLSKA"])
	plec = []
	for i in list(table["studenci"]["uczelnie publiczne"]["ogółem"].keys()):
		if i[0] not in plec:
			plec.append(i[0])
	lata = []
	for i in list(table["studenci"]["uczelnie publiczne"]["ogółem"]["ogółem"]["ogółem"].keys()):
		if i[0] not in lata:
			lata.append(i[0])
	lata = lata[:-1] # remove last entry - no data for 2025
	obszary = []
	for i in list(table["studenci"]["uczelnie publiczne"]["ogółem"]["ogółem"]["ogółem"]["2014"]["[osoba]"].keys()):
		if i not in obszary:
			obszary.append(i)
	print(plec)
	print(lata)
	print(obszary)
	Xk = []
	Xm = []
	for i in lata:
		Xk.append(table["studenci"]["uczelnie publiczne"]["ogółem"]["kobiety"]["ogółem"][i]["[osoba]"]["POLSKA"])
		Xm.append(table["studenci"]["uczelnie publiczne"]["ogółem"]["mężczyźni"]["ogółem"][i]["[osoba]"]["POLSKA"])
	# rysuj skumulowany wykres (kobiety na dole, mężczyźni na górze)
	bars_f = plt.bar(lata, Xk, color="#AA5780", label='Kobiety')
	bars_m = plt.bar(lata, Xm, bottom=Xk, color="#24A0FF", label='Mężczyźni')
	plt.title('Liczba studentów w Polsce (2014-2024)')
	plt.xlabel('Rok')
	plt.ylabel('Liczba studentów', rotation=0, labelpad=50)
	plt.legend()

	# helper: pokaż wartość w milionach z 2 miejscami po przecinku (np. 1,50 dla 1_500_000)
	def fmt_thousands(n):
		try:
			n = float(n)
		except Exception:
			return "0,00"
		mill = n / 1_000_000.0
		# format z separatorem dziesiętnym jako przecinek (polski)
		s = f"{mill:.2f}"
		return s.replace('.', ',')

	# dodaj liczby (adnotacje) na każdym segmencie słupka (wartości w tysiącach)
	for idx, (fk, mk) in enumerate(zip(Xk, Xm)):
		# kobiety (środek dolnego segmentu)
		if fk and fk != 0:
			plt.text(idx, fk/2, fmt_thousands(fk), ha='center', va='center', fontsize=8)
		# mężczyźni (środek górnego segmentu)
		if mk and mk != 0:
			plt.text(idx, fk + mk/2, fmt_thousands(mk), ha='center', va='center', fontsize=8)

	plt.tight_layout()
	plt.show()

	