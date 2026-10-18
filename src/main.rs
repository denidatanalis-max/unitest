use axum::{
    extract::{OriginalUri, Path, State},
    http::StatusCode,
    response::{Html},
    routing::get,
    Router,
};
use sqlx::{postgres::PgPoolOptions, PgPool};


const HALAMAN_404: &str = include_str!("../templates/404.html");

#[tokio::main]
async fn main() {
    // Alamat database dibaca dari environment.
    // Di VPS, isinya dioper systemd dari /etc/myunitest.env.
    let database_url = std::env::var("DATABASE_URL")
        .expect("DATABASE_URL belum di-set");

    // Pool = kumpulan koneksi yang dipakai bergantian oleh semua request.
    let db = PgPoolOptions::new()
        .max_connections(5)
        .connect(&database_url)
        .await
        .expect("gagal konek ke PostgreSQL VPS");

    let app = routes(db);

    let listener = tokio::net::TcpListener::bind("127.0.0.1:9200")
        .await
        .unwrap();
    println!("listening on http://{}", listener.local_addr().unwrap());
    axum::serve(listener, app).await.unwrap();
}


fn routes(db: PgPool) -> Router {
    Router::new()
        .route("/", get(home))
        .route("/about", get(about))
        .route("/halo/{nama}", get(halo))
        .route("/kali/{angka01}/{angka02}", get(kali))
        .route("/db/vps", get(cek_vps))
        .fallback(not_found)
        .with_state(db)
}



async fn not_found(
    OriginalUri(uri): OriginalUri,
) -> (StatusCode, Html<String>) {
    let url = urlencoding::decode(uri.path())
        .unwrap_or_else(|_| uri.path().into());

    let safe_url = url
        .replace('&', "&amp;")
        .replace('<', "&lt;")
        .replace('>', "&gt;")
        .replace('"', "&quot;")
        .replace('\'', "&#39;");

    let html = HALAMAN_404.replace("{{URL}}", &safe_url);

    (StatusCode::NOT_FOUND, Html(html))
}


async fn home() -> &'static str {
    "anda di beranda!"
}

async fn about() -> &'static str {
    "anda di about"
}

async fn halo(Path(nama): Path<String>) -> String {
    format!("Halo, {nama}!")
}

async fn kali(Path((angka01, angka02)): Path<(i32, i32)>) -> String {
    match angka01.checked_mul(angka02) {
        Some(hasil) => format!("hasil: {hasil} = {angka01} * {angka02}"),
        None => "Error: hasil perkalian melebihi batas i32".to_string(),
    }
}

async fn cek_vps(State(db): State<PgPool>) -> (StatusCode, String) {
    let hasil = sqlx::query_scalar::<_, String>("select now()::text")
        .fetch_one(&db)
        .await;

    match hasil {
        Ok(jam) => (StatusCode::OK, format!("VPS terhubung. Jam database: {jam}")),
        Err(e) => {
            // Detail error hanya ke log (journalctl), tidak ke pengunjung.
            eprintln!("cek_vps gagal: {e}");
            (StatusCode::INTERNAL_SERVER_ERROR, "Database VPS tidak bisa dihubungi".to_string())
        }
    }
}
