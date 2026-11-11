mod lrc;
mod lrclib;
mod mpd;

use mpd::{MpdConnection, PlayState};
use serde::Serialize;
use std::env;
use std::error::Error;
use std::io::Write;
use std::sync::mpsc;
use std::thread;
use std::time::{Duration, Instant};

#[derive(Serialize)]
#[serde(tag = "type")]
enum Event {
    #[serde(rename = "lyric")]
    Lyric {
        text: String,
        index: usize,
        total: usize,
    },
    #[serde(rename = "song")]
    Song { title: String, artist: String },
    #[serde(rename = "state")]
    State { playing: bool },
    #[serde(rename = "clear")]
    Clear {},
}

fn emit(event: &Event) {
    let stdout = std::io::stdout();
    let mut out = stdout.lock();
    if let Ok(json) = serde_json::to_string(event) {
        let _ = writeln!(out, "{}", json);
        let _ = out.flush();
    }
}

fn find_active_line(lyrics: &[lrc::LrcLine], current_ms: u64) -> Option<usize> {
    let idx = lyrics.partition_point(|l| l.time_ms <= current_ms);
    if idx > 0 {
        Some(idx - 1)
    } else {
        None
    }
}

fn get_cache_path(artist: &str, title: &str) -> std::path::PathBuf {
    let mut path = if let Ok(home) = std::env::var("HOME") {
        std::path::PathBuf::from(home)
    } else {
        std::path::PathBuf::from(".")
    };
    path.push(".lrc");
    std::fs::create_dir_all(&path).ok();
    
    let safe_artist = artist.replace('/', "_");
    let safe_title = title.replace('/', "_");
    path.push(format!("{} - {}.lrc", safe_artist, safe_title));
    path
}

struct FetchResult {
    songid: u32,
    lyrics: Vec<lrc::LrcLine>,
}

fn fetch_song_lyrics(
    conn: &mut MpdConnection,
    songid: Option<u32>,
    fetch_tx: mpsc::Sender<FetchResult>,
) -> Vec<lrc::LrcLine> {
    let song = match conn.currentsong() {
        Ok(Some(s)) => s,
        _ => {
            emit(&Event::Clear {});
            return Vec::new();
        }
    };

    emit(&Event::Song {
        title: song.title.clone(),
        artist: song.artist.clone(),
    });

    let path = get_cache_path(&song.artist, &song.title);
    if let Ok(content) = std::fs::read_to_string(&path) {
        // Cache hit
        lrc::parse(&content)
    } else {
        if let Some(id) = songid {
            // Cache miss, spawn background fetch
            thread::spawn(move || {
                if let Ok(Some(synced_text)) = lrclib::fetch_synced_lyrics(&song.artist, &song.title, &song.album, song.duration) {
                    if !synced_text.is_empty() {
                        let _ = std::fs::write(&path, &synced_text);
                        let parsed = lrc::parse(&synced_text);
                        let _ = fetch_tx.send(FetchResult {
                            songid: id,
                            lyrics: parsed,
                        });
                    }
                }
            });
        }
        Vec::new()
    }
}

fn run(addr: &str) -> Result<(), Box<dyn Error>> {
    eprintln!("Connecting to MPD at {}...", addr);
    let mut cmd_conn = MpdConnection::connect(addr)?;
    let mut idle_conn = MpdConnection::connect(addr)?;
    eprintln!("Connected.");

    let (tx, rx) = mpsc::channel();
    let (fetch_tx, fetch_rx) = mpsc::channel::<FetchResult>();

    thread::spawn(move || {
        loop {
            match idle_conn.idle("player") {
                Ok(_) => {
                    if tx.send(()).is_err() {
                        break;
                    }
                }
                Err(_) => break,
            }
        }
    });

    let mut status = cmd_conn.status()?;
    let mut playing = status.state == PlayState::Play;
    let mut sync_elapsed_ms = (status.elapsed * 1000.0) as u64;
    let mut sync_instant = Instant::now();
    let mut current_songid = status.songid;

    emit(&Event::State { playing });

    let mut active_lyric_idx = None;
    let mut lyrics = fetch_song_lyrics(&mut cmd_conn, current_songid, fetch_tx.clone());

    loop {
        // Drain all pending MPD idle events
        if rx.try_recv().is_ok() {
            while rx.try_recv().is_ok() {}

            let new_status = cmd_conn.status()?;
            let new_playing = new_status.state == PlayState::Play;

            if new_playing != playing {
                playing = new_playing;
                emit(&Event::State { playing });
            }

            sync_elapsed_ms = (new_status.elapsed * 1000.0) as u64;
            sync_instant = Instant::now();

            if new_status.songid != current_songid {
                current_songid = new_status.songid;
                lyrics = fetch_song_lyrics(&mut cmd_conn, current_songid, fetch_tx.clone());
                active_lyric_idx = None;
            }
        }

        // Process any incoming background fetches
        while let Ok(result) = fetch_rx.try_recv() {
            if Some(result.songid) == current_songid {
                lyrics = result.lyrics;
                active_lyric_idx = None; // Force recalculation
            }
        }

        // Timing: find and emit the active lyric line
        if playing && !lyrics.is_empty() {
            let elapsed = sync_instant.elapsed();
            let current_ms = sync_elapsed_ms + elapsed.as_millis() as u64;
            let new_idx = find_active_line(&lyrics, current_ms);

            if new_idx != active_lyric_idx {
                active_lyric_idx = new_idx;
                match active_lyric_idx {
                    Some(idx) => emit(&Event::Lyric {
                        text: lyrics[idx].text.clone(),
                        index: idx,
                        total: lyrics.len(),
                    }),
                    None => emit(&Event::Clear {}),
                }
            }
        }

        thread::sleep(Duration::from_millis(16));
    }
}

fn main() {
    let host = env::var("MPD_HOST").unwrap_or_else(|_| "127.0.0.1".to_string());
    let port = env::var("MPD_PORT").unwrap_or_else(|_| "6600".to_string());
    let addr = format!("{}:{}", host, port);

    eprintln!("synced-lyrics daemon starting");
    loop {
        if let Err(e) = run(&addr) {
            eprintln!("Error: {}, reconnecting in 3s...", e);
            thread::sleep(Duration::from_secs(3));
        }
    }
}
