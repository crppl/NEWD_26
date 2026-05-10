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
  theme(plot.title=element_text(face="bold", size=13),
        plot.subtitle=element_text(size=10, color="grey40"),
        plot.caption=element_text(size=8, color="grey50"),
        legend.position="bottom"))

out_dir <- "Statystyki_bibliotek_radomskich/phts"
if (!dir.exists(out_dir)) dir.create(out_dir, recursive=TRUE)

save_plot <- function(p, name, w=10, h=6) {
  ggsave(file.path(out_dir, paste0(name, ".png")), plot=p, width=w, height=h, dpi=150)
  message("Saved: ", name)
}

# --- ROW INDICES (R 1-based) ---
# bibl. inne niz publiczne
R_inne_filie  <- 1;  R_inne_prac <- 3;  R_inne_ksieg <- 4
R_inne_spec   <- 5;  R_inne_czyt <- 6
# bibl. publiczne
R_pub_prac <- 9;  R_pub_ksieg <- 10; R_pub_czyt  <- 13; R_pub_wyp <- 14
R_pub_spec <- 19
# wskazniki
R_ksieg1000 <- 26; R_czyt1000 <- 27; R_wyp_czyt <- 28
# niepelnosprawni
R_niepeln_wej <- 17; R_niepeln_wew <- 18
# komputery
R_komp_ogol <- 62; R_komp_prac <- 63; R_komp_int <- 64; R_komp_czyt <- 65
R_komp_nauk <- 76
# udostepnianie
R_ud_zewn <- 89; R_ud_miej <- 91

# ============================================================
# GRUPA 1: STRUKTURA I ZMIENNOSC DANYCH
# ============================================================

# W1 – Boxplot znormalizowany
multi_box <- rbind(mk_ts(R_pub_czyt,"Czytelnicy"), mk_ts(R_pub_wyp,"Wypozyczenia"),
                   mk_ts(R_pub_ksieg,"Ksiegozbiór"), mk_ts(R_pub_prac,"Pracownicy"))
multi_box <- multi_box[!is.na(multi_box$wartosc), ]
multi_box <- do.call(rbind, lapply(split(multi_box, multi_box$seria), function(d) {
  r <- range(d$wartosc, na.rm=TRUE)
  d$wartosc_norm <- if (diff(r)==0) 0 else (d$wartosc - r[1]) / diff(r)
  d
}))

p1 <- ggplot(multi_box, aes(x=seria, y=wartosc_norm, fill=seria)) +
  geom_boxplot(alpha=0.85, outlier.shape=21, outlier.size=2.2) +
  scale_fill_manual(values=cb7[1:4], guide="none") +
  labs(title="Zmiennosc wybranych wskaznikow bibliotek publicznych w Radomiu",
       subtitle="Dane roczne 1995-2024, wartosci znormalizowane do zakresu [0, 1]",
       x="Wskaznik", y="Wartosc znormalizowana [0-1]",
       caption="Zrodlo: GUS / BDL") +
  theme(panel.grid.major.x=element_blank())
save_plot(p1, "W01_boxplot_zmiennosc")

# W2 – Histogram czytelnikow
ts_czyt <- na.omit(get_series(R_pub_czyt))
p2 <- ggplot(data.frame(x=ts_czyt), aes(x=x)) +
  geom_histogram(bins=10, fill="#0072B2", color="white", alpha=0.85) +
  geom_vline(xintercept=mean(ts_czyt), color="#D55E00", linewidth=1.2, linetype="dashed") +
  annotate("text", x=mean(ts_czyt)*1.02, y=3.8, hjust=0, color="#D55E00", size=3.5,
           label=paste0("Srednia:\n",format(round(mean(ts_czyt)),big.mark=" "))) +
  scale_x_continuous(labels=label_number(big.mark=" ")) +
  labs(title="Rozklad liczby czytelnikow bibliotek publicznych w Radomiu",
       subtitle="Dane roczne 2000-2024 (histogram)",
       x="Liczba czytelnikow (os.)", y="Liczba lat",
       caption="Zrodlo: GUS / BDL")
save_plot(p2, "W02_histogram_czytelnicy")

# W3 – Komputeryzacja: 5 kategorii
comp_labels <- c("Komputery ogólem","Dla pracownikow","Z int.","Dla czytelnikow","Dla czyt. int.")
comp_rows   <- c(R_komp_ogol, R_komp_prac, R_komp_int, R_komp_czyt, R_komp_czyt+1)
comp_df <- do.call(rbind, lapply(seq_along(comp_rows), function(i) mk_ts(comp_rows[i], comp_labels[i])))
comp_df <- comp_df[!is.na(comp_df$wartosc), ]

p3 <- ggplot(comp_df, aes(x=rok, y=wartosc, color=seria, linetype=seria)) +
  geom_line(linewidth=0.9) + geom_point(size=1.8) +
  scale_color_manual(values=cb7[1:5], name="Rodzaj") +
  scale_linetype_manual(values=c("solid","dashed","dotdash","twodash","longdash"), name="Rodzaj") +
  scale_x_continuous(breaks=seq(2000,2024,by=4)) +
  labs(title="Komputeryzacja bibliotek publicznych w Radomiu",
       subtitle="Liczba komputerow wedlug przeznaczenia",
       x="Rok", y="Liczba komputerow (szt.)",
       caption="Zrodlo: GUS / BDL") +
  guides(color=guide_legend(nrow=2), linetype=guide_legend(nrow=2))
save_plot(p3, "W03_komputeryzacja")

# W4 – Heatmapa
vars_heat <- list("Czytelnicy"=R_pub_czyt, "Wypozyczenia"=R_pub_wyp,
                  "Ksiegozbiór"=R_pub_ksieg, "Pracownicy"=R_pub_prac,
                  "Komputery"=R_komp_ogol, "Zbiory spec."=R_pub_spec)
heat_df <- do.call(rbind, lapply(names(vars_heat), function(nm) {
  v <- get_series(vars_heat[[nm]])
  r <- range(v, na.rm=TRUE)
  vn <- if (diff(r)==0) rep(0,length(v)) else (v-r[1])/diff(r)
  data.frame(rok=lata_int, wartosc=vn, zmienna=nm)
}))
heat_df <- heat_df[!is.na(heat_df$wartosc), ]
heat_df$zmienna <- factor(heat_df$zmienna, levels=rev(names(vars_heat)))

p4 <- ggplot(heat_df, aes(x=rok, y=zmienna, fill=wartosc)) +
  geom_tile(color="white", linewidth=0.3) +
  scale_fill_viridis_c(option="mako", name="Norm.",
                       breaks=c(0,0.5,1), labels=c("min","0.5","max")) +
  scale_x_continuous(breaks=seq(1995,2024,by=5)) +
  labs(title="Mapa ciepla dynamiki wskaznikow bibliotek publicznych – Radom",
       subtitle="Wartosci znormalizowane [0=min historyczne, 1=max historyczne] dla kazdej zmiennej osobno",
       x="Rok", y=NULL, caption="Zrodlo: GUS / BDL") +
  theme(axis.text.y=element_text(size=10))
save_plot(p4, "W04_heatmap", w=11, h=5)

# ============================================================
# GRUPA 2: WYKRESY PORÓWNAWCZE
# ============================================================

# W5 – Czytelnicy: pub vs inne
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

# W6 – Ksiegozbiór area
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

# W7 – Pracownicy grouped bar
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

# W8 – Podwojna os
czyt1000 <- get_series(R_czyt1000)
wyp_czyt <- get_series(R_wyp_czyt)
wsk_df <- data.frame(rok=lata_int, c1=czyt1000, wc=wyp_czyt)
wsk_df <- wsk_df[!is.na(wsk_df$c1) & !is.na(wsk_df$wc), ]
sf <- max(wsk_df$c1,na.rm=TRUE)/max(wsk_df$wc,na.rm=TRUE)

p8 <- ggplot(wsk_df, aes(x=rok)) +
  geom_col(aes(y=c1), fill="#56B4E9", alpha=0.75) +
  geom_line(aes(y=wc*sf), color="#D55E00", linewidth=1.2) +
  geom_point(aes(y=wc*sf), color="#D55E00", size=2.2) +
  scale_y_continuous(name="Czytelnicy na 1000 ludnosci (os.)",
    sec.axis=sec_axis(~./sf, name="Wypozyczenia na 1 czytelnika (wol.)")) +
  scale_x_continuous(breaks=seq(2000,2024,by=4)) +
  labs(title="Wskazniki aktywnosci czytelniczej w bibl. publicznych Radomia",
       subtitle="Slupki (nieb.): czytelnicy/1000 mieszkancow | Linia (pom.): wypozyczenia na 1 czytelnika",
       x="Rok", caption="Zrodlo: GUS / BDL")
save_plot(p8, "W08_wskazniki_dual_axis")

# W9 – Udostepnianie: stacked area
ud_df <- data.frame(rok=lata_int,
                    Na_zewnatrz=get_series(R_ud_zewn), Na_miejscu=get_series(R_ud_miej))
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

# W10 – Komputery: pub vs naukowe
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

# W11 – Zbiory specjalne
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
# GRUPA 3: WYKRESY WEDLUG UZNANIA
# ============================================================

# W12 – Trend wypozyczen z COVID
wyp_ts <- data.frame(rok=lata_int, val=get_series(R_pub_wyp))
wyp_ts <- wyp_ts[!is.na(wyp_ts$val), ]
p12 <- ggplot(wyp_ts, aes(x=rok, y=val/1000)) +
  annotate("rect", xmin=2019.5, xmax=2021.5, ymin=-Inf, ymax=Inf,
           fill="#CC79A7", alpha=0.15) +
  annotate("text", x=2020.5, y=max(wyp_ts$val/1000)*0.98,
           label="COVID-19", size=3.2, color="#CC79A7", fontface="italic") +
  geom_ribbon(aes(ymin=min(val/1000), ymax=val/1000), fill="#56B4E9", alpha=0.2) +
  geom_line(color="#0072B2", linewidth=1.2) + geom_point(color="#0072B2", size=2) +
  geom_smooth(method="loess", span=0.5, se=FALSE,
              color="#D55E00", linewidth=1, linetype="dashed") +
  scale_x_continuous(breaks=seq(2000,2024,by=4)) +
  scale_y_continuous(labels=label_number(suffix=" tys.")) +
  labs(title="Trend wypozyczen zewnetrznych bibliotek publicznych – Radom",
       subtitle="Linia ciagla: dane | Przerywana: LOESS | Rozowy obszar: pandemia COVID-19",
       x="Rok", y="Wypozyczenia (tys. wol.)", caption="Zrodlo: GUS / BDL")
save_plot(p12, "W12_wypozyczenia_trend")

# W13 – Scatter czytelnicy vs wypozyczenia
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

# W14 – Ksiegozbiór na 1000 ludnosci
ksieg_df <- data.frame(rok=lata_int, val=get_series(R_ksieg1000))
ksieg_df <- ksieg_df[!is.na(ksieg_df$val), ]
p14 <- ggplot(ksieg_df, aes(x=rok, y=val, fill=val)) +
  geom_col(alpha=0.92) +
  geom_hline(yintercept=mean(ksieg_df$val,na.rm=TRUE),
             color="#D55E00", linewidth=1.1, linetype="dashed") +
  annotate("text", x=min(ksieg_df$rok)+2, y=mean(ksieg_df$val,na.rm=TRUE)*1.02,
           label=paste0("Srednia: ",round(mean(ksieg_df$val,na.rm=TRUE),0)," wol./1000"),
           color="#D55E00", size=3.3, hjust=0) +
  scale_fill_gradient2(low="#56B4E9", mid="#E69F00", high="#0072B2",
                       midpoint=median(ksieg_df$val,na.rm=TRUE), name="Wol./1000") +
  scale_x_continuous(breaks=seq(2000,2024,by=4)) +
  labs(title="Ksiegozbiór bibliotek publicznych na 1000 ludnosci Radomia",
       subtitle="Liczba woluminów przypadajacych na 1000 mieszkancow",
       x="Rok", y="Woluminy na 1000 ludnosci", caption="Zrodlo: GUS / BDL") +
  theme(legend.position="right")
save_plot(p14, "W14_ksieg_na_1000")

# W15 – Dostepnosc dla niepelnosprawnych
np_df <- data.frame(rok=lata_int,
                    Wejscie=get_series(R_niepeln_wej),
                    Wewnatrz=get_series(R_niepeln_wew))
np_df <- np_df[!is.na(np_df$Wejscie) | !is.na(np_df$Wewnatrz), ]
np_long <- melt(np_df, id.vars="rok", variable.name="typ", value.name="liczba")
np_long$typ <- factor(np_long$typ, levels=c("Wejscie","Wewnatrz"),
                      labels=c("Wejscie do budynku","Udogodnienia wewnatrz"))
np_long <- np_long[!is.na(np_long$liczba), ]
p15 <- ggplot(np_long, aes(x=rok, y=liczba, fill=typ)) +
  geom_col(alpha=0.9) +
  scale_fill_manual(values=c("#0072B2","#E69F00"), name="Typ udogodnienia") +
  scale_x_continuous(breaks=seq(2000,2024,by=4)) +
  labs(title="Dostepnosc bibliotek publicznych dla osób niepelnosprawnych – Radom",
       subtitle="Liczba obiektów przystosowanych dla uzytkownikow wózkow inwalidzkich",
       x="Rok", y="Liczba obiektów", caption="Zrodlo: GUS / BDL")
save_plot(p15, "W15_niepelnosprawni")

message("GOTOWE: Wszystkie 15 wykresow zapisano.")
