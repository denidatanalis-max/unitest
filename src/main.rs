use axum::{
    extract::{OriginalUri, Path},
    http::StatusCode,
    response::{Html},
    routing::get,
    Router,
};

const HALAMAN_404: &str = include_str!("../templates/404.html");

#[tokio::main]
async fn main() {
    let app = routes();

    let listener = tokio::net::TcpListener::bind("127.0.0.1:9200")
        .await
        .unwrap();
    println!("listening on http://{}", listener.local_addr().unwrap());
    axum::serve(listener, app).await.unwrap();
}

fn routes() -> Router {
    Router::new()
        .route("/", get(home))
        .route("/about", get(about))
        .route("/halo/{nama}", get(halo))
        .route("/kali/{angka01}/{angka02}", get(kali))
        .fallback(not_found)
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