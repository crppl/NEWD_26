library(ggplot2)
library(scales)
library(viridis)
library(RColorBrewer)
library(reshape2)

df <- read.csv('Statystyki_bibliotek_radomskich/bib2.csv', header=TRUE, stringsAsFactors=FALSE, check.names=TRUE)
yr_cols <- names(df)[grepl('^X[0-9]{4}$', names(df))]
lata_int <- as.integer(sub("X","", yr_cols))

get_series <- function(rrow) {
  vals <- unlist(df[rrow, yr_cols])
  vals[vals == "NA" | vals == "" | vals == "None"] <- NA
  suppressWarnings(as.numeric(vals))
}

mk_ts <- function(rrow, name) {
  data.frame(rok=lata_int, wartosc=get_series(rrow), seria=name, stringsAsFactors=FALSE)
}

cb7 <- c("#E69F00","#56B4E9","#009E73","#F0E442","#0072B2","#D55E00","#CC79A7")
cb2 <- c("#0072B2","#D55E00")

theme_set(theme_bw(base_size=12) +
  theme(plot.title    = element_text(face="bold", size=13),
        plot.subtitle = element_text(size=10, color="grey40"),
        plot.caption  = element_text(size=8, color="grey50"),
        legend.position = "bottom"))

out_dir <- "Statystyki_bibliotek_radomskich/phts"
if (!dir.exists(out_dir)) dir.create(out_dir, recursive=TRUE)

save_plot <- function(p, name, w=10, h=6) {
  ggsave(file.path(out_dir, paste0(name, ".png")), plot=p, width=w, height=h, dpi=150)
  message("Saved: ", name)
}




# --- INDEKSY WIERSZY (R 1-based) ---
R_pub_prac  <- 9;  R_pub_ksieg <- 10; R_pub_czyt  <- 13; R_pub_wyp   <- 14
R_pub_spec  <- 19; R_inne_prac <- 3;  R_inne_ksieg <- 4;  R_inne_spec <- 5
R_inne_czyt <- 6;  R_ksieg1000 <- 26; R_czyt1000  <- 27; R_wyp_czyt  <- 28
R_niepeln_wej <- 17; R_niepeln_wew <- 18
R_komp_ogol <- 62; R_komp_prac <- 63; R_komp_int  <- 64; R_komp_czyt <- 65
R_komp_nauk <- 76; R_ud_zewn   <- 89; R_ud_miej   <- 91
R_filie_pub <- 8   # biblioteki i filie publiczne (liczba obiektow)

# ============================================================
# W01 – Boxplot SUROWYCH wartosci (bez normalizacji)
# ============================================================
# Kazda zmienna na osobnym panelu – skale niezalezne (scales="free_y")
multi_raw <- rbind(
  mk_ts(R_pub_czyt,  "Czytelnicy (os.)"),
  mk_ts(R_pub_wyp,   "Wypozyczenia (wol.)"),
  mk_ts(R_pub_ksieg, "Ksiegozbiór (wol.)"),
  mk_ts(R_pub_prac,  "Pracownicy (os.)")
)
multi_raw <- multi_raw[!is.na(multi_raw$wartosc), ]
multi_raw$seria <- factor(multi_raw$seria,
  levels = c("Czytelnicy (os.)","Wypozyczenia (wol.)","Ksiegozbiór (wol.)","Pracownicy (os.)"))

# Nazwy serii jako nazwany wektor kolorow – gwarantuje zgodnosc koloru
# z etykieta niezaleznie od kolejnosci w panelu
kol_w01 <- c("Czytelnicy (os.)"    = cb7[1],
             "Wypozyczenia (wol.)" = cb7[2],
             "Ksiegozbiór (wol.)"  = cb7[3],
             "Pracownicy (os.)"    = cb7[4])

p1 <- ggplot(multi_raw, aes(x=seria, y=wartosc, fill=seria)) +
  geom_boxplot(alpha=0.85, outlier.shape=21, outlier.size=2.2) +
  facet_wrap(~seria, scales="free", ncol=2) +
  scale_fill_manual(values=kol_w01, guide="none") +
  scale_y_continuous(labels=label_number(big.mark=" ")) +
  labs(title="Rozklad surowych wartosci wskaznikow bibliotek publicznych w Radomiu",
       subtitle="Dane roczne 1995-2024 – kazdy panel z wlasna skala osi Y",
       x=NULL, y="Wartosc rzeczywista",
       caption="Zrodlo: GUS / BDL") +
  theme(axis.text.x=element_blank(), axis.ticks.x=element_blank(),
        strip.text=element_text(face="bold", size=10),
        panel.grid.major.x=element_blank())
save_plot(p1, "W01_boxplot_surowe", w=10, h=7)

# ============================================================
# W02 – Histogram: dekadowy przekroj czytelnikow (grupy lat)
# ============================================================
czyt_df <- data.frame(rok=lata_int, czyt=get_series(R_pub_czyt))
czyt_df <- czyt_df[!is.na(czyt_df$czyt), ]
czyt_df$dekada <- cut(czyt_df$rok,
  breaks=c(1994,2000,2010,2020,2025),
  labels=c("1995-2000","2001-2010","2011-2020","2021-2024"))

srednie <- aggregate(czyt ~ dekada, data=czyt_df, FUN=mean)

p2 <- ggplot(czyt_df, aes(x=czyt/1000, fill=dekada)) +
  geom_histogram(bins=15, color="white", alpha=0.85, position="identity") +
  geom_vline(data=srednie, aes(xintercept=czyt/1000, color=dekada),
             linewidth=1.1, linetype="dashed") +
  scale_fill_manual(values=cb7[c(1,2,5,6)], name="Okres") +
  scale_color_manual(values=cb7[c(1,2,5,6)], name="Okres (srednia)") +
  scale_x_continuous(labels=label_number(suffix=" tys.", big.mark=" ")) +
  labs(title="Rozklad rocznej liczby czytelnikow bibliotek publicznych w Radomiu",
       subtitle="Kolorowanie wedlug okresu (dekady) | Przerywane linie = srednie dekadowe",
       x="Czytelnicy (tys. osob)", y="Liczba lat",
       caption="Zrodlo: GUS / BDL") +
  guides(fill=guide_legend(nrow=1), color=guide_legend(nrow=1))
save_plot(p2, "W02_histogram_czytelnicy", w=10, h=6)

# ============================================================
# W02_1 – Liczba czytelnikow na przestrzeni lat (wykres liniowy)
# ============================================================
czyt_line <- data.frame(rok=lata_int, czyt=get_series(R_pub_czyt))
czyt_line <- czyt_line[!is.na(czyt_line$czyt), ]

# Srednie dekadowe jako poziome segmenty
dekady <- list(c(1995,2000), c(2001,2010), c(2011,2020), c(2021,2024))
sr_dek <- do.call(rbind, lapply(seq_along(dekady), function(i) {
  d <- dekady[[i]]
  sub <- czyt_line[czyt_line$rok >= d[1] & czyt_line$rok <= d[2], ]
  data.frame(xmin=d[1], xmax=d[2], sr=mean(sub$czyt, na.rm=TRUE),
             dekada=paste0(d[1],"-",d[2]))
}))

p2_1 <- ggplot(czyt_line, aes(x=rok, y=czyt/1000)) +
  # srednie dekadowe jako szare segmenty w tle
  geom_segment(data=sr_dek,
               aes(x=xmin, xend=xmax, y=sr/1000, yend=sr/1000, color=dekada),
               linewidth=2.5, alpha=0.25, inherit.aes=FALSE) +
  # wypelnienie pod linia
  geom_ribbon(aes(ymin=min(czyt/1000), ymax=czyt/1000), fill="#56B4E9", alpha=0.15) +
  # linia glowna
  geom_line(color="#0072B2", linewidth=1.2) +
  geom_point(aes(fill=czyt/1000), shape=21, size=2.8, color="white", stroke=0.8) +
  # zaznaczenie COVID
  annotate("rect", xmin=2019.5, xmax=2021.5, ymin=-Inf, ymax=Inf,
           fill="#CC79A7", alpha=0.12) +
  annotate("text", x=2020.5, y=max(czyt_line$czyt/1000)*0.985,
           label="COVID-19", size=3, color="#CC79A7", fontface="italic") +
  scale_fill_viridis_c(option="mako", direction=-1, guide="none") +
  scale_color_manual(values=cb7[c(1,2,5,6)], name="Srednia dekadowa") +
  scale_x_continuous(breaks=seq(1995,2024,by=3)) +
  scale_y_continuous(labels=label_number(suffix=" tys.", big.mark=" "),
                     limits=c(NA, max(czyt_line$czyt/1000)*1.05)) +
  labs(title="Liczba czytelnikow bibliotek publicznych w Radomiu (1995-2024)",
       subtitle="Linia: dane roczne | Szerokie paski: srednia dla kazdej dekady | Rozowy obszar: pandemia",
       x="Rok", y="Czytelnicy (tys. osob)",
       caption="Zrodlo: GUS / BDL") +
  guides(color=guide_legend(nrow=1))
save_plot(p2_1, "W02_1_czytelnicy_linia", w=11, h=6)

# ============================================================
# W03 – Komputeryzacja: ciemniejsze tlo panelu dla lepszej widocznosci linii
# ============================================================
comp_labels <- c("Komputery ogólem","Dla pracownikow","Z dostepem do int.",
                 "Dla czytelnikow","Dla czyt. – internet")
comp_rows   <- c(R_komp_ogol, R_komp_prac, R_komp_int, R_komp_czyt, R_komp_czyt+1)
comp_df <- do.call(rbind, lapply(seq_along(comp_rows), function(i)
  mk_ts(comp_rows[i], comp_labels[i])))
comp_df <- comp_df[!is.na(comp_df$wartosc), ]
comp_df$seria <- factor(comp_df$seria, levels=comp_labels)

p3 <- ggplot(comp_df, aes(x=rok, y=wartosc, color=seria, shape=seria)) +
  geom_line(linewidth=1.3) +
  geom_point(size=3, stroke=1.2, fill="white") +
  scale_color_manual(values=cb7[c(6,1,5,3,7)], name=NULL) +
  scale_shape_manual(values=c(21,22,23,24,25), name=NULL) +
  scale_x_continuous(breaks=seq(2000,2024,by=4)) +
  labs(title="Komputeryzacja bibliotek publicznych w Radomiu",
       subtitle="Liczba komputerow wedlug przeznaczenia",
       x="Rok", y="Liczba komputerow (szt.)",
       caption="Zrodlo: GUS / BDL") +
  guides(color=guide_legend(nrow=2), shape=guide_legend(nrow=2)) +
  theme(panel.background=element_rect(fill="#f0f4f8"),
        panel.grid.major=element_line(color="white", linewidth=0.7),
        panel.grid.minor=element_line(color="white", linewidth=0.3))
save_plot(p3, "W03_komputeryzacja", w=10, h=6)

# ============================================================
# W04 – NOWY WYKRES: Wskazniki na mieszkanca i na czytelnika
#        Wykres liniowy trzech wskaznikow wzglednych (lollipop + line)
# ============================================================
wsk_df <- data.frame(
  rok       = lata_int,
  ksieg1000 = get_series(R_ksieg1000),
  czyt1000  = get_series(R_czyt1000),
  wyp_czyt  = get_series(R_wyp_czyt)
)
wsk_df <- wsk_df[!is.na(wsk_df$czyt1000) | !is.na(wsk_df$wyp_czyt), ]

# Skalowanie: czyt1000 i wyp_czyt maja rozne jednostki – normalizuj do % wzgledem max
wsk_long <- reshape2::melt(wsk_df, id.vars="rok",
  variable.name="wskaznik", value.name="val")
wsk_long$wskaznik <- factor(wsk_long$wskaznik,
  levels=c("czyt1000","wyp_czyt","ksieg1000"),
  labels=c("Czytelnicy na 1000 ludnosci (os.)",
           "Wypozyczenia na 1 czytelnika (wol.)",
           "Ksiegozbiór na 1000 ludnosci (wol.)"))
wsk_long <- wsk_long[!is.na(wsk_long$val), ]

p4 <- ggplot(wsk_long, aes(x=rok, y=val, color=wskaznik)) +
  geom_line(linewidth=1.1) +
  geom_point(size=2.2) +
  facet_wrap(~wskaznik, scales="free_y", ncol=1) +
  scale_color_manual(values=c("#0072B2","#D55E00","#009E73"), guide="none") +
  scale_x_continuous(breaks=seq(2000,2024,by=4)) +
  scale_y_continuous(labels=label_number(big.mark=" ")) +
  labs(title="Wskazniki relatywne bibliotek publicznych Radomia (na mieszkanca / na czytelnika)",
       subtitle="Trzy wskazniki efektywnosci – kazdy panel z wlasna skala osi Y",
       x="Rok", y=NULL,
       caption="Zrodlo: GUS / BDL") +
  theme(strip.text=element_text(face="bold", size=9),
        panel.spacing=unit(0.8,"lines"))
save_plot(p4, "W04_wskazniki_panele", w=10, h=8)

# ============================================================
# W05 – Czytelnicy: pub vs inne
# ============================================================
comp5 <- rbind(mk_ts(R_pub_czyt,"Biblioteki publiczne"),
               mk_ts(R_inne_czyt,"Biblioteki inne niz publ."))
comp5 <- comp5[!is.na(comp5$wartosc), ]
p5 <- ggplot(comp5, aes(x=rok, y=wartosc/1000, color=seria)) +
  geom_line(linewidth=1.1) + geom_point(size=2) +
  scale_color_manual(values=cb2, name=NULL) +
  scale_x_continuous(breaks=seq(1995,2024,by=4)) +
  scale_y_continuous(labels=label_number(suffix=" tys.")) +
  labs(title="Porownanie liczby czytelnikow: biblioteki publiczne vs inne",
       subtitle="Radom, dane roczne 1995-2024",
       x="Rok", y="Czytelnicy (tys. os.)", caption="Zrodlo: GUS / BDL")
save_plot(p5, "W05_czytelnicy_porownanie")

# ============================================================
# W06 – Ksiegozbiór area
# ============================================================
comp6 <- rbind(mk_ts(R_pub_ksieg,"Biblioteki publiczne"),
               mk_ts(R_inne_ksieg,"Biblioteki inne niz publ."))
comp6 <- comp6[!is.na(comp6$wartosc), ]
p6 <- ggplot(comp6, aes(x=rok, y=wartosc/1000, fill=seria)) +
  geom_area(alpha=0.55, position="identity") +
  geom_line(aes(color=seria), linewidth=0.8) +
  scale_fill_manual(values=cb2, name=NULL) +
  scale_color_manual(values=cb2, name=NULL) +
  scale_x_continuous(breaks=seq(1995,2024,by=4)) +
  scale_y_continuous(labels=label_number(suffix=" tys.")) +
  labs(title="Wielkosc ksiegozbioru – biblioteki publiczne vs inne niz publiczne",
       subtitle="Radom, dane roczne 1995-2024",
       x="Rok", y="Woluminy (tys. wol.)", caption="Zrodlo: GUS / BDL")
save_plot(p6, "W06_ksiegozbiory_area")

# ============================================================
# W07 – Pracownicy grouped bar
# ============================================================
comp7 <- rbind(mk_ts(R_pub_prac,"Biblioteki publiczne"),
               mk_ts(R_inne_prac,"Biblioteki inne niz publ."))
comp7 <- comp7[!is.na(comp7$wartosc), ]
p7 <- ggplot(comp7, aes(x=rok, y=wartosc, fill=seria)) +
  geom_col(position="dodge", alpha=0.9) +
  scale_fill_manual(values=cb2, name=NULL) +
  scale_x_continuous(breaks=seq(1995,2024,by=4)) +
  labs(title="Liczba pracownikow bibliotek w Radomiu (dzialanosc podstawowa)",
       subtitle="Porownanie: biblioteki publiczne vs inne niz publiczne",
       x="Rok", y="Liczba pracownikow (os.)", caption="Zrodlo: GUS / BDL")
save_plot(p7, "W07_pracownicy_bar")

# ============================================================
# W08 – Podwojna os: POPRAWIONE kolory i opisy osi
# ============================================================
czyt1000_v <- get_series(R_czyt1000)
wyp_czyt_v <- get_series(R_wyp_czyt)
wsk8 <- data.frame(rok=lata_int, c1=czyt1000_v, wc=wyp_czyt_v)
wsk8 <- wsk8[!is.na(wsk8$c1) & !is.na(wsk8$wc), ]
sf   <- max(wsk8$c1, na.rm=TRUE) / max(wsk8$wc, na.rm=TRUE)

col_slupki <- "#56B4E9"   # niebieski – lewa os
col_linia  <- "#D55E00"   # pomaranczowy – prawa os

p8 <- ggplot(wsk8, aes(x=rok)) +
  geom_col(aes(y=c1), fill=col_slupki, alpha=0.80) +
  geom_line(aes(y=wc*sf), color=col_linia, linewidth=1.4) +
  geom_point(aes(y=wc*sf), color=col_linia, size=2.5, shape=16) +
  scale_y_continuous(
    name   = "Czytelnicy na 1000 ludnosci (os.)",
    labels = label_number(big.mark=" "),
    sec.axis = sec_axis(~./sf,
      name   = "Wypozyczenia na 1 czytelnika (wol.)",
      labels = label_number(accuracy=0.1))
  ) +
  scale_x_continuous(breaks=seq(2000,2024,by=4)) +
  labs(
    title    = "Wskazniki aktywnosci czytelniczej w bibl. publicznych Radomia",
    subtitle = paste0(
      "Lewa os (slupki, niebieski): czytelnicy na 1000 mieszkancow [os.]\n",
      "Prawa os (linia, pomarancz.): wypozyczenia na 1 czytelnika [wol.]"),
    x = "Rok",
    caption = "Zrodlo: GUS / BDL"
  ) +
  theme(
    axis.title.y.left  = element_text(color=col_slupki, face="bold"),
    axis.text.y.left   = element_text(color=col_slupki),
    axis.ticks.y.left  = element_line(color=col_slupki),
    axis.line.y.left   = element_line(color=col_slupki, linewidth=1),
    axis.title.y.right = element_text(color=col_linia, face="bold"),
    axis.text.y.right  = element_text(color=col_linia),
    axis.ticks.y.right = element_line(color=col_linia),
    axis.line.y.right  = element_line(color=col_linia, linewidth=1)
  )
save_plot(p8, "W08_wskazniki_dual_axis", w=10, h=6)

# ============================================================
# W09 – Udostepnianie: stacked area
# ============================================================
ud_df <- data.frame(rok=lata_int,
                    Na_zewnatrz=get_series(R_ud_zewn),
                    Na_miejscu =get_series(R_ud_miej))
ud_long <- melt(ud_df, id.vars="rok", variable.name="sposob", value.name="wol")
ud_long$sposob <- factor(ud_long$sposob, labels=c("Na zewnatrz","Na miejscu"))
ud_long <- ud_long[!is.na(ud_long$wol), ]
p9 <- ggplot(ud_long, aes(x=rok, y=wol/1000, fill=sposob)) +
  geom_area(alpha=0.85, position="stack") +
  scale_fill_manual(values=c("#0072B2","#E69F00"), name="Sposob") +
  scale_x_continuous(breaks=seq(1995,2024,by=4)) +
  scale_y_continuous(labels=label_number(suffix=" tys.")) +
  labs(title="Udostepnianie woluminów w bibliotekach innych niz publiczne – Radom",
       subtitle="Laczne udostepnienia na zewnatrz i na miejscu",
       x="Rok", y="Woluminy (tys.)", caption="Zrodlo: GUS / BDL")
save_plot(p9, "W09_udostepnianie")

# ============================================================
# W10 – Komputery: pub vs naukowe
# ============================================================
comp10 <- rbind(mk_ts(R_komp_ogol,"Bibl. publiczne"),
                mk_ts(R_komp_nauk,"Bibl. naukowe i inne"))
comp10 <- comp10[!is.na(comp10$wartosc), ]
p10 <- ggplot(comp10, aes(x=rok, y=wartosc, color=seria, shape=seria)) +
  geom_line(linewidth=1) + geom_point(size=2.5) +
  scale_color_manual(values=cb2, name=NULL) +
  scale_shape_manual(values=c(16,17), name=NULL) +
  scale_x_continuous(breaks=seq(2000,2024,by=4)) +
  labs(title="Komputery ogólem w bibliotekach publicznych i naukowych – Radom",
       subtitle="Porownanie liczby komputerow ogólem",
       x="Rok", y="Liczba komputerow (szt.)", caption="Zrodlo: GUS / BDL")
save_plot(p10, "W10_komputery_pub_vs_nauk")

# ============================================================
# W11 – Zbiory specjalne
# ============================================================
comp11 <- rbind(mk_ts(R_pub_spec,"Biblioteki publiczne"),
                mk_ts(R_inne_spec,"Biblioteki inne niz publ."))
comp11 <- comp11[!is.na(comp11$wartosc), ]
p11 <- ggplot(comp11, aes(x=rok, y=wartosc/1000, fill=seria)) +
  geom_col(position="dodge", alpha=0.9) +
  scale_fill_manual(values=cb2, name=NULL) +
  scale_x_continuous(breaks=seq(1995,2024,by=4)) +
  scale_y_continuous(labels=label_number(suffix=" tys.")) +
  labs(title="Zbiory specjalne w bibliotekach radomskich",
       subtitle="Porownanie: biblioteki publiczne vs inne niz publiczne",
       x="Rok", y="Liczba zbiorow (tys. szt.)", caption="Zrodlo: GUS / BDL")
save_plot(p11, "W11_zbiory_specjalne")

# ============================================================
# W12 – Trend wypozyczen BEZ linii trendu LOESS
# ============================================================
wyp_ts <- data.frame(rok=lata_int, val=get_series(R_pub_wyp))
wyp_ts <- wyp_ts[!is.na(wyp_ts$val), ]
p12 <- ggplot(wyp_ts, aes(x=rok, y=val/1000)) +
  annotate("rect", xmin=2019.5, xmax=2021.5, ymin=-Inf, ymax=Inf,
           fill="#CC79A7", alpha=0.15) +
  annotate("text", x=2020.5, y=max(wyp_ts$val/1000)*0.98,
           label="COVID-19", size=3.2, color="#CC79A7", fontface="italic") +
  geom_ribbon(aes(ymin=min(val/1000), ymax=val/1000), fill="#56B4E9", alpha=0.2) +
  geom_line(color="#0072B2", linewidth=1.2) +
  geom_point(color="#0072B2", size=2) +
  scale_x_continuous(breaks=seq(2000,2024,by=4)) +
  scale_y_continuous(labels=label_number(suffix=" tys.")) +
  labs(title="Wypozyczenia zewnetrzne bibliotek publicznych – Radom",
       subtitle="Wyrazny spadek w latach 2020-2021 zwiazany z pandemia COVID-19",
       x="Rok", y="Wypozyczenia (tys. wol.)", caption="Zrodlo: GUS / BDL")
save_plot(p12, "W12_wypozyczenia_trend")

# ============================================================
# W13 – Scatter czytelnicy vs wypozyczenia
# ============================================================
sc_df <- data.frame(czyt=get_series(R_pub_czyt), wyp=get_series(R_pub_wyp), rok=lata_int)
sc_df <- sc_df[!is.na(sc_df$czyt) & !is.na(sc_df$wyp), ]
p13 <- ggplot(sc_df, aes(x=czyt/1000, y=wyp/1000, color=rok)) +
  geom_point(size=3.5, alpha=0.9) +
  geom_smooth(method="lm", se=TRUE, color="#D55E00", fill="#D55E00",
              alpha=0.15, linewidth=1) +
  scale_color_viridis_c(option="plasma", name="Rok", breaks=seq(2000,2024,by=6)) +
  scale_x_continuous(labels=label_number(suffix=" tys.")) +
  scale_y_continuous(labels=label_number(suffix=" tys.")) +
  labs(title="Zaleznosc wypozyczen od liczby czytelnikow bibl. publicznych",
       subtitle="Radom – kazdy punkt to 1 rok | Linia regresji liniowej",
       x="Czytelnicy (tys. os.)", y="Wypozyczenia (tys. wol.)",
       caption="Zrodlo: GUS / BDL") +
  theme(legend.position="right")
save_plot(p13, "W13_scatter")

# ============================================================
# W14 – Ksiegozbiór na 1000 ludnosci – LEPSZA PALETA (sekwencyjna)
# ============================================================
ksieg_df <- data.frame(rok=lata_int, val=get_series(R_ksieg1000))
ksieg_df <- ksieg_df[!is.na(ksieg_df$val), ]
sr <- mean(ksieg_df$val, na.rm=TRUE)

p14 <- ggplot(ksieg_df, aes(x=rok, y=val, fill=val)) +
  geom_col(alpha=0.95) +
  geom_hline(yintercept=sr, color="#CC79A7", linewidth=1.2, linetype="dashed") +
  annotate("text", x=min(ksieg_df$rok)+2, y=sr*1.015,
           label=paste0("Srednia: ", round(sr,0), " wol./1000"),
           color="#CC79A7", size=3.4, hjust=0, fontface="bold") +
  scale_fill_viridis_c(option="cividis", direction=1,
                       name="Wol./1000",
                       breaks=round(seq(min(ksieg_df$val),max(ksieg_df$val),length.out=5))) +
  scale_x_continuous(breaks=seq(2000,2024,by=4)) +
  scale_y_continuous(labels=label_number(big.mark=" ")) +
  labs(title="Ksiegozbiór bibliotek publicznych na 1000 ludnosci Radomia",
       subtitle="Liczba woluminów przypadajacych na 1000 mieszkancow – paleta cividis",
       x="Rok", y="Woluminy na 1000 ludnosci",
       caption="Zrodlo: GUS / BDL") +
  theme(legend.position="right",
        legend.key.height=unit(1.4,"cm"))
save_plot(p14, "W14_ksieg_na_1000")

# ============================================================
# W15 – Dostepnosc dla niepelnosprawnych + % wszystkich bibliotek
# ============================================================
filie_v <- get_series(R_filie_pub)  # liczba bibl. publicznych ogólem w danym roku
wej_v   <- get_series(R_niepeln_wej)
wew_v   <- get_series(R_niepeln_wew)

np_df <- data.frame(rok=lata_int, filie=filie_v, Wejscie=wej_v, Wewnatrz=wew_v)
np_df <- np_df[!is.na(np_df$Wejscie) | !is.na(np_df$Wewnatrz), ]
np_df <- np_df[!is.na(np_df$filie) & np_df$filie > 0, ]

# Procent = obiekty z co najmniej 1 udogodnieniem (max z wejscia i wewnatrz)
# podzielone przez LACZNA LICZBE FILII w danym roku (mianownik zmienia sie w czasie!)
# To wyjasnia pozorne paradoksy: np. 2016 slupek wyzszy niz 2017,
# ale % nizszy – bo w 2016 bylo 14 filii, a w 2017 juz tylko 12.
np_df$max_ud <- pmax(np_df$Wejscie, np_df$Wewnatrz, na.rm=TRUE)
np_df$pct    <- round(np_df$max_ud / np_df$filie * 100, 1)

# Etykieta % umieszczona na szczycie slupka
np_long <- melt(np_df[, c("rok","Wejscie","Wewnatrz")],
                id.vars="rok", variable.name="typ", value.name="liczba")
np_long$typ <- factor(np_long$typ, labels=c("Wejscie do budynku","Udogodnienia wewnatrz"))
np_long <- np_long[!is.na(np_long$liczba), ]

# Top slupka = suma obu kategorii w danym roku (dla pozycji etykiety)
top_df <- aggregate(liczba ~ rok, data=np_long, FUN=function(x) sum(x, na.rm=TRUE))
top_df <- merge(top_df, np_df[, c("rok","pct","filie")], by="rok")

# Etykieta: "%  (X/Y fil.)" – pokazuje mianownik wprost
top_df$etykieta <- paste0(top_df$pct, "%\n(",
                           top_df$max_ud <- np_df$max_ud[match(top_df$rok, np_df$rok)],
                           "/", top_df$filie, " fil.)")

p15 <- ggplot(np_long, aes(x=rok, y=liczba, fill=typ)) +
  geom_col(alpha=0.9) +
  geom_text(data=top_df,
            aes(x=rok, y=liczba, label=etykieta),
            inherit.aes=FALSE,
            vjust=-0.15, size=2.6, fontface="bold", color="grey25", lineheight=0.9) +
  scale_fill_manual(values=c("#0072B2","#E69F00"), name="Typ udogodnienia") +
  scale_x_continuous(breaks=seq(2000,2024,by=2)) +
  scale_y_continuous(limits=c(0, max(top_df$liczba)*1.30),
                     breaks=0:max(top_df$liczba,na.rm=TRUE)) +
  labs(title="Dostepnosc bibliotek publicznych dla osób niepelnosprawnych – Radom",
       subtitle=paste0(
         "Slupki: liczba obiektów z udogodnieniami | Etykiety: % bibl. z udogodnieniami (obiekty / laczna liczba filii)\n",
         "Uwaga: wyzszy slupek moze miec nizszy % – gdy laczna liczba filii spada szybciej niz liczba obiektow dostosowanych"),
       x="Rok", y="Liczba obiektów",
       caption="Zrodlo: GUS / BDL")
save_plot(p15, "W15_niepelnosprawni", w=12, h=7)

message("GOTOWE: Wszystkie 15 wykresow zapisano.")