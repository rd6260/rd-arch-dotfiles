use std::io::{self, BufRead, BufReader, Write};
use std::net::TcpStream;

#[derive(Debug, Clone, Copy, PartialEq)]
pub enum PlayState {
    Play,
    Pause,
    Stop,
}

#[derive(Debug, Clone)]
pub struct MpdStatus {
    pub state: PlayState,
    pub elapsed: f64,
    pub duration: f64,
    pub songid: Option<u32>,
}

#[derive(Debug, Clone)]
pub struct MpdSong {
    pub file: String,
    pub artist: String,
    pub title: String,
    pub album: String,
    pub duration: f64,
}

pub struct MpdConnection {
    reader: BufReader<TcpStream>,
    writer: TcpStream,
}

impl MpdConnection {
    pub fn connect(addr: &str) -> io::Result<Self> {
        let stream = TcpStream::connect(addr)?;
        let writer = stream.try_clone()?;
        let mut reader = BufReader::new(stream);

        let mut greeting = String::new();
        reader.read_line(&mut greeting)?;
        if !greeting.starts_with("OK MPD") {
            return Err(io::Error::new(
                io::ErrorKind::InvalidData,
                "Invalid MPD greeting",
            ));
        }

        Ok(Self { reader, writer })
    }

    fn read_response(&mut self) -> io::Result<Vec<(String, String)>> {
        let mut pairs = Vec::new();
        loop {
            let mut line = String::new();
            if self.reader.read_line(&mut line)? == 0 {
                return Err(io::Error::new(
                    io::ErrorKind::UnexpectedEof,
                    "Connection closed",
                ));
            }
            let line = line.trim_end();
            if line == "OK" {
                break;
            }
            if line.starts_with("ACK ") {
                return Err(io::Error::new(io::ErrorKind::Other, line.to_string()));
            }

            if let Some(idx) = line.find(": ") {
                let key = line[..idx].to_string();
                let value = line[idx + 2..].to_string();
                pairs.push((key, value));
            }
        }
        Ok(pairs)
    }

    pub fn status(&mut self) -> io::Result<MpdStatus> {
        self.writer.write_all(b"status\n")?;
        let pairs = self.read_response()?;
        
        let mut state = PlayState::Stop;
        let mut elapsed = 0.0;
        let mut duration = 0.0;
        let mut songid = None;

        for (k, v) in pairs {
            match k.as_str() {
                "state" => {
                    state = match v.as_str() {
                        "play" => PlayState::Play,
                        "pause" => PlayState::Pause,
                        _ => PlayState::Stop,
                    };
                }
                "elapsed" => {
                    elapsed = v.parse().unwrap_or(0.0);
                }
                "duration" => {
                    duration = v.parse().unwrap_or(0.0);
                }
                "songid" => {
                    songid = v.parse().ok();
                }
                _ => {}
            }
        }

        Ok(MpdStatus {
            state,
            elapsed,
            duration,
            songid,
        })
    }

    pub fn currentsong(&mut self) -> io::Result<Option<MpdSong>> {
        self.writer.write_all(b"currentsong\n")?;
        let pairs = self.read_response()?;
        
        if pairs.is_empty() {
            return Ok(None);
        }

        let mut file = String::new();
        let mut artist = String::new();
        let mut title = String::new();
        let mut album = String::new();
        let mut duration = 0.0;

        for (k, v) in pairs {
            match k.as_str() {
                "file" => file = v,
                "Artist" => artist = v,
                "Title" => title = v,
                "Album" => album = v,
                "duration" => duration = v.parse().unwrap_or(0.0),
                _ => {}
            }
        }

        Ok(Some(MpdSong {
            file,
            artist,
            title,
            album,
            duration,
        }))
    }

    pub fn idle(&mut self, subsystem: &str) -> io::Result<Vec<String>> {
        let cmd = format!("idle {}\n", subsystem);
        self.writer.write_all(cmd.as_bytes())?;
        let pairs = self.read_response()?;
        
        let mut events = Vec::new();
        for (k, v) in pairs {
            if k == "changed" {
                events.push(v);
            }
        }
        Ok(events)
    }
}
