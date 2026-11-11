use std::error::Error;
use std::io::{Read, Write};
use std::net::TcpStream;
use std::sync::Arc;

fn url_encode(s: &str) -> String {
    let mut out = String::new();
    for byte in s.bytes() {
        match byte {
            b'A'..=b'Z' | b'a'..=b'z' | b'0'..=b'9' | b'-' | b'_' | b'.' | b'~' => {
                out.push(byte as char);
            }
            b' ' => out.push_str("%20"),
            _ => out.push_str(&format!("%{:02X}", byte)),
        }
    }
    out
}

fn decode_chunked(body: &[u8]) -> Vec<u8> {
    let mut decoded = Vec::new();
    let mut pos = 0;
    while pos < body.len() {
        let mut end = pos;
        while end < body.len() && body[end] != b'\r' {
            end += 1;
        }
        if end >= body.len() || end + 1 >= body.len() || body[end + 1] != b'\n' {
            break; // malformed
        }
        
        let hex_str = std::str::from_utf8(&body[pos..end]).unwrap_or("");
        let size = usize::from_str_radix(hex_str.trim(), 16).unwrap_or(0);
        
        if size == 0 {
            break;
        }
        
        pos = end + 2; // skip \r\n
        if pos + size > body.len() {
            break; // malformed
        }
        decoded.extend_from_slice(&body[pos..pos + size]);
        pos += size;
        
        if pos + 1 < body.len() && body[pos] == b'\r' && body[pos + 1] == b'\n' {
            pos += 2;
        } else {
            break;
        }
    }
    decoded
}

pub fn fetch_synced_lyrics(
    artist: &str,
    title: &str,
    album: &str,
    duration_secs: f64,
) -> Result<Option<String>, Box<dyn Error>> {
    let mut root_store = rustls::RootCertStore::empty();
    root_store.extend(webpki_roots::TLS_SERVER_ROOTS.iter().cloned());
    let config = Arc::new(
        rustls::ClientConfig::builder()
            .with_root_certificates(root_store)
            .with_no_client_auth(),
    );

    let server_name = "lrclib.net".try_into()?;
    let conn = rustls::ClientConnection::new(config, server_name)?;
    let sock = TcpStream::connect("lrclib.net:443")?;
    let mut stream = rustls::StreamOwned::new(conn, sock);

    let artist_enc = url_encode(artist);
    let title_enc = url_encode(title);
    let album_enc = url_encode(album);
    let dur_int = duration_secs as u64;

    let path = format!(
        "/api/get?artist_name={}&track_name={}&album_name={}&duration={}",
        artist_enc, title_enc, album_enc, dur_int
    );

    let request = format!(
        "GET {} HTTP/1.1\r\n\
         Host: lrclib.net\r\n\
         User-Agent: synced-lyrics/0.1.0\r\n\
         Accept: application/json\r\n\
         Connection: close\r\n\
         \r\n",
        path
    );

    stream.write_all(request.as_bytes())?;

    let mut response = Vec::new();
    stream.read_to_end(&mut response)?;

    // Parse HTTP response
    let header_end = response
        .windows(4)
        .position(|w| w == b"\r\n\r\n")
        .ok_or("Invalid HTTP response")?;

    let headers_str = std::str::from_utf8(&response[..header_end])?;
    let body_raw = &response[header_end + 4..];

    if headers_str.starts_with("HTTP/1.1 404") {
        return Ok(None);
    }

    let is_chunked = headers_str.contains("Transfer-Encoding: chunked") || headers_str.contains("transfer-encoding: chunked");
    let body = if is_chunked {
        decode_chunked(body_raw)
    } else {
        body_raw.to_vec()
    };

    let json: serde_json::Value = serde_json::from_slice(&body)?;
    
    if let Some(synced) = json.get("syncedLyrics") {
        if synced.is_string() {
            return Ok(Some(synced.as_str().unwrap().to_string()));
        }
    }

    Ok(None)
}
