# BLM4522 — Proje 2: Veritabanı Yedekleme ve Felaketten Kurtarma

> 22290742 - ŞEVVAL ENSARİOĞLU  
> **Video Linki:** *https://youtu.be/CULaZNqfJI8?si=M72rQseGR3YZReDx*

---

## Proje Hakkında

Bu projede Northwind PostgreSQL veritabanı üzerinde kapsamlı bir yedekleme ve felaketten kurtarma (Disaster Recovery) altyapısı kurulmuştur. Yedekleme geçmişi, felaket senaryoları, point-in-time restore mantığı ve veritabanı mirroring simülasyonu SQL üzerinden gerçeklenmiştir.

| Konu | Açıklama |
|------|----------|
| **Yedek Altyapısı** | `backup_dr` şeması altında yedekleme geçmişi ve recovery point tabloları |
| **Yedekleme Çeşitleri** | Tablo kopyalama yöntemiyle TAM yedek, trigger ile log bazlı ARTIK/FARK yedekleme simülasyonu |
| **Felaket Senaryosu** | Sipariş silinmesi (DELETE) ve fiyat bozulması gibi durumların canlandırılması |
| **Point-in-Time Restore** | Veriyi istenilen belirli bir ana / recovery point'e geri döndürme |
| **Doğrulama ve Mirroring** | Yedek veri sayısı doğrulaması ve Database Mirroring simülasyonu |

---

## Kullanılan Araçlar

| Araç | Sürüm | Açıklama |
|------|-------|----------|
| PostgreSQL | 17 | Ana veritabanı sistemi |
| DBeaver | 25.2.4 | Veritabanı yönetim arayüzü |
| PL/pgSQL | — | Trigger ve prosedürel işlemler |
| Northwind DB | — | Örnek veritabanı |

---

## Proje Yapısı

```
blm4522-proje2-db-backup-and-recovery/
│
├── README.md
├── rapor/
│   └── rapor.pdf
├── sql/
│   ├── 01_altyapi_ve_tablolar.sql       ← Şema, yedek geçmişi, değişiklik log tabloları
│   ├── 02_tam_ve_artik_yedekleme.sql    ← Tam yedek tabloları ve Log Trigger'ları
│   ├── 03_felaket_senaryolari.sql       ← Veri silme, PITR testleri ve veriyi geri yükleme
│   └── 04_dogrulama_ve_raporlama.sql    ← Yedek doğrulaması, Mirroring ve Raporlar
└── ekran_goruntuleri/
```

---

## Yapılan Çalışmalar

### 1. Yedek Altyapısı (`01_altyapi_ve_tablolar.sql`)

Tüm yedekleme ve kurtarma tabloları `backup_dr` şeması altında toplanmıştır. 
- **`backup_history`**: Alınan yedeklerin zamanı ve açıklaması tutulur.
- **`recovery_points`**: Özel durumlardan önce alınan anlık durum isimlerini tutar.
- **`incremental_change_log`**: Artık yedekleme simülasyonu için tablo değişikliklerini loglar.

### 2. Tam ve Artık Yedekleme (`02_tam_ve_artik_yedekleme.sql`)

Tam yedekler tabloların kopyalanması şeklinde (`_full_backup` sonekiyle) simüle edilmiştir. 
Artık ve fark yedekler ise PostgreSQL **Trigger** mekanizmalarıyla (INSERT/UPDATE/DELETE loglanması) sağlanmıştır:
- `products`, `orders` ve `order_details` tablolarına trigger eklenerek tüm değişimler `incremental_change_log` tablosuna `JSONB` formatında yazılır.

### 3. Felaket Senaryoları ve Kurtarma (`03_felaket_senaryolari.sql`)

Kazayla veya kasıtlı veri silinmelerine karşı senaryolar işletilmiştir:
1. **Yanlışlıkla Sipariş Silinmesi**: `order_id = 10248` kaydı `orders` ve `order_details` tablolarından silinir. Ardından tam yedek üzerinden kontrol edilerek kayıp veriler tabloya tekrar `INSERT` edilir.
2. **Point-In-Time Restore (PITR) Mantığı**: Hatalı bir `UPDATE` sonrası (fiyatın 999 yapılması) veriler, belirlenen bir yedeğe (`products_pitr_demo`) bakılarak eski, güvenilir haline (`UPDATE ... FROM ...`) geri çekilir.

### 4. Doğrulama ve Raporlama (`04_dogrulama_ve_raporlama.sql`)

- **Yedek Doğrulama**: Orijinal tablolar (`products`, `orders`) ile yedek tabloların satır sayıları (`COUNT`) karşılaştırılarak `VALID` veya `CHECK REQUIRED` durumu raporlanır.
- **Database Mirroring Simülasyonu**: `mirror_db` isimli ayrı bir şema açılarak verilerin replike edilmesi (ayna kopyasının tutulması) sağlanır.
- **Raporlama**: `backup_history`, `recovery_points` ve `incremental_change_log` tabloları sorgulanarak geçmişte yapılan tüm işlemler tek ekranda listelenir.
