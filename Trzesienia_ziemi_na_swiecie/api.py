
import os
import time
from datetime import datetime
import requests

# Plik wynikowy ma około 500 MB.

BASE_URL = "https://earthquake.usgs.gov/fdsnws/event/1/query"
START = "2000-01-01"
END = "2026-05-10"
MIN_MAG = "0"
LIMIT = 20000
INITIAL_OFFSET = 1
MAX_YEARS_PER_QUERY = 1
OUTPUT_FILE = f"earthquakes_{START}_to_{END}.csv"


def fetch_page(offset: int, starttime: str, endtime: str) -> str:
	params = {
		"format": "csv",
		"starttime": starttime,
		"endtime": endtime,
		"minmagnitude": MIN_MAG,
		"limit": LIMIT,
		"offset": offset,
	}
	resp = requests.get(BASE_URL, params=params, timeout=60)
	resp.raise_for_status()
	return resp.text


def append_lines_to_file(path: str, lines: list, write_header: bool):
	mode = "w" if write_header else "a"
	with open(path, mode, encoding="utf-8", newline="") as f:
		f.write("\n".join(lines) + "\n")


def main():
	overall_first = True
	total_rows = 0
	
	if os.path.exists(OUTPUT_FILE):
		print(f"Plik {OUTPUT_FILE} już istnieje — nadpisuję.")
		os.remove(OUTPUT_FILE)

	start_dt = datetime.strptime(START, "%Y-%m-%d")
	end_dt = datetime.strptime(END, "%Y-%m-%d")

	year = start_dt.year
	last_year = end_dt.year

	while year <= last_year:
		chunk_start = datetime(year, 1, 1)
		chunk_end_year = year + MAX_YEARS_PER_QUERY - 1
		chunk_end = datetime(chunk_end_year, 12, 31)
		if chunk_end > end_dt:
			chunk_end = end_dt

		chunk_start_str = chunk_start.strftime("%Y-%m-%d")
		chunk_end_str = chunk_end.strftime("%Y-%m-%d")

		print(f"Przetwarzam zakres {chunk_start_str} -> {chunk_end_str}")

		offset = INITIAL_OFFSET
		while True:
			print(f"  Pobieram offset={offset} (limit={LIMIT})...")
			try:
				text = fetch_page(offset, chunk_start_str, chunk_end_str)
			except Exception as e:
				print(f"  Błąd podczas pobierania offset={offset}: {e}")
				break

			lines = text.splitlines()
			if not lines:
				print("  Brak zwróconych linii — przechodzę do następnego zakresu.")
				break

			header = lines[0]
			data_lines = lines[1:]

			if overall_first:
				append_lines_to_file(OUTPUT_FILE, [header] + data_lines, write_header=True)
				overall_first = False
			else:
				if data_lines:
					append_lines_to_file(OUTPUT_FILE, data_lines, write_header=False)

			rows_this_page = len(data_lines)
			total_rows += rows_this_page
			print(f"  Zapisano {rows_this_page} rekordów (suma: {total_rows}).")

			if rows_this_page < LIMIT:
				print("  Otrzymano mniej rekordów niż limit — koniec tego zakresu.")
				break

			offset += LIMIT
			time.sleep(1)

		year += MAX_YEARS_PER_QUERY

	print(f"Gotowe. Całkowita liczba rekordów: {total_rows}. Plik: {OUTPUT_FILE}")


if __name__ == "__main__":
	main()

