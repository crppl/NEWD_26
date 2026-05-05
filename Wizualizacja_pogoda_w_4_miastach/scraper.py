import csv
import requests
from bs4 import BeautifulSoup


URL = (
	"https://www.ogimet.com/cgi-bin/gclimat?lang=en&mode=0&ind=07149"
	"&ord=DIR&year=2026&mes=3&months=1000"
)


def text_or_empty(cell):
	if cell is None:
		return ""
	t = cell.get_text(strip=True)
	if t in ("----", "-", ""):
		return ""
	return t


def fetch_and_parse(url=URL):
	resp = requests.get(url)
	resp.raise_for_status()
	soup = BeautifulSoup(resp.text, "html.parser")

	# find the table that contains Section 1 (mandatory monthly data)
	anchor = soup.find("a", attrs={"name": "sec1"})
	if not anchor:
		raise RuntimeError("Could not find section anchor in page")
	table = anchor.find_parent("table")
	if not table:
		raise RuntimeError("Could not find data table")

	rows = []
	tbody = table.find("tbody") or table
	for tr in tbody.find_all("tr"):
		tds = tr.find_all("td")
		if len(tds) < 15:
			continue
		year = text_or_empty(tds[0])
		month = text_or_empty(tds[1])
		# Sea-level pressure is column index 3, mean temp column 5, precipitation column 14
		pressure = text_or_empty(tds[3])
		temp = text_or_empty(tds[5])
		precip = text_or_empty(tds[14])

		# skip rows without year/month
		if not year or not month:
			continue
		try:
			y = int(year)
			m = int(month)
		except ValueError:
			continue

		if 2000 <= y <= 2026:
			rows.append((f"{y:04d}-{m:02d}", temp, pressure, precip))

	return rows


def save_csv(rows, path="output.csv"):
	with open(path, "w", newline="", encoding="utf-8") as f:
		writer = csv.writer(f)
		writer.writerow(["date", "avg_temperature", "avg_airpressure", "avg_precipitation"])
		for r in rows:
			writer.writerow(r)


def main():
	print("Fetching ogimet page and parsing monthly data...")
	rows = fetch_and_parse()
	if not rows:
		print("No rows parsed; check the page or selector.")
		return
	# sort by date
	rows.sort(key=lambda x: x[0])
	save_csv(rows)
	print(f"Wrote {len(rows)} rows to output.csv")


if __name__ == "__main__":
	main()

