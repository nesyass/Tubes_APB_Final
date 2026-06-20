# Daftar Pertanyaan & Jawaban Presentasi Backend (Flutter & SQLite)
**Aplikasi:** Expert Printing (Tugas Besar Aplikasi Perangkat Bergerak)

Berikut adalah daftar kemungkinan pertanyaan yang akan ditanyakan oleh dosen/penguji terkait implementasi *backend* (database lokal) beserta panduan jawabannya, yang sudah disesuaikan dengan file `DatabaseHelper` milikmu:

---

### 1. Pertanyaan Arsitektur Dasar
**Q: Kenapa kamu menggunakan SQLite untuk backend aplikasi ini, kenapa tidak menggunakan Firebase atau API (MySQL)?**

**Jawaban yang disarankan:** 
"Untuk lingkup Tugas Besar ini, kami fokus mendemonstrasikan kapabilitas penyimpanan data lokal (*on-device storage*) secara terstruktur dan relasional. SQLite sangat ringan, cepat, bekerja tanpa koneksi internet (offline-first), dan memungkinkan kami untuk merancang skema database SQL yang kompleks seperti relasi *many-to-many*. Namun secara arsitektur, karena kami sudah memisahkan *logic* database di dalam `DatabaseHelper` dan Model yang rapi, project ini akan sangat mudah di-scale/migrasi ke REST API di masa depan."

---

### 2. Pertanyaan Manajemen Koneksi (Penting!)
**Q: Bagaimana cara kamu memastikan tidak terjadi kebocoran memori (memory leak) atau aplikasi melambat karena terlalu banyak membuka koneksi database?**

**Jawaban yang disarankan:**
"Saya menerapkan pola **Singleton Pattern** pada kelas `DatabaseHelper` (menggunakan `static final _instance` dan `factory`). Ini memastikan bahwa sepanjang siklus hidup aplikasi, hanya ada **satu instance koneksi database** yang aktif dan digunakan bersama-sama oleh semua fitur. Jadi setiap kali UI meminta data, mereka menggunakan koneksi yang sama tanpa membuka koneksi baru."

---

### 3. Pertanyaan Skema & Relasi Database
**Q: Coba jelaskan bagaimana relasi antar tabel di databasemu, terutama antara Layanan (Services) dan Cabang (Branches)?**

**Jawaban yang disarankan:**
"Database ini menggunakan arsitektur relasional dengan *Foreign Key*. Untuk `services` dan `branches`, karena satu layanan bisa ada di banyak cabang dan satu cabang punya banyak layanan, saya menggunakan relasi **Many-to-Many**. Relasi ini dijembatani oleh tabel pivot bernama `service_branches`. 
Selain itu, saya menggunakan konstrain `ON DELETE CASCADE` di hampir semua *Foreign Key* (misal: `cart_items` ke `users`). Artinya jika suatu user dihapus, maka semua isi keranjang (*cart*) miliknya akan otomatis terhapus dari database tanpa perlu *query* manual, sehingga menjaga integritas data."

---

### 4. Pertanyaan Keamanan Data (Transaksi)
**Q: Saat user melakukan Checkout, data disimpan ke tabel `orders` dan `order_items`. Bagaimana kalau aplikasi error/crash tepat saat sedang menyimpan `order_items`? Apakah datanya tidak sinkron?**

**Jawaban yang disarankan:**
"Untuk mencegah hal tersebut, pada method `insertOrder` saya membungkus proses insert ke dalam **Transaction** (`db.transaction`). Jika proses insert ke tabel `orders` berhasil, namun insert ke `order_items` tiba-tiba gagal, maka SQLite akan secara otomatis melakukan **Rollback** (membatalkan insert ke `orders`). Hal ini menjamin prinsip *Atomicity*—data akan disimpan semuanya, atau tidak sama sekali. Tidak akan ada data *order* yang 'yatim' tanpa *item*."

---

### 5. Pertanyaan Migrasi & Skema Update
**Q: Apa yang terjadi kalau sewaktu-waktu kamu perlu menambah fitur baru yang butuh tabel baru atau menambah kolom di tabel lama? Bagaimana cara aplikasinya update database?**

**Jawaban yang disarankan:**
"Saya mengaturnya menggunakan mekanisme versi database. Saat inisialisasi di `openDatabase`, saya mendefinisikan parameter `version`. Jika versi ini saya naikkan, SQLite akan memicu fungsi `onUpgrade`. 
Untuk fase *development* saat ini, jika `onUpgrade` terpanggil, saya men-drop (`DROP TABLE IF EXISTS`) semua tabel dan membuatnya ulang agar strukturnya bersih. Namun untuk fase *production* nanti, di dalam `onUpgrade` saya tinggal menjalankan perintah `ALTER TABLE` agar data user lama tidak hilang."

---

### 6. Pertanyaan Pengisian Data Awal
**Q: Saat aplikasi baru pertama kali diinstal di device dosen, darimana asal data-data cabang, layanan print, dan data dummy lainnya?**

**Jawaban yang disarankan:**
"Saya mengimplementasikan fitur *Database Seeder*. Di dalam `DatabaseHelper`, setelah semua tabel selesai di-*create* (via event `onCreate`), aplikasi akan secara otomatis memanggil method `_seedData()`. Method ini akan melakukan eksekusi *insert* data-data *dummy* seperti User, Service (Print Booklet, Poster), dan daftar Cabang (Dago, Buah Batu). Hal ini memudahkan *testing* karena data sudah siap pakai (siap presentasi) saat aplikasi pertama kali dijalankan."

---

### 7. Pertanyaan Autentikasi
**Q: Bagaimana cara kamu menangani Login dan Register di aplikasi ini? Apakah aman?**

**Jawaban yang disarankan:**
"Untuk prototipe ini, saya menggunakan tabel `users` lokal dengan kolom email dan password, lalu menggunakan *query SELECT* biasa (pencocokan `WHERE email = ? AND password = ?`) di method `getUserByEmailAndPassword()`. Ini sudah cukup fungsional untuk mendemonstrasikan sistem *auth* dan pengelolaan *session* pengguna secara offline. Namun saya sadar bahwa sebagai *best practice* di dunia nyata, autentikasi tidak boleh menggunakan *plain-text* dan password harus melalui proses *hashing*."

---

### 💡 Tips Tambahan untuk Presentasi:
1. **Pahami letak baris kodenya:** Jika ditanya tentang **Transaksi**, buka file `database_helper.dart` arahkan ke method `insertOrder` (sekitar baris ke-332).
2. **Pahami letak relasinya:** Jika ditanya **ON DELETE CASCADE**, tunjukkan *query* `CREATE TABLE` di method `_createTables`.
3. **Seeder:** Kalau aplikasi sempat di-install ulang / *uninstall* di emulator/HP sebelum demo, jangan panik, datanya akan terisi ulang otomatis berkat fungsi *seeder* (`_seedData`).
